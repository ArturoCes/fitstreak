/// What the user wants to achieve.
enum Goal {
  /// Hypertrophy.
  muscle('Ganar músculo'),

  /// Strength (fewer reps, longer rests).
  strength('Ganar fuerza'),

  /// Fat loss (more reps, shorter rests, calorie deficit).
  fatLoss('Perder grasa'),

  /// General fitness.
  health('Salud y forma general');

  /// Creates a goal with its label.
  const Goal(this.label);

  /// Spanish label shown in the app.
  final String label;
}

/// Training experience.
enum Level {
  /// Little or no training.
  beginner('Principiante', 'Llevo poco o nada entrenando'),

  /// Trains regularly for months.
  intermediate('Intermedio', 'Entreno con regularidad desde hace meses'),

  /// Several years of serious training.
  expert('Avanzado', 'Varios años entrenando en serio');

  /// Creates a level with its label and description.
  const Level(this.label, this.description);

  /// Spanish label shown in the app.
  final String label;

  /// Spanish one-line description for the onboarding.
  final String description;

  /// Same value as the dataset's `level` field.
  String get datasetKey => name;
}

/// Where the user trains.
enum Place {
  /// A gym: all equipment assumed, the user unticks what is missing.
  gym('Gimnasio'),

  /// At home: only the equipment the user ticks.
  home('En casa');

  /// Creates a place with its label.
  const Place(this.label);

  /// Spanish label shown in the app.
  final String label;
}

/// Used to estimate calorie needs (Mifflin-St Jeor). "Prefer not to say"
/// uses the average of both formulas.
enum Sex {
  /// Male formula.
  male('Hombre'),

  /// Female formula.
  female('Mujer'),

  /// Average of both formulas.
  unspecified('Prefiero no decirlo');

  /// Creates a value with its label.
  const Sex(this.label);

  /// Spanish label shown in the app.
  final String label;
}

/// Areas to protect; the generator avoids movements that load them.
enum Injury {
  /// Knee.
  knee('Rodilla'),

  /// Lower back.
  lowerBack('Zona lumbar'),

  /// Shoulder.
  shoulder('Hombro'),

  /// Wrist.
  wrist('Muñeca');

  /// Creates an injury with its label.
  const Injury(this.label);

  /// Spanish label shown in the app.
  final String label;
}

/// Equipment the user may have. Keys matching the dataset's `equipment` field
/// are used as is; [extraEquipment] holds requirements the dataset does not
/// record (see equipment_rules.dart).
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

/// Pull-up bar (needed by pull-ups, chin-ups, hanging raises).
const pullUpBar = 'pull-up bar';

/// Parallel bars (needed by dips).
const dipStation = 'dip station';

/// Weight bench.
const bench = 'bench';

/// Equipment inferred from exercise names rather than the dataset.
const extraEquipment = [pullUpBar, dipStation, bench];

/// Spanish labels for [extraEquipment].
const extraEquipmentEs = {
  pullUpBar: 'Barra de dominadas',
  dipStation: 'Paralelas (fondos)',
  bench: 'Banco',
};

/// The user's answers from the onboarding, used to build the routine and
/// estimate calories.
class UserProfile {
  /// Creates a profile.
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
    this.sex = Sex.unspecified,
  });

  /// Age in years.
  final int age;

  /// Sex for the calorie formula.
  final Sex sex;

  /// Height in centimetres.
  final int heightCm;

  /// Body weight in kilograms.
  final double weightKg;

  /// Training goal.
  final Goal goal;

  /// Experience level.
  final Level level;

  /// Training days per week (2-6).
  final int daysPerWeek;

  /// Session length in minutes (30, 45, 60 or 75).
  final int minutesPerSession;

  /// Gym or home.
  final Place place;

  /// Available equipment (bodyweight is always available).
  final Set<String> equipment;

  /// Areas to protect.
  final Set<Injury> injuries;

  /// Exercises the user marked as "I don't have this".
  final Set<String> blockedExercises;

  /// Body mass index.
  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  /// Jumps and impacts are avoided with a high BMI or from age 60.
  bool get prefersLowImpact => bmi >= 30 || age >= 60;

  /// Copy with the given fields replaced.
  UserProfile copyWith({Set<String>? blockedExercises, int? daysPerWeek, Sex? sex}) => UserProfile(
        age: age,
        sex: sex ?? this.sex,
        heightCm: heightCm,
        weightKg: weightKg,
        goal: goal,
        level: level,
        daysPerWeek: daysPerWeek ?? this.daysPerWeek,
        minutesPerSession: minutesPerSession,
        place: place,
        equipment: equipment,
        injuries: injuries,
        blockedExercises: blockedExercises ?? this.blockedExercises,
      );

  /// Serializes the profile for preferences.
  Map<String, dynamic> toJson() => {
        'age': age,
        'sex': sex.name,
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

  /// Reads a profile written by [toJson]. Profiles saved before `sex` existed
  /// get [Sex.unspecified].
  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        age: j['age'] as int,
        sex: Sex.values.asNameMap()[j['sex']] ?? Sex.unspecified,
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
