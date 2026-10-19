/// Ejercicio tal y como viene de free-exercise-db (dominio público).
/// https://github.com/yuhonas/free-exercise-db
class Exercise {
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
  });

  /// Mientras no tengamos almacenamiento propio, las imágenes se sirven
  /// desde el repo original.
  static const imageBaseUrl =
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';

  final String id;
  final String name;
  final String level; // beginner | intermediate | expert
  final String category; // strength, stretching, cardio...
  final String? force; // push | pull | static
  final String? mechanic; // compound | isolation
  final String? equipment; // null = sin especificar
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> instructions;
  final List<String> images;

  /// Sin equipo especificado lo tratamos como peso corporal.
  String get equipmentOrBody => equipment ?? 'body only';

  List<String> get imageUrls => [for (final i in images) '$imageBaseUrl$i'];

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
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

  static List<String> _strings(Object? v) =>
      (v as List<dynamic>? ?? const []).cast<String>();
}
