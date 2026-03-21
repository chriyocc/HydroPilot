import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_fi/app/models/app_settings.dart';
import 'package:home_fi/app/modules/home/controllers/home_controller.dart';
import 'package:home_fi/app/routes/app_pages.dart';
import 'package:home_fi/app/theme/text_theme.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final HomeController controller;
  late final TextEditingController backendBaseUrlController;
  late final TextEditingController maintenanceDeviceIpController;

  @override
  void initState() {
    super.initState();
    controller = Get.find<HomeController>();
    backendBaseUrlController = TextEditingController();
    maintenanceDeviceIpController = TextEditingController();
    _syncFromSettings(controller.settings);
  }

  @override
  void dispose() {
    backendBaseUrlController.dispose();
    maintenanceDeviceIpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      id: 'settings',
      builder: (_) {
        _syncFromSettings(controller.settings);

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Text(
              'Settings',
              style: HomeFiTextTheme.kHeadTextStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure the backend URL for runtime status, commands, and live updates.',
              style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _SettingsCard(
              child: Column(
                children: [
                  TextField(
                    controller: backendBaseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Backend Base URL',
                      hintText: 'http://192.168.1.44:3000',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Save Settings'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Setup / Maintenance',
                    style: HomeFiTextTheme.kSub2HeadTextStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use this only for onboarding, recovery, and direct local diagnostics. Runtime monitoring and control still go through the backend.',
                    style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: maintenanceDeviceIpController,
                    decoration: const InputDecoration(
                      labelText: 'Saved Local Device IP',
                      hintText: '192.168.1.50',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'AP mode always uses 192.168.4.1. LAN maintenance uses the saved local IP only.',
                    style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saveMaintenanceSettings,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('Save Local IP'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Get.toNamed(Routes.MAINTENANCE),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('Open Setup / Maintenance'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _saveSettings() {
    final settings = controller.settings.copyWith(
      backendBaseUrl: backendBaseUrlController.text.trim(),
    );

    controller.updateSettings(settings);
    FocusScope.of(context).unfocus();
    Get.snackbar('Settings saved', 'HydroPilot configuration updated.');
  }

  void _syncFromSettings(AppSettings settings) {
    backendBaseUrlController.text = settings.backendBaseUrl;
    maintenanceDeviceIpController.text = settings.maintenanceDeviceIp;
  }

  void _saveMaintenanceSettings() {
    controller.updateMaintenanceDeviceIp(maintenanceDeviceIpController.text);
    FocusScope.of(context).unfocus();
    Get.snackbar('Maintenance settings saved', 'Local device IP updated.');
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

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
