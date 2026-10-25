import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/progress_state.dart';
import '../../data/summary.dart';
import '../../data/summary_state.dart';
import '../../services/notifications.dart';
import '../routine/share_receiver.dart';

const _enabledKey = 'summary_notifications';

/// Nightly summary and Sunday analysis notifications (on by default).
class SummaryNotificationsNotifier extends Notifier<bool> {
  /// Loads the saved setting.
  @override
  bool build() => ref.read(prefsProvider).getBool(_enabledKey) ?? true;

  /// Turns the summaries on or off.
  Future<void> set(bool on) async {
    state = on;
    await ref.read(prefsProvider).setBool(_enabledKey, on);
  }
}

/// Whether the summary notifications are on.
final summaryNotificationsProvider =
    NotifierProvider<SummaryNotificationsNotifier, bool>(SummaryNotificationsNotifier.new);

/// Keeps the summary notifications scheduled with up-to-date text (on app
/// start, on resume and after a workout) and opens "Tu resumen" when one is
/// tapped.
class SummaryScheduler extends ConsumerStatefulWidget {
  /// Wraps [child]; [router] opens the summary.
  const SummaryScheduler({super.key, required this.router, required this.child});

  /// The app router.
  final GoRouter router;

  /// The rest of the app.
  final Widget child;

  @override
  ConsumerState<SummaryScheduler> createState() => _SummarySchedulerState();
}

/// Listens to notification taps and app lifecycle.
class _SummarySchedulerState extends ConsumerState<SummaryScheduler> with WidgetsBindingObserver {
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    WidgetsBinding.instance.addObserver(this);
    final notifications = ref.read(notificationsProvider);
    _taps = notifications.taps.listen(_open);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _schedule();
      final launched = await notifications.launchPayload().catchError((_) => null);
      if (launched != null) _open(launched);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _taps?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  /// Opens the summary for a tapped notification's [payload].
  void _open(String payload) {
    if (ref.read(profileProvider) == null) return;
    if (payload == NotificationService.summaryTodayPayload) openSummary(widget.router);
    if (payload == NotificationService.summaryWeekPayload) openSummary(widget.router, week: true);
  }

  /// Reschedules both summaries with the current text.
  Future<void> _schedule() async {
    final enabled = ref.read(summaryNotificationsProvider);
    final routine = ref.read(routineProvider);
    if (ref.read(profileProvider) == null || routine == null) return;
    try {
      final next = ref.read(nextDayIndexProvider);
      final daily = dailyNotificationText(
        now: DateTime.now(),
        logs: ref.read(workoutLogsProvider),
        streak: ref.read(streakProvider),
        nextDayName: routine.days.isEmpty ? null : routine.days[next.clamp(0, routine.days.length - 1)].name,
      );
      final weekly = await ref.read(weekSummaryProvider.future) ?? '';
      await ref.read(notificationsProvider).scheduleSummaries(daily: daily, weekly: weekly, enabled: enabled);
    } catch (e) {
      debugPrint('No se pudieron programar los resúmenes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Finishing a workout or changing the setting changes the scheduled text.
    ref.listen(workoutLogsProvider, (_, _) => _schedule());
    ref.listen(summaryNotificationsProvider, (_, _) => _schedule());
    return widget.child;
  }
}
