import 'dart:math';

import 'equipment_rules.dart';
import 'exercise.dart';
import 'routine.dart';
import 'user_profile.dart';

/// Un hueco de la rutina: qué tipo de ejercicio queremos, no cuál en concreto.
class Slot {
  const Slot(this.label, this.muscles, {this.force, this.mechanic});

  final String label;
  final Set<String> muscles;
  final String? force; // push | pull | static
  final String? mechanic; // compound | isolation
}

const _squat = Slot('Pierna (sentadilla)', {'quadriceps'}, mechanic: 'compound');
const _hinge = Slot(
  'Bisagra de cadera',
  {'hamstrings', 'glutes', 'lower back'},
  mechanic: 'compound',
);
const _chestPress = Slot(
  'Empuje de pecho',
  {'chest'},
  force: 'push',
  mechanic: 'compound',
);
const _verticalPull = Slot(
  'Tirón vertical',
  {'lats'},
  force: 'pull',
  mechanic: 'compound',
);
const _row = Slot(
  'Remo',
  {'middle back', 'lats'},
  force: 'pull',
  mechanic: 'compound',
);
const _shoulderPress = Slot(
  'Empuje de hombro',
  {'shoulders'},
  force: 'push',
  mechanic: 'compound',
);
const _lateral = Slot('Hombro (aislamiento)', {'shoulders'}, mechanic: 'isolation');
const _chestIso = Slot('Pecho (aislamiento)', {'chest'}, mechanic: 'isolation');
const _glutes = Slot('Glúteo', {'glutes'});
const _quadIso = Slot('Cuádriceps (aislamiento)', {'quadriceps'}, mechanic: 'isolation');
const _hamIso = Slot('Femoral (aislamiento)', {'hamstrings'}, mechanic: 'isolation');
const _biceps = Slot('Bíceps', {'biceps'}, force: 'pull');
const _triceps = Slot('Tríceps', {'triceps'}, force: 'push');
const _calves = Slot('Gemelos', {'calves'});
const _core = Slot('Core', {'abdominals'});

// Ordenados por prioridad: si la sesión es corta se cortan los últimos.
const _fullA = [_squat, _chestPress, _verticalPull, _hinge, _shoulderPress, _core, _biceps, _triceps];
const _fullB = [_hinge, _shoulderPress, _row, _squat, _chestPress, _core, _calves, _triceps];
const _fullC = [_squat, _chestPress, _row, _glutes, _lateral, _core, _biceps, _calves];
const _upper = [_chestPress, _verticalPull, _shoulderPress, _row, _triceps, _biceps, _chestIso];
const _lower = [_squat, _hinge, _glutes, _quadIso, _hamIso, _calves, _core];
const _push = [_chestPress, _shoulderPress, _chestPress, _lateral, _triceps, _chestIso, _triceps];
const _pull = [_verticalPull, _row, _row, _biceps, _core, _biceps, _lateral];

List<(String, List<Slot>)> splitFor(int days) => switch (days) {
      <= 2 => [('Cuerpo completo A', _fullA), ('Cuerpo completo B', _fullB)],
      3 => [
          ('Cuerpo completo A', _fullA),
          ('Cuerpo completo B', _fullB),
          ('Cuerpo completo C', _fullC),
        ],
      4 => [
          ('Torso A', _upper),
          ('Pierna A', _lower),
          ('Torso B', _upper),
          ('Pierna B', _lower),
        ],
      5 => [
          ('Empuje', _push),
          ('Tirón', _pull),
          ('Pierna', _lower),
          ('Torso', _upper),
          ('Pierna B', _lower),
        ],
      _ => [
          ('Empuje A', _push),
          ('Tirón A', _pull),
          ('Pierna A', _lower),
          ('Empuje B', _push),
          ('Tirón B', _pull),
          ('Pierna B', _lower),
        ],
    };

