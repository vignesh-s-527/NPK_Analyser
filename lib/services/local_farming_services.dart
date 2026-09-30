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
  Future<void> saveTask(int farmId, CalendarEvent task) =>
      LocalStore.instance.saveCalendarTask(farmId, task);
  @override
  Future<void> setCompleted(int taskId, bool completed) =>
      LocalStore.instance.completeCalendarTask(taskId, completed);
  @override
  Future<void> deleteTask(int taskId) =>
      LocalStore.instance.deleteCalendarTask(taskId);
}

class LocalFarmingReminderService implements FarmingReminderService {
  LocalFarmingReminderService._();
  static final instance = LocalFarmingReminderService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
    _ready = true;
  }

  @override
  Future<void> schedule(CalendarEvent event) async {
    await initialize();
    if (event.id == null || !event.date.isAfter(DateTime.now())) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin.zonedSchedule(
      event.id!,
      event.title,
      'Farming calendar reminder · ${event.type}',
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
    );
  }
}
