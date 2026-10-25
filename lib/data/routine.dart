/// Another exercise that can be done instead of the planned one ("Dips or
/// cable triceps pushdown"): the user picks which one to do.
class ExerciseOption {
  /// Creates an option for [exerciseId], shown as [slot].
  const ExerciseOption({required this.exerciseId, required this.slot});

  /// Catalog (or custom) exercise id.
  final String exerciseId;

  /// Label shown to the user ("Extensión de tríceps").
  final String slot;

  /// Serializes the option for preferences and share codes.
  Map<String, dynamic> toJson() => {'exerciseId': exerciseId, 'slot': slot};

  /// Reads an option written by [toJson].
  factory ExerciseOption.fromJson(Map<String, dynamic> j) =>
      ExerciseOption(exerciseId: j['exerciseId'] as String, slot: j['slot'] as String);
}

/// One exercise of a routine day, with its sets, reps and rest.
class RoutineItem {
  /// Creates a routine item.
  const RoutineItem({
    required this.exerciseId,
    required this.slot,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    this.note,
    this.alternatives = const [],
  });

  /// Catalog (or custom) exercise id.
  final String exerciseId;

  /// The role it plays in the day ("Chest push"...), used for display and to
  /// look for equivalent substitutes. In an imported routine it is the name
  /// the user wrote ("Press banca").
  final String slot;

  /// Number of sets.
  final int sets;

  /// Target reps as written: "8-12", or seconds for timed holds ("30-45 s").
  final String reps;

  /// Rest after each set, in seconds.
  final int restSeconds;

  /// The user's own comment ("ligero", "brazos atrás").
  final String? note;

  /// The other exercises the user can choose from (not including this one).
  final List<ExerciseOption> alternatives;

  /// Same item doing exercise [id] instead (label, sets and options kept).
  RoutineItem withExercise(String id) => RoutineItem(
        exerciseId: id,
        slot: slot,
        sets: sets,
        reps: reps,
        restSeconds: restSeconds,
        note: note,
        alternatives: alternatives,
      );

  /// Same item with [options] as its alternatives.
  RoutineItem withAlternatives(List<ExerciseOption> options) => RoutineItem(
        exerciseId: exerciseId,
        slot: slot,
        sets: sets,
        reps: reps,
        restSeconds: restSeconds,
        note: note,
        alternatives: options,
      );

  /// Switches to alternative [index] and keeps the current exercise as an
  /// alternative, so the choice can be undone.
  RoutineItem choose(int index) {
    final picked = alternatives[index];
    return RoutineItem(
      exerciseId: picked.exerciseId,
      slot: picked.slot,
      sets: sets,
      reps: reps,
      restSeconds: restSeconds,
      note: note,
      alternatives: [
        for (final (i, a) in alternatives.indexed)
          i == index ? ExerciseOption(exerciseId: exerciseId, slot: slot) : a,
      ],
    );
  }

  /// Serializes the item for preferences and share codes.
  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'slot': slot,
        'sets': sets,
        'reps': reps,
        'restSeconds': restSeconds,
        if (note != null) 'note': note,
        if (alternatives.isNotEmpty) 'alternatives': [for (final a in alternatives) a.toJson()],
      };

  /// Reads an item written by [toJson].
  factory RoutineItem.fromJson(Map<String, dynamic> j) => RoutineItem(
        exerciseId: j['exerciseId'] as String,
        slot: j['slot'] as String,
        sets: j['sets'] as int,
        reps: j['reps'] as String,
        restSeconds: j['restSeconds'] as int,
        note: j['note'] as String?,
        alternatives: [
          for (final a in j['alternatives'] as List? ?? const [])
            ExerciseOption.fromJson(a as Map<String, dynamic>),
        ],
      );
}

/// A training day of the routine ("Push", "Pierna"...).
class RoutineDay {
  /// Creates a day.
  const RoutineDay({required this.name, required this.items, this.note});

  /// Day name shown in the chips and the workout.
  final String name;

  /// Exercises in order.
  final List<RoutineItem> items;

  /// Reminder for the day ("NO reventar bíceps aquí").
  final String? note;

  /// Serializes the day.
  Map<String, dynamic> toJson() => {
        'name': name,
        'items': [for (final i in items) i.toJson()],
        if (note != null) 'note': note,
      };

  /// Reads a day written by [toJson].
  factory RoutineDay.fromJson(Map<String, dynamic> j) => RoutineDay(
        name: j['name'] as String,
        items: [
          for (final i in j['items'] as List)
            RoutineItem.fromJson(i as Map<String, dynamic>),
        ],
        note: j['note'] as String?,
      );
}

/// The user's weekly routine: generated, imported or followed from someone.
class Routine {
  /// Creates a routine.
  const Routine({required this.days, this.title, this.notes = const []});

  /// Training days, done in order.
  final List<RoutineDay> days;

  /// Only set on imported or shared routines.
  final String? title;

  /// General advice of the routine (rests, golden rules...).
  final List<String> notes;

  /// Serializes the routine.
  Map<String, dynamic> toJson() => {
        'days': [for (final d in days) d.toJson()],
        if (title != null) 'title': title,
        if (notes.isNotEmpty) 'notes': notes,
      };

  /// Reads a routine written by [toJson].
  factory Routine.fromJson(Map<String, dynamic> j) => Routine(
        days: [
          for (final d in j['days'] as List)
            RoutineDay.fromJson(d as Map<String, dynamic>),
        ],
        title: j['title'] as String?,
        notes: [...(j['notes'] as List? ?? const []).cast<String>()],
      );
}
