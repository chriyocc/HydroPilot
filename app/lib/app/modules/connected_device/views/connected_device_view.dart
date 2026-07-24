import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_fi/app/modules/home/controllers/home_controller.dart';
import 'package:home_fi/app/theme/color_theme.dart';
import 'package:home_fi/app/theme/text_theme.dart';

class ConnectedDeviceView extends GetView<HomeController> {
  const ConnectedDeviceView({super.key});

  static const _motionDuration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      id: 'control',
      builder: (_) {
        final isLocal = controller.settings.usesLocalNetwork;

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            _ControlHeader(
              isLocal: isLocal,
              message: controller.lastActionMessage,
            ),
            const SizedBox(height: 20),
            _SectionTitle(
              label: 'Manual Hardware',
              supportingText: isLocal
                  ? 'Controller relay states from the local network.'
                  : 'Manual overrides for core hardware.',
            ),
            const SizedBox(height: 12),
            _ResponsiveControls(
              children: [
                if (!isLocal)
                  _ToggleCard(
                    icon: Icons.water_drop_outlined,
                    label: 'Pump',
                    subtitle: 'Manual relay',
                    value: controller.deviceState.pumpOn ?? false,
                    enabled: !controller.isCommandPending(CommandType.pump),
                    onChanged: controller.togglePump,
                  ),
                _ToggleCard(
                  icon: Icons.light_mode_outlined,
                  label: 'Grow Light',
                  subtitle: 'Supplemental lighting',
                  value: controller.deviceState.lightOn ?? false,
                  enabled: !controller.isCommandPending(CommandType.light),
                  onChanged: controller.toggleGrowLight,
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (!isLocal) ...[
              _RemoteDosingControls(controller: controller),
              const SizedBox(height: 22),
            ],
            _LocalDosingControls(controller: controller),
          ],
        );
      },
    );
  }
}

class _ControlHeader extends StatelessWidget {
  const _ControlHeader({
    required this.isLocal,
    required this.message,
  });

