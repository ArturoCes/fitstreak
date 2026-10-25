// Importing a hand-written routine (WhatsApp, notes, a .docx...):
//
//   🔥 *DÍA 1 – PUSH (pecho/hombro)*
//   * Press banca → 4x6–10
//   * Curl barra recta (ligero) → 3x10–12
//   📌 Recordatorio: solo activación
//   ⏱️ *DESCANSOS*
//   * Ejercicios grandes → 2–3 min
//
// [parseRoutineText] extracts days, exercises, sets, notes and rests, and
// [matchExercise] finds each Spanish name in the (English) catalog.

import 'dart:math';

import 'exercise.dart';

/// One exercise line of an imported routine.
class ParsedItem {
  /// Creates a parsed exercise.
  ParsedItem({
    required this.name,
    required this.sets,
    required this.reps,
    this.note,
    this.restSeconds,
    this.alternatives = const [],
  });

  /// Name as the user wrote it, without the comment in parentheses.
  final String name;

  /// "Fondos o jalón de tríceps en polea": the other names.
  final List<String> alternatives;

  /// Number of sets.
  final int sets;

  /// Rep range ("6-10") or seconds ("30 s").
  final String reps;

  /// Comment in parentheses ("Ligero").
  final String? note;

  /// Rest written on the same line; otherwise it depends on the exercise type.
  final int? restSeconds;
}

/// One day of an imported routine.
class ParsedDay {
  /// Creates an empty day called [name].
  ParsedDay(this.name);

  /// Day name ("Push").
  String name;

  /// Header description and reminder lines of the day.
  final notes = <String>[];

  /// Exercises in order.
  final items = <ParsedItem>[];

  /// The notes joined in one text (null when there are none).
  String? get note => notes.isEmpty ? null : notes.join('\n');
}

/// The result of parsing a routine text.
class ParsedRoutine {
  /// Creates a parsed routine.
  ParsedRoutine({
    required this.title,
    required this.days,
    required this.notes,
    required this.bigRest,
    required this.smallRest,
  });

  /// Title from a header before the first day (null if none).
  final String? title;

  /// Days that have at least one exercise.
  final List<ParsedDay> days;

  /// Sections that are not days (rests, tips, rules...).
  final List<String> notes;

  /// Rest of the big exercises, in seconds.
  final int bigRest;

  /// Rest of the isolation exercises, in seconds.
  final int smallRest;

  /// Total exercises across all days.
  int get exerciseCount => days.fold(0, (a, d) => a + d.items.length);
}

