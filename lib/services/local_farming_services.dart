import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/local_store.dart';
import '../models/domain.dart';
import 'contracts.dart';

class LocalFarmingCalendarService implements FarmingCalendarService {
  const LocalFarmingCalendarService();
  @override
  Future<List<CalendarEvent>> events(int farmId) =>
      LocalStore.instance.calendarTasks(farmId);
  @override
  Future<int> saveTask(int farmId, CalendarEvent task) =>
      LocalStore.instance.saveCalendarTask(farmId, task);
  @override
  Future<void> setCompleted(int taskId, bool completed) =>
      LocalStore.instance.completeCalendarTask(taskId, completed);
  @override
  Future<void> deleteTask(int taskId) =>
      LocalStore.instance.deleteCalendarTask(taskId);
}

String notificationCategoryForTask(String type) {
  final lower = type.toLowerCase();
  if (lower.contains('water')) return 'watering';
  if (lower.contains('fertil')) return 'fertilizer';
  if (lower.contains('plant') || lower.contains('sow')) return 'planting';
  if (lower.contains('harvest')) return 'harvesting';
  return 'calendar_tasks';
}

class LocalFarmingReminderService implements FarmingReminderService {
  LocalFarmingReminderService._();
  static final instance = LocalFarmingReminderService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  (int farmId, int taskId)? _pendingTap;
  static void Function(int farmId, int taskId)? onCalendarReminderTap;

  Future<void> initialize() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings,
        onDidReceiveNotificationResponse: _handleResponse);
    _ready = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse != null) {
      _handleResponse(launch!.notificationResponse!);
    }
  }

  void _handleResponse(NotificationResponse response) {
    try {
      final payload =
          jsonDecode(response.payload ?? '{}') as Map<String, dynamic>;
      final historyId = payload['history_id'] as int?;
      final farmId = payload['farm_id'] as int?;
      final taskId = payload['task_id'] as int?;
      if (historyId != null)
        LocalStore.instance.markNotificationRead(historyId);
      if (farmId != null && taskId != null) {
        _pendingTap = (farmId, taskId);
        dispatchPendingTap();
      }
    } on FormatException {
      // Ignore invalid notification payloads.
    }
  }

  void dispatchPendingTap() {
    final tap = _pendingTap;
    final callback = onCalendarReminderTap;
    if (tap == null || callback == null) return;
    _pendingTap = null;
    callback(tap.$1, tap.$2);
  }

  @override
  Future<void> schedule(CalendarEvent event) async {
    await initialize();
    if (event.id == null || !event.date.isAfter(DateTime.now())) return;
    final category = notificationCategoryForTask(event.type);
    final preferences = await LocalStore.instance.notificationPreferences();
    if (!(preferences[category] ?? true)) return;
    await _plugin.cancel(event.id!);
    await LocalStore.instance.markReminderCancelled(event.id!);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final body = 'Farming calendar reminder · ${event.type}';
    final historyId = await LocalStore.instance.addNotification(
      notificationId: event.id!,
      category: category,
      title: event.title,
      body: body,
      scheduledFor: event.date,
      farmId: event.farmId,
      taskId: event.id,
    );
    await _plugin.zonedSchedule(
      event.id!,
      event.title,
      body,
      tz.TZDateTime.from(event.date, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'farming_tasks',
          'Farming tasks',
          channelDescription: 'Local reminders for your farming calendar',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode({
        'history_id': historyId,
        'farm_id': event.farmId,
        'task_id': event.id
      }),
    );
    await LocalStore.instance.markReminderScheduled(historyId);
  }

  @override
  Future<void> cancel(CalendarEvent event) async {
    if (event.id == null) return;
    await cancelNotification(event.id!);
  }

  @override
  Future<void> cancelNotification(int notificationId) async {
    await initialize();
    await _plugin.cancel(notificationId);
    await LocalStore.instance.markReminderCancelled(notificationId);
  }
}
