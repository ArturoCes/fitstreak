import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/exercise.dart';
import '../../data/exercise_repository.dart';
import '../../data/progress_state.dart';
import '../../data/routine.dart';
import '../../data/routine_import.dart';
import '../../data/routine_share.dart';
import '../../data/sync/routine_sync.dart';
import '../../data/sync/sync_state.dart';
import '../../ui/exercise_media.dart';
import '../../ui/exercise_picker.dart';
import '../../ui/theme.dart';

/// An exercise of the routine being imported, matched (or not) with the
/// catalog.
class _DraftItem {
  /// Creates the draft exercise.
  _DraftItem({
    required this.name,
    required this.note,
    required this.sets,
    required this.reps,
    required this.rest,
    required this.exercise,
    required this.quality,
    List<({String name, Exercise? exercise})>? alts,
  }) : alts = [...?alts];

  /// Name as written.
  final String name;

  /// Comment in parentheses.
  final String? note;

  /// Number of sets.
  final int sets;

  /// Rep range or seconds.
  final String reps;

  /// Rest in seconds.
  final int rest;

  /// Matched exercise; null = it will be saved as a custom exercise.
  Exercise? exercise;

  /// How reliable the match is.
  MatchQuality quality;

  /// "Fondos o jalón de tríceps": the other options (null exercise = custom).
  /// They can be added and removed in the review.
  final List<({String name, Exercise? exercise})> alts;
}

/// A day of the routine being imported.
class _DraftDay {
  /// Creates the draft day.
  _DraftDay(this.name, this.note, this.items);

  /// Day name.
  final String name;

  /// Day reminder.
  final String? note;

  /// Exercises in order.
  final List<_DraftItem> items;
}

/// The routine being imported, as understood, before saving it.
class _Draft {
  /// Creates the draft.
  _Draft({required this.title, required this.days, required this.notes, this.customs = const [], this.remote});

  /// Routine title.
  final String title;

  /// Days.
  final List<_DraftDay> days;

  /// General notes.
  final List<String> notes;

  /// Custom exercises that come in a shared code.
  final List<Exercise> customs;

  /// Published routine (FS-… code): it is followed when saved.
  final RemoteRoutine? remote;

  /// Every exercise across the days.
  Iterable<_DraftItem> get items => days.expand((d) => d.items);
}

/// Paste or open a hand-written routine (or a shared code or link), review
/// how it was understood and save it as the user's routine.
class ImportRoutineScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [initialText] is read right away.
  const ImportRoutineScreen({super.key, this.initialText});

  /// Text from "Share → FitStreak": it is read directly.
  final String? initialText;

  @override
  ConsumerState<ImportRoutineScreen> createState() => _ImportRoutineScreenState();
}

