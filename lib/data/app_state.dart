import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'exercise_repository.dart';
import 'routine.dart';
import 'routine_generator.dart';
import 'user_profile.dart';

/// Se sobrescribe en main() con la instancia ya cargada.
final prefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('prefsProvider sin inicializar'),
);

const _profileKey = 'profile';
const _routineKey = 'routine';

class ProfileNotifier extends Notifier<UserProfile?> {
  @override
  UserProfile? build() {
    final raw = ref.read(prefsProvider).getString(_profileKey);
    return raw == null ? null : UserProfile.fromJson(jsonDecode(raw));
  }

  Future<void> save(UserProfile p) async {
    state = p;
    await ref.read(prefsProvider).setString(_profileKey, jsonEncode(p.toJson()));
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, UserProfile?>(
  ProfileNotifier.new,
);

class RoutineNotifier extends Notifier<Routine?> {
  @override
  Routine? build() {
    final raw = ref.read(prefsProvider).getString(_routineKey);
    return raw == null ? null : Routine.fromJson(jsonDecode(raw));
  }

  Future<RoutineGenerator> generator() async {
    final all = await ref.read(exercisesProvider.future);
    return RoutineGenerator(ref.read(profileProvider)!, all);
  }

  Future<void> regenerate() async => _save((await generator()).generate());

  Future<void> swap(int day, int item, String exerciseId) async =>
      _save(state!.replace(day, item, exerciseId));

  /// "No tengo esto": no volver a proponerlo y cambiarlo por la mejor opción.
  Future<void> block(int day, int item) async {
    final id = state!.days[day].items[item].exerciseId;
    final profiles = ref.read(profileProvider.notifier);
    final p = ref.read(profileProvider)!;
    await profiles.save(p.copyWith(blockedExercises: {...p.blockedExercises, id}));

    final gen = await generator();
    final current = gen.byId(id);
    final alt = current == null ? const [] : gen.alternatives(current, limit: 1);
    if (alt.isNotEmpty) await swap(day, item, alt.first.id);
  }

  Future<void> _save(Routine r) async {
    state = r;
    await ref.read(prefsProvider).setString(_routineKey, jsonEncode(r.toJson()));
  }
}

final routineProvider = NotifierProvider<RoutineNotifier, Routine?>(
  RoutineNotifier.new,
);
