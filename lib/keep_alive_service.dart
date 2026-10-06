import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Wraps the native foreground keep-alive service.
///
/// The service is started when a Nearby connection is established and stopped
/// only when the user explicitly disconnects (or the peer drops the link).
class KeepAliveService {
  KeepAliveService._();
  static final KeepAliveService instance = KeepAliveService._();

  static const MethodChannel _channel = MethodChannel('nearby_chat_app/keepalive');

  bool _running = false;

  bool get isRunning => _running;

  Future<void> start() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (_running) return;
    try {
      await _channel.invokeMethod('start');
      _running = true;
      await _ensureBatteryOptimizationIgnored();
      debugPrint('⚡ KeepAlive: foreground service started');
    } on PlatformException catch (e) {
      debugPrint('⚡ KeepAlive: start failed: $e');
    }
  }

  Future<void> stop() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (!_running) return;
    try {
      await _channel.invokeMethod('stop');
      _running = false;
      debugPrint('⚡ KeepAlive: foreground service stopped');
    } on PlatformException catch (e) {
      debugPrint('⚡ KeepAlive: stop failed: $e');
    }
  }

  /// Requests the "ignore battery optimizations" dialog when not already
  /// whitelisted, so the OS does not kill the process in the background.
  Future<void> _ensureBatteryOptimizationIgnored() async {
    try {
      final ignoring =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      if (ignoring == false) {
        debugPrint('⚡ KeepAlive: requesting battery optimization exemption');
        await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
      }
    } on PlatformException catch (_) {}
  }
}
