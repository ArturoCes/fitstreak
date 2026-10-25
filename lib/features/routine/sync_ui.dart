import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/app_state.dart';
import '../../data/exercise_repository.dart';
import '../../data/sync/routine_sync.dart';
import '../../data/sync/supabase_sync_api.dart';
import '../../data/sync/sync_state.dart';
import '../../ui/theme.dart';

const _offline = 'No hay conexión con el servidor. Prueba otra vez en un rato.';

/// Shows [text] in a snack bar, replacing the current one.
void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Whether my routine has changes that followers don't see yet.
final unpushedChangesProvider = Provider<bool>((ref) {
  ref.watch(syncProvider);
  final exercises = ref.watch(exercisesProvider).value;
  if (exercises == null) return false;
  return ref.read(syncProvider.notifier).hasUnpushedChanges(ref.watch(routineProvider), exercises);
});

/// Publishes my routine, or shows the published one and uploads changes.
Future<void> showPublishSheet(BuildContext context, WidgetRef ref) async {
  final published = ref.read(syncProvider).published;
  if (published == null) {
    final author = await _askAuthor(context, null);
    if (author == null || !context.mounted) return;
    await _publish(context, ref, author, first: true);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => _PublishedSheet(parentContext: context),
  );
}

/// Uploads my routine under [author] and tells the user how it went;
/// [first] means it is being published for the first time.
Future<void> _publish(BuildContext context, WidgetRef ref, String author, {required bool first}) async {
  try {
    final p = await ref.read(syncProvider.notifier).publish(author: author);
    if (!context.mounted) return;
    if (first) {
      await _showCode(context, ref, p.id);
    } else {
      _snack(context, 'Cambios publicados: tus seguidores verán la versión nueva al abrir la app');
    }
  } catch (e) {
    debugPrint('No se pudo publicar: $e');
    if (context.mounted) _snack(context, _offline);
  }
}

/// Asks for the name shown as author (prefilled with [current]).
Future<String?> _askAuthor(BuildContext context, String? current) {
  final name = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Publicar tu rutina'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Te daremos un enlace. Quien lo abra podrá seguir tu rutina y, cuando la cambies, '
            'le preguntaremos si quiere la versión nueva.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: '¿Con qué nombre te verán?'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        ListenableBuilder(
          listenable: name,
          builder: (_, _) => FilledButton(
            onPressed: name.text.trim().isEmpty ? null : () => Navigator.pop(c, name.text.trim()),
            child: const Text('Publicar'),
          ),
        ),
      ],
    ),
  );
}

/// Opens the share sheet with the link and code of routine [id].
Future<void> _shareCode(WidgetRef ref, String id) {
  final title = ref.read(routineProvider)?.title ?? 'mi rutina';
  return SharePlus.instance.share(ShareParams(
    subject: 'Rutina: $title',
    text: '💪 Sigue mi rutina «$title» en FitStreak: ${routineLink(supabaseUrl, id)}\n\n'
        'Si el enlace no abre la app, copia este mensaje y pégalo en FitStreak → Opciones → '
        'Importar mi rutina (código ${formatCode(id)}).',
  ));
}

/// Shares a link to my routine. Publishes it the first time (asking for the
/// name) and uploads pending changes first. Returns false without a
/// connection (the long code is shared instead) and null if cancelled.
Future<bool?> shareRoutineLink(BuildContext context, WidgetRef ref) async {
  var p = ref.read(syncProvider).published;
  final author = p?.author ?? await _askAuthor(context, null);
  if (author == null) return null;
  try {
    if (p == null || ref.read(unpushedChangesProvider)) {
      p = await ref.read(syncProvider.notifier).publish(author: author);
    }
  } catch (e) {
    debugPrint('No se pudo publicar: $e');
    return false;
  }
  await _shareCode(ref, p.id);
  return true;
}

/// Shows the code of routine [id] with copy and share buttons.
Future<void> _showCode(BuildContext context, WidgetRef ref, String id) => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.public, size: 36, color: AppColors.teal),
        title: const Text('Rutina publicada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Comparte el enlace con quien quieras que la siga. Su código es:', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            SelectableText(formatCode(id), style: Theme.of(c).textTheme.headlineMedium),
            const SizedBox(height: 12),
            const Text(
              'Cuando cambies tu rutina, entra en Opciones → Mi rutina publicada → Subir cambios.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: routineLink(supabaseUrl, id)));
              Navigator.pop(c);
            },
            child: const Text('Copiar enlace'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(c);
              _shareCode(ref, id);
            },
            icon: const Icon(Icons.share),
            label: const Text('Compartir'),
          ),
        ],
      ),
    );

/// Sheet of my published routine: code, followers, search listing,
/// upload changes and stop publishing.
class _PublishedSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const _PublishedSheet({required this.parentContext});

  /// For messages: the sheet closes before the upload finishes.
  final BuildContext parentContext;

  @override
  ConsumerState<_PublishedSheet> createState() => _PublishedSheetState();
}

