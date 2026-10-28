import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/labels_es.dart';
import '../../data/motivation.dart';
import '../../data/progress_state.dart';
import '../routine/share_receiver.dart';
import '../../data/user_profile.dart';
import '../../data/sync/sync_state.dart';

/// First-run questions (body, goal, schedule, equipment, quotes, health)
/// that build the profile and the first routine.
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// The answers and the current step.
class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _step = 0;
  bool _saving = false;

  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  Sex? _sex;
  Goal? _goal;
  Level? _level;
  int _days = 3;
  int _minutes = 45;
  Place? _place;
  final Set<String> _equipment = {};
  final Set<Injury> _injuries = {};
  MotivationTaste? _taste;
  bool _acceptedDisclaimer = false;

  static const _stepCount = 6;

  @override
  void initState() {
    super.initState();
    // So the "Siguiente" button enables while typing.
    for (final c in [_age, _height, _weight]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  /// Typed age, if valid.
  int? get _ageValue => int.tryParse(_age.text);
  /// Typed height, if valid.
  int? get _heightValue => int.tryParse(_height.text);
  /// Typed weight (comma or dot), if valid.
  double? get _weightValue => double.tryParse(_weight.text.replaceAll(',', '.'));

  /// Whether the current step is complete.
  bool get _canContinue => switch (_step) {
        0 => _sex != null &&
            _inRange(_ageValue, _minAge, _maxAge) &&
            _inRange(_heightValue, _minHeight, _maxHeight) &&
            _inRange(_weightValue, _minWeight, _maxWeight),
        1 => _goal != null && _level != null,
        2 => true,
        3 => _place != null,
        4 => _taste != null,
        _ => _acceptedDisclaimer,
      };

  /// Whether [v] is set and within [min]..[max].
  static const _minAge = 14, _maxAge = 99;
  static const _minHeight = 120, _maxHeight = 230;
  static const _minWeight = 30, _maxWeight = 300;

  static bool _inRange(num? v, num min, num max) =>
      v != null && v >= min && v <= max;

  /// Picks gym or home and presets the equipment.
  void _selectPlace(Place p) => setState(() {
        _place = p;
        _equipment.clear();
        // At the gym everything is assumed and the user removes what's missing.
        if (p == Place.gym) {
          _equipment.addAll([...datasetEquipment, ...extraEquipment]);
        }
      });

  /// Next step, or on the last one saves the profile and builds the routine.
  Future<void> _next() async {
    if (_step < _stepCount - 1) {
      setState(() => _step++);
      // To the step's page, not "the next one": two quick taps would leave
      // the page behind the step counter.
      await _pages.animateToPage(
        _step,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    setState(() => _saving = true);
    await ref.read(profileProvider.notifier).save(
          UserProfile(
            age: _ageValue!,
            sex: _sex!,
            heightCm: _heightValue!,
            weightKg: _weightValue!,
            goal: _goal!,
            level: _level!,
            daysPerWeek: _days,
            minutesPerSession: _minutes,
            place: _place!,
            equipment: {..._equipment},
            injuries: {..._injuries},
          ),
        );
    await ref.read(motivationProvider.notifier).setTaste(_taste!);
    await ref.read(routineProvider.notifier).regenerate();
    // New routine: the one followed from someone else is no longer theirs.
    await ref.read(syncProvider.notifier).stopFollowing();
    await ref.read(dayOverrideProvider.notifier).set(0);
    if (!mounted) return;
    context.go('/');
    // If someone shared a routine before the app was set up, now is the time
    // to import it.
    final prefs = ref.read(prefsProvider);
    final pending = prefs.getString(pendingImportKey);
    if (pending != null) {
      await prefs.remove(pendingImportKey);
      if (mounted) context.push('/import', extra: pending);
    }
  }

  /// Previous step.
  void _back() {
    setState(() => _step--);
    _pages.animateToPage(
      _step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _step == 0
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
        title: Text('Paso ${_step + 1} de $_stepCount'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_step + 1) / _stepCount),
        ),
      ),
      body: PageView(
        controller: _pages,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _bodyStep(),
          _goalStep(),
          _scheduleStep(),
          _equipmentStep(),
          _motivationStep(),
          _healthStep(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _canContinue && !_saving ? _next : null,
            child: Text(_step == _stepCount - 1 ? 'Crear mi rutina' : 'Siguiente'),
          ),
        ),
      ),
    );
  }

  /// Step 1: sex, age, height and weight.
  Widget _bodyStep() => _StepList(
        title: 'Cuéntanos sobre ti',
        subtitle: 'Lo usamos para ajustar la intensidad de la rutina.',
        children: [
          Text('Sexo', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in Sex.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: _sex == s,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: _sex == s ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  ),
                  onSelected: (_) => setState(() => _sex = s),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Solo para calcular las calorías que gastas.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _NumberField(controller: _age, label: 'Edad', suffix: 'años', min: _minAge, max: _maxAge),
          _NumberField(controller: _height, label: 'Altura', suffix: 'cm', min: _minHeight, max: _maxHeight),
          _NumberField(
            controller: _weight,
            label: 'Peso',
            suffix: 'kg',
            decimal: true,
            min: _minWeight,
            max: _maxWeight,
          ),
        ],
      );

  /// Step 2: goal and level.
  Widget _goalStep() => _StepList(
        title: '¿Qué buscas?',
        children: [
          for (final g in Goal.values)
            _Choice(
              label: g.label,
              selected: _goal == g,
              onTap: () => setState(() => _goal = g),
            ),
          const SizedBox(height: 16),
          Text('Tu nivel', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final l in Level.values)
            _Choice(
              label: l.label,
              subtitle: l.description,
              selected: _level == l,
              onTap: () => setState(() => _level = l),
            ),
        ],
      );

  /// Step 3: days per week and session length.
  Widget _scheduleStep() => _StepList(
        title: '¿Cuánto puedes entrenar?',
        children: [
          Text('Días por semana: $_days'),
          Slider(
            value: _days.toDouble(),
            min: 2,
            max: 6,
            divisions: 4,
            label: '$_days',
            onChanged: (v) => setState(() => _days = v.round()),
          ),
          const SizedBox(height: 16),
          const Text('Minutos por sesión'),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              for (final m in const [30, 45, 60, 75])
                ButtonSegment(value: m, label: Text('$m')),
            ],
            selected: {_minutes},
            onSelectionChanged: (s) => setState(() => _minutes = s.first),
          ),
        ],
      );

  /// Step 4: gym or home, and the equipment.
  Widget _equipmentStep() => _StepList(
        title: '¿Dónde entrenas?',
        children: [
          Row(
            spacing: 12,
            children: [
              for (final p in Place.values)
                Expanded(
                  child: _Choice(
                    label: p.label,
                    icon: p == Place.gym ? Icons.fitness_center : Icons.home,
                    selected: _place == p,
                    onTap: () => _selectPlace(p),
                  ),
                ),
            ],
          ),
          if (_place != null) ...[
            const SizedBox(height: 16),
            Text(
              _place == Place.gym
                  ? 'Desmarca lo que tu gimnasio NO tenga'
                  : 'Marca lo que tienes en casa',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final eq in [...datasetEquipment, ...extraEquipment])
                  FilterChip(
                    label: Text(equipmentEs[eq] ?? extraEquipmentEs[eq] ?? eq),
                    selected: _equipment.contains(eq),
                    onSelected: (on) => setState(
                      () => on ? _equipment.add(eq) : _equipment.remove(eq),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Los ejercicios con tu propio peso siempre están incluidos.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      );

  /// Step 5: quote taste.
  Widget _motivationStep() => _StepList(
        title: '¿Qué te motiva más?',
        subtitle: 'Cada día verás una frase de tus personajes favoritos. '
            'Luego puedes poner una imagen tuya de fondo.',
        children: [
          for (final t in MotivationTaste.values)
            _Choice(
              label: '${t.emoji}  ${t.label}',
              subtitle: switch (t) {
                MotivationTaste.anime => 'Slam Dunk, Haikyuu, Naruto, One Piece…',
                MotivationTaste.movies => 'Rocky, Star Wars, Gladiator…',
                MotivationTaste.both => 'Un poco de todo',
                MotivationTaste.none => 'Sin frases en la pantalla de inicio',
              },
              selected: _taste == t,
              onTap: () => setState(() => _taste = t),
            ),
        ],
      );

  /// Step 6: injuries and the medical disclaimer.
  Widget _healthStep() => _StepList(
        title: '¿Alguna molestia o lesión?',
        subtitle: 'Apartaremos los ejercicios que más cargan esa zona.',
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final i in Injury.values)
                FilterChip(
                  label: Text(i.label),
                  selected: _injuries.contains(i),
                  onSelected: (on) => setState(
                    () => on ? _injuries.add(i) : _injuries.remove(i),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: CheckboxListTile(
              value: _acceptedDisclaimer,
              onChanged: (v) => setState(() => _acceptedDisclaimer = v ?? false),
              title: const Text('Entiendo que esta app no sustituye el consejo médico'),
              subtitle: const Text(
                'Si tienes una lesión o enfermedad, consulta con un profesional '
                'antes de empezar. Para el entreno si sientes dolor.',
              ),
            ),
          ),
        ],
      );
}

/// A step's scrollable page with title and subtitle.
class _StepList extends StatelessWidget {
  /// Creates the page.
  const _StepList({required this.title, this.subtitle, required this.children});

  /// Question of the step.
  final String title;

  /// Explanation under the title.
  final String? subtitle;

  /// The step's fields.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: text.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: text.bodyMedium),
        ],
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

/// Numeric text field with a unit suffix. Says so when the typed value is
/// out of [min]..[max].
class _NumberField extends StatelessWidget {
  /// Creates the field.
  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.min,
    required this.max,
    this.decimal = false,
  });

  /// Holds the typed text.
  final TextEditingController controller;

  /// Field label.
  final String label;

  /// Unit ("años", "cm", "kg").
  final String suffix;

  /// Allows decimals (comma or dot).
  final bool decimal;

  /// Smallest valid value.
  final int min;

  /// Largest valid value.
  final int max;

  /// Something was typed and it is not a valid value.
  bool get _outOfRange {
    if (controller.text.isEmpty) return false;
    final v = num.tryParse(controller.text.replaceAll(',', '.'));
    return v == null || v < min || v > max;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]')),
          // Three digits, plus one decimal for the weight ("72,5").
          LengthLimitingTextInputFormatter(decimal ? 5 : 3),
        ],
        decoration: InputDecoration(
          labelText: label,
          errorText: _outOfRange ? 'Entre $min y $max $suffix' : null,
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// A selectable option card.
class _Choice extends StatelessWidget {
  /// Creates the option.
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  /// Option text.
  final String label;

  /// Explanation under it.
  final String? subtitle;

  /// Leading icon (narrow side-by-side options).
  final IconData? icon;

  /// Whether it is chosen.
  final bool selected;

  /// Chooses it.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.primaryContainer : null,
      child: ListTile(
        leading: icon == null ? null : Icon(icon),
        // Beside an icon in a half-width card: shrink instead of breaking
        // the word ("Gimnasi/o").
        title: icon == null
            ? Text(label)
            : FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(label, maxLines: 1),
              ),
        subtitle: subtitle == null ? null : Text(subtitle!),
        // With an icon it sits in a narrow row: the color shows the selection.
        trailing: selected && icon == null ? const Icon(Icons.check_circle) : null,
        onTap: onTap,
      ),
    );
  }
}
