import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_fi/app/models/device_state.dart';
import 'package:home_fi/app/models/runtime_status.dart';
import 'package:home_fi/app/models/sensor_data.dart';
import 'package:home_fi/app/modules/home/controllers/home_controller.dart';
import 'package:home_fi/app/routes/app_pages.dart';
import 'package:home_fi/app/theme/color_theme.dart';
import 'package:home_fi/app/theme/text_theme.dart';

class DashboardView extends GetView<HomeController> {
  const DashboardView({super.key});

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
                backendBaseUrl: controller.settings.backendBaseUrl,
                runtimeStatus: controller.runtimeStatus,
              ),
              const SizedBox(height: 24),
              Text(
                'Sensors',
                style: HomeFiTextTheme.kSub2HeadTextStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
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
    required this.backendBaseUrl,
    required this.runtimeStatus,
  });

  final String? statusMessage;
  final String backendBaseUrl;
  final RuntimeStatus runtimeStatus;

  @override
  Widget build(BuildContext context) {
    final backendLabel = runtimeStatus.isBackendReachable
        ? 'Backend Reachable'
        : 'Backend Unreachable';
    final deviceLabel = runtimeStatus.isDeviceOnline == true
        ? 'Device Online'
        : runtimeStatus.isDeviceOnline == false
            ? 'Device Offline'
            : 'Device Unknown';
    final streamLabel = runtimeStatus.isStreamConnected
        ? 'Live Stream Connected'
        : 'Live Stream Reconnecting';

    return Container(
      padding: const EdgeInsets.all(22),
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
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusChip(
                label: backendLabel,
                color: runtimeStatus.isBackendReachable
                    ? GFTheme.success
                    : GFTheme.warning,
              ),
              _StatusChip(
                label: deviceLabel,
                color: runtimeStatus.isDeviceOnline == true
                    ? GFTheme.success
                    : Theme.of(context).colorScheme.primary,
              ),
              _StatusChip(
                label: streamLabel,
                color: runtimeStatus.isStreamConnected
                    ? GFTheme.success
                    : GFTheme.warning,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            backendBaseUrl.isEmpty
                ? 'Backend URL not configured.'
                : backendBaseUrl,
            style: HomeFiTextTheme.kBodyTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (statusMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              statusMessage!,
              style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Get.toNamed(Routes.MAINTENANCE),
            icon: const Icon(Icons.build_circle_outlined),
            label: const Text('Setup / Maintenance'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
          ),
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
      _MetricCardData(
        label: 'pH',
        icon: Icons.science_outlined,
        value: _formatValue(sensorData.ph, suffix: ''),
      ),
      _MetricCardData(
        label: 'EC',
        icon: Icons.bolt_outlined,
        value: _formatValue(sensorData.ec, suffix: ' mS/cm'),
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
    ];

    return GridView.builder(
      itemCount: cards.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final card = cards[index];
        return _MetricCard(card: card, isLoading: isLoading);
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [kCardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          Text(
            card.label,
            style: HomeFiTextTheme.kBodyTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : Text(
                  card.value,
                  style: HomeFiTextTheme.kSubHeadTextStyle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.deviceState});

  final DeviceState deviceState;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        ],
      ),
    );
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({
    required this.label,
    required this.value,
  });

  final String label;
  final bool? value;

  @override
  Widget build(BuildContext context) {
    final isOn = value == true;
    final text = value == null ? 'Unknown' : (isOn ? 'ON' : 'OFF');

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
    return Container(
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
