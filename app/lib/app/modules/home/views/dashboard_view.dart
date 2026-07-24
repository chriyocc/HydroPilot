import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_fi/app/models/device_state.dart';
import 'package:home_fi/app/models/sensor_data.dart';
import 'package:home_fi/app/modules/home/controllers/home_controller.dart';
import 'package:home_fi/app/theme/color_theme.dart';
import 'package:home_fi/app/theme/text_theme.dart';

class DashboardView extends GetView<HomeController> {
  const DashboardView({super.key});

  static const _motionDuration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      id: 'dashboard',
      builder: (_) {
        return RefreshIndicator(
          onRefresh: () => controller.refreshStatus(showLoading: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              _DashboardHeader(
                statusMessage: controller.statusMessage,
              ),
              const SizedBox(height: 24),
              Text(
                'Sensors',
                style: HomeFiTextTheme.kSub2HeadTextStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              _EcHistoryCard(
                values: controller.ecHistory.ecValues,
                periodMs: controller.ecHistory.periodMs,
                windowMs: controller.ecHistory.windowMs,
              ),
              const SizedBox(height: 14),
              _SensorGrid(
                sensorData: controller.sensorData,
                isLoading: controller.isLoadingStatus,
              ),
              const SizedBox(height: 24),
              Text(
                'Device States',
                style: HomeFiTextTheme.kSub2HeadTextStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              _StatusCard(deviceState: controller.deviceState),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.statusMessage,
  });

  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: DashboardView._motionDuration,
      padding: const EdgeInsets.all(22),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [kCardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HydroPilot',
            style: HomeFiTextTheme.kBodyTextStyle.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'System Dashboard',
            style: HomeFiTextTheme.kSubHeadTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Monitor pH, nutrients, temperature, and core hardware states from one screen.',
            style: HomeFiTextTheme.kBodyTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (statusMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              statusMessage!,
              style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SensorGrid extends StatelessWidget {
  const _SensorGrid({
    required this.sensorData,
    required this.isLoading,
  });

  final SensorData sensorData;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cards = [
      if (sensorData.ph != null)
        _MetricCardData(
          label: 'pH',
          icon: Icons.science_outlined,
          value: _formatValue(sensorData.ph, suffix: ''),
        ),
      _MetricCardData(
        label: 'EC',
        icon: Icons.bolt_outlined,
        value: sensorData.ec != null && sensorData.ec! > 20
            ? _formatValue(sensorData.ec, suffix: ' uS/cm')
            : _formatValue(sensorData.ec, suffix: ' mS/cm'),
      ),
      _MetricCardData(
        label: 'Water Temperature',
        icon: Icons.thermostat_rounded,
        value: _formatValue(sensorData.waterTemperature, suffix: '°C'),
      ),
      _MetricCardData(
        label: 'Water Level',
        icon: Icons.water_drop_outlined,
        value: _formatValue(sensorData.waterLevel, suffix: '%'),
      ),
      if (sensorData.humidity != null)
        _MetricCardData(
          label: 'Humidity',
          icon: Icons.water_outlined,
          value: _formatValue(sensorData.humidity, suffix: '%'),
        ),
      if (sensorData.tds != null)
        _MetricCardData(
          label: 'TDS',
          icon: Icons.grain_outlined,
          value: _formatValue(sensorData.tds, suffix: ' ppm'),
        ),
      if (sensorData.distance != null)
        _MetricCardData(
          label: 'Distance',
          icon: Icons.straighten,
          value: _formatValue(sensorData.distance, suffix: ' mm'),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 290;
        final cardWidth = useTwoColumns
            ? (constraints.maxWidth - 14) / 2
            : constraints.maxWidth;
        final childAspectRatio = useTwoColumns
            ? (cardWidth / 174).clamp(0.76, 0.96).toDouble()
            : (cardWidth / 164).clamp(1.15, 1.65).toDouble();

        return AnimatedSwitcher(
          duration: DashboardView._motionDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: GridView.builder(
            key: ValueKey('${constraints.maxWidth.round()}-$isLoading'),
            itemCount: cards.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: useTwoColumns ? 2 : 1,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: childAspectRatio,
            ),
            itemBuilder: (context, index) {
              final card = cards[index];
              return _MetricCard(card: card, isLoading: isLoading);
            },
          ),
        );
      },
    );
  }

  String _formatValue(double? value, {required String suffix}) {
    if (value == null) {
      return '--';
    }

    final displayValue =
        value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '$displayValue$suffix';
  }
}

class _EcHistoryCard extends StatelessWidget {
  const _EcHistoryCard({
    required this.values,
    required this.periodMs,
    required this.windowMs,
  });

  final List<double> values;
  final int periodMs;
  final int windowMs;

  @override
  Widget build(BuildContext context) {
    final latest = values.isEmpty ? null : values.last;
    final windowMinutes = windowMs <= 0 ? 0 : (windowMs / 60000).round();

    return AnimatedContainer(
      duration: DashboardView._motionDuration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [kCardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EC History',
            style: HomeFiTextTheme.kSub2HeadTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            latest == null
                ? 'Waiting for EC samples.'
                : '${latest.toStringAsFixed(0)} uS/cm across ${values.length} samples',
            style: HomeFiTextTheme.kBodyTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (windowMinutes > 0 && periodMs > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Last $windowMinutes min, every ${periodMs ~/ 1000}s',
              style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 72,
            child: CustomPaint(
              painter: _EcSparklinePainter(
                values: values,
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EcSparklinePainter extends CustomPainter {
  const _EcSparklinePainter({
    required this.values,
    required this.color,
  });

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.length < 2) {
      return;
    }

    final maxValue = values.fold<double>(values.first, math.max);
    final minValue = values.fold<double>(values.first, math.min);
    final range = (maxValue - minValue).abs() < 1 ? 1.0 : maxValue - minValue;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - ((values[i] - minValue) / range * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _EcSparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.label,
    required this.icon,
    required this.value,
  });

  final String label;
  final IconData icon;
  final String value;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.card,
    required this.isLoading,
  });

  final _MetricCardData card;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: DashboardView._motionDuration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [kCardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              card.icon,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.15,
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: DashboardView._motionDuration,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final offsetAnimation = Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: isLoading
                      ? SizedBox(
                          key: ValueKey('${card.label}-loading'),
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : _MetricValue(
                          key: ValueKey('${card.label}-${card.value}'),
                          value: card.value,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricValue extends StatelessWidget {
  const _MetricValue({
    super.key,
    required this.value,
  });

  final String value;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: value,
      child: SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: HomeFiTextTheme.kSubHeadTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.deviceState});

  final DeviceState deviceState;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: DashboardView._motionDuration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [kCardShadow],
      ),
      child: Column(
        children: [
          _StateRow(
            label: 'Pump Status',
            value: deviceState.pumpOn,
          ),
          const Divider(height: 24),
          _StateRow(
            label: 'Grow Light Status',
            value: deviceState.lightOn,
          ),
          if (deviceState.liquidAWet != null ||
              deviceState.liquidBWet != null) ...[
            const Divider(height: 24),
            _StateRow(
              label: 'Liquid A',
              value: deviceState.liquidAWet,
              trueLabel: 'WET',
              falseLabel: 'DRY',
            ),
            const Divider(height: 24),
            _StateRow(
              label: 'Liquid B',
              value: deviceState.liquidBWet,
              trueLabel: 'WET',
              falseLabel: 'DRY',
            ),
          ],
        ],
      ),
    );
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({
    required this.label,
    required this.value,
    this.trueLabel = 'ON',
    this.falseLabel = 'OFF',
  });

  final String label;
  final bool? value;
  final String trueLabel;
  final String falseLabel;

  @override
  Widget build(BuildContext context) {
    final isOn = value == true;
    final text = value == null ? 'Unknown' : (isOn ? trueLabel : falseLabel);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: HomeFiTextTheme.kBodyTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _StatusChip(
          label: text,
          color: value == null
              ? Theme.of(context).colorScheme.primary
              : (isOn ? GFTheme.success : GFTheme.warning),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: DashboardView._motionDuration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: HomeFiTextTheme.kBodyTextStyle.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
