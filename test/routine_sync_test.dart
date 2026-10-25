import 'dart:convert';
import 'dart:math';

import 'package:fitstreak/data/app_state.dart';
import 'package:fitstreak/data/exercise_repository.dart';
import 'package:fitstreak/data/routine.dart';
import 'package:fitstreak/data/routine_share.dart';
import 'package:fitstreak/data/sync/routine_sync.dart';
import 'package:fitstreak/data/sync/sync_state.dart';
import 'package:fitstreak/data/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supabase en memoria, con las mismas reglas que las políticas RLS: solo el
/// dueño cambia su rutina y cada cambio sube la versión.
class FakeSyncApi implements RoutineSyncApi {
  final rows = <String, ({String owner, RemoteRoutine routine})>{};
  final follows = <(String, String)>{};

  /// Rutinas que salen en el buscador.
  final public = <String>{};
  String user = 'yo';
  int clock = 0;

  /// Códigos que ya existen, para probar los choques.
  final taken = <String>{};

  RemoteRoutine _row(String id, String author, String title, Map<String, dynamic> payload, int version) =>
      RemoteRoutine(
        id: id,
        author: author,
        title: title,
        // Como si pasara por JSON: el servidor no guarda objetos de Dart.
        payload: jsonDecode(jsonEncode(payload)) as Map<String, dynamic>,
        version: version,
        updatedAt: DateTime(2026, 10, 20).add(Duration(minutes: clock++)),
        followers: follows.where((f) => f.$2 == id).length,
      );

  @override
  Future<String> ensureSignedIn() async => user;

  @override
  Future<RemoteRoutine> create({
    required String id,
    required String author,
    required String title,
    required Map<String, dynamic> payload,
  }) async {
    if (rows.containsKey(id) || taken.remove(id)) throw const CodeTakenException();
    final r = _row(id, author, title, payload, 1);
    rows[id] = (owner: user, routine: r);
    return r;
  }

  @override
  Future<RemoteRoutine> update({
    required String id,
    required String author,
    required String title,
    required Map<String, dynamic> payload,
  }) async {
    final old = rows[id];
    if (old == null || old.owner != user) throw StateError('RLS: no es tuya');
    final r = _row(id, author, title, payload, old.routine.version + 1);
    rows[id] = (owner: user, routine: r);
    return r;
  }

  @override
  Future<List<RemoteRoutine>> fetch(List<String> ids) async => [
        for (final id in ids)
          if (rows[id] case final row?)
            _row(id, row.routine.author, row.routine.title, row.routine.payload, row.routine.version),
      ];

  @override
  Future<List<RemoteRoutine>> mine() async => [
        for (final r in rows.values)
          if (r.owner == user) r.routine,
      ];

  @override
  Future<List<RemoteRoutine>> search(String query, {int limit = 20}) async {
    final q = query.trim().toLowerCase();
    final found = [
      for (final row in rows.values)
        if (public.contains(row.routine.id) &&
            (q.isEmpty ||
                row.routine.author.toLowerCase().contains(q) ||
                row.routine.title.toLowerCase().contains(q)))
          RemoteRoutine(
            id: row.routine.id,
            author: row.routine.author,
            title: row.routine.title,
            payload: const {},
            version: row.routine.version,
            updatedAt: row.routine.updatedAt,
            followers: follows.where((f) => f.$2 == row.routine.id).length,
          ),
    ]..sort((a, b) =>
        a.followers != b.followers ? b.followers.compareTo(a.followers) : b.updatedAt.compareTo(a.updatedAt));
    return found.take(limit.clamp(1, 50)).toList();
  }

  @override
  Future<void> setPublic(String id, bool isPublic) async {
    if (rows[id]?.owner != user) throw StateError('RLS: no es tuya');
    isPublic ? public.add(id) : public.remove(id);
  }

  @override
  Future<void> follow(String id) async => follows.add((user, id));

  @override
  Future<void> unfollow(String id) async => follows.remove((user, id));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const profile = UserProfile(
    age: 25,
    heightCm: 175,
    weightKg: 75,
    goal: Goal.muscle,
    level: Level.intermediate,
    daysPerWeek: 4,
    minutesPerSession: 60,
    place: Place.gym,
    equipment: {...datasetEquipment, ...extraEquipment},
    injuries: {},
  );

  final curl = customExercise(id: 'custom-curl-bayesian', name: 'Curl bayesian', equipment: 'cable');

