import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:nearby_chat_app/keep_alive_service.dart';
import 'package:nearby_chat_app/permission_service.dart';
import 'package:nearby_connections/nearby_connections.dart';

/// Lifecycle of the single shared Nearby link.
enum LinkState { idle, hosting, discovering, connected }

/// Immutable snapshot of the shared link, rebuilt on every change.
class LinkSnapshot {
  const LinkSnapshot({
    required this.state,
    required this.status,
    required this.isHost,
    this.deviceName,
    this.connectedEndpointId,
    this.connectedEndpointName,
    this.endpoints = const <String, String>{},
  });

  final LinkState state;
  final String status;
  final bool isHost;
  final String? deviceName;
  final String? connectedEndpointId;
  final String? connectedEndpointName;

  /// Endpoints discovered so far (id -> name). Cleared once connected.
  final Map<String, String> endpoints;

  bool get isConnected => state == LinkState.connected;

  LinkSnapshot copyWith({
    LinkState? state,
    String? status,
    bool? isHost,
    String? deviceName,
    String? connectedEndpointId,
    String? connectedEndpointName,
    Map<String, String>? endpoints,
  }) {
    return LinkSnapshot(
      state: state ?? this.state,
      status: status ?? this.status,
      isHost: isHost ?? this.isHost,
      deviceName: deviceName ?? this.deviceName,
      connectedEndpointId: connectedEndpointId ?? this.connectedEndpointId,
      connectedEndpointName: connectedEndpointName ?? this.connectedEndpointName,
      endpoints: endpoints ?? this.endpoints,
    );
  }
}

/// A received payload routed by its one-byte channel tag.
class AppPayload {
  const AppPayload({
    required this.tag,
    required this.body,
    required this.endpointId,
  });

  final int tag;
  final Uint8List body;
  final String endpointId;

  String get text => utf8.decode(body);
}

/// The one Nearby connection shared by Chat, Walkie Talkie, Tic-Tac-Toe
/// and Ludo.
///
/// All features talk through this singleton: one serviceId, one
/// advertising/discovery session, one link. Every payload is framed as
/// `[channel tag byte][body]` so each feature only reads its own traffic.
class ConnectionService {
  ConnectionService._();

  static final ConnectionService instance = ConnectionService._();

  static const String serviceId = 'com.nearby.connect';
  static const Strategy strategy = Strategy.P2P_POINT_TO_POINT;

  static const int tagChat = 1;
  static const int tagGame = 2;
  static const int tagAudio = 3;
  static const int tagLudo = 4;

  final Nearby _nearby = Nearby();

  final StreamController<LinkSnapshot> _snapshots =
      StreamController<LinkSnapshot>.broadcast();
  final StreamController<AppPayload> _payloads =
      StreamController<AppPayload>.broadcast();

  LinkSnapshot _snapshot = const LinkSnapshot(
    state: LinkState.idle,
    status: 'Not connected',
    isHost: false,
  );

  String? _pendingEndpointName;

  /// Optional hooks: the screen currently discovering owns them.
  void Function(String endpointId, String name)? onEndpointFound;
  void Function(String endpointId, String name)? onEndpointLost;

  Stream<LinkSnapshot> get snapshotStream => _snapshots.stream;
  Stream<AppPayload> get payloadStream => _payloads.stream;

  LinkSnapshot get snapshot => _snapshot;
  bool get isConnected => _snapshot.isConnected;
  bool get isHost => _snapshot.isHost;
  String? get connectedEndpointId => _snapshot.connectedEndpointId;
  String? get connectedEndpointName => _snapshot.connectedEndpointName;

  // ---------------------------------------------------------------- guards

  /// Central permission gate: only asks for what is missing.
  Future<bool> _ensurePermissions() async {
    final granted = await PermissionService.instance.ensureAll();
    if (!granted) {
      _emit(_snapshot.copyWith(
        status: 'Permissions missing — allow them in Settings',
      ));
    }
    return granted;
  }

  void _emit(LinkSnapshot next) {
    _snapshot = next;
    if (!_snapshots.isClosed) _snapshots.add(next);
  }

  // ---------------------------------------------------------------- host

