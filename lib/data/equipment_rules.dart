import 'exercise.dart';
import 'user_profile.dart';

// The dataset only lists the "main" equipment. Pull-ups or dips appear as
// "body only" although they need a bar or parallel bars, so those
// requirements are inferred from the name.

final _needsPullUpBar = RegExp(
  r'pull-?ups?|chin-?ups?|hanging|muscle.?up|inverted row',
  caseSensitive: false,
);
final _needsDipStation = RegExp(r'\bdips?\b', caseSensitive: false);
final _needsBench = RegExp(r'bench|incline|decline', caseSensitive: false);
// Incline or decline push-ups can rest on any chair.
final _pushUp = RegExp(r'push-?ups?', caseSensitive: false);

/// Extra equipment an exercise needs on top of `exercise.equipment`.
Set<String> extraRequirements(Exercise e) {
  final n = e.name;
  return {
    if (_needsPullUpBar.hasMatch(n)) pullUpBar,
    // Bench dips can be done on a chair.
    if (_needsDipStation.hasMatch(n) && !n.toLowerCase().contains('bench'))
      dipStation,
    if (_needsBench.hasMatch(n) &&
        !_needsDipStation.hasMatch(n) &&
        !_pushUp.hasMatch(n) &&
        e.equipmentOrBody != 'machine')
      bench,
  };
}

/// Equipment the generator never uses: "other" is too vague and a foam
/// roller is not for strength training.
const _neverForRoutines = {'other', 'foam roll'};

/// Whether the user can do [e] with the [available] equipment (bodyweight is
/// always available).
bool hasEquipmentFor(Exercise e, Set<String> available) {
  final eq = e.equipmentOrBody;
  if (_neverForRoutines.contains(eq)) return false;
  if (eq != 'body only' && !available.contains(eq)) return false;
  return extraRequirements(e).every(available.contains);
}

// Rough rules per injury. They do not replace professional advice: they only
// keep away the movements that usually load that area the most.
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

/// Whether [e] suits the profile: avoids the movements flagged for the user's
/// injuries, and jumps and impacts for profiles that prefer low impact.
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
