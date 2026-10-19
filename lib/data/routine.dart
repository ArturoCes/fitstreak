class RoutineItem {
  const RoutineItem({
    required this.exerciseId,
    required this.slot,
    required this.sets,
    required this.reps,
    required this.restSeconds,
  });

  final String exerciseId;

  /// Qué papel cumple en el día ("Empuje de pecho"...). Sirve para mostrarlo
  /// y para buscar sustitutos equivalentes.
  final String slot;
  final int sets;
  final String reps; // "8-12", "30-45 s"
  final int restSeconds;

  RoutineItem withExercise(String id) => RoutineItem(
        exerciseId: id,
        slot: slot,
        sets: sets,
        reps: reps,
        restSeconds: restSeconds,
      );

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'slot': slot,
        'sets': sets,
        'reps': reps,
        'restSeconds': restSeconds,
      };

  factory RoutineItem.fromJson(Map<String, dynamic> j) => RoutineItem(
        exerciseId: j['exerciseId'] as String,
        slot: j['slot'] as String,
        sets: j['sets'] as int,
        reps: j['reps'] as String,
        restSeconds: j['restSeconds'] as int,
      );
}

class RoutineDay {
  const RoutineDay({required this.name, required this.items});

  final String name;
  final List<RoutineItem> items;

  Map<String, dynamic> toJson() => {
        'name': name,
        'items': [for (final i in items) i.toJson()],
      };

  factory RoutineDay.fromJson(Map<String, dynamic> j) => RoutineDay(
        name: j['name'] as String,
        items: [
          for (final i in j['items'] as List)
            RoutineItem.fromJson(i as Map<String, dynamic>),
        ],
      );
}

class Routine {
  const Routine({required this.days});

  final List<RoutineDay> days;

  Routine replace(int day, int item, String exerciseId) => Routine(
        days: [
          for (final (d, rd) in days.indexed)
            d != day
                ? rd
                : RoutineDay(
                    name: rd.name,
                    items: [
                      for (final (i, it) in rd.items.indexed)
                        i == item ? it.withExercise(exerciseId) : it,
                    ],
                  ),
        ],
      );

  Map<String, dynamic> toJson() => {
        'days': [for (final d in days) d.toJson()],
      };

  factory Routine.fromJson(Map<String, dynamic> j) => Routine(
        days: [
          for (final d in j['days'] as List)
            RoutineDay.fromJson(d as Map<String, dynamic>),
        ],
      );
}