  final bool isLocal;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: ConnectedDeviceView._motionDuration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [kCardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Control',
                      style: HomeFiTextTheme.kSubHeadTextStyle.copyWith(
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLocal
                          ? 'Local dosing and relay controls for the ESP32.'
                          : 'Cloud/manual controls for pump, light, and nutrient dosing.',
                      style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusPill(
                label: isLocal ? 'Local Network' : 'Backend Mode',
                icon: isLocal ? Icons.wifi_rounded : Icons.cloud_outlined,
              ),
              if (message != null)
                _StatusPill(
                  label: message!,
                  icon: Icons.check_circle_outline_rounded,
                  maxWidth: 250,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    this.maxWidth,
  });

  final String label;
  final IconData icon;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimary;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.label,
    required this.supportingText,
  });

  final String label;
  final String supportingText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: HomeFiTextTheme.kSub2HeadTextStyle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          supportingText,
          style: HomeFiTextTheme.kBodyTextStyle.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RemoteDosingControls extends StatelessWidget {
  const _RemoteDosingControls({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return _ControlPanel(
      icon: Icons.opacity_rounded,
      title: 'Dosing',
      subtitle: 'Single-shot nutrient commands.',
      child: _ResponsiveControls(
        children: [
          _ActionButton(
            icon: Icons.looks_one_rounded,
            label: 'Dose Nutrient A',
            onPressed: controller.isCommandPending(CommandType.nutrientA)
                ? null
                : controller.doseNutrientA,
          ),
          _ActionButton(
            icon: Icons.looks_two_rounded,
            label: 'Dose Nutrient B',
            onPressed: controller.isCommandPending(CommandType.nutrientB)
                ? null
                : controller.doseNutrientB,
          ),
        ],
      ),
    );
  }
}

class _LocalDosingControls extends StatelessWidget {
  const _LocalDosingControls({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          label: 'Dosing Heads',
          supportingText: 'Prime lines, set EC targets, and trigger doses.',
        ),
        const SizedBox(height: 12),
        _ResponsiveControls(
          children: [
            _DosingHeadSection(
              title: 'Head A',
              icon: Icons.looks_one_rounded,
              accentColor: Theme.of(context).colorScheme.primary,
              targetEc: controller.targetEcA,
              onTargetEcChanged: controller.setTargetEcA,
              primeActive: controller.deviceState.primeAOn,
              targetActive: controller.deviceState.targetDoseAOn,
              shotActive: controller.deviceState.shotDoseAOn,
              primePending: controller.isCommandPending(CommandType.primeA),
              targetPending:
                  controller.isCommandPending(CommandType.targetDoseA),
              shotPending: controller.isCommandPending(CommandType.shotDoseA),
              onPrime: controller.togglePrimeA,
              onTargetDose: controller.toggleTargetDoseA,
              onShotDose: controller.startShotDoseA,
            ),
            _DosingHeadSection(
              title: 'Head B',
              icon: Icons.looks_two_rounded,
              accentColor: GFTheme.warning,
              targetEc: controller.targetEcB,
              onTargetEcChanged: controller.setTargetEcB,
              primeActive: controller.deviceState.primeBOn,
              targetActive: controller.deviceState.targetDoseBOn,
              shotActive: controller.deviceState.shotDoseBOn,
              primePending: controller.isCommandPending(CommandType.primeB),
              targetPending:
                  controller.isCommandPending(CommandType.targetDoseB),
              shotPending: controller.isCommandPending(CommandType.shotDoseB),
              onPrime: controller.togglePrimeB,
              onTargetDose: controller.toggleTargetDoseB,
              onShotDose: controller.startShotDoseB,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ControlPanel(
          icon: Icons.join_inner_rounded,
          title: 'Combined Target Dose',
          subtitle: 'Run A and B together against one EC target.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TargetEcField(
                initialValue: controller.targetEcAb,
                onChanged: controller.setTargetEcAb,
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: controller.deviceState.targetDoseAbOn == true
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
                label: controller.deviceState.targetDoseAbOn == true
                    ? 'Stop Target Dose A + B'
                    : 'Start Target Dose A + B',
                onPressed: controller.isCommandPending(CommandType.targetDoseAb)
                    ? null
                    : controller.toggleTargetDoseAb,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DosingHeadSection extends StatelessWidget {
  const _DosingHeadSection({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.targetEc,
    required this.onTargetEcChanged,
    required this.primeActive,
    required this.targetActive,
    required this.shotActive,
    required this.primePending,
    required this.targetPending,
    required this.shotPending,
    required this.onPrime,
    required this.onTargetDose,
    required this.onShotDose,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final double targetEc;
  final ValueChanged<String> onTargetEcChanged;
  final bool? primeActive;
  final bool? targetActive;
  final bool? shotActive;
  final bool primePending;
  final bool targetPending;
  final bool shotPending;
  final VoidCallback onPrime;
  final VoidCallback onTargetDose;
  final VoidCallback onShotDose;

  @override
  Widget build(BuildContext context) {
    return _ControlPanel(
      icon: icon,
      title: title,
      subtitle: 'Line prime, target dose, and shot dose.',
      accentColor: accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ActionButton(
            icon: primeActive == true ? Icons.stop_rounded : Icons.bolt_rounded,
            label: primeActive == true ? 'Stop Prime Line' : 'Prime Line',
            onPressed: primePending ? null : onPrime,
          ),
          const SizedBox(height: 12),
          _TargetEcField(
            initialValue: targetEc,
            onChanged: onTargetEcChanged,
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: targetActive == true
                ? Icons.stop_rounded
                : Icons.track_changes_rounded,
            label: targetActive == true ? 'Stop Target Dose' : 'Target Dose',
            onPressed: targetPending ? null : onTargetDose,
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.flash_on_rounded,
            label: shotActive == true ? 'Shot Dose Running' : 'Shot Dose',
            onPressed: shotPending || shotActive == true ? null : onShotDose,
          ),
        ],
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = accentColor ?? colorScheme.primary;

    return AnimatedContainer(
      duration: ConnectedDeviceView._motionDuration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        boxShadow: const [kCardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: HomeFiTextTheme.kSub2HeadTextStyle.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ResponsiveControls extends StatelessWidget {
  const _ResponsiveControls({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns =
            children.length > 1 && constraints.maxWidth >= 560;
        final spacing = useTwoColumns ? 14.0 : 12.0;
        final itemWidth = useTwoColumns
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class _TargetEcField extends StatelessWidget {
  const _TargetEcField({
    required this.initialValue,
    required this.onChanged,
  });

  final double initialValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue.toStringAsFixed(1),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: const InputDecoration(
        labelText: 'Target EC (mS/cm)',
        hintText: '1.0',
        prefixIcon: Icon(Icons.speed_rounded),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = value ? GFTheme.success : colorScheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: ConnectedDeviceView._motionDuration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value
              ? GFTheme.success.withValues(alpha: 0.24)
              : colorScheme.outline,
        ),
        boxShadow: const [kCardShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: activeColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: HomeFiTextTheme.kSub2HeadTextStyle.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value ? 'On' : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          disabledBackgroundColor: Theme.of(context).colorScheme.outlineVariant,
          disabledForegroundColor:
              Theme.of(context).colorScheme.onSurfaceVariant,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: HomeFiTextTheme.kBodyTextStyle.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
