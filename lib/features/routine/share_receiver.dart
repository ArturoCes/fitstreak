import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';

const _channel = MethodChannel('fitstreak/share');

/// What MainActivity sends when fitstreak://summary/today|week is opened.
const summaryPrefix = 'SUMMARY:';

/// Opens "Tu resumen" and, with [speak], reads it aloud.
void openSummary(GoRouter router, {bool week = false, bool speak = false}) {
  router.push('/summary?week=${week ? 1 : 0}&speak=${speak ? 1 : 0}');
}

/// Preferences key of shared text that arrived before the onboarding ended.
const pendingImportKey = 'pending_import_text';

/// Listens to text other apps share with FitStreak (WhatsApp → Share →
/// FitStreak), links and icon shortcuts, and opens the right screen.
class SharedTextReceiver extends ConsumerStatefulWidget {
  /// Wraps [child]; [router] opens the screens.
  const SharedTextReceiver({super.key, required this.router, required this.child});

  /// The app router.
  final GoRouter router;

  /// The rest of the app.
  final Widget child;

  @override
  ConsumerState<SharedTextReceiver> createState() => _SharedTextReceiverState();
}

/// Talks to MainActivity over the `fitstreak/share` channel.
class _SharedTextReceiverState extends ConsumerState<SharedTextReceiver> with WidgetsBindingObserver {
  /// Only Android shares text with the app.
  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedTextAvailable') await _take();
    });
    // Cold start from "Share": wait until the router is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _take());
  }

  @override
  void dispose() {
    if (_supported) {
      WidgetsBinding.instance.removeObserver(this);
      _channel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _take();
  }

  /// Takes the pending shared text, if any, and acts on it.
  Future<void> _take() async {
    final String? text;
    try {
      text = await _channel.invokeMethod<String>('takeSharedText');
    } catch (e) {
      debugPrint('No se pudo leer el texto compartido: $e');
      return;
    }
    if (text == null || text.trim().isEmpty || !mounted) return;
    // Icon shortcut or "Ok Google, open FitStreak's summary".
    if (text.startsWith(summaryPrefix)) {
      if (ref.read(profileProvider) == null) return;
      openSummary(widget.router, week: text == '${summaryPrefix}week', speak: true);
      return;
    }
    if (ref.read(profileProvider) == null) {
      // No profile yet: it is imported when the onboarding ends.
      await ref.read(prefsProvider).setString(pendingImportKey, text);
      return;
    }
    widget.router.push('/import', extra: text);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
