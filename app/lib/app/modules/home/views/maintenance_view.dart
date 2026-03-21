import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_fi/app/modules/home/controllers/home_controller.dart';
import 'package:home_fi/app/routes/app_pages.dart';
import 'package:home_fi/app/theme/text_theme.dart';

class MaintenanceView extends GetView<HomeController> {
  const MaintenanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup / Maintenance')),
      body: GetBuilder<HomeController>(
        id: 'maintenance',
        builder: (_) {
          final modeLabel = switch (controller.maintenanceConnectionType) {
            MaintenanceConnectionType.ap => 'AP mode',
            MaintenanceConnectionType.lan => 'LAN mode',
            null => 'Not connected',
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              Text(
                'Local maintenance only',
                style: HomeFiTextTheme.kHeadTextStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use this screen for onboarding, recovery, health inspection, and direct diagnostics. Normal monitoring and control should stay on backend runtime mode.',
                style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _MaintenanceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entry paths',
                      style: HomeFiTextTheme.kSub2HeadTextStyle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AP mode uses 192.168.4.1. LAN mode uses the saved local device IP from Settings.',
                      style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => controller.enterMaintenanceMode(
                              MaintenanceConnectionType.ap,
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('Enter AP Mode'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => controller.enterMaintenanceMode(
                              MaintenanceConnectionType.lan,
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('Enter LAN Mode'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Current path: $modeLabel',
                      style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (controller.lastMaintenanceMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        controller.lastMaintenanceMessage!,
                        style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _MaintenanceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maintenance status',
                      style: HomeFiTextTheme.kSub2HeadTextStyle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Reachable',
                      value: controller.maintenanceHealth?.isReachable == true
                          ? 'Yes'
                          : 'No',
                    ),
                    _DetailRow(
                      label: 'Declared mode',
                      value: controller.maintenanceHealth?.mode ?? '--',
                    ),
                    _DetailRow(
                      label: 'Base URL',
                      value: controller.maintenanceHealth?.baseUrl ?? '--',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton(
                          onPressed: controller.isInMaintenanceMode
                              ? controller.refreshMaintenanceStatus
                              : null,
                          child: const Text('Refresh Local Status'),
                        ),
                        OutlinedButton(
                          onPressed: () => Get.toNamed(Routes.WIFI_SETUP),
                          child: const Text('Open WiFi Setup'),
                        ),
                        TextButton(
                          onPressed: controller.isInMaintenanceMode
                              ? controller.exitMaintenanceMode
                              : null,
                          child: const Text('Exit Maintenance'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (controller.maintenanceConfig != null) ...[
                const SizedBox(height: 18),
                _MaintenanceMapCard(
                  title: 'Local config',
                  data: controller.maintenanceConfig!,
                ),
              ],
              if (controller.maintenanceDebugStatus != null) ...[
                const SizedBox(height: 18),
                _MaintenanceMapCard(
                  title: 'Debug inspection',
                  data: controller.maintenanceDebugStatus!,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [kCardShadow],
      ),
      child: child,
    );
  }
}

class _MaintenanceMapCard extends StatelessWidget {
  const _MaintenanceMapCard({
    required this.title,
    required this.data,
  });

  final String title;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return _MaintenanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: HomeFiTextTheme.kSub2HeadTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          for (final entry in data.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DetailRow(
                label: entry.key,
                value: entry.value?.toString() ?? 'null',
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
