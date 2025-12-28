import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/foundation.dart';

/// Service for managing local push notifications
/// - Schedule notifications at slot times
/// - Cancel scheduled notifications
class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();

  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _isInitialized = false;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  // ========== INITIALIZATION ==========

  /// Initialize local notifications
  /// Must be called before using notification features
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      _notificationsPlugin = FlutterLocalNotificationsPlugin();

      // Initialize timezone data
      tz_data.initializeTimeZones();

      // Android setup
      const androidSettings =
          AndroidInitializationSettings('app_icon');

      // iOS setup
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(initSettings);

      _isInitialized = true;
      debugPrint('Notifications initialized');
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  // ========== SIMPLE NOTIFICATIONS ==========

  /// Show immediate notification
  Future<void> showNotification({
    required String title,
    required String body,
    required int id,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      const androidDetails = AndroidNotificationDetails(
        'medicine_alerts',
        'Medicine Alerts',
        channelDescription: 'Notifications for medicine schedule',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id,
        title,
        body,
        details,
      );

      debugPrint('Notification shown: $title');
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  // ========== SCHEDULED NOTIFICATIONS ==========

  /// Schedule notification at specific time
  /// @param title: Notification title
  /// @param body: Notification message
  /// @param scheduledTime: When to show notification
  /// @param id: Unique notification ID
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    required int id,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      const androidDetails = AndroidNotificationDetails(
        'medicine_alerts',
        'Medicine Alerts',
        channelDescription: 'Notifications for medicine schedule',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint('Notification scheduled: $title at $scheduledTime');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  /// Schedule daily notification at specific time
  /// @param title: Notification title
  /// @param body: Notification message
  /// @param hour: Hour (0-23)
  /// @param minute: Minute (0-59)
  /// @param id: Unique notification ID
  Future<void> scheduleDailyNotification({
    required String title,
    required String body,
    required int hour,
    required int minute,
    required int id,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      const androidDetails = AndroidNotificationDetails(
        'medicine_alerts',
        'Medicine Alerts',
        channelDescription: 'Notifications for medicine schedule',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final now = DateTime.now();
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If scheduled time is in the past, schedule for tomorrow
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint(
          'Daily notification scheduled: $title at $hour:${minute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('Error scheduling daily notification: $e');
    }
  }

  // ========== MEDICINE SLOT NOTIFICATIONS ==========

  /// Schedule notification for a medicine slot
  /// @param slot: Slot name ("morning", "afternoon", "night")
  /// @param startTime: Time range start (e.g., "08:00")
  /// @param userName: User's name
  /// @param id: Unique notification ID
  Future<void> scheduleMedicineSlotNotification({
    required String slot,
    required String startTime,
    required String userName,
    required int id,
  }) async {
    try {
      // Parse time string (HH:mm format)
      final parts = startTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      await scheduleDailyNotification(
        title: '💊 Medicine Time',
        body: 'Hi $userName! Time for your $slot medicine.',
        hour: hour,
        minute: minute,
        id: id,
      );
    } catch (e) {
      debugPrint('Error scheduling medicine slot notification: $e');
    }
  }

  // ========== CANCELLATION ==========

  /// Cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      debugPrint('Notification $id cancelled');
    } catch (e) {
      debugPrint('Error canceling notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      debugPrint('All notifications cancelled');
    } catch (e) {
      debugPrint('Error canceling all notifications: $e');
    }
  }

  /// Check if initialized
  bool get isInitialized => _isInitialized;
}