int exercisesPerSession(int minutes) => switch (minutes) {
      <= 30 => 4,
      <= 45 => 5,
      <= 60 => 6,
      _ => 7,
    };

/// Ejercicios conocidos que preferimos frente a variantes raras del dataset.
const _staples = {
  'Barbell_Squat', 'Goblet_Squat', 'Dumbbell_Squat', 'Bodyweight_Squat',
  'Leg_Press', 'Hack_Squat', 'Dumbbell_Lunges',
  'Romanian_Deadlift', 'Barbell_Deadlift', 'Barbell_Hip_Thrust',
  'Butt_Lift_Bridge', 'Kettlebell_One-Legged_Deadlift', 'One-Arm_Kettlebell_Swings',
  'Barbell_Bench_Press_-_Medium_Grip', 'Dumbbell_Bench_Press', 'Pushups',
  'Machine_Bench_Press', 'Leverage_Chest_Press', 'Dumbbell_Flyes', 'Cable_Crossover',
  'Pullups', 'Chin-Up', 'Wide-Grip_Lat_Pulldown', 'Seated_Cable_Rows',
  'Bent_Over_Barbell_Row', 'One-Arm_Dumbbell_Row', 'Inverted_Row',
  'Standing_Military_Press', 'Dumbbell_Shoulder_Press', 'Side_Lateral_Raise',
  'Face_Pull', 'Band_Pull_Apart',
  'Barbell_Curl', 'Dumbbell_Bicep_Curl', 'Hammer_Curls',
  'Triceps_Pushdown', 'Dips_-_Triceps_Version', 'Bench_Dips',
  'Leg_Extensions', 'Lying_Leg_Curls', 'Standing_Calf_Raises',
  'Plank', 'Crunches', 'Air_Bike', 'Hanging_Leg_Raise',
  // Peso corporal, para quien entrena en casa sin material.
  'Incline_Push-Up', 'Decline_Push-Up', 'Single_Leg_Glute_Bridge',
  'Glute_Kickback', 'Natural_Glute_Ham_Raise',
};

const _routineCategories = {'strength', 'powerlifting'};
const _levelOrder = ['beginner', 'intermediate', 'expert'];

class RoutineGenerator {
  RoutineGenerator(this.profile, this.all, {int? seed}) : _rng = Random(seed);

  final UserProfile profile;
  final List<Exercise> all;
  final Random _rng;

  late final Map<String, Exercise> _byId = {for (final e in all) e.id: e};

  /// Ejercicios que este usuario puede hacer: tiene el equipo, no los ha
  /// bloqueado y no chocan con sus lesiones.
  late final List<Exercise> usable = [
    for (final e in all)
      if (_routineCategories.contains(e.category) &&
          !profile.blockedExercises.contains(e.id) &&
          hasEquipmentFor(e, profile.equipment) &&
          isSafeFor(e, profile))
        e,
  ];

  int get _userLevel => profile.level.index;
  int _levelOf(Exercise e) => _levelOrder.indexOf(e.level);

  Routine generate() {
    final perSession = exercisesPerSession(profile.minutesPerSession);
    final used = <String>{};
    return Routine(
      days: [
        for (final (name, slots) in splitFor(profile.daysPerWeek))
          RoutineDay(
            name: name,
            items: _fillDay(slots, perSession, used),
          ),
      ],
    );
  }

  /// Si un hueco no se puede cubrir (p. ej. dorsal sin barra ni bandas),
  /// se pasa al siguiente de la plantilla para no dejar el día corto.
  List<RoutineItem> _fillDay(List<Slot> slots, int count, Set<String> used) {
    final items = <RoutineItem>[];
    for (final slot in slots) {
      if (items.length == count) break;
      if (_pick(slot, used) case final e?) items.add(_item(slot, e));
    }
    return items;
  }

