/// Spanish labels for the dataset values (which come in English). Exercise
/// names stay in English by the user's choice; instructions are translated in
/// assets/data/instructions_es.json.
library;

/// Muscle keys → Spanish.
const muscleEs = {
  'abdominals': 'Abdominales',
  'abductors': 'Abductores',
  'adductors': 'Aductores',
  'biceps': 'Bíceps',
  'calves': 'Gemelos',
  'chest': 'Pecho',
  'forearms': 'Antebrazos',
  'glutes': 'Glúteos',
  'hamstrings': 'Isquiotibiales',
  'lats': 'Dorsales',
  'lower back': 'Lumbar',
  'middle back': 'Espalda media',
  'neck': 'Cuello',
  'quadriceps': 'Cuádriceps',
  'shoulders': 'Hombros',
  'traps': 'Trapecios',
  'triceps': 'Tríceps',
};

/// Equipment keys → Spanish.
const equipmentEs = {
  'body only': 'Peso corporal',
  'barbell': 'Barra',
  'dumbbell': 'Mancuernas',
  'kettlebells': 'Kettlebell',
  'bands': 'Bandas elásticas',
  'cable': 'Polea',
  'machine': 'Máquina',
  'medicine ball': 'Balón medicinal',
  'exercise ball': 'Fitball',
  'foam roll': 'Foam roller',
  'e-z curl bar': 'Barra Z',
  'other': 'Otro',
};

/// Difficulty levels → Spanish.
const levelEs = {
  'beginner': 'Principiante',
  'intermediate': 'Intermedio',
  'expert': 'Avanzado',
};

/// Mechanics (compound / isolation) → Spanish.
const mechanicEs = {'compound': 'Compuesto', 'isolation': 'Aislamiento'};

/// Looks [key] up in [table]: `-` when there is no key, the key itself when
/// the table has no translation for it.
String es(Map<String, String> table, String? key) =>
    key == null ? '-' : (table[key] ?? key);
