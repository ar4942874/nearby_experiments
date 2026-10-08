import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nearby_chat_app/connection_service.dart';
import 'package:nearby_chat_app/games/ludo/ludo_state.dart';

/// Ludo transport. Thin wrapper over the shared [ConnectionService] on
/// [ConnectionService.tagLudo]: it keeps its own game streams but never
/// owns the underlying link, so leaving the Ludo screen does not tear
/// down Chat / Walkie Talkie / Tic-Tac-Toe.
///
/// Wire protocol (JSON bodies on tag 4) — both peers run the same
/// [LudoState] engine, so only tiny action payloads cross the link:
///
/// - `{"type":"roll",  "player":n, "dice":n}`
/// - `{"type":"move",  "player":n, "piece":n, "dice":n}`
/// - `{"type":"pass",  "player":n}`
/// - `{"type":"reset"}`
/// - `{"type":"state", "v":n, "state":{...}}` — full snapshot; applied
///   only when its version is newer than the local one. Sent when a peer
///   (re)enters the screen and as a corrective reply when an action
///   fails local validation.
class LudoService {
  final ConnectionService _conn = ConnectionService.instance;

  final LudoState _state = LudoState();

  int? _myPlayer; // 0 = host, 1 = guest
  bool _isHost = false;
  LinkState _lastState = LinkState.idle;
  String? _lastStatus;
  List<String> _lastIds = const [];

  final List<String> discoveredEndpoints = [];
  final Map<String, String> endpointNames = {};

  final StreamController<LudoState> _stateCtrl =
      StreamController<LudoState>.broadcast();
  Stream<LudoState> get stateStream => _stateCtrl.stream;

  final StreamController<String> _statusCtrl =
      StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusCtrl.stream;

  final StreamController<List<String>> _discoveryCtrl =
      StreamController<List<String>>.broadcast();
  Stream<List<String>> get discoveryStream => _discoveryCtrl.stream;

  StreamSubscription<LinkSnapshot>? _snapSub;
  StreamSubscription<AppPayload>? _payloadSub;

  LudoService() {
    _snapSub = _conn.snapshotStream.listen(_onSnapshot);
    _payloadSub = _conn.payloadStream.listen((payload) {
      if (payload.tag == ConnectionService.tagLudo) _onLudoData(payload.text);
    });
    // Replay the current link so listeners registered in initState see it.
    Future.microtask(() {
      if (!_stateCtrl.isClosed) _onSnapshot(_conn.snapshot);
    });
  }

  int? get myPlayer => _myPlayer;
  bool get isHost => _isHost;
  LudoState get state => _state;

  /// Emits an immutable snapshot so listeners (and painters) can compare
  /// before/after values reliably.
  void _emitState() {
    if (!_stateCtrl.isClosed) _stateCtrl.add(_state.copy());
  }

  // ------------------------------------------------------------ link events

  void _onSnapshot(LinkSnapshot snapshot) {
    final ids = List<String>.from(snapshot.endpoints.keys);
    if (!listEquals(ids, _lastIds)) {
      _lastIds = ids;
      discoveredEndpoints
        ..clear()
        ..addAll(ids);
      endpointNames
        ..clear()
        ..addAll(snapshot.endpoints);
      if (!_discoveryCtrl.isClosed) _discoveryCtrl.add(ids);
    }

    final status =
        snapshot.state == LinkState.connected ? 'Connected!' : snapshot.status;
    if (status != _lastStatus) {
      _lastStatus = status;
      if (!_statusCtrl.isClosed) _statusCtrl.add(status);
    }

    if (snapshot.state == LinkState.connected) {
      _isHost = snapshot.isHost;
      _myPlayer = snapshot.isHost ? 0 : 1;
    } else if (_lastState == LinkState.connected) {
      _myPlayer = null;
      _isHost = false;
    } else if (snapshot.state == LinkState.hosting) {
      _isHost = true;
      _myPlayer = 0;
    } else if (snapshot.state == LinkState.discovering) {
      _isHost = false;
      _myPlayer = 1;
    }

    final enteredConnected = snapshot.state == LinkState.connected &&
        _lastState != LinkState.connected;
    if (enteredConnected) {
      // Start (or restart) the game locally, then tell the peer what we
      // have. If the peer is further along (it kept the game alive while
      // we were away) it replies with its newer state and we adopt it.
      _state.reset();
      _emitState();
      _sendState();
    }
    _lastState = snapshot.state;
  }