  /// Otras opciones para el hueco que ocupa [current], de mejor a peor.
  List<Exercise> alternatives(Exercise current, {int limit = 10}) {
    final slot = Slot(
      'alt',
      current.primaryMuscles.toSet(),
      force: current.force,
      mechanic: current.mechanic,
    );
    final ranked = _candidates(slot, exclude: {current.id})
      ..sort((a, b) => _score(b, slot).compareTo(_score(a, slot)));
    return ranked.take(limit).toList();
  }

  Exercise? _pick(Slot slot, Set<String> used) {
    var options = _candidates(slot, exclude: used);
    // Mejor repetir un ejercicio de otro día que dejar el hueco vacío.
    if (options.isEmpty) options = _candidates(slot);
    if (options.isEmpty) return null;

    // Algo de variedad entre los mejor puntuados.
    final scored = [for (final e in options) (e, _score(e, slot) + _rng.nextDouble() * 2)]
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final pick = scored.first.$1;
    used.add(pick.id);
    return pick;
  }

  /// Si no hay nada que cumpla todo, se relaja: primero la mecánica, luego el
  /// tipo de fuerza y por último el nivel.
  List<Exercise> _candidates(Slot slot, {Set<String> exclude = const {}}) {
    bool base(Exercise e) =>
        !exclude.contains(e.id) && e.primaryMuscles.any(slot.muscles.contains);
    bool levelOk(Exercise e) => _levelOf(e) <= _userLevel;
    bool forceOk(Exercise e) => slot.force == null || e.force == slot.force;
    bool mechOk(Exercise e) => slot.mechanic == null || e.mechanic == slot.mechanic;

    // Nunca más de un nivel por encima: mejor dejar el hueco vacío que darle
    // a un principiante flexiones en pino.
    bool oneAbove(Exercise e) => _levelOf(e) <= _userLevel + 1;

    final passes = <bool Function(Exercise)>[
      (e) => base(e) && levelOk(e) && forceOk(e) && mechOk(e),
      (e) => base(e) && levelOk(e) && forceOk(e),
      (e) => base(e) && levelOk(e),
      (e) => base(e) && oneAbove(e),
    ];
    for (final test in passes) {
      final r = usable.where(test).toList();
      if (r.isNotEmpty) return r;
    }
    return [];
  }

  double _score(Exercise e, Slot slot) {
    var s = 0.0;
    if (_staples.contains(e.id)) s += 10;
    // Si tiene material, mejor con carga que con el propio peso (los
    // candidatos ya vienen filtrados por el equipo disponible).
    if (e.equipmentOrBody != 'body only') s += 3;
    if (slot.mechanic != null && e.mechanic == slot.mechanic) s += 3;
    if (slot.force != null && e.force == slot.force) s += 2;
    // El primer músculo del hueco es el principal.
    if (e.primaryMuscles.contains(slot.muscles.first)) s += 1;
    s -= (_userLevel - _levelOf(e)).abs() * 1.5;
    return s;
  }

  RoutineItem _item(Slot slot, Exercise e) {
    final compound = e.mechanic == 'compound';
    var (sets, reps, rest) = switch ((profile.goal, compound)) {
      (Goal.strength, true) => (4, '5-6', 150),
      (Goal.strength, false) => (3, '8-10', 90),
      (Goal.muscle, true) => (4, '8-10', 120),
      (Goal.muscle, false) => (3, '10-12', 75),
      (Goal.fatLoss, true) => (3, '12-15', 60),
      (Goal.fatLoss, false) => (3, '15', 45),
      (Goal.health, true) => (3, '10-12', 90),
      (Goal.health, false) => (2, '12-15', 60),
    };
    if (profile.level == Level.beginner && sets > 2) sets--;
    if (e.force == 'static') reps = '30-45 s';
    return RoutineItem(
      exerciseId: e.id,
      slot: slot.label,
      sets: sets,
      reps: reps,
      restSeconds: rest,
    );
  }

  Exercise? byId(String id) => _byId[id];
}
