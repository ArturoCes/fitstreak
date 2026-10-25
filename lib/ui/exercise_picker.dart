import 'package:flutter/material.dart';

import '../data/exercise.dart';
import '../data/labels_es.dart';
import '../data/routine_import.dart';
import 'exercise_media.dart';
import 'theme.dart';

/// Result of the picker: a catalog exercise or "use as my own".
sealed class PickedExercise {
  /// Base constructor.
  const PickedExercise();
}

/// The user picked [exercise] from the catalog.
class PickedFromCatalog extends PickedExercise {
  /// Creates the result.
  const PickedFromCatalog(this.exercise);

  /// The chosen exercise.
  final Exercise exercise;
}

/// The user chose to keep their own name as a custom exercise.
class PickedCustom extends PickedExercise {
  /// Creates the result.
  const PickedCustom();
}

/// Sheet to search the catalog typing in Spanish or English. With
/// [allowCustom] it offers keeping the user's own name without a photo.
Future<PickedExercise?> showExercisePicker(
  BuildContext context, {
  required List<Exercise> catalog,
  required String initialQuery,
  bool allowCustom = false,
}) =>
    showModalBottomSheet<PickedExercise>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PickerSheet(catalog: catalog, initialQuery: initialQuery, allowCustom: allowCustom),
    );

/// The search sheet.
class _PickerSheet extends StatefulWidget {
  /// Creates the sheet.
  const _PickerSheet({required this.catalog, required this.initialQuery, required this.allowCustom});

  /// Exercises to search.
  final List<Exercise> catalog;

  /// Text the search starts with.
  final String initialQuery;

  /// Whether to offer "use as my own".
  final bool allowCustom;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

/// Holds the search text.
class _PickerSheetState extends State<_PickerSheet> {
  late final _query = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = searchCatalog(_query.text, widget.catalog);
    final media = MediaQuery.of(context);
    return SizedBox(
      height: media.size.height * 0.85,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _query,
                autofocus: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Busca: remo polea, curl martillo, squat…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(_query.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (widget.allowCustom)
              ListTile(
                leading: const IconTile(icon: Icons.edit_note, color: AppColors.orange, size: 40),
                title: Text('Usar «${widget.initialQuery}» como ejercicio propio'),
                subtitle: const Text('Sin foto ni instrucciones, pero con su registro y progreso'),
                onTap: () => Navigator.pop(context, const PickedCustom()),
              ),
            const Divider(height: 1),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('Sin resultados. Prueba con otra palabra.'))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final e = results[i];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox.square(dimension: 48, child: ExerciseMedia(e)),
                          ),
                          title: Text(e.name),
                          subtitle: Text(
                            '${es(equipmentEs, e.equipmentOrBody)}'
                            '${e.primaryMuscles.isEmpty ? '' : ' · ${es(muscleEs, e.primaryMuscles.first)}'}',
                          ),
                          onTap: () => Navigator.pop(context, PickedFromCatalog(e)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
