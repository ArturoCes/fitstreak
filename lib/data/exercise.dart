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
    this.drawings = const [],
    this.instructionsEs = const [],
  });

  /// Dibujos de Everkinetic (CC BY-SA 4.0), emparejados por nombre.
  /// https://github.com/everkinetic/data
  static const drawingBaseUrl =
      'https://raw.githubusercontent.com/everkinetic/data/main/dist/png/';

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

  /// Posición inicial y final del dibujo; vacío si no hay dibujo para este.
  final List<String> drawings;

  /// Instrucciones traducidas (tool/i18n_es); vacío si falta la traducción.
  final List<String> instructionsEs;

  /// Pasos a mostrar: en español si existen, si no el original. Sin vacíos.
  List<String> get steps => [
        for (final s in instructionsEs.isNotEmpty ? instructionsEs : instructions)
          if (s.trim().isNotEmpty) s,
      ];

  List<String> get imageUrls => [for (final i in images) '$imageBaseUrl$i'];

  List<String> get drawingUrls => [for (final d in drawings) '$drawingBaseUrl$d'];

  /// Las imágenes a mostrar según la preferencia, con las fotos como respaldo.
  List<String> urlsFor({required bool drawings}) =>
      drawings && this.drawings.isNotEmpty ? drawingUrls : imageUrls;

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

  static List<String> _strings(Object? v) =>
      (v as List<dynamic>? ?? const []).cast<String>();
}