/// Input text, the parsed draft and the save flow.
class _ImportRoutineScreenState extends ConsumerState<ImportRoutineScreen> {
  final _text = TextEditingController();
  final _title = TextEditingController();
  _Draft? _draft;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    final initial = widget.initialText;
    if (initial != null && initial.trim().isNotEmpty) {
      _text.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
    }
  }

  /// If the clipboard holds a message with a routine code, it is used.
  Future<void> _checkClipboard() async {
    try {
      final copied = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (copied == null || !mounted || _text.text.isNotEmpty) return;
      if (!copied.contains(sharePrefix) && parseRoutineCode(copied) == null) return;
      _text.text = copied;
      await _analyze();
    } catch (_) {
      // No permission to read the clipboard (web): pasted by hand.
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _title.dispose();
    super.dispose();
  }

  /// Pastes the clipboard text.
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text case final t? when t.trim().isNotEmpty) {
      _text.text = t;
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay texto copiado.')));
    }
  }

  /// Opens a .txt, .md or .docx file and loads its text.
  Future<void> _openFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['txt', 'md', 'docx'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final text = file.name.toLowerCase().endsWith('.docx')
          ? docxToText(bytes)
          : utf8.decode(bytes, allowMalformed: true);
      _text.text = text;
      setState(() => _error = null);
    } catch (e) {
      setState(() => _error = 'No pude leer el archivo. Usa un .txt o un .docx (Word), o copia y pega el texto.');
    }
  }

  /// Reads the text (code, link or hand-written routine) into a draft.
  Future<void> _analyze() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final catalog = await ref.read(exercisesProvider.future);
    final byId = {for (final e in catalog) e.id: e};
    final text = _text.text;

    _Draft? draft;
    var shared = decodeRoutine(text);
    RemoteRoutine? remote;
    if (shared == null && !text.contains(sharePrefix)) {
      if (parseRoutineCode(text) case final id?) {
        try {
          remote = await ref.read(syncProvider.notifier).lookup(id);
        } catch (e) {
          debugPrint('No se pudo leer la rutina $id: $e');
          setState(() {
            _busy = false;
            _error = 'No hay conexión con el servidor. Prueba otra vez en un rato.';
          });
          return;
        }
        if (remote == null) {
          setState(() {
            _busy = false;
            _error = 'No existe ninguna rutina con el código ${formatCode(id)}. Revisa que esté bien copiado.';
          });
          return;
        }
        shared = sharedFromPayload(remote.payload);
      }
    }
    if (shared != null) {
      final customs = {for (final c in shared.customExercises) c.id: c};
      draft = _Draft(
        title: remote?.title ?? shared.routine.title ?? 'Rutina compartida',
        notes: shared.routine.notes,
        customs: shared.customExercises,
        remote: remote,
        days: [
          for (final d in shared.routine.days)
            _DraftDay(d.name, d.note, [
              for (final i in d.items)
                _DraftItem(
                  name: i.slot,
                  note: i.note,
                  sets: i.sets,
                  reps: i.reps,
                  rest: i.restSeconds,
                  exercise: byId[i.exerciseId] ?? customs[i.exerciseId],
                  quality: MatchQuality.exact,
                  alts: [
                    for (final a in i.alternatives)
                      (name: a.slot, exercise: byId[a.exerciseId] ?? customs[a.exerciseId]),
                  ],
                ),
            ]),
        ],
      );
    } else if (text.contains(sharePrefix)) {
      setState(() {
        _busy = false;
        _error = 'El código está incompleto. Copia el mensaje entero que te enviaron.';
      });
      return;
    } else {
      final parsed = parseRoutineText(text);
      if (parsed.exerciseCount > 0) {
        draft = _Draft(
          title: parsed.title ?? 'Mi rutina',
          notes: parsed.notes,
          days: [
            for (final d in parsed.days)
              _DraftDay(d.name, d.note, [
                for (final i in d.items)
                  () {
                    final m = matchExercise(i.name, catalog);
                    return _DraftItem(
                      name: i.name,
                      note: i.note,
                      sets: i.sets,
                      reps: i.reps,
                      rest: i.restSeconds ??
                          (looksIsolation(i.name, m.exercise) ? parsed.smallRest : parsed.bigRest),
                      exercise: m.exercise,
                      quality: m.quality,
                      alts: [
                        for (final a in i.alternatives) (name: a, exercise: matchExercise(a, catalog).exercise),
                      ],
                    );
                  }(),
              ]),
          ],
        );
      }
    }

    setState(() {
      _busy = false;
      if (draft == null) {
        _error = 'No encontré ejercicios. Cada uno necesita sus series y repeticiones, '
            'por ejemplo: «Press banca → 4x8-10».';
      } else {
        _draft = draft;
        _title.text = draft.title;
      }
    });
  }

  /// Tapping an exercise in the review: change it, add another option
  /// ("Fondos o extensión de tríceps") or remove one it has.
  Future<void> _edit(_DraftItem item) async {
    final action = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(item.name, style: Theme.of(sheet).textTheme.titleMedium),
            ),
            ListTile(
              leading: const IconTile(icon: Icons.swap_horiz, color: AppColors.teal, size: 36),
              title: const Text('Cambiar por otro ejercicio'),
              subtitle: const Text('Cualquiera del catálogo, o dejarlo como propio'),
              onTap: () => Navigator.pop(sheet, 'change'),
            ),
            ListTile(
              leading: const IconTile(icon: Icons.alt_route, color: AppColors.orange, size: 36),
              title: const Text('Añadir otra opción'),
              subtitle: Text('«${item.name} o …»: el día del entreno eliges cuál'),
              onTap: () => Navigator.pop(sheet, 'add'),
            ),
            for (final (i, a) in item.alts.indexed)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: Text('Quitar «o ${a.name}»'),
                onTap: () => Navigator.pop(sheet, i),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action is int) {
      setState(() => item.alts.removeAt(action));
    } else if (action == 'add') {
      await _addOption(item);
    } else {
      await _change(item);
    }
  }

  /// Adds a catalog exercise as another option of [item].
  Future<void> _addOption(_DraftItem item) async {
    final catalog = await ref.read(exercisesProvider.future);
    if (!mounted) return;
    final picked = await showExercisePicker(
      context,
      catalog: [for (final e in catalog) if (!isCustomExercise(e.id)) e],
      initialQuery: '',
    );
    if (picked case PickedFromCatalog(:final exercise)) {
      setState(() => item.alts.add((name: exercise.name, exercise: exercise)));
    }
  }

  /// Replaces [item]'s exercise, or keeps it as a custom one.
  Future<void> _change(_DraftItem item) async {
    final catalog = await ref.read(exercisesProvider.future);
    if (!mounted) return;
    final picked = await showExercisePicker(
      context,
      catalog: [for (final e in catalog) if (!isCustomExercise(e.id)) e],
      initialQuery: item.name,
      allowCustom: true,
    );
    if (picked == null) return;
    setState(() {
      switch (picked) {
        case PickedFromCatalog(:final exercise):
          item.exercise = exercise;
          item.quality = MatchQuality.exact;
        case PickedCustom():
          item.exercise = null;
          item.quality = MatchQuality.none;
      }
    });
  }

  /// Saves the draft as the user's routine (with confirmation if there was
  /// one), its custom exercises, the day order and the following state.
  Future<void> _save() async {
    final draft = _draft!;
    if (ref.read(routineProvider) != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('¿Usar esta rutina?'),
          content: const Text('Sustituirá a tu rutina actual. Tu historial, tus gráficos y tu racha se mantienen.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Usar esta')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);

    // Unmatched ones are saved as custom exercises.
    final customs = <String, Exercise>{for (final c in draft.customs) c.id: c};
    String idOf(String name, Exercise? e) {
      if (e != null) {
        if (isCustomExercise(e.id)) customs[e.id] = e;
        return e.id;
      }
      final id = customIdFor(name);
      customs[id] = customExercise(id: id, name: name, equipment: customEquipmentFor(name));
      return id;
    }

    final routine = Routine(
      title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      notes: draft.notes,
      days: [
        for (final d in draft.days)
          RoutineDay(
            name: d.name,
            note: d.note,
            items: [
              for (final i in d.items)
                RoutineItem(
                  exerciseId: idOf(i.name, i.exercise),
                  slot: i.name,
                  sets: i.sets,
                  reps: i.reps,
                  restSeconds: i.rest,
                  note: i.note,
                  alternatives: [
                    for (final a in i.alts) ExerciseOption(exerciseId: idOf(a.name, a.exercise), slot: a.name),
                  ],
                ),
            ],
          ),
      ],
    );

    final prefs = ref.read(prefsProvider);
    await saveCustomExercises(prefs, customs.values.toList());
    ref.invalidate(exercisesProvider);
    await ref.read(routineProvider.notifier).replaceWith(routine);
    // New routine: start with its first day.
    await ref.read(dayOverrideProvider.notifier).set(0);
    // With an FS- code the routine is followed; anything else stops following.
    final sync = ref.read(syncProvider.notifier);
    try {
      draft.remote == null ? await sync.stopFollowing() : await sync.startFollowing(draft.remote!);
    } catch (e) {
      debugPrint('No se pudo apuntar como seguidor: $e');
    }
    // The streak uses the days per week to know how many rests are allowed.
    final profile = ref.read(profileProvider);
    if (profile != null) {
      await ref
          .read(profileProvider.notifier)
          .save(profile.copyWith(daysPerWeek: routine.days.length.clamp(2, 6)));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rutina guardada: ${routine.days.length} días, ${draft.items.length} ejercicios')),
    );
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return PopScope(
      canPop: draft == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _draft = null);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(draft == null ? 'Importar rutina' : 'Revisa tu rutina')),
        body: draft == null ? _input(context) : _review(context, draft),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: _busy
                  ? null
                  : draft == null
                      ? (_text.text.trim().isEmpty ? null : _analyze)
                      : _save,
              icon: Icon(draft == null ? Icons.auto_fix_high : Icons.check),
              label: Text(draft == null
                  ? 'Leer rutina'
                  : draft.remote == null
                      ? 'Guardar como mi rutina'
                      : 'Seguir esta rutina'),
            ),
          ),
        ),
      ),
    );
  }

  /// Step 1: paste or open the routine.
  Widget _input(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Pega tu rutina tal cual la tienes (WhatsApp, notas…), abre un archivo, '
          'o pega el mensaje con el código que te ha pasado otra persona.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 12),
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: const Text('Pegar'),
              ),
            ),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openFile,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Abrir archivo'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          minLines: 12,
          maxLines: 20,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: 'DÍA 1 – PUSH\n'
                '• Press banca → 4x6-10\n'
                '• Elevaciones laterales → 3x12\n'
                '📌 Recordatorio: técnica limpia\n\n'
                'DÍA 2 – PULL\n'
                '• Dominadas → 4x6-10\n'
                '…',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 12),
        Text(
          'Cada ejercicio necesita series × repeticiones (4x8-10, 3 x 12, 3x30s, 3 series). '
          'Los títulos con «Día 1», «Push», «Pierna»… separan los días. '
          'Los descansos se leen de una sección «Descansos» si la hay.',
          style: text.bodySmall,
        ),
      ],
    );
  }

  /// Step 2: review the understood routine before saving.
  Widget _review(BuildContext context, _Draft draft) {
    final text = Theme.of(context).textTheme;
    final approx = draft.items.where((i) => i.quality == MatchQuality.approximate).length;
    final custom = draft.items.where((i) => i.exercise == null || i.exercise!.images.isEmpty).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Nombre de la rutina'),
        ),
        if (draft.remote case final r?) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sync, color: AppColors.teal),
              title: Text('Rutina de ${r.author}'),
              subtitle: const Text('Cuando la cambie, te preguntaremos si quieres la versión nueva.'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Stat('${draft.days.length} días', AppColors.teal),
            _Stat('${draft.items.length} ejercicios', AppColors.tealDark),
            if (approx > 0) _Stat('$approx para revisar', AppColors.orange),
            if (custom > 0) _Stat('$custom sin foto', AppColors.muted),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Toca un ejercicio para cambiarlo por cualquier otro o añadirle otra opción '
          '(«Fondos o extensión de tríceps»). Los de «revisar» son una equivalencia aproximada.',
          style: text.bodySmall,
        ),
        for (final d in draft.days) ...[
          const SizedBox(height: 18),
          Text(d.name, style: text.titleLarge),
          if (d.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text('📌 ${d.note!.replaceAll('\n', ' · ')}', style: text.bodySmall),
            ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final i in d.items) _ItemTile(item: i, onTap: () => _edit(i)),
              ],
            ),
          ),
        ],
        if (draft.notes.isNotEmpty) ...[
          const SizedBox(height: 18),
          Card(
            child: ExpansionTile(
              shape: const Border(),
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: Text('Notas de la rutina (${draft.notes.length})'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final n in draft.notes)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(n)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Summary pill ("4 días", "2 para revisar").
class _Stat extends StatelessWidget {
  /// Creates the pill.
  const _Stat(this.label, this.color);

  /// Text.
  final String label;

  /// Text and tint color.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color)),
    );
  }
}

/// A reviewed exercise: thumbnail, match status, sets and rest.
class _ItemTile extends StatelessWidget {
  /// Creates the tile.
  const _ItemTile({required this.item, required this.onTap});

  /// The draft exercise.
  final _DraftItem item;

  /// Opens its menu.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final e = item.exercise;
    final (IconData icon, Color color, String status) = e == null
        ? (Icons.edit_note, AppColors.muted, 'Ejercicio propio (sin foto)')
        : item.quality == MatchQuality.approximate
            ? (Icons.help_outline, AppColors.orange, 'Revisa: ${e.name}')
            : (Icons.check_circle, AppColors.teal, e.name);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox.square(
                dimension: 52,
                child: e == null
                    ? ColoredBox(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.fitness_center, color: AppColors.muted),
                      )
                    : ExerciseMedia(e),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.note == null ? item.name : '${item.name} (${item.note!.toLowerCase()})',
                    style: text.titleSmall,
                  ),
                  for (final a in item.alts)
                    Text('o ${a.name}', style: text.bodySmall?.copyWith(color: AppColors.teal)),
                  Row(
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: color),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${item.sets}×${item.reps}', style: text.titleSmall),
                Text('${item.rest} s', style: text.bodySmall),
              ],
            ),
            // Hint that it can be tapped to change it.
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.more_vert, size: 20, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
