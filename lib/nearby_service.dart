import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nearby_chat_app/connection_service.dart';
import 'package:nearby_chat_app/game_state.dart';

/// Tic-Tac-Toe transport. Thin wrapper over the shared [ConnectionService]:
/// it keeps its own game streams but never owns the underlying link, so
/// leaving the game screen does not tear down Chat/Walkie connections.
class NearbyService {
  static const String serviceId = ConnectionService.serviceId;

  final ConnectionService _conn = ConnectionService.instance;

  String? _myPlayer; // "X" or "O"
  bool _isHost = false;
  LinkState _lastState = LinkState.idle;
  String? _lastStatus;
  List<String> _lastIds = const [];

  final List<String> discoveredEndpoints = [];
  final Map<String, String> endpointNames = {};

  TicTacToeState _gameState = TicTacToeState();

  final StreamController<TicTacToeState> _gameStateController =
      StreamController<TicTacToeState>.broadcast();
  Stream<TicTacToeState> get gameStateStream => _gameStateController.stream;

  final StreamController<String> _connectionStatusController =
      StreamController<String>.broadcast();
  Stream<String> get connectionStatusStream => _connectionStatusController.stream;

  final StreamController<List<String>> _discoveryController =
      StreamController<List<String>>.broadcast();
  Stream<List<String>> get discoveryStream => _discoveryController.stream;

  StreamSubscription<LinkSnapshot>? _snapSub;
  StreamSubscription<AppPayload>? _payloadSub;

  NearbyService() {
    _snapSub = _conn.snapshotStream.listen(_onSnapshot);
    _payloadSub = _conn.payloadStream.listen((payload) {
      if (payload.tag == ConnectionService.tagGame) _onGameData(payload.text);
    });
    // Replay the current link so listeners registered in initState see it.
    Future.microtask(() {
      if (_gameStateController.isClosed) return;
      _onSnapshot(_conn.snapshot);
    });
  }

  String? get myPlayer => _myPlayer;
  bool get isHost => _isHost;
  String? get currentEndpointId => _conn.connectedEndpointId;

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
      if (!_discoveryController.isClosed) _discoveryController.add(ids);
    }

    final status =
        snapshot.state == LinkState.connected ? 'Connected!' : snapshot.status;
    if (status != _lastStatus) {
      _lastStatus = status;
      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add(status);
      }
    }

    if (snapshot.state == LinkState.connected) {
      _isHost = snapshot.isHost;
      _myPlayer = snapshot.isHost ? 'X' : 'O';
    } else if (_lastState == LinkState.connected) {
      _myPlayer = null;
      _isHost = false;
    } else if (snapshot.state == LinkState.hosting) {
      _isHost = true;
      _myPlayer = 'X';
    } else if (snapshot.state == LinkState.discovering) {
      _isHost = false;
      _myPlayer = 'O';
    }

    final enteredConnected = snapshot.state == LinkState.connected &&
        _lastState != LinkState.connected;
    if (enteredConnected) {
      _gameState.reset();
      if (!_gameStateController.isClosed) _gameStateController.add(_gameState);
      if (snapshot.isHost) {
        _sendGameState();
      } else if (snapshot.isConnected) {
        // Joined an existing link: ask the host for the current board.
        _conn.sendGame(jsonEncode({'type': 'state_request'})).catchError((_) {});
      }
    }
    _lastState = snapshot.state;
  }

  // ------------------------------------------------------------ game events

  void _onGameData(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;

      if (json['type'] == 'move') {
        final row = json['row'] as int;
        final col = json['col'] as int;
        final player = json['player'] as String;
        _gameState.makeMove(row, col, player: player);
        if (!_gameStateController.isClosed) _gameStateController.add(_gameState);
      } else if (json['type'] == 'state') {
        _gameState = TicTacToeState.fromJson(json['state']);
        if (!_gameStateController.isClosed) _gameStateController.add(_gameState);
      } else if (json['type'] == 'state_request') {
        if (_isHost) _sendGameState();
      } else if (json['type'] == 'reset') {
        _gameState.reset();
        if (!_gameStateController.isClosed) _gameStateController.add(_gameState);
      }
    } catch (e) {
      debugPrint('Game payload parse error: $e');
    }
  }

  // ---------------------------------------------------------------- actions

  /// Start advertising (Host). Permission gate lives in ConnectionService.
  Future<bool> startAdvertising(String userName) => _conn.host(userName);

  /// Start discovery (Client).
  Future<bool> startDiscovery(String userName) => _conn.discover(userName);

  /// Request connection to a discovered endpoint.
  Future<void> requestConnection(String endpointId, String userName) =>
      _conn.connectTo(endpointId);

  Future<void> sendMove(int row, int col) async {
    if (_myPlayer == null || !_conn.isConnected) return;
    await _conn.sendGame(jsonEncode({
      'type': 'move',
      'row': row,
      'col': col,
      'player': _myPlayer,
    }));
  }

  Future<void> _sendGameState() async {
    if (!_conn.isConnected) return;
    await _conn.sendGame(jsonEncode({
      'type': 'state',
      'state': _gameState.toJson(),
    }));
  }

  Future<void> resetGame() async {
    _gameState.reset();
    if (!_gameStateController.isClosed) _gameStateController.add(_gameState);
    if (_conn.isConnected) {
      await _conn.sendGame(jsonEncode({'type': 'reset'}));
    }
  }

  /// Explicit user action: tears down the shared link.
  Future<void> disconnect() => _conn.disconnect();

  /// Leaves the game. Deliberately does NOT disconnect — the shared link
  /// belongs to the whole app, not to this screen.
  void dispose() {
    _snapSub?.cancel();
    _payloadSub?.cancel();
    _gameStateController.close();
    _connectionStatusController.close();
    _discoveryController.close();
  }
}
