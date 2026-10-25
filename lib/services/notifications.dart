import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications: reminders, streak at risk, the ongoing workout
/// with its chronometer, the rest-end chime and the summaries. They need no
/// server. Not scheduled on the web (browsers don't support them reliably),
/// only on Android and iOS.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _dailyId = 1;
  static const _atRiskId = 2;
  static const _workoutId = 3;
  static const _restEndId = 4;
  static const _dailySummaryId = 5;
  static const _weekSummaryId = 6;

  /// Payload of the daily summary notification (opens "Tu resumen").
  static const summaryTodayPayload = 'summary:today';

  /// Payload of the weekly summary notification.
  static const summaryWeekPayload = 'summary:week';

  /// Taps on notifications while the app is open or in the background.
  final _taps = StreamController<String>.broadcast();

  /// Payloads of the notifications the user taps.
  Stream<String> get taps => _taps.stream;

  static const _summaryDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'summaries',
      'Resúmenes',
      channelDescription: 'Resumen de cada noche y análisis de la semana los domingos',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      styleInformation: BigTextStyleInformation(''),
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Rest-end chime (android/app/src/main/res/raw/rest_end.wav).
  static final _restEndDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'rest_end',
      'Fin del descanso',
      channelDescription: 'Suena cuando acaba el descanso, también con el móvil bloqueado',
      importance: Importance.max,
      priority: Priority.max,
      sound: const RawResourceAndroidNotificationSound('rest_end'),
      vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      // Removes itself if untouched: the workout stays in the ongoing one.
      timeoutAfter: 60000,
    ),
    iOS: const DarwinNotificationDetails(presentSound: true),
  );

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Recordatorios',
      channelDescription: 'Recordatorio diario y aviso de racha en peligro',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Whether notifications work on this platform.
  bool get supported => !kIsWeb;

  /// Initializes the plugin and the time zone once.
  Future<void> init() async {
    if (!supported || _ready) return;
    tz.initializeTimeZones();
    final local = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(local.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_flame'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final payload = r.payload;
        if (payload != null) _taps.add(payload);
      },
    );
    _ready = true;
    // Channels from older versions (the ongoing one didn't show on the lock
    // screen).
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final old in const ['workout', 'workout_alerts']) {
      await android?.deleteNotificationChannel(channelId: old).catchError((_) {});
    }
  }

  /// Asks for permission (Android 13+ and iOS). Returns whether it was
  /// granted.
  Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  /// Daily reminder at the chosen time (removed when [time] is null).
  Future<void> scheduleDaily(TimeOfDay? time) async {
    if (!supported) return;
    await init();
    await _plugin.cancel(id: _dailyId);
    if (time == null) return;
    await _plugin.zonedSchedule(
      id: _dailyId,
      title: '¡Hora de entrenar! 💪',
      body: 'Tu rutina de hoy te espera. Mantén viva la racha.',
      scheduledDate: _next(time),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Payload of the notification that cold-started the app (null if it
  /// wasn't started that way).
  Future<String?> launchPayload() async {
    if (!supported) return null;
    await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true ? details?.notificationResponse?.payload : null;
  }

  /// Tonight's summary at 21:30 and the weekly analysis on Sunday at 20:00.
  /// Rescheduled when the app opens and after training so the text stays up
  /// to date. With [enabled] false both are removed.
  Future<void> scheduleSummaries({
    required String daily,
    required String weekly,
    required bool enabled,
  }) async {
    if (!supported) return;
    await init();
    await _plugin.cancel(id: _dailySummaryId);
    await _plugin.cancel(id: _weekSummaryId);
    if (!enabled) return;
    final now = tz.TZDateTime.now(tz.local);

    var tonight = tz.TZDateTime(tz.local, now.year, now.month, now.day, 21, 30);
    if (!tonight.isAfter(now)) tonight = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, 21, 30);
    await _plugin.zonedSchedule(
      id: _dailySummaryId,
      title: 'Tu día en FitStreak',
      body: daily,
      scheduledDate: tonight,
      notificationDetails: _summaryDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: summaryTodayPayload,
    );

    final daysToSunday = (DateTime.sunday - now.weekday) % 7;
    var sunday = tz.TZDateTime(tz.local, now.year, now.month, now.day + daysToSunday, 20);
    if (!sunday.isAfter(now)) sunday = tz.TZDateTime(tz.local, now.year, now.month, now.day + 7, 20);
    await _plugin.zonedSchedule(
      id: _weekSummaryId,
      title: 'Tu semana en FitStreak 📊',
      body: weekly,
      scheduledDate: sunday,
      notificationDetails: _summaryDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: summaryWeekPayload,
    );
  }

  /// "Streak at risk" alert for tonight, if there was no workout today.
  Future<void> scheduleAtRisk({required int streakDays, required bool atRisk}) async {
    if (!supported) return;
    await init();
    await _plugin.cancel(id: _atRiskId);
    if (!atRisk || streakDays == 0) return;
    final now = tz.TZDateTime.now(tz.local);
    final tonight = tz.TZDateTime(tz.local, now.year, now.month, now.day, 21);
    if (!tonight.isAfter(now)) return;
    await _plugin.zonedSchedule(
      id: _atRiskId,
      title: '🔥 Tu racha de $streakDays días está en peligro',
      body: 'Entrena hoy aunque sea un rato para no perderla.',
      scheduledDate: tonight,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Ongoing notification while a workout is in progress. Android draws the
  /// chronometer itself: counting down to [chronometerAt] while resting and
  /// up from it the rest of the time. It uses a normal-importance channel
  /// without sound: "silent" channels don't show on the lock screen.
  Future<void> showWorkout({
    required String title,
    required String body,
    DateTime? chronometerAt,
    bool countDown = false,
  }) async {
    if (!supported) return;
    await init();
    await _plugin.show(
      id: _workoutId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'workout_timer',
          'Entreno en curso',
          channelDescription: 'Temporizador del entreno activo, también en la pantalla de bloqueo',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: false,
          enableVibration: false,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          silent: true,
          showWhen: chronometerAt != null,
          when: chronometerAt?.millisecondsSinceEpoch,
          usesChronometer: chronometerAt != null,
          chronometerCountDown: countDown,
          category: AndroidNotificationCategory.stopwatch,
          visibility: NotificationVisibility.public,
        ),
      ),
    );
  }

  /// Schedules the chime for [at] with the system: it rings even when the
  /// app is asleep and the phone locked. Returns false if it couldn't be
  /// scheduled at the exact time (no exact alarm permission).
  Future<bool> scheduleRestEnd(DateTime at, {required String body}) async {
    if (!supported) return false;
    await init();
    await _plugin.cancel(id: _restEndId);
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null && !(await android.canScheduleExactNotifications() ?? false)) return false;
    await _plugin.zonedSchedule(
      id: _restEndId,
      title: '¡Se acabó el descanso! 💪',
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _restEndDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    return true;
  }

  /// Rings the chime now (when it couldn't be scheduled with the system).
  Future<void> showRestEnd({required String body}) async {
    if (!supported) return;
    await init();
    await _plugin.show(
      id: _restEndId,
      title: '¡Se acabó el descanso! 💪',
      body: body,
      notificationDetails: _restEndDetails,
    );
  }

  /// Removes the scheduled chime (rest skipped, changed or paused).
  Future<void> cancelRestEnd() async {
    if (!supported) return;
    await init();
    await _plugin.cancel(id: _restEndId);
  }

  /// Removes every reminder, alert and the workout notification.
  Future<void> cancelAll() async {
    if (!supported) return;
    await init();
    await _plugin.cancelAll();
  }

  /// Removes the workout notification and the rest-end chime.
  Future<void> cancelWorkout() async {
    if (!supported) return;
    await init();
    await _plugin.cancel(id: _workoutId);
    await _plugin.cancel(id: _restEndId);
  }

  /// The next occurrence of [t] (today if still ahead, otherwise tomorrow).
  tz.TZDateTime _next(TimeOfDay t) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }
}
