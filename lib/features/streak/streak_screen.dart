import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../data/progress_state.dart';
import '../../data/streak.dart';

class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final profile = ref.watch(profileProvider);
    final logs = ref.watch(workoutLogsProvider);
    final now = DateTime.now();
    final days = streak.current(now);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Racha')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Text('🔥', style: TextStyle(fontSize: 72, color: days == 0 ? Colors.grey : null)),
                Text('$days ${days == 1 ? 'día' : 'días'}', style: text.displaySmall),
                Text('Mejor racha: ${streak.best} · 🧊 ${streak.freezes}/$maxFreezes protectores'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (streak.atRisk(now))
            Card(
              color: scheme.errorContainer,
              child: const ListTile(
                leading: Icon(Icons.warning_amber),
                title: Text('Tu racha está en peligro'),
                subtitle: Text('Entrena hoy o mañana gastarás un protector.'),
              ),
            )
          else if (streak.trainedOn(now))
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Hoy ya has entrenado'),
              ),
            ),
          const SizedBox(height: 8),
          _Calendar(streak: streak, today: now),
          const SizedBox(height: 8),
          if (profile != null)
            Text(
              'Con ${profile.daysPerWeek} días por semana puedes descansar hasta '
              '${maxRestDays(profile.daysPerWeek)} días seguidos sin perder la racha. '
              'Si te pasas, un protector cubre cada día extra. Ganas uno cada '
              '$freezeEvery días de racha.',
              style: text.bodySmall,
            ),
          const Divider(height: 32),
          const _ReminderTile(),
          if (logs.isNotEmpty) ...[
            const Divider(height: 32),
            Text('Últimos entrenos', style: text.titleMedium),
            for (final l in logs.reversed.take(5))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fitness_center),
                title: Text(l.dayName),
                subtitle: Text(
                  '${l.date.day}/${l.date.month} · ${l.setsDone}/${l.setsTotal} series · '
                  '${(l.durationSeconds / 60).round()} min',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Últimas 5 semanas, de lunes a domingo.
class _Calendar extends StatelessWidget {
  const _Calendar({required this.streak, required this.today});

  final StreakState streak;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = dateOnly(today);
    final monday = t.subtract(Duration(days: t.weekday - 1));
    final first = monday.subtract(const Duration(days: 28));
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                for (final l in labels)
                  Expanded(child: Center(child: Text(l, style: Theme.of(context).textTheme.labelSmall))),
              ],
            ),
            const SizedBox(height: 6),
            for (var w = 0; w < 5; w++)
              Row(
                children: [
                  for (var d = 0; d < 7; d++)
                    Expanded(
                      child: Builder(builder: (_) {
                        final date = DateTime(first.year, first.month, first.day + w * 7 + d);
                        final trained = streak.trainedOn(date);
                        final isToday = date == t;
                        final future = date.isAfter(t);
                        return Padding(
                          padding: const EdgeInsets.all(3),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: trained ? scheme.primary : null,
                                border: isToday ? Border.all(color: scheme.primary, width: 2) : null,
                              ),
                              child: Center(
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: trained
                                        ? scheme.onPrimary
                                        : future
                                            ? scheme.outline
                                            : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ReminderTile extends ConsumerWidget {
  const _ReminderTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = ref.watch(reminderProvider);
    final supported = ref.watch(notificationsProvider).supported;
    final notifier = ref.read(reminderProvider.notifier);

    Future<void> pick() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: time ?? const TimeOfDay(hour: 19, minute: 0),
        helpText: 'Hora del recordatorio',
      );
      if (picked == null) return;
      final ok = await notifier.set(picked);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activa las notificaciones en los ajustes del móvil')),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Recordatorio diario'),
          subtitle: Text(time == null ? 'Desactivado' : 'Cada día a las ${time.format(context)}'),
          value: time != null,
          onChanged: (on) => on ? pick() : notifier.set(null),
        ),
        if (time != null)
          TextButton.icon(
            onPressed: pick,
            icon: const Icon(Icons.schedule),
            label: const Text('Cambiar hora'),
          ),
        if (!supported)
          Text(
            'En la versión web no se envían notificaciones; funcionan en la app del móvil. '
            'Si tu racha está en peligro también te avisamos a las 21:00.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}