  /// Starts advertising (this device becomes the host).
  Future<bool> host(String deviceName) async {
    print('🔵 ConnectionService.host() called with deviceName=$deviceName');
    if (!await _ensurePermissions()) {
      print('🔵 ConnectionService.host(): permissions not granted');
      return false;
    }
    if (_snapshot.state == LinkState.connected) {
      print('🔵 ConnectionService.host(): already connected');
      return true;
    }
    if (_snapshot.state == LinkState.hosting) {
      print('🔵 ConnectionService.host(): already hosting');
      return true;
    }
    if (_snapshot.state == LinkState.discovering) {
      print('🔵 ConnectionService.host(): stopping discovery first');
      await _stopDiscovery();
    }

    try {
      print('🔵 ConnectionService.host(): calling _nearby.startAdvertising...');
      final started = await _nearby.startAdvertising(
        deviceName,
        strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: serviceId,
      );
      print('🔵 ConnectionService.host(): startAdvertising returned started=$started');
      if (started) {
        _emit(_snapshot.copyWith(
          state: LinkState.hosting,
          status: 'Advertising as $deviceName...',
          isHost: true,
          deviceName: deviceName,
          connectedEndpointId: null,
          connectedEndpointName: null,
          endpoints: const <String, String>{},
        ));
        print('🔵 ConnectionService.host(): emitted hosting state');
        return true;
      }
      print('🔵 ConnectionService.host(): advertising did not start');
      _emit(_snapshot.copyWith(state: LinkState.idle, status: 'Advertising did not start'));
      return false;
    } catch (e) {
      print('🔵 ConnectionService.host() error: $e');
      _emit(_snapshot.copyWith(state: LinkState.idle, status: 'Advertising failed: $e'));
      return false;
    }
  }

  // ------------------------------------------------------------ discovery

  /// Starts discovering nearby peers. Found endpoints appear in [snapshot].
  Future<bool> discover(String deviceName) async {
    print('🔵 ConnectionService.discover() called with deviceName=$deviceName');
    if (!await _ensurePermissions()) {
      print('🔵 ConnectionService.discover(): permissions not granted');
      return false;
    }
    if (_snapshot.state == LinkState.connected) {
      print('🔵 ConnectionService.discover(): already connected');
      return true;
    }
    if (_snapshot.state == LinkState.discovering) {
      print('🔵 ConnectionService.discover(): already discovering');
      return true;
    }
    if (_snapshot.state == LinkState.hosting) {
      print('🔵 ConnectionService.discover(): stopping advertising first');
      await _stopAdvertising();
    }

    try {
      print('🔵 ConnectionService.discover(): calling _nearby.startDiscovery...');
      final started = await _nearby.startDiscovery(
        deviceName,
        strategy,
        onEndpointFound: (id, name, _) {
          print('🔵 ConnectionService.onEndpointFound: id=$id, name=$name');
          final endpoints = Map<String, String>.from(_snapshot.endpoints);
          final isNew = !endpoints.containsKey(id);
          endpoints[id] = name;
          _emit(_snapshot.copyWith(
            status: 'Found: $name',
            endpoints: endpoints,
          ));
          if (isNew) onEndpointFound?.call(id, name);
        },
        onEndpointLost: (id) {
          if (id == null) return;
          print('🔵 ConnectionService.onEndpointLost: id=$id');
          final endpoints = Map<String, String>.from(_snapshot.endpoints);
          final name = endpoints.remove(id);
          _emit(_snapshot.copyWith(endpoints: endpoints));
          if (name != null) onEndpointLost?.call(id, name);
        },
        serviceId: serviceId,
      );
      print('🔵 ConnectionService.discover(): startDiscovery returned started=$started');
      if (started) {
        _emit(_snapshot.copyWith(
          state: LinkState.discovering,
          status: 'Discovering...',
          isHost: false,
          deviceName: deviceName,
          connectedEndpointId: null,
          connectedEndpointName: null,
          endpoints: const <String, String>{},
        ));
        print('🔵 ConnectionService.discover(): emitted discovering state');
        return true;
      }
      print('🔵 ConnectionService.discover(): discovery did not start');
      _emit(_snapshot.copyWith(state: LinkState.idle, status: 'Discovery did not start'));
      return false;
    } catch (e) {
      print('🔵 ConnectionService.discover() error: $e');
      _emit(_snapshot.copyWith(state: LinkState.idle, status: 'Discovery failed: $e'));
      return false;
    }
  }

