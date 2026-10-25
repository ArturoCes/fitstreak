import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/sync/routine_sync.dart';
import '../../data/sync/sync_state.dart';
import '../../ui/theme.dart';

/// Search routines their authors listed. Tapping one opens "Importar" with
/// its code: the same path as a link.
class SearchRoutinesScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SearchRoutinesScreen({super.key});

  @override
  ConsumerState<SearchRoutinesScreen> createState() => _SearchRoutinesScreenState();
}

/// Search text, debounce and results.
class _SearchRoutinesScreenState extends ConsumerState<SearchRoutinesScreen> {
  final _text = TextEditingController();
  Timer? _debounce;

  /// Request counter, so an old response arriving late isn't shown.
  int _request = 0;
  List<RemoteRoutine>? _results;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Without text: the most followed.
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  /// Searches 350 ms after the user stops typing.
  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  /// Runs the search for [q] and shows the results.
  Future<void> _search(String q) async {
    final request = ++_request;
    setState(() => _failed = false);
    try {
      final results = await ref.read(syncProvider.notifier).search(q);
      if (mounted && request == _request) setState(() => _results = results);
    } catch (_) {
      if (mounted && request == _request) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(syncProvider).published?.id;
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar rutinas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _text,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (q) {
                _debounce?.cancel();
                _search(q);
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Nombre del autor o de la rutina',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: switch ((results, _failed)) {
              (_, true) => _Message(
                  'No hay conexión con el servidor. Prueba otra vez en un rato.',
                  action: TextButton(onPressed: () => _search(_text.text), child: const Text('Reintentar')),
                ),
              (null, _) => const Center(child: CircularProgressIndicator()),
              (final r?, _) when r.isEmpty => _Message(
                  _text.text.trim().isEmpty
                      ? 'Aún no hay rutinas en el buscador.'
                      : 'No hay rutinas públicas con «${_text.text.trim()}».\n'
                          'Si alguien te pasó su código o enlace, pégalo en Importar.',
                ),
              (final r?, _) => ListView.separated(
                  itemCount: r.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final routine = r[i];
                    return ListTile(
                      leading: const IconTile(icon: Icons.fitness_center, color: AppColors.teal, size: 36),
                      title: Text(routine.title),
                      subtitle: Text(
                        '${routine.author}${routine.id == mine ? ' (tú)' : ''} · ${switch (routine.followers) {
                          0 => 'sin seguidores',
                          1 => '1 seguidor',
                          final n => '$n seguidores',
                        }}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/import', extra: formatCode(routine.id)),
                    );
                  },
                ),
            },
          ),
        ],
      ),
    );
  }
}

/// Centered message (no results, no connection) with an optional action.
class _Message extends StatelessWidget {
  /// Creates the message.
  const _Message(this.text, {this.action});

  /// Message text.
  final String text;

  /// Button under the message.
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              ?action,
            ],
          ),
        ),
      );
}