  // ------------------------------------------------------------ game events

  void _onLudoData(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      switch (json['type']) {
        case 'roll':
          final player = (json['player'] as num).toInt();
          final dice = (json['dice'] as num).toInt();
          if (!_state.roll(player, dice)) {
            debugPrint('Ludo: rejected remote roll $data');
            _sendState(); // offer our state; peer adopts if newer
            break;
          }
          _emitState();
          break;
        case 'move':
          final player = (json['player'] as num).toInt();
          final piece = (json['piece'] as num).toInt();
          final dice = (json['dice'] as num).toInt();
          if (!_state.move(player, piece, dice)) {
            debugPrint('Ludo: rejected remote move $data');
            _sendState();
            break;
          }
          _emitState();
          break;
        case 'pass':
          final player = (json['player'] as num).toInt();
          if (!_state.pass(player)) {
            debugPrint('Ludo: rejected remote pass $data');
            _sendState();
            break;
          }
          _emitState();
          break;
        case 'reset':
          _state.reset();
          _emitState();
          break;
        case 'state':
          final incoming = LudoState.fromJson(
            (json['state'] as Map).cast<String, dynamic>(),
          );
          if (incoming.version > _state.version) {
            debugPrint(
              'Ludo: adopting peer state v${incoming.version} '
              '(we were v${_state.version})',
            );
            _state
              ..reset()
              ..pieces[0].setAll(0, incoming.pieces[0])
              ..pieces[1].setAll(0, incoming.pieces[1])
              ..currentPlayer = incoming.currentPlayer
              ..dice = incoming.dice
              ..consecutiveSixes = incoming.consecutiveSixes
              ..winner = incoming.winner
              ..version = incoming.version;
            _emitState();
          }
          break;
        default:
          debugPrint('Ludo: unknown payload type ${json['type']}');
      }
    } catch (e) {
      debugPrint('Ludo payload parse error: $e');
    }
  }

  // ---------------------------------------------------------------- actions

  /// Rolls the dice (only when it is this player's turn to roll).
  Future<bool> rollDice(int value) async {
    final player = _myPlayer;
    if (player == null || !_conn.isConnected) return false;
    if (!_state.roll(player, value)) return false;
    _emitState();
    try {
      await _conn.sendLudo(jsonEncode({
        'type': 'roll',
        'player': player,
        'dice': value,
      }));
    } catch (_) {}
    return true;
  }

  /// Moves [piece] with the pending dice value.
  Future<bool> movePiece(int piece) async {
    final player = _myPlayer;
    if (player == null || !_conn.isConnected) return false;
    final dice = _state.dice;
    if (dice == null) return false;
    if (!_state.move(player, piece, dice)) return false;
    _emitState();
    try {
      await _conn.sendLudo(jsonEncode({
        'type': 'move',
        'player': player,
        'piece': piece,
        'dice': dice,
      }));
    } catch (_) {}
    return true;
  }

  /// Passes the turn (only valid when no piece can legally move).
  Future<bool> passTurn() async {
    final player = _myPlayer;
    if (player == null || !_conn.isConnected) return false;
    if (!_state.pass(player)) return false;
    _emitState();
    try {
      await _conn.sendLudo(jsonEncode({'type': 'pass', 'player': player}));
    } catch (_) {}
    return true;
  }

  /// Starts a new game on both devices.
  Future<void> resetGame() async {
    _state.reset();
    _emitState();
    try {
      await _conn.sendLudo(jsonEncode({'type': 'reset'}));
    } catch (_) {}
  }

  Future<void> _sendState() async {
    if (!_conn.isConnected) return;
    try {
      await _conn.sendLudo(jsonEncode({
        'type': 'state',
        'v': _state.version,
        'state': _state.toJson(),
      }));
    } catch (_) {}
  }

  /// Explicit user action: tears down the shared link.
  Future<void> disconnect() => _conn.disconnect();

  /// Leaves the game. Deliberately does NOT disconnect — the shared link
  /// belongs to the whole app, not to this screen.
  void dispose() {
    _snapSub?.cancel();
    _payloadSub?.cancel();
    _stateCtrl.close();
    _statusCtrl.close();
    _discoveryCtrl.close();
  }
}
