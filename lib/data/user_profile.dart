enum Goal {
  muscle('Ganar músculo'),
  strength('Ganar fuerza'),
  fatLoss('Perder grasa'),
  health('Salud y forma general');

  const Goal(this.label);
  final String label;
}

enum Level {
  beginner('Principiante', 'Llevo poco o nada entrenando'),
  intermediate('Intermedio', 'Entreno con regularidad desde hace meses'),
  expert('Avanzado', 'Varios años entrenando en serio');

  const Level(this.label, this.description);
  final String label;
  final String description;

  /// Mismo nombre que el campo `level` del dataset.
  String get datasetKey => name;
}

enum Place {
  gym('Gimnasio'),
  home('En casa');

  const Place(this.label);
  final String label;
}

enum Injury {
  knee('Rodilla'),
  lowerBack('Zona lumbar'),
  shoulder('Hombro'),
  wrist('Muñeca');

  const Injury(this.label);
  final String label;
}

/// Equipo que el usuario puede tener. Las claves que coinciden con el campo
/// `equipment` del dataset se usan tal cual; las de [extraEquipment] son
/// requisitos que el dataset no recoge (ver equipment_rules.dart).
const datasetEquipment = [
  'dumbbell',
  'barbell',
  'kettlebells',
  'bands',
  'cable',
  'machine',
  'e-z curl bar',
  'medicine ball',
  'exercise ball',
];

const pullUpBar = 'pull-up bar';
const dipStation = 'dip station';
const bench = 'bench';
const extraEquipment = [pullUpBar, dipStation, bench];

const extraEquipmentEs = {
  pullUpBar: 'Barra de dominadas',
  dipStation: 'Paralelas (fondos)',
  bench: 'Banco',
};

class UserProfile {
  const UserProfile({
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.goal,
    required this.level,
    required this.daysPerWeek,
    required this.minutesPerSession,
    required this.place,
    required this.equipment,
    required this.injuries,
    this.blockedExercises = const {},
  });

  final int age;
  final int heightCm;
  final double weightKg;
  final Goal goal;
  final Level level;
  final int daysPerWeek; // 2-6
  final int minutesPerSession; // 30, 45, 60, 75
  final Place place;

  /// Equipo disponible (el peso corporal siempre lo está).
  final Set<String> equipment;
  final Set<Injury> injuries;

  /// Ejercicios que el usuario ha marcado como "no tengo esto".
  final Set<String> blockedExercises;

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  /// Evitamos saltos e impactos con IMC alto o a partir de 60 años.
  bool get prefersLowImpact => bmi >= 30 || age >= 60;

  UserProfile copyWith({Set<String>? blockedExercises}) => UserProfile(
        age: age,
        heightCm: heightCm,
        weightKg: weightKg,
        goal: goal,
        level: level,
        daysPerWeek: daysPerWeek,
        minutesPerSession: minutesPerSession,
        place: place,
        equipment: equipment,
        injuries: injuries,
        blockedExercises: blockedExercises ?? this.blockedExercises,
      );

  Map<String, dynamic> toJson() => {
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'goal': goal.name,
        'level': level.name,
        'daysPerWeek': daysPerWeek,
        'minutesPerSession': minutesPerSession,
        'place': place.name,
        'equipment': equipment.toList(),
        'injuries': [for (final i in injuries) i.name],
        'blockedExercises': blockedExercises.toList(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        age: j['age'] as int,
        heightCm: j['heightCm'] as int,
        weightKg: (j['weightKg'] as num).toDouble(),
        goal: Goal.values.byName(j['goal'] as String),
        level: Level.values.byName(j['level'] as String),
        daysPerWeek: j['daysPerWeek'] as int,
        minutesPerSession: j['minutesPerSession'] as int,
        place: Place.values.byName(j['place'] as String),
        equipment: {...(j['equipment'] as List).cast<String>()},
        injuries: {
          for (final i in (j['injuries'] as List).cast<String>())
            Injury.values.byName(i),
        },
        blockedExercises: {
          ...(j['blockedExercises'] as List? ?? const []).cast<String>(),
        },
      );
}
