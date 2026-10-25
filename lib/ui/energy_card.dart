import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_state.dart';
import '../data/energy.dart';
import '../data/health_state.dart';
import '../data/user_profile.dart';
import 'theme.dart';

/// "Today: goal, eaten, burned, steps". With Health Connect it uses the
/// watch and what is logged in Fitia; without it, the goal and FitStreak's
/// own workouts.
class EnergyCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const EnergyCard({super.key});

  @override
  ConsumerState<EnergyCard> createState() => _EnergyCardState();
}

/// Re-reads Health Connect when coming back to the app (in case you ate
/// something and logged it in Fitia, or walked with the watch).
class _EnergyCardState extends ConsumerState<EnergyCard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(todayEnergyProvider);
  }

  @override
  Widget build(BuildContext context) => const _EnergyCardBody();
}

/// The card's content.
class _EnergyCardBody extends ConsumerWidget {
  /// Creates the content.
  const _EnergyCardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final energy = ref.watch(todayEnergyProvider).value;
    final profile = ref.watch(profileProvider);
    final connected = ref.watch(healthProvider);
    if (energy == null || profile == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final eaten = energy.eatenKcal;
    final progress = eaten == null ? null : (eaten / energy.goalKcal).clamp(0.0, 1.2);
    final over = eaten != null && eaten > energy.goalKcal;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showDetails(context, ref, profile),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Energía de hoy', style: text.titleMedium),
                  const Spacer(),
                  Text(
                    connected ? 'Health Connect' : 'Estimado',
                    style: text.labelSmall?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.info_outline, size: 16, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Stat(icon: Icons.flag_outlined, label: 'Meta', value: '${energy.goalKcal}', color: AppColors.teal),
                  _Stat(
                    icon: Icons.restaurant,
                    label: 'Comido',
                    value: eaten == null ? '—' : '$eaten',
                    color: over ? AppColors.orange : AppColors.tealDark,
                  ),
                  _Stat(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Gastado',
                    value: '${energy.burnedKcal}',
                    color: AppColors.orange,
                  ),
                  if (energy.steps != null)
                    _Stat(icon: Icons.directions_walk, label: 'Pasos', value: _thousands(energy.steps!), color: AppColors.muted),
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.toDouble().clamp(0, 1),
                    minHeight: 8,
                    color: over ? AppColors.orange : AppColors.teal,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  over
                      ? 'Te has pasado ${-energy.leftKcal!} kcal de tu meta'
                      : 'Te quedan ${energy.leftKcal} kcal para tu meta',
                  style: text.bodySmall,
                ),
              ],
              if (!connected) ...[
                const SizedBox(height: 12),
                if (healthSupported)
                  OutlinedButton.icon(
                    onPressed: () => connectHealth(context, ref),
                    icon: const Icon(Icons.favorite_border),
                    label: const Text('Conectar reloj y Fitia (Health Connect)'),
                  ),
              ],
              if (profile.sex == Sex.unspecified)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    onPressed: () => _askSex(context, ref, profile),
                    child: const Text('Indica tu sexo para afinar la meta'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Steps with a thousands separator ("8.432").
  static String _thousands(int n) =>
      n >= 1000 ? '${n ~/ 1000}.${(n % 1000).toString().padLeft(3, '0')}' : '$n';

  /// Asks for the sex (profiles created before it was asked) and saves it.
  Future<void> _askSex(BuildContext context, WidgetRef ref, UserProfile p) async {
    final s = await showDialog<Sex>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Sexo'),
        children: [
          for (final s in Sex.values)
            SimpleDialogOption(onPressed: () => Navigator.pop(c, s), child: Text(s.label)),
        ],
      ),
    );
    if (s != null) await ref.read(profileProvider.notifier).save(p.copyWith(sex: s));
  }

  /// Explains how each figure is calculated, with connect/disconnect.
  Future<void> _showDetails(BuildContext context, WidgetRef ref, UserProfile p) async {
    final connected = ref.read(healthProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        final text = Theme.of(sheet).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cómo se calcula', style: text.titleLarge),
                const SizedBox(height: 12),
                Text(
                  '• Meta: tu gasto diario estimado (${maintenanceKcal(p)} kcal, según peso, altura, edad, sexo '
                  'y días de entreno) ${_goalText(p.goal)}.\n'
                  '• Gastado: calorías activas de hoy. ${connected ? 'Vienen del reloj vía Health Connect, con tus entrenos de FitStreak incluidos.' : 'Solo tus entrenos de FitStreak (duración × peso). Conecta el reloj para contar todo el día.'}\n'
                  '• Comido: lo que apuntas en Fitia u otra app que guarde comidas en Health Connect.\n\n'
                  'Son aproximaciones: úsalas como guía, no como medida exacta.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (healthSupported)
                  connected
                      ? OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheet);
                            ref.read(healthProvider.notifier).disconnect();
                          },
                          icon: const Icon(Icons.link_off),
                          label: const Text('Desconectar Health Connect'),
                        )
                      : FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(sheet);
                            connectHealth(context, ref);
                          },
                          icon: const Icon(Icons.favorite_border),
                          label: const Text('Conectar Health Connect'),
                        ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheet);
                    context.go('/onboarding');
                  },
                  child: const Text('Cambiar mis datos (peso, objetivo…)'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// How the goal adjusts maintenance, in Spanish.
  static String _goalText(Goal g) => switch (g) {
        Goal.fatLoss => '− 400 kcal para perder grasa',
        Goal.muscle => '+ 250 kcal para ganar músculo',
        Goal.strength => '+ 150 kcal para ganar fuerza',
        Goal.health => 'para mantenerte',
      };
}

/// Asks Health Connect for permissions and explains the result.
Future<void> connectHealth(BuildContext context, WidgetRef ref) async {
  final result = await ref.read(healthProvider.notifier).connect();
  if (!context.mounted) return;
  final msg = switch (result) {
    HealthConnectResult.connected =>
      'Conectado. Para ver lo que comes, en Fitia activa también Health Connect.',
    HealthConnectResult.denied => 'Sin permisos no se puede leer nada. Puedes volver a intentarlo cuando quieras.',
    HealthConnectResult.notInstalled => 'Instala Health Connect desde Google Play y vuelve a pulsar Conectar.',
    HealthConnectResult.unsupported => 'Health Connect solo está en Android.',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// One figure of the card: icon, value and label.
class _Stat extends StatelessWidget {
  /// Creates a figure.
  const _Stat({required this.icon, required this.label, required this.value, required this.color});

  /// Icon above the value.
  final IconData icon;

  /// Label under the value.
  final String label;

  /// The figure.
  final String value;

  /// Icon color.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          Text(label, style: text.labelSmall?.copyWith(color: AppColors.muted)),
        ],
      ),
    );
  }
}
