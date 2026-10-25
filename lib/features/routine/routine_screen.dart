import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/active_workout.dart';
import '../../data/app_state.dart';
import '../../data/exercise.dart';
import '../../data/exercise_repository.dart';
import '../../data/labels_es.dart';
import '../../data/progress_state.dart';
import '../../data/routine.dart';
import '../../data/settings_state.dart';
import '../../data/motivation.dart';
import '../../data/reset.dart';
import '../../data/routine_share.dart';
import '../../data/sync/routine_sync.dart';
import '../../data/sync/sync_state.dart';
import 'sync_ui.dart';
import '../../ui/exercise_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../ui/exercise_media.dart';
import '../../ui/energy_card.dart';
import '../summary/summary_scheduler.dart';
import '../../ui/quote_card.dart';
import '../workout/overlay_bubble.dart';
import '../../ui/theme.dart';

/// Home screen: today's day of the routine, the streak and every day's
/// exercises, with the options menu.
class RoutineScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const RoutineScreen({super.key});

  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

/// Holds the day picked by hand.
class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  /// Day picked by hand; null = the one that is due.
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final routine = ref.watch(routineProvider);
    final profile = ref.watch(profileProvider);
    final exercises = ref.watch(exercisesProvider).value;
    final nextDay = ref.watch(nextDayIndexProvider);
    final streak = ref.watch(streakProvider);
    final active = ref.watch(activeWorkoutProvider);
    // After a workout the due day changes: go back to it.
    ref.listen(nextDayIndexProvider, (_, _) => setState(() => _picked = null));

    if (routine == null || profile == null || exercises == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final byId = {for (final e in exercises) e.id: e};
    final selected = (_picked ?? nextDay).clamp(0, routine.days.length - 1);
    final day = routine.days[selected];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                IconTile(
                  icon: Icons.tune,
                  color: Theme.of(context).colorScheme.tertiary,
                  tooltip: 'Opciones',
                  onTap: () => _showOptions(context),
                ),
                const Spacer(),
                IconTile(
                  icon: Icons.insights_rounded,
                  color: AppColors.teal,
                  tooltip: 'Tu resumen',
                  onTap: () => context.push('/summary'),
                ),
                const SizedBox(width: 8),
                StreakPill(streak.current(DateTime.now())),
              ],
            ),
            if (ref.watch(unpushedChangesProvider))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_upload_outlined, color: AppColors.orange),
                    title: const Text('Has cambiado tu rutina publicada'),
                    subtitle: const Text('Tus seguidores aún tienen la versión anterior'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showPublishSheet(context, ref),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text('Hola 👋', style: text.titleMedium?.copyWith(color: AppColors.muted)),
            Text(
              selected == nextDay ? '¡Vamos a por\nel entreno de hoy!' : 'Echa un vistazo\na otro día',
              style: text.headlineMedium,
            ),
            const SizedBox(height: 20),
            _HeroCard(
              day: day,
              isToday: selected == nextDay,
              minutes: profile.minutesPerSession,
              preview: day.items.isEmpty ? null : byId[day.items.first.exerciseId],
              resuming: active?.dayIndex == selected,
              onStart: () => _start(selected),
            ),
            if (selected != nextDay)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => ref.read(dayOverrideProvider.notifier).set(selected),
                  icon: const Icon(Icons.event_available, size: 18),
                  label: Text('Que hoy toque ${day.name}'),
                ),
              ),
            const SizedBox(height: 16),
            const EnergyCard(),
            const SizedBox(height: 12),
            const QuoteCard(),
            const SizedBox(height: 24),
            Text('Tus días', style: text.titleMedium),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 8,
                children: [
                  for (final (i, d) in routine.days.indexed)
                    ChoiceChip(
                      label: Text(i == nextDay ? '${d.name} · hoy' : d.name),
                      selected: i == selected,
                      showCheckmark: false,
                      labelStyle: text.bodyMedium?.copyWith(
                        color: i == selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      ),
                      onSelected: (_) => setState(() => _picked = i),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('Ejercicios', style: text.titleMedium),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    routine.title ?? '${profile.goal.label} · ${profile.place.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => _regenerateDay(selected),
                  icon: const Icon(Icons.autorenew, size: 18),
                  label: const Text('Cambiar día'),
                ),
              ],
            ),
            if (day.note != null) ...[
              const SizedBox(height: 8),
              _NoteCard(day.note!),
            ],
            const SizedBox(height: 6),
            for (final (i, item) in day.items.indexed)
              if (byId[item.exerciseId] case final ex?)
                _ItemCard(day: selected, index: i, item: item, exercise: ex),
            if (routine.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: ExpansionTile(
                  shape: const Border(),
                  leading: const Icon(Icons.sticky_note_2_outlined),
                  title: Text('Notas de tu rutina (${routine.notes.length})'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final n in routine.notes)
                      Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(n)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Starts [day] or, if another workout is half done, asks what to do.
  Future<void> _start(int day) async {
    final notifier = ref.read(activeWorkoutProvider.notifier);
    final active = ref.read(activeWorkoutProvider);
    if (active != null && active.dayIndex != day) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Tienes un entreno a medias'),
          content: Text('${active.dayName}: ${active.setsDone} de ${active.setsTotal} series.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Descartarlo')),
            FilledButton(onPressed: () => Navigator.pop(c, false), child: const Text('Seguir con él')),
          ],
        ),
      );
      if (replace == null) return;
      if (replace) notifier.abandon();
    }
    await notifier.start(day);
    if (mounted) context.push('/workout');
  }

  /// Options sheet: sharing, import, search, regenerate, settings, credits.
  Future<void> _showOptions(BuildContext context) async {
    final sync = ref.read(syncProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      // With many options it doesn't fit the default height: make it scroll.
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const IconTile(icon: Icons.upload_file, color: AppColors.orange, size: 36),
              title: const Text('Importar mi rutina'),
              subtitle: const Text('Pega tu rutina, abre un archivo o un código compartido'),
              onTap: () => Navigator.pop(sheet, 'import'),
            ),
            ListTile(
              leading: const IconTile(icon: Icons.search, color: AppColors.tealDark, size: 36),
              title: const Text('Buscar rutinas'),
              subtitle: const Text('Encuentra y sigue rutinas que otros han hecho públicas'),
              onTap: () => Navigator.pop(sheet, 'search'),
            ),
            ListTile(
              leading: const IconTile(icon: Icons.share_outlined, color: AppColors.teal, size: 36),
              title: const Text('Compartir mi rutina'),
              subtitle: const Text('Envía un enlace: quien lo abra la sigue y recibe tus cambios'),
              onTap: () => Navigator.pop(sheet, 'share'),
            ),
            if (sync.published case final p?)
              ListTile(
                leading: const IconTile(icon: Icons.public, color: AppColors.teal, size: 36),
                title: const Text('Mi rutina publicada'),
                subtitle: Text('${formatCode(p.id)} · '
                    '${ref.read(unpushedChangesProvider) ? 'cambios sin subir' : 'al día'}'),
                onTap: () => Navigator.pop(sheet, 'publish'),
              ),
            if (sync.following case final f?)
              ListTile(
                leading: const IconTile(icon: Icons.sync, color: AppColors.orange, size: 36),
                title: Text('Rutina de ${f.author}'),
                subtitle: const Text('La sigues · buscar versión nueva o dejar de seguirla'),
                onTap: () => Navigator.pop(sheet, 'following'),
              ),
            ListTile(
              leading: const IconTile(icon: Icons.alternate_email, color: AppColors.tealDark, size: 36),
              title: const Text('Cuenta'),
              subtitle: const Text('Email opcional para no perder tu rutina publicada'),
              onTap: () => Navigator.pop(sheet, 'account'),
            ),
            ListTile(
              leading: const IconTile(icon: Icons.refresh, color: AppColors.teal, size: 36),
              title: const Text('Generar otra rutina'),
              onTap: () => Navigator.pop(sheet, 'regen'),
            ),
            ListTile(
              leading: const IconTile(icon: Icons.person_outline, color: AppColors.orange, size: 36),
              title: const Text('Cambiar mis datos'),
              onTap: () => Navigator.pop(sheet, 'profile'),
            ),
            ListTile(
              leading: const IconTile(icon: Icons.dark_mode_outlined, color: AppColors.tealDark, size: 36),
              title: const Text('Tema'),
              subtitle: Text(_themeLabel(ref.read(themeModeProvider))),
              onTap: () => Navigator.pop(sheet, 'theme'),
            ),
            ListTile(
              leading: const IconTile(icon: Icons.insights_rounded, color: AppColors.teal, size: 36),
              title: const Text('Resumen cada noche y análisis del domingo'),
              subtitle: Text(ref.read(summaryNotificationsProvider) ? 'Activado' : 'Desactivado'),
              onTap: () => Navigator.pop(sheet, 'summaries'),
            ),
            ListTile(
              leading: const IconTile(icon: Icons.format_quote, color: AppColors.orange, size: 36),
              title: const Text('Frases motivadoras'),
              subtitle: Text(ref.read(motivationProvider).taste?.label ?? 'Sin elegir'),
              onTap: () => Navigator.pop(sheet, 'quotes'),
            ),
            ListTile(
              leading: const IconTile(icon: Icons.bubble_chart_outlined, color: AppColors.teal, size: 36),
              title: const Text('Burbuja sobre otras apps'),
              subtitle: Text(ref.read(overlayBubbleProvider) ? 'Activada' : 'Desactivada'),
              onTap: () => Navigator.pop(sheet, 'bubble'),
            ),
            ListTile(
              leading: IconTile(icon: Icons.info_outline, color: Theme.of(sheet).colorScheme.tertiary, size: 36),
              title: const Text('Créditos de imágenes'),
              onTap: () => Navigator.pop(sheet, 'credits'),
            ),
            const Divider(),
            ListTile(
              leading: IconTile(icon: Icons.delete_forever_outlined, color: Theme.of(sheet).colorScheme.error, size: 36),
              title: Text('Borrar todos los datos', style: TextStyle(color: Theme.of(sheet).colorScheme.error)),
              subtitle: const Text('Empezar de cero como recién instalada'),
              onTap: () => Navigator.pop(sheet, 'wipe'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'import':
        context.push('/import');
      case 'search':
        context.push('/search');
      case 'share':
        await _share(context);
      case 'publish':
        await showPublishSheet(context, ref);
      case 'following':
        await showFollowingSheet(context, ref);
      case 'account':
        await showAccountDialog(context, ref);
      case 'regen':
        if (ref.read(routineProvider)?.title != null) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('¿Generar otra rutina?'),
              content: const Text('Perderás la rutina que importaste. Puedes volver a importarla luego.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Generar')),
              ],
            ),
          );
          if (ok != true) return;
        }
        await ref.read(routineProvider.notifier).regenerate();
        await ref.read(dayOverrideProvider.notifier).set(0);
        await ref.read(syncProvider.notifier).stopFollowing();
      case 'profile':
        context.go('/onboarding');
      case 'theme':
        final picked = await showDialog<ThemeMode>(
          context: context,
          builder: (c) => SimpleDialog(
            title: const Text('Tema'),
            children: [
              for (final m in ThemeMode.values)
                ListTile(
                  title: Text(_themeLabel(m)),
                  trailing: m == ref.read(themeModeProvider) ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(c, m),
                ),
            ],
          ),
        );
        if (picked != null) await ref.read(themeModeProvider.notifier).set(picked);
      case 'summaries':
        final on = !ref.read(summaryNotificationsProvider);
        await ref.read(summaryNotificationsProvider.notifier).set(on);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(on
                ? 'Te avisaremos cada noche a las 21:30 y los domingos a las 20:00.'
                : 'Resúmenes desactivados.'),
          ));
        }
      case 'quotes':
        await showMotivationSettings(context);
      case 'bubble':
        await toggleOverlayBubble(context, ref);
      case 'wipe':
        final sure = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            icon: Icon(Icons.warning_amber_rounded, size: 40, color: Theme.of(c).colorScheme.error),
            title: const Text('¿Borrar todo?'),
            content: const Text(
              'Se borrarán tu perfil, la rutina, la racha y los protectores, el historial '
              'de entrenos y los gráficos, el entreno en curso, los recordatorios y tus ajustes.\n\n'
              'No se puede deshacer.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(c).colorScheme.error,
                  foregroundColor: Theme.of(c).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Borrar todo'),
              ),
            ],
          ),
        );
        if (sure == true && context.mounted) await wipeAllData(context, ref);
      case 'credits':
        showDialog<void>(context: context, builder: (_) => const _CreditsDialog());
    }
  }

  /// Other exercises for the same day (same muscles), with undo.
  Future<void> _regenerateDay(int day) async {
    final notifier = ref.read(routineProvider.notifier);
    final name = ref.read(routineProvider)!.days[day].name;
    final before = await notifier.regenerateDay(day);
    if (before == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('$name: ejercicios nuevos para los mismos músculos'),
      action: SnackBarAction(label: 'Deshacer', onPressed: () => notifier.replaceWith(before)),
    ));
  }

  /// Shares a link to the published routine. Without a connection, a message
  /// with the long code the other person pastes in "Importar mi rutina".
  Future<void> _share(BuildContext context) async {
    final linked = await shareRoutineLink(context, ref);
    if (linked != false || !context.mounted) return;
    final routine = ref.read(routineProvider);
    final exercises = await ref.read(exercisesProvider.future);
    if (routine == null) return;
    final byId = {for (final e in exercises) e.id: e};
    final title = routine.title ?? 'Mi rutina';
    final summary = [
      for (final d in routine.days)
        '• ${d.name}: ${d.items.map((i) => isCustomExercise(i.exerciseId) || routine.title != null ? i.slot : byId[i.exerciseId]?.name ?? i.slot).join(', ')}',
    ].join('\n');
    final code = encodeRoutine(routine, exercises);
    await SharePlus.instance.share(ShareParams(
      subject: 'Rutina: $title',
      text: '💪 Te paso mi rutina «$title» de FitStreak\n\n$summary\n\n'
          'Para usarla: mantén pulsado este mensaje → Compartir → FitStreak. '
          'O cópialo y abre FitStreak → Opciones → Importar mi rutina.\n\n$code',
    ));
  }

  /// Spanish label of theme mode [m].
  static String _themeLabel(ThemeMode m) => switch (m) {
        ThemeMode.system => 'Como el sistema',
        ThemeMode.light => 'Claro',
        ThemeMode.dark => 'Oscuro',
      };
}

