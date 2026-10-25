import 'package:supabase_flutter/supabase_flutter.dart';

import 'routine_sync.dart';

/// Supabase project URL. The publishable key can ship in the app: what it
/// allows is limited by the RLS policies (supabase/schema.sql). Both can be
/// overridden at build time with --dart-define.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://hglqemhdjidnnurngvxb.supabase.co',
);
/// Supabase publishable (anon) key.
const supabaseKey = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: 'sb_publishable_wpVf8Kbhc6QiqeCHwB43SQ_AJh6Lh41',
);

/// Connects the Supabase client; called once in `main()`.
Future<void> initSupabase() => Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);

/// [RoutineSyncApi] backed by the Supabase tables `routines` and `follows`
/// and the `get_routines` / `search_routines` functions.
class SupabaseRoutineSyncApi implements RoutineSyncApi {
  /// Creates the API over [_client].
  SupabaseRoutineSyncApi(this._client);

  final SupabaseClient _client;

  /// The auth client.
  GoTrueClient get _auth => _client.auth;

  @override
  Future<String> ensureSignedIn() async {
    final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user;
    return user!.id;
  }

  @override
  Future<RemoteRoutine> create({
    required String id,
    required String author,
    required String title,
    required Map<String, dynamic> payload,
  }) async {
    await ensureSignedIn();
    try {
      final row = await _client
          .from('routines')
          .insert({'id': id, 'author': author, 'title': title, 'payload': payload})
          .select()
          .single();
      return RemoteRoutine.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const CodeTakenException();
      rethrow;
    }
  }

  @override
  Future<RemoteRoutine> update({
    required String id,
    required String author,
    required String title,
    required Map<String, dynamic> payload,
  }) async {
    await ensureSignedIn();
    final row = await _client
        .from('routines')
        .update({'author': author, 'title': title, 'payload': payload})
        .eq('id', id)
        .select()
        .single();
    return RemoteRoutine.fromJson(row);
  }

  @override
  Future<List<RemoteRoutine>> fetch(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client.rpc<List<dynamic>>('get_routines', params: {'ids': ids});
    return [for (final r in rows) RemoteRoutine.fromJson((r as Map).cast<String, dynamic>())];
  }

  @override
  Future<List<RemoteRoutine>> mine() async {
    if (_auth.currentUser == null) return const [];
    final rows = await _client.from('routines').select().order('updated_at', ascending: false);
    return [for (final r in rows) RemoteRoutine.fromJson(r)];
  }

  @override
  Future<List<RemoteRoutine>> search(String query, {int limit = 20}) async {
    final rows = await _client.rpc<List<dynamic>>('search_routines', params: {'q': query.trim(), 'lim': limit});
    return [for (final r in rows) RemoteRoutine.fromJson((r as Map).cast<String, dynamic>())];
  }

  @override
  Future<void> setPublic(String id, bool isPublic) async {
    await ensureSignedIn();
    await _client.from('routines').update({'is_public': isPublic}).eq('id', id);
  }

  @override
  Future<void> follow(String id) async {
    await ensureSignedIn();
    await _client.from('follows').upsert({'routine_id': id}, ignoreDuplicates: true);
  }

  @override
  Future<void> unfollow(String id) async {
    if (_auth.currentUser == null) return;
    await _client.from('follows').delete().eq('routine_id', id);
  }
}

/// Optional email account: keeps the anonymous account so the published
/// routine isn't lost when changing phones. It is verified with a 6-digit
/// code sent by email.
class EmailAccount {
  /// Creates the account helper over [_auth].
  EmailAccount(this._auth);

  final GoTrueClient _auth;

  /// Account email, or null when anonymous or signed out.
  String? get email {
    final u = _auth.currentUser;
    return u == null || u.isAnonymous ? null : u.email;
  }

  /// Step 1 to add an email to this account: sends the code.
  Future<void> linkEmail(String email) async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    await _auth.updateUser(UserAttributes(email: email));
  }

  /// Step 2 to add an email: confirms the [code] that was sent.
  Future<void> confirmLink(String email, String code) =>
      _auth.verifyOTP(email: email, token: code, type: OtpType.emailChange);

  /// Step 1 to sign in to an account that already has an email (another
  /// phone): sends the code.
  Future<void> sendLoginCode(String email) => _auth.signInWithOtp(email: email, shouldCreateUser: false);

  /// Step 2 to sign in: confirms the [code] that was sent.
  Future<void> confirmLogin(String email, String code) =>
      _auth.verifyOTP(email: email, token: code, type: OtpType.email);
}