/// Lower case without accents, emojis or symbols: "Jalón (espalda)" →
/// "jalon espalda".
String normalizeEs(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñç';
  const to = 'aaaaeeeeiiiioooouuuunc';
  final lower = s.toLowerCase();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

final _setsReps = RegExp(
  r'(\d+)\s*[x×X]\s*(\d+)(?:\s*(?:-|–|—|a)\s*(\d+))?\s*(seg(?:undos)?|sec|s\b|"|min(?:utos)?)?',
);
final _seriesOnly = RegExp(r'(\d+)\s*series?\b(?:\s*(?:de|x)\s*(\d+)(?:\s*(?:-|–|—|a)\s*(\d+))?)?', caseSensitive: false);
// With the accented capitals spelled out: "DÍA" doesn't always match [ií].
final _dayHeader = RegExp(
  r'(?<![\p{L}])(d[iíIÍ]a|day|sesi[oóOÓ]n|entreno|workout|rutina)\s*(\d+|[a-eA-E](?![\p{L}]))'
  r'|^(lunes|martes|mi[eéEÉ]rcoles|jueves|viernes|s[aáAÁ]bado|domingo)(?![\p{L}])',
  caseSensitive: false,
  unicode: true,
);
final _splitWords = RegExp(
  r'^(push|pull|legs?|piernas?|upper|lower|torso|full ?body|cuerpo completo|pecho|espalda|hombros?|brazos?)\b',
  caseSensitive: false,
);
final _duration = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:(?:-|–|—|a)\s*(\d+(?:[.,]\d+)?))?\s*(min|m\b|seg|s\b|")', caseSensitive: false);

/// Removes bullets, bold markers and emojis from the ends of a line.
String _clean(String line) {
  var s = line.replaceAll('*', '').replaceAll('_', ' ').trim();
  // Leading bullets and emojis (anything that isn't a letter, a digit, a
  // parenthesis or an opening mark).
  s = s.replaceFirst(RegExp(r'^[^\p{L}\p{N}(¡¿❌✔✅]+', unicode: true), '');
  s = s.replaceFirst(RegExp(r'^\d+[.)]\s+'), ''); // "1. Press banca"
  return s.trim();
}

/// Separator-only lines ("---", "===").
bool _isRule(String line) => RegExp(r'^[\s\-–—=_*~·•.]{3,}$').hasMatch(line);

/// Whether a line without sets looks like a title: bold, mostly upper case
/// or ending in a colon.
bool _looksLikeHeader(String raw, String clean) {
  if (clean.isEmpty || clean.length > 70) return false;
  final boldWrapped = RegExp(r'^\W*\*[^*]+\*\W*$', unicode: true).hasMatch(raw.trim());
  final letters = clean.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
  final upper = letters.replaceAll(RegExp(r'[^\p{Lu}]', unicode: true), '');
  final mostlyUpper = letters.length >= 4 && upper.length / letters.length > 0.7;
  return boldWrapped || mostlyUpper || clean.endsWith(':');
}

/// "PIERNAS + CORE" → "Piernas + Core".
String _titleCase(String s) => s
    .toLowerCase()
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');

/// [s] with its first letter in upper case.
String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Day name and description of a header line: "DÍA 1 – PUSH (pecho/hombro)" → ("Push", "Pecho/hombro").
(String, String?) _dayName(String clean, int number) {
  var s = clean.replaceFirst(_dayHeader, '').trim();
  s = s.replaceFirst(RegExp(r'^[\s:.\-–—|]+'), '').trim();
  String? desc;
  final paren = RegExp(r'\(([^)]*)\)').firstMatch(s);
  if (paren != null) {
    desc = _capitalize(paren[1]!.trim().toLowerCase());
    s = s.replaceRange(paren.start, paren.end, '').trim();
  }
  s = s.replaceAll(RegExp(r'[:\-–—|]+$'), '').trim();
  if (s.isEmpty) return ('Día $number', desc);
  final isUpper = s == s.toUpperCase();
  return (isUpper ? _titleCase(s) : s, desc);
}

/// Seconds of a written duration, using the middle of a range ("2–3 min" →
/// 150, "60-90 seg" → 75).
int? _parseSeconds(String s) {
  final m = _duration.firstMatch(s);
  if (m == null) return null;
  double n(String? v) => double.parse(v!.replaceAll(',', '.'));
  final a = n(m[1]);
  final b = m[2] == null ? a : n(m[2]);
  final unit = m[3]!.toLowerCase();
  final mins = unit.startsWith('m');
  return ((a + b) / 2 * (mins ? 60 : 1)).round();
}

/// Parses an exercise line ("Press banca → 4x6–10"); null when the line
/// has no sets × reps.
ParsedItem? _parseExercise(String clean) {
  final m = _setsReps.firstMatch(clean) ?? _seriesOnly.firstMatch(clean);
  if (m == null) return null;
  var name = clean.substring(0, m.start);
  if (name.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '').isEmpty) {
    name = clean.substring(m.end); // "4x10 press banca"
  }
  String? note;
  final paren = RegExp(r'\(([^)]*)\)').firstMatch(name);
  if (paren != null) {
    note = _capitalize(paren[1]!.trim());
    name = name.replaceRange(paren.start, paren.end, ' ');
  }
  name = name
      .replaceAll(RegExp(r'(→|->|=>|:|\||–|—)'), ' ')
      .replaceAll(RegExp(r'\s+-\s*$'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (name.isEmpty) return null;

  final int sets;
  String reps;
  if (m.pattern == _setsReps) {
    sets = int.parse(m[1]!);
    final lo = int.parse(m[2]!);
    final hi = m[3] == null ? null : int.parse(m[3]!);
    reps = hi == null || hi == lo ? '$lo' : '$lo-$hi';
    final unit = m[4]?.toLowerCase();
    if (unit != null && unit.startsWith('min')) {
      reps = hi == null ? '${lo * 60} s' : '${lo * 60}-${hi * 60} s';
    } else if (unit != null) {
      reps = '$reps s';
    }
  } else {
    sets = int.parse(m[1]!);
    final lo = m[2] == null ? null : int.parse(m[2]!);
    final hi = m[3] == null ? null : int.parse(m[3]!);
    reps = lo == null ? '8-12' : (hi == null ? '$lo' : '$lo-$hi');
  }
  final after = clean.substring(m.end);
  final rest = RegExp(r'descanso', caseSensitive: false).hasMatch(after) ? _parseSeconds(after) : null;
  // "Fondos o jalón de tríceps", "Fondos / jalón de tríceps": one or the other.
  final names = [
    for (final n in name.split(RegExp(r'\s+(?:o|ó|u)\s+|\s*/\s*', caseSensitive: false)))
      if (n.trim().isNotEmpty) _capitalize(n.trim()),
  ];
  final options = names.length > 1 && names.every((n) => n.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '').length >= 3)
      ? names
      : [_capitalize(name)];
  return ParsedItem(
    name: options.first,
    alternatives: options.skip(1).toList(),
    sets: sets.clamp(1, 12),
    reps: reps,
    note: note,
    restSeconds: rest,
  );
}

/// Parses a routine written by hand: day headers ("Día 1", "Push",
/// "Lunes"...), exercise lines with sets × reps, reminders inside a day and
/// note sections (a "Descansos" section sets the rest times).
ParsedRoutine parseRoutineText(String text) {
  final days = <ParsedDay>[];
  final notes = <String>[];
  String? title;
  ParsedDay? day;
  List<String>? section; // lines of the current note section
  var bigRest = 120;
  var smallRest = 75;
  var sectionIsRest = false;

  // Stores the current note section, if it has any line besides its title.
  void closeSection() {
    if (section != null && section!.length > 1) notes.add(section!.join('\n'));
    section = null;
    sectionIsRest = false;
  }

  for (final raw in text.split(RegExp(r'\r?\n'))) {
    if (raw.trim().isEmpty || _isRule(raw.trim())) continue;
    final clean = _clean(raw);
    if (clean.isEmpty) continue;

    final item = _parseExercise(clean);
    final header = item == null && (_dayHeader.hasMatch(clean) || _looksLikeHeader(raw, clean));

    if (header && (_dayHeader.hasMatch(clean) || _splitWords.hasMatch(clean))) {
      closeSection();
      final (name, desc) = _dayName(clean, days.length + 1);
      day = ParsedDay(name);
      if (desc != null && desc.isNotEmpty) day.notes.add(desc);
      days.add(day);
      continue;
    }
    if (header) {
      // Note section (rests, tips, rules...). Before any day, the first one
      // is the title.
      closeSection();
      day = null;
      final name = clean.replaceAll(RegExp(r':$'), '').trim();
      if (days.isEmpty && title == null && !RegExp('descanso', caseSensitive: false).hasMatch(name)) {
        title = _capitalize(name.toLowerCase());
        continue;
      }
      section = [_capitalize(name.toLowerCase())];
      sectionIsRest = RegExp('descanso', caseSensitive: false).hasMatch(name);
      continue;
    }

    if (item != null && section == null) {
      day ??= () {
        final d = ParsedDay('Día ${days.length + 1}');
        days.add(d);
        return d;
      }();
      day.items.add(item);
      continue;
    }

    if (section != null) {
      final line = raw.trim().replaceAll('*', '').trim();
      section!.add(line.startsWith(RegExp(r'[❌✔✅•\-]')) ? line : '• ${_clean(raw)}');
      if (sectionIsRest) {
        final secs = _parseSeconds(clean);
        if (secs != null) {
          final n = normalizeEs(clean);
          final small = RegExp(r'\b(biceps|triceps|brazo|aisla|accesori|peque|abdom|core|hombro lateral|gemelo)').hasMatch(n);
          if (small) {
            smallRest = secs;
          } else {
            bigRest = secs;
          }
        }
      }
      continue;
    }

    // Loose line inside a day: a reminder or comment.
    final d = day;
    if (d != null) {
      d.notes.add(_capitalize(clean.replaceFirst(RegExp(r'^(recordatorio|nota|tip|ojo)\s*:\s*', caseSensitive: false), '')));
    }
  }
  closeSection();

  return ParsedRoutine(
    title: title,
    days: [for (final d in days) if (d.items.isNotEmpty) d],
    notes: notes,
    bigRest: bigRest,
    smallRest: smallRest,
  );
}

/// Small exercises (short rest), by mechanic or by their Spanish name.
bool looksIsolation(String spanishName, Exercise? match) {
  if (match?.mechanic == 'isolation') return true;
  return RegExp(
    r'\b(curl|elevacion|elevaciones|extension|extensiones|gemelo|gemelos|pantorrilla|abdominal|abdominales|rueda|plancha|'
    r'crunch|patada|aperturas|lateral|laterales|face|encogimiento|encogimientos|triceps|biceps|pajaro|pajaros|contractora|cruce)\b',
  ).hasMatch(normalizeEs(spanishName));
}

/// How good a catalog match is.
enum MatchQuality {
  /// A known Spanish name of that exercise.
  exact,

  /// The closest equivalent: worth reviewing.
  approximate,

  /// Nothing similar: it becomes a custom exercise.
  none,
}

/// The catalog exercise found for a Spanish name.
class ExerciseMatch {
  /// Creates a match.
  const ExerciseMatch(this.exercise, this.quality);

  /// The matched exercise (null when there is none).
  final Exercise? exercise;

  /// How reliable the match is.
  final MatchQuality quality;
}

/// Spanish aliases → catalog id. The alias with the most words found in the
/// name wins (each word works as a prefix: "mancuerna" matches "mancuernas").
/// Entries marked with `~` are approximate equivalents.
const _aliases = <(String, String)>[
  // Chest
  ('press banca inclinado mancuerna', 'Incline_Dumbbell_Press'),
  ('press inclinado mancuerna', 'Incline_Dumbbell_Press'),
  ('press inclinado', 'Barbell_Incline_Bench_Press_-_Medium_Grip'),
  ('press banca inclinado', 'Barbell_Incline_Bench_Press_-_Medium_Grip'),
  ('press declinado', 'Decline_Barbell_Bench_Press'),
  ('press banca mancuerna', 'Dumbbell_Bench_Press'),
  ('press plano mancuerna', 'Dumbbell_Bench_Press'),
  ('press banca cerrado', 'Close-Grip_Barbell_Bench_Press'),
  ('press cerrado', 'Close-Grip_Barbell_Bench_Press'),
  ('press banca maquina', 'Machine_Bench_Press'),
  ('press pecho maquina', 'Machine_Bench_Press'),
  ('press banca', 'Barbell_Bench_Press_-_Medium_Grip'),
  ('press plano', 'Barbell_Bench_Press_-_Medium_Grip'),
  ('press pecho', 'Barbell_Bench_Press_-_Medium_Grip'),
  ('aperturas inclinad', 'Incline_Dumbbell_Flyes'),
  ('aperturas polea', 'Cable_Crossover'),
  ('aperturas', 'Dumbbell_Flyes'),
  ('cruce polea', 'Cable_Crossover'),
  ('crossover', 'Cable_Crossover'),
  ('contractora', 'Butterfly'),
  ('pec deck', 'Butterfly'),
  ('peck deck', 'Butterfly'),
  ('flexiones', 'Pushups'),
  ('lagartijas', 'Pushups'),
  ('fondos cerrado', 'Dips_-_Triceps_Version'),
  ('fondos triceps', 'Dips_-_Triceps_Version'),
  ('fondos banco', 'Bench_Dips'),
  ('fondos', 'Dips_-_Chest_Version'),
  ('pullover', 'Bent-Arm_Dumbbell_Pullover'),
  // Shoulders
  ('press hombro mancuerna', 'Dumbbell_Shoulder_Press'),
  ('press militar mancuerna', 'Dumbbell_Shoulder_Press'),
  ('press hombro maquina', 'Machine_Shoulder_Military_Press'),
  ('press hombro barra', 'Barbell_Shoulder_Press'),
  ('press hombro', 'Dumbbell_Shoulder_Press'),
  ('press militar', 'Standing_Military_Press'),
  ('press arnold', 'Arnold_Dumbbell_Press'),
  ('elevaciones laterales polea', 'Cable_Seated_Lateral_Raise'),
  ('elevaciones laterales', 'Side_Lateral_Raise'),
  ('elevacion lateral', 'Side_Lateral_Raise'),
  ('laterales', 'Side_Lateral_Raise'),
  ('elevaciones frontales', 'Front_Dumbbell_Raise'),
  ('elevacion frontal', 'Front_Dumbbell_Raise'),
  ('pajaro', 'Reverse_Flyes'),
  ('posterior hombro', 'Reverse_Flyes'),
  ('deltoides posterior', 'Reverse_Flyes'),
  ('face pull', 'Face_Pull'),
  ('remo menton', 'Upright_Barbell_Row'),
  ('remo al menton', 'Upright_Barbell_Row'),
  ('encogimientos mancuerna', 'Dumbbell_Shrug'),
  ('encogimientos hombro', 'Barbell_Shrug'),
  ('trapecio', 'Barbell_Shrug'),
  // Back
  ('dominadas supin', 'Chin-Up'),
  ('dominadas agarre estrecho', 'Chin-Up'),
  ('chin up', 'Chin-Up'),
  ('dominadas asistid', 'Band_Assisted_Pull-Up'),
  ('dominadas', 'Pullups'),
  ('dominada', 'Pullups'),
  ('pull up', 'Pullups'),
  ('jalon cerrado', 'Close-Grip_Front_Lat_Pulldown'),
  ('jalon agarre estrecho', 'Close-Grip_Front_Lat_Pulldown'),
  ('jalon triangulo', 'V-Bar_Pulldown'),
  ('jalon supino', 'Underhand_Cable_Pulldowns'),
  ('jalon brazos rectos', 'Straight-Arm_Pulldown'),
  ('jalon triceps', 'Triceps_Pushdown'),
  ('jalon', 'Wide-Grip_Lat_Pulldown'),
  ('polea al pecho', 'Wide-Grip_Lat_Pulldown'),
  ('lat pulldown', 'Wide-Grip_Lat_Pulldown'),
  ('remo mancuerna', 'One-Arm_Dumbbell_Row'),
  ('remo unilateral', 'One-Arm_Dumbbell_Row'),
  ('remo polea', 'Seated_Cable_Rows'),
  ('remo sentado', 'Seated_Cable_Rows'),
  ('remo gironda', 'Seated_Cable_Rows'),
  ('remo en t', 'T-Bar_Row_with_Handle'),
  ('remo t', 'T-Bar_Row_with_Handle'),
  ('remo inclinado mancuerna', 'Dumbbell_Incline_Row'),
  ('remo barra', 'Bent_Over_Barbell_Row'),
  ('remo pendlay', 'Bent_Over_Barbell_Row'),
  ('remo', 'Bent_Over_Barbell_Row'),
  ('hiperextensiones', 'Hyperextensions_Back_Extensions'),
  ('lumbares', 'Hyperextensions_Back_Extensions'),
  ('extension lumbar', 'Hyperextensions_Back_Extensions'),
  ('peso muerto rumano', 'Romanian_Deadlift'),
  ('peso muerto piernas rigidas', 'Stiff-Legged_Barbell_Deadlift'),
  ('peso muerto mancuerna', 'Stiff-Legged_Dumbbell_Deadlift'),
  ('peso muerto sumo', 'Sumo_Deadlift'),
  ('peso muerto', 'Barbell_Deadlift'),
  ('rumano', 'Romanian_Deadlift'),
  ('buenos dias', 'Good_Morning'),
  // Biceps
  ('~curl bayesian', 'Incline_Dumbbell_Curl'),
  ('~curl bayesiano', 'Incline_Dumbbell_Curl'),
  ('curl martillo polea', 'Cable_Hammer_Curls_-_Rope_Attachment'),
  ('curl martillo', 'Hammer_Curls'),
  ('martillo', 'Hammer_Curls'),
  ('curl concentrado', 'Concentration_Curls'),
  ('curl predicador', 'Preacher_Curl'),
  ('curl scott', 'Preacher_Curl'),
  ('banco scott', 'Preacher_Curl'),
  ('curl arana', 'Spider_Curl'),
  ('curl inclinado', 'Incline_Dumbbell_Curl'),
  ('curl polea', 'Standing_Biceps_Cable_Curl'),
  ('curl barra z', 'EZ-Bar_Curl'),
  ('curl z', 'EZ-Bar_Curl'),
  ('curl ez', 'EZ-Bar_Curl'),
  ('curl alterno', 'Dumbbell_Alternate_Bicep_Curl'),
  ('curl mancuerna', 'Dumbbell_Bicep_Curl'),
  ('curl invertido', 'Reverse_Barbell_Curl'),
  ('curl inverso', 'Reverse_Barbell_Curl'),
  ('curl femoral sentado', 'Seated_Leg_Curl'),
  ('curl femoral de pie', 'Standing_Leg_Curl'),
  ('curl femoral', 'Lying_Leg_Curls'),
  ('femoral tumbado', 'Lying_Leg_Curls'),
  ('femoral sentado', 'Seated_Leg_Curl'),
  ('femoral', 'Lying_Leg_Curls'),
  ('curl barra', 'Barbell_Curl'),
  ('curl biceps', 'Barbell_Curl'),
  ('curl', 'Barbell_Curl'),
  // Triceps
  ('triceps cuerda', 'Triceps_Pushdown_-_Rope_Attachment'),
  ('extension triceps cuerda', 'Triceps_Pushdown_-_Rope_Attachment'),
  ('extension triceps polea', 'Triceps_Pushdown'),
  ('triceps polea', 'Triceps_Pushdown'),
  ('extension triceps tras nuca', 'Cable_Rope_Overhead_Triceps_Extension'),
  ('triceps tras nuca', 'Cable_Rope_Overhead_Triceps_Extension'),
  ('extension triceps mancuerna', 'Dumbbell_One-Arm_Triceps_Extension'),
  ('extension triceps', 'Triceps_Pushdown'),
  ('press frances', 'EZ-Bar_Skullcrusher'),
  ('rompecraneos', 'EZ-Bar_Skullcrusher'),
  ('skull crusher', 'EZ-Bar_Skullcrusher'),
  ('patada triceps', 'Tricep_Dumbbell_Kickback'),
  ('patada de triceps', 'Tricep_Dumbbell_Kickback'),
  // Legs
  ('sentadilla bulgara', 'Split_Squat_with_Dumbbells'),
  ('bulgara', 'Split_Squat_with_Dumbbells'),
  ('sentadilla hack', 'Hack_Squat'),
  ('hack squat', 'Hack_Squat'),
  ('sentadilla goblet', 'Goblet_Squat'),
  ('goblet', 'Goblet_Squat'),
  ('sentadilla frontal', 'Front_Barbell_Squat'),
  ('sentadilla smith', 'Smith_Machine_Squat'),
  ('sentadilla multipower', 'Smith_Machine_Squat'),
  ('sentadilla mancuerna', 'Dumbbell_Squat'),
  ('sentadilla libre', 'Bodyweight_Squat'),
  ('sentadilla', 'Barbell_Squat'),
  ('squat', 'Barbell_Squat'),
  ('prensa', 'Leg_Press'),
  ('zancadas', 'Dumbbell_Lunges'),
  ('zancada', 'Dumbbell_Lunges'),
  ('estocadas', 'Dumbbell_Lunges'),
  ('lunges', 'Dumbbell_Lunges'),
  ('step up', 'Dumbbell_Step_Ups'),
  ('extension cuadriceps', 'Leg_Extensions'),
  ('extensiones cuadriceps', 'Leg_Extensions'),
  ('extension pierna', 'Leg_Extensions'),
  ('extensiones pierna', 'Leg_Extensions'),
  ('cuadriceps', 'Leg_Extensions'),
  ('hip thrust', 'Barbell_Hip_Thrust'),
  ('empuje cadera', 'Barbell_Hip_Thrust'),
  ('puente gluteo', 'Barbell_Glute_Bridge'),
  ('patada gluteo', 'Glute_Kickback'),
  ('abductores', 'Thigh_Abductor'),
  ('abduccion', 'Thigh_Abductor'),
  ('aductores', 'Thigh_Adductor'),
  ('aduccion', 'Thigh_Adductor'),
  ('gemelos sentado', 'Seated_Calf_Raise'),
  ('gemelo sentado', 'Seated_Calf_Raise'),
  ('gemelos prensa', 'Calf_Press_On_The_Leg_Press_Machine'),
  ('gemelos', 'Standing_Calf_Raises'),
  ('gemelo', 'Standing_Calf_Raises'),
  ('pantorrilla', 'Standing_Calf_Raises'),
  ('elevacion talones', 'Standing_Calf_Raises'),
  // Core
  ('rueda abdominal', 'Ab_Roller'),
  ('rueda', 'Ab_Roller'),
  ('ab wheel', 'Ab_Roller'),
  ('plancha lateral', 'Push_Up_to_Side_Plank'),
  ('plancha', 'Plank'),
  ('crunch polea', 'Cable_Crunch'),
  ('crunch maquina', 'Ab_Crunch_Machine'),
  ('crunch invertido', 'Reverse_Crunch'),
  ('crunch', 'Crunches'),
  ('abdominales', 'Crunches'),
  ('encogimientos abdominales', 'Crunches'),
  ('elevaciones piernas colgado', 'Hanging_Leg_Raise'),
  ('elevacion piernas colgado', 'Hanging_Leg_Raise'),
  ('elevaciones piernas', 'Flat_Bench_Lying_Leg_Raise'),
  ('elevacion piernas', 'Flat_Bench_Lying_Leg_Raise'),
  ('giros rusos', 'Russian_Twist'),
  ('russian twist', 'Russian_Twist'),
];

/// Catalog ids used by the aliases, for the test that checks they exist.
Iterable<String> get aliasExerciseIds => _aliases.map((a) => a.$2);

/// For the approximate search: Spanish word → English words.
const _vocab = <String, List<String>>{
  'press': ['press'],
  'banca': ['bench'],
  'banco': ['bench'],
  'inclinado': ['incline'],
  'inclinada': ['incline'],
  'declinado': ['decline'],
  'mancuerna': ['dumbbell'],
  'mancuernas': ['dumbbell'],
  'barra': ['barbell'],
  'polea': ['cable'],
  'poleas': ['cable'],
  'maquina': ['machine'],
  'multipower': ['smith'],
  'smith': ['smith'],
  'curl': ['curl'],
  'martillo': ['hammer'],
  'remo': ['row'],
  'jalon': ['pulldown'],
  'sentadilla': ['squat'],
  'zancada': ['lunge'],
  'zancadas': ['lunge'],
  'muerto': ['deadlift'],
  'extension': ['extension'],
  'extensiones': ['extension'],
  'gemelo': ['calf'],
  'gemelos': ['calf'],
  'elevacion': ['raise'],
  'elevaciones': ['raise'],
  'lateral': ['lateral'],
  'laterales': ['lateral'],
  'frontal': ['front'],
  'frontales': ['front'],
  'fondos': ['dips'],
  'dominadas': ['pullups'],
  'triceps': ['triceps'],
  'biceps': ['biceps'],
  'hombro': ['shoulder'],
  'hombros': ['shoulder'],
  'pecho': ['chest'],
  'espalda': ['back'],
  'pierna': ['leg'],
  'piernas': ['leg'],
  'femoral': ['leg', 'curl'],
  'gluteo': ['glute'],
  'gluteos': ['glute'],
  'abdominal': ['ab', 'crunch'],
  'cuerda': ['rope'],
  'sentado': ['seated'],
  'tumbado': ['lying'],
  'unilateral': ['one', 'arm'],
  'cerrado': ['close', 'grip'],
  'abierto': ['wide', 'grip'],
  'kettlebell': ['kettlebell'],
  'rusa': ['kettlebell'],
  'aperturas': ['flyes'],
  'patada': ['kickback'],
  'encogimientos': ['shrug'],
  'concentrado': ['concentration'],
  'predicador': ['preacher'],
  'invertido': ['reverse'],
  'frances': ['skullcrusher'],
  'plancha': ['plank'],
  'flexiones': ['pushups'],
};

/// Whether [w] is among [tokens]. Short words ("t", "z", "en") must match
/// whole; longer ones work as a prefix ("mancuerna" → "mancuernas").
bool _hasWord(List<String> tokens, String w) =>
    tokens.any((t) => w.length <= 2 ? t == w : t.startsWith(w));

/// Finds the catalog exercise for a Spanish (or English) name: first by
/// alias, then by translating word by word and picking the closest name.
ExerciseMatch matchExercise(String spanishName, List<Exercise> catalog) {
  final tokens = normalizeEs(spanishName).split(' ');
  final byId = {for (final e in catalog) e.id: e};

  (int, String, bool)? best;
  for (final (key, id) in _aliases) {
    final approx = key.startsWith('~');
    final words = (approx ? key.substring(1) : key).split(' ');
    if (!words.every((w) => _hasWord(tokens, w))) continue;
    if (!byId.containsKey(id)) continue;
    if (best == null || words.length > best.$1) best = (words.length, id, approx);
  }
  if (best != null) {
    return ExerciseMatch(byId[best.$2], best.$3 ? MatchQuality.approximate : MatchQuality.exact);
  }

  // No alias: translate word by word and look for the best fitting name.
  final english = <String>{
    for (final t in tokens) ...?_vocab[t],
    // Names already in English ("Leg press", "Face pull").
    for (final t in tokens) if (t.length > 2 && !_vocab.containsKey(t)) t,
  };
  if (english.isEmpty) return const ExerciseMatch(null, MatchQuality.none);
  Exercise? found;
  var bestScore = 0.0;
  for (final e in catalog) {
    final name = e.name.toLowerCase().split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty).toList();
    final hits = english.where((w) => name.any((n) => n.startsWith(w) || w.startsWith(n) && n.length > 3)).length;
    if (hits == 0) continue;
    final score = hits / english.length - 0.04 * max(0, name.length - hits);
    if (score > bestScore) {
      bestScore = score;
      found = e;
    }
  }
  return bestScore >= 0.5 ? ExerciseMatch(found, MatchQuality.approximate) : const ExerciseMatch(null, MatchQuality.none);
}