/// Big card of the day to train, with its start button.
class _HeroCard extends StatelessWidget {
  /// Creates the card.
  const _HeroCard({
    required this.day,
    required this.isToday,
    required this.minutes,
    required this.preview,
    required this.resuming,
    required this.onStart,
  });

  /// A workout of this day is half done.
  final bool resuming;

  /// The day shown.
  final RoutineDay day;

  /// Whether it is the day that is due.
  final bool isToday;

  /// Estimated duration.
  final int minutes;

  /// Exercise whose drawing decorates the card.
  final Exercise? preview;

  /// Starts or resumes the workout.
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.teal, AppColors.tealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'HOY TOCA' : 'DÍA',
                  style: text.labelMedium?.copyWith(color: Colors.white70, letterSpacing: 1.2),
                ),
                const SizedBox(height: 4),
                Text(day.name, style: text.titleLarge?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  '${day.items.length} ejercicios · $minutes min',
                  style: text.bodyMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(resuming ? 'Continuar' : 'Empezar'),
                ),
              ],
            ),
          ),
          if (preview != null) ...[
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 110,
                height: 120,
                child: ExerciseMedia(preview!, animate: true),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// An exercise of a day: drawing, sets, options and the swap menu.
class _ItemCard extends ConsumerWidget {
  /// Creates the card.
  const _ItemCard({
    required this.day,
    required this.index,
    required this.item,
    required this.exercise,
  });

  /// Day index.
  final int day;

  /// Position within the day.
  final int index;

  /// The routine item.
  final RoutineItem item;

  /// Its current exercise.
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/exercise/${exercise.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox.square(dimension: 72, child: ExerciseMedia(exercise)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.slot.toUpperCase(),
                      style: text.labelSmall?.copyWith(color: AppColors.teal, letterSpacing: 0.8),
                    ),
                    Text(exercise.name, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(
                      '${item.sets} × ${item.reps} · ${item.restSeconds} s · '
                      '${es(equipmentEs, exercise.equipmentOrBody)}',
                      style: text.bodySmall,
                    ),
                    // "Fondos o jalón de tríceps": tap to do the other one.
                    for (final (o, alt) in item.alternatives.indexed)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: InputChip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.swap_vert, size: 16, color: AppColors.teal),
                          label: Text('o ${alt.slot}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          tooltip: 'Hacer ${alt.slot} en su lugar',
                          onPressed: () =>
                              ref.read(routineProvider.notifier).chooseOption(day, index, o),
                          deleteButtonTooltipMessage: 'Quitar esta opción',
                          onDeleted: () => ref.read(routineProvider.notifier).removeOption(day, index, o),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconTile(
                icon: Icons.swap_horiz,
                size: 36,
                tooltip: 'Cambiar ejercicio',
                onTap: () => _showAlternatives(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Swap sheet: similar exercises to replace it or add as another option.
  Future<void> _showAlternatives(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(routineProvider.notifier);
    final gen = await notifier.generator();
    final options = gen.alternatives(exercise);
    if (!context.mounted) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scroll) => ListView(
          controller: scroll,
          children: [
            ListTile(
              leading: const IconTile(icon: Icons.search, color: AppColors.teal, size: 36),
              title: const Text('Buscar en el catálogo'),
              subtitle: const Text('Elige cualquier ejercicio'),
              onTap: () => Navigator.pop(sheet, '__search__'),
            ),
            ListTile(
              leading: const IconTile(icon: Icons.alt_route, color: AppColors.orange, size: 36),
              title: const Text('Añadir otra opción'),
              subtitle: Text('«${item.slot} o …»: el día del entreno eliges cuál'),
              onTap: () => Navigator.pop(sheet, '__option__'),
            ),
            ListTile(
              leading: IconTile(icon: Icons.block, color: Theme.of(sheet).colorScheme.tertiary, size: 36),
              title: const Text('No tengo este equipo o máquina'),
              subtitle: const Text('No volveremos a proponértelo'),
              onTap: () => Navigator.pop(sheet, '__block__'),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                options.isEmpty
                    ? 'No hay alternativas con tu equipo'
                    : 'Alternativas que trabajan lo mismo',
                style: Theme.of(sheet).textTheme.titleSmall,
              ),
            ),
            for (final alt in options)
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.square(dimension: 48, child: ExerciseMedia(alt)),
                ),
                title: Text(alt.name),
                subtitle: Text(
                  '${es(equipmentEs, alt.equipmentOrBody)} · ${es(levelEs, alt.level)}',
                ),
                onTap: () => Navigator.pop(sheet, alt.id),
              ),
          ],
        ),
      ),
    );

    if (picked == null) return;
    if (picked == '__option__') {
      final catalog = await ref.read(exercisesProvider.future);
      if (!context.mounted) return;
      final found = await showExercisePicker(
        context,
        catalog: [for (final e in catalog) if (!isCustomExercise(e.id)) e],
        initialQuery: '',
      );
      if (found case PickedFromCatalog(:final exercise)) {
        await notifier.addOption(day, index, exerciseId: exercise.id, slot: exercise.name);
      }
      return;
    }
    if (picked == '__search__') {
      final catalog = await ref.read(exercisesProvider.future);
      if (!context.mounted) return;
      final found = await showExercisePicker(
        context,
        catalog: [for (final e in catalog) if (!isCustomExercise(e.id)) e],
        initialQuery: item.slot,
      );
      if (found case PickedFromCatalog(:final exercise)) await notifier.swap(day, index, exercise.id);
      return;
    }
    if (picked == '__block__') {
      await notifier.block(day, index);
    } else {
      await notifier.swap(day, index, picked);
    }
  }
}

/// Day reminder of an imported routine.
class _NoteCard extends StatelessWidget {
  /// Creates the card.
  const _NoteCard(this.note);

  /// Reminder text.
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📌 '),
          Expanded(child: Text(note, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Credits and licenses of the exercise data and drawings.
class _CreditsDialog extends StatelessWidget {
  /// Creates the dialog.
  const _CreditsDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créditos'),
      content: const Text(
        'Fotos e instrucciones: free-exercise-db (github.com/yuhonas/free-exercise-db), '
        'dominio público.\n\n'
        'Dibujos: Everkinetic (github.com/everkinetic/data), licencia '
        'Creative Commons BY-SA 4.0.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}
