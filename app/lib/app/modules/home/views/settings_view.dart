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
  late final TextEditingController localDeviceBaseUrlController;
  late TransportMode selectedTransportMode;

  @override
  void initState() {
    super.initState();
    controller = Get.find<HomeController>();
    backendBaseUrlController = TextEditingController();
    localDeviceBaseUrlController = TextEditingController();
    selectedTransportMode = controller.settings.transportMode;
    _syncFromSettings(controller.settings);
  }

  @override
  void dispose() {
    backendBaseUrlController.dispose();
    localDeviceBaseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      id: 'settings',
      builder: (_) {
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
              'Choose local ESP32 testing or the real backend runtime path.',
              style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _SettingsCard(
              child: Column(
                children: [
                  SegmentedButton<TransportMode>(
                    segments: const [
                      ButtonSegment(
                        value: TransportMode.localNetwork,
                        label: Text('Local Network'),
                      ),
                      ButtonSegment(
                        value: TransportMode.realServer,
                        label: Text('Real Server'),
                      ),
                    ],
                    selected: {selectedTransportMode},
                    onSelectionChanged: (selection) {
                      setState(() {
                        selectedTransportMode = selection.single;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  if (selectedTransportMode == TransportMode.localNetwork)
                    TextField(
                      controller: localDeviceBaseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Local ESP32 URL',
                        hintText: 'http://192.168.1.50',
                      ),
                    )
                  else
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
                    'Device Setup',
                    style: HomeFiTextTheme.kSub2HeadTextStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use this for onboarding or recovery when the controller is broadcasting its setup access point.',
                    style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connect your phone to the device AP, then send Wi-Fi credentials to `192.168.4.1` to move the controller onto your network.',
                    style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Get.toNamed(Routes.WIFI_SETUP),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Open Device Setup'),
                    ),
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
      transportMode: selectedTransportMode,
      localDeviceBaseUrl: localDeviceBaseUrlController.text.trim(),
      backendBaseUrl: backendBaseUrlController.text.trim(),
    );

    controller.updateSettings(settings);
    FocusScope.of(context).unfocus();
    Get.snackbar('Settings saved', 'HydroPilot configuration updated.');
  }

  void _syncFromSettings(AppSettings settings) {
    selectedTransportMode = settings.transportMode;
    backendBaseUrlController.text = settings.backendBaseUrl;
    localDeviceBaseUrlController.text = settings.localDeviceBaseUrl;
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
