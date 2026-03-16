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
  late final TextEditingController deviceIpController;
  late final TextEditingController mqttBrokerController;
  late final TextEditingController topicPrefixController;
  late final TextEditingController refreshIntervalController;

  @override
  void initState() {
    super.initState();
    controller = Get.find<HomeController>();
    deviceIpController = TextEditingController();
    mqttBrokerController = TextEditingController();
    topicPrefixController = TextEditingController();
    refreshIntervalController = TextEditingController();
    _syncFromSettings(controller.settings);
  }

  @override
  void dispose() {
    deviceIpController.dispose();
    mqttBrokerController.dispose();
    topicPrefixController.dispose();
    refreshIntervalController.dispose();
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
              'Configure controller address, topic prefix, and refresh timing for the MVP.',
              style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _SettingsCard(
              child: Column(
                children: [
                  TextField(
                    controller: deviceIpController,
                    decoration: const InputDecoration(
                      labelText: 'Device IP',
                      hintText: '192.168.4.1',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: mqttBrokerController,
                    decoration: const InputDecoration(
                      labelText: 'MQTT Broker IP',
                      hintText: 'Optional for later',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: topicPrefixController,
                    decoration: const InputDecoration(
                      labelText: 'Topic Prefix',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: refreshIntervalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Refresh Interval (seconds)',
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
                    'WiFi Setup',
                    style: HomeFiTextTheme.kSub2HeadTextStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Send WiFi credentials to the ESP32 when it is running in AP mode.',
                    style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Get.toNamed(Routes.WIFI_SETUP),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('Open WiFi Setup'),
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
    final refreshInterval = int.tryParse(refreshIntervalController.text.trim());
    final settings = controller.settings.copyWith(
      deviceIp: deviceIpController.text.trim().isEmpty
          ? controller.settings.deviceIp
          : deviceIpController.text.trim(),
      mqttBrokerIp: mqttBrokerController.text.trim(),
      topicPrefix: topicPrefixController.text.trim().isEmpty
          ? controller.settings.topicPrefix
          : topicPrefixController.text.trim(),
      refreshInterval: refreshInterval != null && refreshInterval > 0
          ? refreshInterval
          : controller.settings.refreshInterval,
    );

    controller.updateSettings(settings);
    FocusScope.of(context).unfocus();
    Get.snackbar('Settings saved', 'HydroPilot configuration updated.');
  }

  void _syncFromSettings(AppSettings settings) {
    deviceIpController.text = settings.deviceIp;
    mqttBrokerController.text = settings.mqttBrokerIp;
    topicPrefixController.text = settings.topicPrefix;
    refreshIntervalController.text = settings.refreshInterval.toString();
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