/// Loads the published version and handles the search listing switch.
class _PublishedSheetState extends ConsumerState<_PublishedSheet> {
  late final Future<RemoteRoutine?> _remote;

  @override
  void initState() {
    super.initState();
    final id = ref.read(syncProvider).published!.id;
    _remote = ref.read(syncProvider.notifier).lookup(id).catchError((_) => null);
  }

  bool _savingPublic = false;

  /// Error shown inside the sheet: a SnackBar would be hidden behind it.
  String? _publicError;

  /// Lists or unlists the routine in the search.
  Future<void> _setPublic(bool value) async {
    setState(() {
      _savingPublic = true;
      _publicError = null;
    });
    try {
      await ref.read(syncProvider.notifier).setPublic(value);
    } catch (_) {
      if (mounted) setState(() => _publicError = _offline);
    } finally {
      if (mounted) setState(() => _savingPublic = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(syncProvider).published;
    if (p == null) return const SizedBox.shrink();
    final dirty = ref.watch(unpushedChangesProvider);
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tu rutina publicada', style: text.titleLarge),
            const SizedBox(height: 4),
            Row(
              children: [
                SelectableText(formatCode(p.id), style: text.headlineSmall?.copyWith(color: AppColors.teal)),
                const Spacer(),
                FutureBuilder(
                  future: _remote,
                  builder: (_, snap) => Text(
                    switch (snap.data?.followers) {
                      null => '',
                      1 => '1 seguidor',
                      final n => '$n seguidores',
                    },
                    style: text.bodyMedium,
                  ),
                ),
              ],
            ),
            Text('Publicada como «${p.author}»', style: text.bodySmall),
            const SizedBox(height: 12),
            Text(
              dirty
                  ? 'Has cambiado tu rutina desde la última vez. Tus seguidores aún ven la versión anterior.'
                  : 'Tus seguidores tienen la misma versión que tú.',
              style: text.bodyMedium?.copyWith(color: dirty ? AppColors.orange : null),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: p.isPublic,
              onChanged: _savingPublic ? null : (v) => _setPublic(v),
              title: const Text('Que aparezca en el buscador'),
              subtitle: Text(p.isPublic
                  ? 'Cualquiera puede encontrarla buscando «${p.author}» o su título, y seguirla.'
                  : 'Ahora solo la encuentra quien tiene tu código o enlace. '
                      'Si lo activas, cualquiera podrá encontrarla por tu nombre o su título.'),
            ),
            if (_publicError case final e?)
              Text(e, style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: dirty
                  ? () {
                      Navigator.pop(context);
                      _publish(widget.parentContext, ref, p.author, first: false);
                    }
                  : null,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Subir cambios'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _shareCode(ref, p.id);
              },
              icon: const Icon(Icons.share),
              label: const Text('Compartir enlace'),
            ),
            TextButton(
              onPressed: () async {
                final author = await _askAuthor(context, p.author);
                if (author == null || !context.mounted) return;
                Navigator.pop(context);
                await _publish(widget.parentContext, ref, author, first: false);
              },
              child: const Text('Cambiar mi nombre'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The routine I follow: check for a new version or stop following it.
Future<void> showFollowingSheet(BuildContext context, WidgetRef ref) async {
  final f = ref.read(syncProvider).following;
  if (f == null) return;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text('«${f.title}»', style: Theme.of(sheet).textTheme.titleLarge),
            subtitle: Text('Rutina de ${f.author} · ${formatCode(f.id)}'),
          ),
          ListTile(
            leading: const IconTile(icon: Icons.sync, color: AppColors.teal, size: 36),
            title: const Text('Buscar versión nueva'),
            onTap: () => Navigator.pop(sheet, 'check'),
          ),
          ListTile(
            leading: IconTile(icon: Icons.link_off, color: Theme.of(sheet).colorScheme.error, size: 36),
            title: const Text('Dejar de seguirla'),
            subtitle: const Text('Te quedas con la rutina como está ahora'),
            onTap: () => Navigator.pop(sheet, 'stop'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'check':
      await promptRoutineUpdate(context, ref, manual: true);
    case 'stop':
      await ref.read(syncProvider.notifier).stopFollowing();
      if (context.mounted) _snack(context, 'Ya no sigues «${f.title}». Tu rutina no cambia.');
  }
}

/// If the author of the routine I follow changed it, asks whether to apply
/// the new version. It is never applied without asking. [manual]: the user
/// asked, so "nothing new" and "no connection" are reported too.
Future<void> promptRoutineUpdate(BuildContext context, WidgetRef ref, {bool manual = false}) async {
  final sync = ref.read(syncProvider.notifier);
  final RemoteRoutine? update;
  try {
    update = await sync.checkForUpdate();
  } catch (e) {
    debugPrint('No se pudo buscar la versión nueva: $e');
    if (manual && context.mounted) _snack(context, _offline);
    return;
  }
  if (!context.mounted) return;
  if (update == null) {
    if (manual) _snack(context, 'Ya tienes la última versión');
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.system_update_alt, size: 36, color: AppColors.teal),
      title: Text('Hay una versión nueva de la rutina de ${update!.author}'),
      content: Text(
        '«${update.title}»\n\n¿Actualizar? Sustituirá a tu rutina actual, también los cambios '
        'que le hayas hecho tú. Tu historial, tus gráficos y tu racha se mantienen.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Ahora no')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Actualizar')),
      ],
    ),
  );
  if (ok == true) {
    await sync.applyUpdate(update);
    if (context.mounted) _snack(context, 'Rutina actualizada a la versión de ${update.author}');
  } else if (ok == false) {
    await sync.dismiss(update);
  }
}

/// Optional email so the published routine isn't lost when changing phones.
Future<void> showAccountDialog(BuildContext context, WidgetRef ref) async {
  final auth = Supabase.instance.client.auth;
  // If the email was confirmed with the link in the mail (not the code),
  // the saved session doesn't know yet.
  if (auth.currentSession != null) {
    try {
      await auth.refreshSession();
    } catch (_) {}
    if (!context.mounted) return;
  }
  final account = EmailAccount(auth);
  final restored = await showDialog<bool>(context: context, builder: (_) => _AccountDialog(account));
  if (restored == null || !context.mounted) return;
  if (!restored) {
    _snack(context, 'Email guardado: ya no perderás tu rutina publicada');
    return;
  }
  try {
    final r = await ref.read(syncProvider.notifier).restorePublication();
    if (context.mounted) {
      _snack(context, r == null ? 'Sesión iniciada' : 'Recuperada tu rutina publicada ${formatCode(r.id)}');
    }
  } catch (_) {
    if (context.mounted) _snack(context, _offline);
  }
}

/// Dialog to add an email to this account or sign in to an existing one.
class _AccountDialog extends StatefulWidget {
  /// Creates the dialog.
  const _AccountDialog(this.account);

  /// The account helper.
  final EmailAccount account;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

/// Email and code fields and the two-step flow.
class _AccountDialogState extends State<_AccountDialog> {
  final _email = TextEditingController();
  final _code = TextEditingController();

  /// true: sign in to an existing account (another phone); false: add the
  /// email to this one.
  bool _login = false;
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Runs a step [f] showing progress and turning errors into a message.
  Future<void> _run(Future<void> Function() f) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await f();
    } on AuthException catch (e) {
      debugPrint('Auth: ${e.code} ${e.message}');
      _error = switch (e.code) {
        'email_exists' => 'Ese email ya tiene cuenta. Usa «Ya tengo cuenta».',
        'otp_expired' => 'El código no es válido o ha caducado.',
        'over_email_send_rate_limit' => 'Se han enviado demasiados correos. Prueba en un rato.',
        'otp_disabled' || 'user_not_found' => 'No hay ninguna cuenta con ese email.',
        _ => 'No se pudo: ${e.message}',
      };
    } catch (e) {
      _error = _offline;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.account.email;
    if (email != null) {
      return AlertDialog(
        title: const Text('Tu cuenta'),
        content: Text('Tu rutina publicada está guardada con $email. En otro móvil entra con ese email '
            'para seguir actualizándola.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vale'))],
      );
    }
    final mail = _email.text.trim();
    return AlertDialog(
      title: Text(_login ? 'Entrar con tu email' : 'Guardar con tu email'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _login
                  ? 'Te enviamos un código para entrar en tu cuenta y recuperar tu rutina publicada.'
                  : 'Es opcional. Sirve para no perder tu rutina publicada si cambias de móvil o '
                      'reinstalas la app. Te enviamos un código para comprobar el email.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              onChanged: (_) => setState(() {}),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Código del correo'),
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (!_codeSent)
              TextButton(
                onPressed: () => setState(() {
                  _login = !_login;
                  _error = null;
                }),
                child: Text(_login ? 'Guardar esta cuenta con un email' : 'Ya tengo cuenta (otro móvil)'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        if (!_codeSent)
          FilledButton(
            onPressed: _busy || !mail.contains('@')
                ? null
                : () => _run(() async {
                      await (_login ? widget.account.sendLoginCode(mail) : widget.account.linkEmail(mail));
                      _codeSent = true;
                    }),
            child: const Text('Enviar código'),
          )
        else
          FilledButton(
            onPressed: _busy || _code.text.trim().length != 6
                ? null
                : () => _run(() async {
                      final code = _code.text.trim();
                      await (_login
                          ? widget.account.confirmLogin(mail, code)
                          : widget.account.confirmLink(mail, code));
                      if (mounted) Navigator.pop(this.context, _login);
                    }),
            child: const Text('Confirmar'),
          ),
      ],
    );
  }
}
