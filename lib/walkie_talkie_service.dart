import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nearby_chat_app/audio_service.dart';
import 'package:nearby_chat_app/connection_service.dart';

/// Walkie Talkie transport. Thin wrapper over the shared [ConnectionService]:
/// it reuses the same link as Chat/Tic-Tac-Toe and only owns the audio side.
class WalkieTalkieService {
  final ConnectionService _conn = ConnectionService.instance;
  final AudioService _audioService = AudioService();

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  StreamSubscription<LinkSnapshot>? _snapSub;
  StreamSubscription<AppPayload>? _payloadSub;

  void Function(String, String)? _foundHook;
  bool _autoConnect = false;
  bool _wasConnected = false;
  String? _lastStatus;

  WalkieTalkieService() {
    _foundHook = (endpointId, name) {
      if (_autoConnect) _conn.connectTo(endpointId);
    };
    _conn.onEndpointFound = _foundHook;

    _snapSub = _conn.snapshotStream.listen(_onSnapshot);
    _payloadSub = _conn.payloadStream.listen((payload) {
      if (payload.tag == ConnectionService.tagAudio) {
        _audioService.playAudioFromBytes(payload.body);
        _emitStatus('Playing received audio...');
      }
    });
    // Replay the current link so listeners registered in initState see it.
    Future.microtask(() {
      if (_statusController.isClosed) return;
      _onSnapshot(_conn.snapshot);
    });
  }

  bool get isConnected => _conn.isConnected;
  String? get connectedEndpoint => _conn.connectedEndpointId;

  void _emitStatus(String status) {
    if (status == _lastStatus) return;
    _lastStatus = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  void _onSnapshot(LinkSnapshot snapshot) {
    if (snapshot.state == LinkState.connected) {
      _autoConnect = false;
      _wasConnected = true;
      _emitStatus('Connected!');
      if (!_connectionController.isClosed) _connectionController.add(true);
    } else {
      if (_wasConnected) {
        _wasConnected = false;
        if (!_connectionController.isClosed) _connectionController.add(false);
      }
      _emitStatus(snapshot.status);
    }
  }

  // ---------------------------------------------------------------- actions

  /// Start advertising (Host). Permission gate lives in ConnectionService.
  Future<bool> startAdvertising(String userName) {
    _autoConnect = false;
    return _conn.host(userName);
  }

  /// Start discovery (Client). Auto-connects to the first peer found.
  Future<bool> startDiscovery(String userName) {
    _autoConnect = true;
    return _conn.discover(userName);
  }

  /// Request connection to a discovered endpoint.
  Future<void> requestConnection(String endpointId, String userName) =>
      _conn.connectTo(endpointId);

  /// Push-to-talk: start recording.
  Future<void> startTalking() async {
    if (!_conn.isConnected) {
      _emitStatus('Not connected!');
      return;
    }
    await _audioService.startRecording();
    _emitStatus('Recording...');
  }

  /// Push-to-talk: stop recording and send the audio clip to the peer.
  Future<void> stopTalking() async {
    if (!_conn.isConnected) return;

    final audioPath = await _audioService.stopRecording();
    if (audioPath == null) {
      _emitStatus('Recording failed');
      return;
    }

    try {
      final file = File(audioPath);
      final bytes = await file.readAsBytes();
      await _conn.sendAudio(Uint8List.fromList(bytes));
      _emitStatus('Audio sent (${bytes.length} bytes)');
      await file.delete();
    } catch (e) {
      _emitStatus('Send failed: $e');
    }
  }

  /// Explicit user action: tears down the shared link.
  Future<void> disconnect() async {
    _autoConnect = false;
    await _conn.disconnect();
  }

  /// Leaves the walkie screen. Deliberately does NOT disconnect — the shared
  /// link belongs to the whole app, not to this screen.
  void dispose() {
    if (_conn.onEndpointFound == _foundHook) _conn.onEndpointFound = null;
    _snapSub?.cancel();
    _payloadSub?.cancel();
    _audioService.dispose();
    _statusController.close();
    _connectionController.close();
  }
}
