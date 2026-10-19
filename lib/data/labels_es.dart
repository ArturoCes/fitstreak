/// Traducciones de los valores del dataset (que viene en inglés).
/// Los nombres e instrucciones de cada ejercicio se traducirán más adelante.
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

const levelEs = {
  'beginner': 'Principiante',
  'intermediate': 'Intermedio',
  'expert': 'Avanzado',
};

const categoryEs = {
  'strength': 'Fuerza',
  'stretching': 'Estiramiento',
  'plyometrics': 'Pliometría',
  'cardio': 'Cardio',
  'powerlifting': 'Powerlifting',
  'strongman': 'Strongman',
  'olympic weightlifting': 'Halterofilia',
};

const forceEs = {'push': 'Empuje', 'pull': 'Tirón', 'static': 'Estático'};

const mechanicEs = {'compound': 'Compuesto', 'isolation': 'Aislamiento'};

String es(Map<String, String> table, String? key) =>
    key == null ? '-' : (table[key] ?? key);
