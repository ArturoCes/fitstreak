/// An exercise as it comes from free-exercise-db (public domain).
/// https://github.com/yuhonas/free-exercise-db
class Exercise {
  /// Creates an exercise. Catalog entries are built with [Exercise.fromJson];
  /// the user's own exercises use `customExercise` in exercise_repository.dart.
  const Exercise({
    required this.id,
    required this.name,
    required this.level,
    required this.category,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.instructions,
    required this.images,
    this.force,
    this.mechanic,
    this.equipment,
    this.drawings = const [],
    this.instructionsEs = const [],
  });

  /// Base URL of the Everkinetic drawings (CC BY-SA 4.0), matched by name.
  /// https://github.com/everkinetic/data
  static const drawingBaseUrl =
      'https://raw.githubusercontent.com/everkinetic/data/main/dist/png/';

  /// Base URL of the photos. Until we have our own storage, images are served
  /// straight from the original repository.
  static const imageBaseUrl =
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';

  /// Stable identifier from the dataset (e.g. `Barbell_Squat`), or
  /// `custom-...` for the user's own exercises.
  final String id;

  /// English name from the dataset (shown as is, by the user's choice).
  final String name;

  /// Difficulty: `beginner`, `intermediate` or `expert`.
  final String level;

  /// Dataset category: `strength`, `stretching`, `cardio`...
  final String category;

  /// Movement direction: `push`, `pull` or `static` (null if unknown).
  final String? force;

  /// `compound` or `isolation` (null if unknown).
  final String? mechanic;

  /// Main equipment (`barbell`, `dumbbell`...); null means unspecified.
  final String? equipment;

  /// Muscles mainly worked, using the dataset's English keys.
  final List<String> primaryMuscles;

  /// Muscles worked as helpers.
  final List<String> secondaryMuscles;

  /// Original English instructions, one step per item.
  final List<String> instructions;

  /// Photo paths relative to [imageBaseUrl] (start and end position).
  final List<String> images;

  /// The equipment, treating "unspecified" as bodyweight.
  String get equipmentOrBody => equipment ?? 'body only';

  /// Drawing files (start and end position); empty when there is no drawing.
  final List<String> drawings;

  /// Spanish instructions (assets/data/instructions_es.json); empty when the
  /// translation is missing.
  final List<String> instructionsEs;

  /// Steps to show: in Spanish when available, otherwise the original. Blank
  /// steps are dropped.
  List<String> get steps => [
        for (final s in instructionsEs.isNotEmpty ? instructionsEs : instructions)
          if (s.trim().isNotEmpty) s,
      ];

  /// Full photo URLs.
  List<String> get imageUrls => [for (final i in images) '$imageBaseUrl$i'];

  /// Full drawing URLs.
  List<String> get drawingUrls => [for (final d in drawings) '$drawingBaseUrl$d'];

  /// The images to show for the user's preference, falling back to photos
  /// when the exercise has no drawing.
  List<String> urlsFor({required bool drawings}) =>
      drawings && this.drawings.isNotEmpty ? drawingUrls : imageUrls;

  /// Parses a dataset entry, adding the matched [drawings] and Spanish
  /// [instructionsEs] that live in separate asset files.
  factory Exercise.fromJson(
    Map<String, dynamic> json, {
    List<String> drawings = const [],
    List<String> instructionsEs = const [],
  }) =>
      Exercise(
        drawings: drawings,
        instructionsEs: instructionsEs,
        id: json['id'] as String,
        name: json['name'] as String,
        level: json['level'] as String,
        category: json['category'] as String,
        force: json['force'] as String?,
        mechanic: json['mechanic'] as String?,
        equipment: json['equipment'] as String?,
        primaryMuscles: _strings(json['primaryMuscles']),
        secondaryMuscles: _strings(json['secondaryMuscles']),
        instructions: _strings(json['instructions']),
        images: _strings(json['images']),
      );

  /// Reads an optional JSON list of strings.
  static List<String> _strings(Object? v) =>
      (v as List<dynamic>? ?? const []).cast<String>();
}