  /// Connects to a previously discovered endpoint.
  Future<bool> connectTo(String endpointId) async {
    print('🔵 ConnectionService.connectTo() called with endpointId=$endpointId');
    if (_snapshot.connectedEndpointId == endpointId) return true;
    if (!await _ensurePermissions()) {
      print('🔵 ConnectionService.connectTo(): permissions not granted');
      return false;
    }

    final deviceName =
        _snapshot.deviceName ?? 'User_${DateTime.now().millisecondsSinceEpoch % 10000}';
    try {
      _emit(_snapshot.copyWith(status: 'Connecting...'));
      print('🔵 ConnectionService.connectTo(): calling requestConnection...');
      await _nearby.requestConnection(
        deviceName,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      print('🔵 ConnectionService.connectTo(): requestConnection returned');
      return true;
    } catch (e) {
      print('🔵 ConnectionService.connectTo() error: $e');
      _emit(_snapshot.copyWith(status: 'Connection request failed: $e'));
      return false;
    }
  }

  /// Tears the shared link down: disconnects, stops advertising and discovery.
  Future<void> disconnect() async {
    final endpointId = _snapshot.connectedEndpointId;
    if (endpointId != null) {
    try {
      await _nearby.disconnectFromEndpoint(endpointId);
      } catch (_) {}
    }
    await _stopAdvertising();
    await _stopDiscovery();
    // Explicit user disconnect: stop the background keep-alive service.
    await KeepAliveService.instance.stop();
    _emit(const LinkSnapshot(
      state: LinkState.idle,
      status: 'Disconnected',
      isHost: false,
    ));
  }

  Future<void> _stopAdvertising() async {
    try {
      await _nearby.stopAdvertising();
    } catch (_) {}
  }

  Future<void> _stopDiscovery() async {
    try {
      await _nearby.stopDiscovery();
    } catch (_) {}
  }

  // ------------------------------------------------------ nearby callbacks

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    print('🔵 _onConnectionInitiated: id=$id, endpointName=${info.endpointName}');
    _pendingEndpointName = info.endpointName;
    _emit(_snapshot.copyWith(status: 'Connection initiated with ${info.endpointName}'));
    // Must call acceptConnection synchronously in the callback
    _nearby
        .acceptConnection(id, onPayLoadRecieved: _onPayloadReceived)
        .catchError((Object e) {
      print('🔵 acceptConnection error: $e');
      _emit(_snapshot.copyWith(status: 'Accept failed: $e'));
      return Future<void>.value();
    });
  }

  void _onConnectionResult(String id, Status status) {
    print('🔵 _onConnectionResult: id=$id, status=$status');
    if (status == Status.CONNECTED) {
      print('🔵 _onConnectionResult: CONNECTED, stopping adv/discovery');
      _stopAdvertising();
      _stopDiscovery();
      // Keep the process alive in the background until the user disconnects.
      KeepAliveService.instance.start();
      _emit(LinkSnapshot(
        state: LinkState.connected,
        status: 'Connected!',
        isHost: _snapshot.isHost,
        deviceName: _snapshot.deviceName,
        connectedEndpointId: id,
        connectedEndpointName: _pendingEndpointName,
      ));
    } else {
      print('🔵 _onConnectionResult: not connected, status=$status');
      _emit(_snapshot.copyWith(
        state: LinkState.idle,
        status: 'Connection failed ($status)',
        connectedEndpointId: null,
        connectedEndpointName: null,
      ));
    }
    _pendingEndpointName = null;
  }

  void _onDisconnected(String id) {
    print('🔵 _onDisconnected: id=$id');
    // Link is gone (peer or system): stop the background keep-alive service.
    KeepAliveService.instance.stop();
    _emit(const LinkSnapshot(
      state: LinkState.idle,
      status: 'Peer disconnected',
      isHost: false,
    ));
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type != PayloadType.BYTES) return;
    final bytes = payload.bytes;
    if (bytes == null || bytes.isEmpty) return;

    print('📥 Payload received: tag=${bytes[0]}, bodyLen=${bytes.length - 1}, endpoint=$endpointId');
    
    _payloads.add(AppPayload(
      tag: bytes[0],
      body: Uint8List.sublistView(bytes, 1),
      endpointId: endpointId,
    ));
  }

  // ---------------------------------------------------------------- sending

  Future<void> _sendTagged(int tag, Uint8List body) async {
    final endpointId = _snapshot.connectedEndpointId;
    if (endpointId == null) throw StateError('Not connected');
    final framed = Uint8List(1 + body.length);
    framed[0] = tag;
    framed.setAll(1, body);
    print('📤 Sending payload: tag=$tag, bodyLen=${body.length}, endpoint=$endpointId');
    await _nearby.sendBytesPayload(endpointId, framed);
  }

  Future<void> sendChat(String text) =>
      _sendTagged(tagChat, Uint8List.fromList(utf8.encode(text)));

  Future<void> sendGame(String json) =>
      _sendTagged(tagGame, Uint8List.fromList(utf8.encode(json)));

  Future<void> sendAudio(Uint8List audio) => _sendTagged(tagAudio, audio);

  Future<void> sendLudo(String json) =>
      _sendTagged(tagLudo, Uint8List.fromList(utf8.encode(json)));
}
