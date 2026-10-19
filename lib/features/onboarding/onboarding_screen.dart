import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/labels_es.dart';
import '../../data/user_profile.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _step = 0;
  bool _saving = false;

  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  Goal? _goal;
  Level? _level;
  int _days = 3;
  int _minutes = 45;
  Place? _place;
  final Set<String> _equipment = {};
  final Set<Injury> _injuries = {};
  bool _acceptedDisclaimer = false;

  static const _stepCount = 5;

  @override
  void initState() {
    super.initState();
    // Para que el botón "Siguiente" se active al escribir.
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

  int? get _ageValue => int.tryParse(_age.text);
  int? get _heightValue => int.tryParse(_height.text);
  double? get _weightValue => double.tryParse(_weight.text.replaceAll(',', '.'));

  bool get _canContinue => switch (_step) {
        0 => _inRange(_ageValue, 14, 99) &&
            _inRange(_heightValue, 120, 230) &&
            _inRange(_weightValue, 30, 300),
        1 => _goal != null && _level != null,
        2 => true,
        3 => _place != null,
        _ => _acceptedDisclaimer,
      };

  static bool _inRange(num? v, num min, num max) =>
      v != null && v >= min && v <= max;

  void _selectPlace(Place p) => setState(() {
        _place = p;
        _equipment.clear();
        // En el gimnasio damos todo por hecho y el usuario quita lo que falte.
        if (p == Place.gym) {
          _equipment.addAll([...datasetEquipment, ...extraEquipment]);
        }
      });

  Future<void> _next() async {
    if (_step < _stepCount - 1) {
      setState(() => _step++);
      await _pages.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    setState(() => _saving = true);
    await ref.read(profileProvider.notifier).save(
          UserProfile(
            age: _ageValue!,
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
    await ref.read(routineProvider.notifier).regenerate();
    if (mounted) context.go('/');
  }

  void _back() {
    setState(() => _step--);
    _pages.previousPage(
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

  Widget _bodyStep() => _StepList(
        title: 'Cuéntanos sobre ti',
        subtitle: 'Lo usamos para ajustar la intensidad de la rutina.',
        children: [
          _NumberField(controller: _age, label: 'Edad', suffix: 'años'),
          _NumberField(controller: _height, label: 'Altura', suffix: 'cm'),
          _NumberField(
            controller: _weight,
            label: 'Peso',
            suffix: 'kg',
            decimal: true,
          ),
        ],
      );

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

class _StepList extends StatelessWidget {
  const _StepList({required this.title, this.subtitle, required this.children});

  final String title;
  final String? subtitle;
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

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
    this.decimal = false,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]')),
        ],
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.primaryContainer : null,
      child: ListTile(
        leading: icon == null ? null : Icon(icon),
        title: Text(label),
        subtitle: subtitle == null ? null : Text(subtitle!),
        // Con icono va en una fila estrecha: la selección ya se ve por el color.
        trailing: selected && icon == null ? const Icon(Icons.check_circle) : null,
        onTap: onTap,
      ),
    );
  }
}
