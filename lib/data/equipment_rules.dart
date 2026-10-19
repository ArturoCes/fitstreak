import 'exercise.dart';
import 'user_profile.dart';

// El dataset solo indica el equipo "principal". Dominadas o fondos aparecen
// como "body only" aunque necesitan barra o paralelas, así que deducimos esos
// requisitos por el nombre.

final _needsPullUpBar = RegExp(
  r'pull-?ups?|chin-?ups?|hanging|muscle.?up|inverted row',
  caseSensitive: false,
);
final _needsDipStation = RegExp(r'\bdips?\b', caseSensitive: false);
final _needsBench = RegExp(r'bench|incline|decline', caseSensitive: false);
// Las flexiones inclinadas o declinadas se apoyan en cualquier silla.
final _pushUp = RegExp(r'push-?ups?', caseSensitive: false);

/// Equipo extra que pide un ejercicio además de `exercise.equipment`.
Set<String> extraRequirements(Exercise e) {
  final n = e.name;
  return {
    if (_needsPullUpBar.hasMatch(n)) pullUpBar,
    // Los fondos en banco se pueden hacer con una silla.
    if (_needsDipStation.hasMatch(n) && !n.toLowerCase().contains('bench'))
      dipStation,
    if (_needsBench.hasMatch(n) &&
        !_needsDipStation.hasMatch(n) &&
        !_pushUp.hasMatch(n) &&
        e.equipmentOrBody != 'machine')
      bench,
  };
}

/// Equipo que el generador nunca usa: "other" es demasiado ambiguo y el foam
/// roller no es para entrenar fuerza.
const _neverForRoutines = {'other', 'foam roll'};

bool hasEquipmentFor(Exercise e, Set<String> available) {
  final eq = e.equipmentOrBody;
  if (_neverForRoutines.contains(eq)) return false;
  if (eq != 'body only' && !available.contains(eq)) return false;
  return extraRequirements(e).every(available.contains);
}

// Reglas orientativas por lesión. No sustituyen el consejo de un profesional:
// solo apartan los movimientos que más suelen cargar esa zona.
final _injuryRules = {
  Injury.knee: RegExp(
    r'jump|hop|lunge|pistol|sissy|split squat|step.?up|box|burpee|skater',
    caseSensitive: false,
  ),
  Injury.lowerBack: RegExp(
    r'deadlift|good morning|bent.?over|hyperextension|superman|clean|snatch|'
    r't-bar|barbell squat|front squat',
    caseSensitive: false,
  ),
  Injury.shoulder: RegExp(
    r'behind the neck|upright row|\bdips?\b|military press|overhead|snatch|'
    r'handstand|kipping|muscle.?up|shoulder press|arnold',
    caseSensitive: false,
  ),
  Injury.wrist: RegExp(
    r'push-?ups?|pushups|handstand|front squat|clean',
    caseSensitive: false,
  ),
};

final _highImpact = RegExp(
  r'jump|hop|burpee|box|bound|skater|sprint',
  caseSensitive: false,
);

bool isSafeFor(Exercise e, UserProfile p) {
  for (final injury in p.injuries) {
    if (_injuryRules[injury]!.hasMatch(e.name)) return false;
  }
  if (p.prefersLowImpact &&
      (e.category == 'plyometrics' || _highImpact.hasMatch(e.name))) {
    return false;
  }
  return true;
}
