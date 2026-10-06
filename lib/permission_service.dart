import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Single source of truth for every runtime permission the app needs.
///
/// SDK-gated so each Android version is asked for exactly what it requires:
/// - SDK <= 30 : location (pre-Bluetooth-scanning BLE discovery needs it)
/// - SDK >= 31 : bluetoothScan / bluetoothAdvertise / bluetoothConnect
/// - SDK >= 33 : nearbyWifiDevices
/// - always    : microphone (Walkie Talkie)
class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  int? _sdk;

  Future<int> get sdkVersion async => _sdk ??= await _readSdk();

  Future<int> _readSdk() async {
    if (!Platform.isAndroid) return 0;
    final info = DeviceInfoPlugin();
    final android = await info.androidInfo;
    return android.version.sdkInt;
  }

  /// Permissions required on this device, gated by SDK level.
  Future<List<Permission>> requiredPermissions() async {
    if (!Platform.isAndroid) return const [];
    final sdk = await sdkVersion;
    return <Permission>[
      if (sdk <= 30) Permission.locationWhenInUse,
      if (sdk >= 31) ...[
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ],
      if (sdk >= 33) Permission.nearbyWifiDevices,
      Permission.microphone,
    ];
  }

  /// Check-only: returns permissions that are not granted yet. Never prompts.
  Future<List<Permission>> missingPermissions() async {
    final required = await requiredPermissions();
    final missing = <Permission>[];
    for (final permission in required) {
      if (!await permission.isGranted) missing.add(permission);
    }
    return missing;
  }

  /// Check first, request only what is missing. Returns true when all are granted.
  Future<bool> ensureAll() async {
    if (!Platform.isAndroid) return true;
    final missing = await missingPermissions();
    if (missing.isEmpty) return true;
    final results = await missing.request();
    return results.values.every((status) => status.isGranted);
  }

  /// Opens the app's system settings page (for permanently denied permissions).
  Future<bool> openSettings() => openAppSettings();
}
