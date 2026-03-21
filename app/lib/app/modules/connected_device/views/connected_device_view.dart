import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_fi/app/modules/home/controllers/home_controller.dart';
import 'package:home_fi/app/theme/text_theme.dart';

class ConnectedDeviceView extends GetView<HomeController> {
  const ConnectedDeviceView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      id: 'control',
      builder: (_) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Text(
              'Control',
              style: HomeFiTextTheme.kHeadTextStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manual overrides for pump, grow light, and nutrient dosing.',
              style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _ToggleCard(
              label: 'Pump',
              subtitle: 'Manual relay control',
              value: controller.deviceState.pumpOn ?? false,
              enabled: !controller.isCommandPending(CommandType.pump),
              onChanged: controller.togglePump,
            ),
            const SizedBox(height: 14),
            _ToggleCard(
              label: 'Grow Light',
              subtitle: 'Supplemental lighting',
              value: controller.deviceState.lightOn ?? false,
              enabled: !controller.isCommandPending(CommandType.light),
              onChanged: controller.toggleGrowLight,
            ),
            const SizedBox(height: 24),
            Text(
              'Dosing',
              style: HomeFiTextTheme.kSub2HeadTextStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Dose Nutrient A',
                    onPressed:
                        controller.isCommandPending(CommandType.nutrientA)
                            ? null
                            : controller.doseNutrientA,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: 'Dose Nutrient B',
                    onPressed:
                        controller.isCommandPending(CommandType.nutrientB)
                            ? null
                            : controller.doseNutrientB,
                  ),
                ),
              ],
            ),
            if (controller.lastActionMessage != null) ...[
              const SizedBox(height: 18),
              Text(
                controller.lastActionMessage!,
                style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [kCardShadow],
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: enabled ? onChanged : null,
        title: Text(
          label,
          style: HomeFiTextTheme.kSub2HeadTextStyle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: HomeFiTextTheme.kBodyTextStyle.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: HomeFiTextTheme.kBodyTextStyle.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