/// Catalog search typing in Spanish or English ("remo polea", "cable row").
/// The ones sharing the most words come first, after the alias match.
List<Exercise> searchCatalog(String query, List<Exercise> catalog, {int limit = 40}) {
  final tokens = normalizeEs(query).split(' ').where((t) => t.length > 1).toList();
  if (tokens.isEmpty) return catalog.take(limit).toList();
  final words = <String>{for (final t in tokens) ...?_vocab[t], ...tokens};
  final scored = <(double, Exercise)>[];
  for (final e in catalog) {
    final name = normalizeEs(e.name).split(' ');
    final hits = words.where((w) => name.any((n) => n.startsWith(w))).length;
    if (hits == 0) continue;
    scored.add((hits - name.length * 0.05, e));
  }
  final alias = matchExercise(query, catalog).exercise;
  scored.sort((a, b) => b.$1.compareTo(a.$1));
  return [
    ?alias,
    for (final (_, e) in scored) if (e.id != alias?.id) e,
  ].take(limit).toList();
}

/// Stable id of a custom exercise derived from its name.
String customIdFor(String name) => 'custom-${normalizeEs(name).replaceAll(' ', '-')}';

/// Likely equipment of a custom exercise, to know whether to ask for kg.
String customEquipmentFor(String spanishName) {
  final n = normalizeEs(spanishName);
  if (RegExp(r'\b(mancuerna)').hasMatch(n)) return 'dumbbell';
  if (RegExp(r'\b(barra)').hasMatch(n)) return 'barbell';
  if (RegExp(r'\b(polea|cable)').hasMatch(n)) return 'cable';
  if (RegExp(r'\b(kettlebell|rusa)').hasMatch(n)) return 'kettlebells';
  if (RegExp(r'\b(plancha|flexion|dominada|burpee|salto|correr|comba|abdominal|crunch|rueda)').hasMatch(n)) {
    return 'body only';
  }
  return 'machine';
}
