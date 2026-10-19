import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Recordatorios locales: no necesitan servidor. En web no se programan
/// (el navegador no las soporta de forma fiable), solo en Android e iOS.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _dailyId = 1;
  static const _atRiskId = 2;

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

  bool get supported => !kIsWeb;

  Future<void> init() async {
    if (!supported || _ready) return;
    tz.initializeTimeZones();
    final local = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(local.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Pide permiso (Android 13+ e iOS). Devuelve si se concedió.
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

  /// Recordatorio diario a la hora elegida (o lo quita si [time] es null).
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

  /// Aviso de "racha en peligro" para esta noche, si hoy aún no se entrenó.
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

  tz.TZDateTime _next(TimeOfDay t) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }
}