  Routine routineV(int sets, {String title = 'PPL de Ana'}) => Routine(
        title: title,
        days: [
          RoutineDay(name: 'Push', items: [
            RoutineItem(
              exerciseId: 'Barbell_Bench_Press_-_Medium_Grip',
              slot: 'Press banca',
              sets: sets,
              reps: '6-10',
              restSeconds: 150,
            ),
            const RoutineItem(
              exerciseId: 'custom-curl-bayesian',
              slot: 'Curl bayesian',
              sets: 3,
              reps: '10-12',
              restSeconds: 75,
            ),
          ]),
          const RoutineDay(name: 'Pull', items: []),
          const RoutineDay(name: 'Pierna', items: []),
        ],
      );

  late FakeSyncApi api;

  Future<ProviderContainer> device({Map<String, Object> extra = const {}}) async {
    SharedPreferences.setMockInitialValues({'profile': jsonEncode(profile.toJson()), ...extra});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      prefsProvider.overrideWithValue(prefs),
      routineSyncApiProvider.overrideWithValue(api),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => api = FakeSyncApi());

  group('código corto', () {
    test('sale del alfabeto sin letras confusas y se encuentra dentro de un mensaje', () {
      final id = newRoutineId(Random(3));
      expect(id, matches(RegExp(r'^[2-9A-HJ-NP-Z]{6}$')));
      expect(parseRoutineCode('Sigue mi rutina 💪 ${formatCode(id)} en FitStreak'), id);
      expect(parseRoutineCode('código: fs-7k2qxm'), '7K2QXM');
      expect(parseRoutineCode('Sigue mi rutina: ${routineLink('https://x.supabase.co', id)}'), id);
      expect(parseRoutineCode('fitstreak://r/7K2QXM'), '7K2QXM');
    });

    test('no confunde otras cosas con un código', () {
      expect(parseRoutineCode('FS-7K2QX'), isNull); // corto
      expect(parseRoutineCode('FS-7K2QXMM'), isNull); // largo
      expect(parseRoutineCode('FS-OOOOOO'), isNull); // letras que no usamos
      expect(parseRoutineCode('XFS-7K2QXM'), isNull);
      expect(parseRoutineCode('sin código'), isNull);
    });
  });

  group('pendingUpdate', () {
    const f = Following(id: 'ABCDEF', author: 'Ana', title: 'PPL', version: 2);
    RemoteRoutine remote(int v, [String id = 'ABCDEF']) => RemoteRoutine(
        id: id, author: 'Ana', title: 'PPL', payload: const {}, version: v, updatedAt: DateTime(2026));

    test('solo avisa de versiones más nuevas', () {
      expect(pendingUpdate(f, remote(2)), isNull);
      expect(pendingUpdate(f, remote(1)), isNull);
      expect(pendingUpdate(f, remote(3))?.version, 3);
      expect(pendingUpdate(f, null), isNull);
      expect(pendingUpdate(f, remote(3, 'OTRA22')), isNull);
    });

    test('una versión rechazada no se vuelve a preguntar, la siguiente sí', () {
      final dismissed = f.copyWith(dismissed: 3);
      expect(pendingUpdate(dismissed, remote(3)), isNull);
      expect(pendingUpdate(dismissed, remote(4))?.version, 4);
    });

    test('el estado se guarda y se lee igual', () {
      final back = Following.fromJson(jsonDecode(jsonEncode(f.copyWith(dismissed: 5).toJson())));
      expect((back.id, back.author, back.title, back.version, back.dismissed), ('ABCDEF', 'Ana', 'PPL', 2, 5));
    });
  });

  test('el autor publica, ve si tiene cambios sin subir y los sube', () async {
    final c = await device();
    await saveCustomExercises(c.read(prefsProvider), [curl]);
    await c.read(routineProvider.notifier).replaceWith(routineV(4));
    final sync = c.read(syncProvider.notifier);
    final exercises = await c.read(exercisesProvider.future);

    // El primer código que sale ya existe: prueba con otro.
    final clash = newRoutineId(Random(0));
    api.taken.add(clash);
    final p = await sync.publish(author: 'Ana', random: Random(0));
    expect(p.id, isNot(clash));
    expect(p.id, matches(RegExp(r'^[2-9A-HJ-NP-Z]{6}$')));
    expect(p.version, 1);
    expect(sync.hasUnpushedChanges(c.read(routineProvider), exercises), isFalse);
    // El ejercicio propio viaja con la rutina.
    expect(sharedFromPayload(api.rows[p.id]!.routine.payload).customExercises.single.name, 'Curl bayesian');

    await c.read(routineProvider.notifier).replaceWith(routineV(5));
    expect(sync.hasUnpushedChanges(c.read(routineProvider), exercises), isTrue);

    final p2 = await sync.publish(author: 'Ana');
    expect(p2.id, p.id, reason: 'mismo código: los seguidores no tienen que hacer nada');
    expect(p2.version, 2);
    expect(sync.hasUnpushedChanges(c.read(routineProvider), exercises), isFalse);

    // Sobrevive a cerrar la app.
    final reopened = ProviderContainer(overrides: [
      prefsProvider.overrideWithValue(c.read(prefsProvider)),
      routineSyncApiProvider.overrideWithValue(api),
    ]);
    addTearDown(reopened.dispose);
    expect(reopened.read(syncProvider).published?.id, p.id);
  });

  test('el seguidor recibe el cambio del autor y decide si lo pone', () async {
    // Ana publica (en su móvil, aquí directamente en el servidor).
    api.user = 'ana';
    await api.create(
      id: 'ANA234',
      author: 'Ana',
      title: 'PPL de Ana',
      payload: sharePayload(routineV(4), [curl]),
    );

    // Yo sigo su rutina.
    api.user = 'yo';
    final c = await device();
    final sync = c.read(syncProvider.notifier);
    final remote = (await sync.lookup('ANA234'))!;
    await sync.applyUpdate(remote);
    await sync.startFollowing(remote);
    expect(c.read(syncProvider).following?.version, 1);
    expect(c.read(routineProvider)!.days.first.items.first.sets, 4);
    expect(api.follows, contains(('yo', 'ANA234')));
    expect(await sync.checkForUpdate(), isNull, reason: 'ya tengo la última');
    // El ejercicio propio de Ana existe ahora en mi móvil.
    final exercises = await c.read(exercisesProvider.future);
    expect(exercises.any((e) => e.id == curl.id), isTrue);
    // Tres días en su rutina: mi racha cuenta tres por semana.
    expect(c.read(profileProvider)!.daysPerWeek, 3);

    // Ana cambia su rutina.
    api.user = 'ana';
    await api.update(id: 'ANA234', author: 'Ana', title: 'PPL de Ana', payload: sharePayload(routineV(5), [curl]));
    api.user = 'yo';

    // Al abrir la app: hay versión nueva, pero no se pone sola.
    final update = (await sync.checkForUpdate())!;
    expect(update.version, 2);
    expect(update.author, 'Ana');
    expect(c.read(routineProvider)!.days.first.items.first.sets, 4);

    // "Ahora no": no vuelve a preguntar por esa versión.
    await sync.dismiss(update);
    expect(await sync.checkForUpdate(), isNull);

    // Ana vuelve a cambiarla: ahora sí pregunta, y la acepto.
    api.user = 'ana';
    await api.update(id: 'ANA234', author: 'Ana', title: 'PPL de Ana v3', payload: sharePayload(routineV(6), [curl]));
    api.user = 'yo';
    final v3 = (await sync.checkForUpdate())!;
    await sync.applyUpdate(v3);
    expect(c.read(routineProvider)!.days.first.items.first.sets, 6);
    expect(c.read(syncProvider).following?.version, 3);
    expect(c.read(syncProvider).following?.title, 'PPL de Ana v3');
    expect(await sync.checkForUpdate(), isNull);
  });

  test('aplicar una versión nueva no toca el historial ni la racha', () async {
    api.user = 'ana';
    await api.create(id: 'ANA234', author: 'Ana', title: 'PPL', payload: sharePayload(routineV(4), [curl]));
    api.user = 'yo';
    final c = await device(extra: {'history': '[{"marca":1}]', 'streak': '{"dias":7}'});
    final sync = c.read(syncProvider.notifier);
    await sync.applyUpdate((await sync.lookup('ANA234'))!);
    final prefs = c.read(prefsProvider);
    expect(prefs.getString('history'), '[{"marca":1}]');
    expect(prefs.getString('streak'), '{"dias":7}');
  });

  test('un seguidor no puede cambiar la rutina de otro', () async {
    api.user = 'ana';
    await api.create(id: 'ANA234', author: 'Ana', title: 'PPL', payload: sharePayload(routineV(4), [curl]));
    api.user = 'yo';
    await expectLater(
      api.update(id: 'ANA234', author: 'Yo', title: 'Mía', payload: const {}),
      throwsStateError,
    );
  });

  test('seguir mi propia rutina no hace nada y dejar de seguir la quita', () async {
    final c = await device();
    await c.read(routineProvider.notifier).replaceWith(routineV(4));
    final sync = c.read(syncProvider.notifier);
    final p = await sync.publish(author: 'Yo');
    await sync.startFollowing((await sync.lookup(p.id))!);
    expect(c.read(syncProvider).following, isNull);

    api.user = 'ana';
    await api.create(id: 'ANA234', author: 'Ana', title: 'PPL', payload: sharePayload(routineV(4), [curl]));
    api.user = 'yo';
    await sync.startFollowing((await sync.lookup('ANA234'))!);
    expect(c.read(syncProvider).following?.id, 'ANA234');
    await sync.stopFollowing();
    expect(c.read(syncProvider).following, isNull);
    expect(api.follows, isEmpty);
    expect(c.read(prefsProvider).getString('sync_following'), isNull);
  });

  test('al entrar con email en otro móvil se recupera la rutina publicada', () async {
    api.user = 'ana';
    await api.create(id: 'ANA234', author: 'Ana', title: 'PPL', payload: sharePayload(routineV(4), [curl]));
    final c = await device();
    final restored = await c.read(syncProvider.notifier).restorePublication();
    expect(restored?.id, 'ANA234');
    expect(c.read(syncProvider).published?.author, 'Ana');
  });

  group('buscador', () {
    Future<void> publishAs(String user, String id, String author, String title, {bool public = true}) async {
      api.user = user;
      await api.create(id: id, author: author, title: title, payload: sharePayload(routineV(4), [curl]));
      if (public) await api.setPublic(id, true);
    }

    test('mi rutina no sale en el buscador hasta que lo activo, y se puede quitar', () async {
      final c = await device();
      await c.read(routineProvider.notifier).replaceWith(routineV(4, title: 'Torso pierna'));
      final sync = c.read(syncProvider.notifier);
      final p = await sync.publish(author: 'Arturo');
      expect(p.isPublic, isFalse, reason: 'privada por defecto');
      expect(await sync.search('arturo'), isEmpty);

      await sync.setPublic(true);
      expect(c.read(syncProvider).published?.isPublic, isTrue);
      expect((await sync.search('arturo')).single.id, p.id);
      expect((await sync.search('PIERNA')).single.title, 'Torso pierna');

      // Subir cambios no la vuelve privada ni sube la versión por hacerla pública.
      await c.read(routineProvider.notifier).replaceWith(routineV(5, title: 'Torso pierna'));
      final p2 = await sync.publish(author: 'Arturo');
      expect((p2.isPublic, p2.version), (true, 2));

      // Sobrevive a cerrar la app.
      final back = Publication.fromJson(jsonDecode(c.read(prefsProvider).getString('sync_published')!));
      expect(back.isPublic, isTrue);

      await sync.setPublic(false);
      expect(await sync.search('arturo'), isEmpty);
      expect(c.read(syncProvider).published?.isPublic, isFalse);
    });

    test('busca por autor o título, las más seguidas primero, sin las privadas', () async {
      await publishAs('ana', 'ANA234', 'Ana', 'PPL de Ana');
      await publishAs('bea', 'BEA234', 'Bea', 'Full body');
      await publishAs('carla', 'CAR234', 'Carla', 'PPL secreto', public: false);
      api.user = 'otro';
      await api.follow('BEA234');

      api.user = 'yo';
      final c = await device();
      final sync = c.read(syncProvider.notifier);
      expect([for (final r in await sync.search('ppl')) r.id], ['ANA234']);
      expect([for (final r in await sync.search('bea')) r.id], ['BEA234']);
      expect([for (final r in await sync.search('  ')) r.id], ['BEA234', 'ANA234'], reason: 'sin texto: las más seguidas');
      expect((await sync.search('full')).single.followers, 1);
      expect(await sync.search('nadie'), isEmpty);
    });

    test('desde el buscador se sigue igual que con el código', () async {
      await publishAs('ana', 'ANA234', 'Ana', 'PPL de Ana');
      api.user = 'yo';
      final c = await device();
      final sync = c.read(syncProvider.notifier);
      final hit = (await sync.search('ana')).single;
      // La pantalla de importar recibe "FS-<id>" y lo resuelve por código.
      final id = parseRoutineCode(formatCode(hit.id))!;
      final remote = (await sync.lookup(id))!;
      await sync.applyUpdate(remote);
      await sync.startFollowing(remote);
      expect(c.read(syncProvider).following?.author, 'Ana');
      expect(c.read(routineProvider)!.days.first.items.first.sets, 4);
      expect((await sync.search('ana')).single.followers, 1);
    });

    test('nadie puede hacer pública la rutina de otro', () async {
      await publishAs('ana', 'ANA234', 'Ana', 'PPL', public: false);
      api.user = 'yo';
      await expectLater(api.setPublic('ANA234', true), throwsStateError);
      expect(await api.search('ana'), isEmpty);
    });
  });
}
