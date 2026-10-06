import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Top-level background notification handler (required for background isolate)
@pragma('vm:entry-point')
void _backgroundNotificationHandler(NotificationResponse response) {
  debugPrint('Background notification tapped: ${response.payload}');
}

/// Local notification service for chat messages.
/// Works in both foreground and background (when app is alive).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String _channelId = 'chat_messages';
  static const String _channelName = 'Chat Messages';
  static const String _channelDescription = 'Notifications for incoming chat messages';

  /// Initialize the notification service. Call once at app startup.
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    // Android initialization settings
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _backgroundNotificationHandler,
    );

    // Create Android notification channel (required for Android 8+)
    await _createNotificationChannel();

    // Request permissions
    await _requestPermissions();

    _initialized = true;
    debugPrint('NotificationService initialized');
  }

  /// Create the Android notification channel
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Request notification permissions (Android 13+, iOS)
  Future<void> _requestPermissions() async {
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }

    final iosImpl = _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Show a chat notification
  /// [senderName] - name of the message sender
  /// [message] - the message text
  /// [payload] - optional payload to pass when notification is tapped
  Future<void> showChatNotification({
    required String senderName,
    required String message,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    // Truncate message if too long
    final displayMessage = message.length > 100
        ? '${message.substring(0, 100)}...'
        : message;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        displayMessage,
        htmlFormatBigText: false,
        contentTitle: senderName,
        htmlFormatContentTitle: false,
        summaryText: displayMessage,
        htmlFormatSummaryText: false,
      ),
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF3A7D6E), // App accent color
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.message,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      senderName,
      displayMessage,
      details,
      payload: payload,
    );
  }

  /// Handle notification tap (foreground)
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Navigation handled by the app's router if needed
    // The app can listen to a stream for navigation
  }

  /// Cancel a specific notification
  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      return await androidImpl.areNotificationsEnabled() ?? false;
    }
    return true; // iOS always allows if user granted
  }
}