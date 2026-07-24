import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_fi/app/models/app_settings.dart';
import 'package:home_fi/app/models/runtime_status.dart';
import 'package:home_fi/app/modules/home/controllers/home_controller.dart';
import 'package:home_fi/app/routes/app_pages.dart';
import 'package:home_fi/app/theme/color_theme.dart';
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
            _ConnectionStatusCard(
              settings: controller.settings,
              runtimeStatus: controller.runtimeStatus,
              statusMessage: controller.statusMessage,
            ),
            const SizedBox(height: 18),
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

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({
    required this.settings,
    required this.runtimeStatus,
    required this.statusMessage,
  });

  final AppSettings settings;
  final RuntimeStatus runtimeStatus;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    final isLocal = settings.transportMode == TransportMode.localNetwork;
    final endpointUrl =
        isLocal ? settings.localDeviceBaseUrl : settings.backendBaseUrl;
    final backendLabel = runtimeStatus.isBackendReachable
        ? (isLocal ? 'ESP32 Reachable' : 'Backend Reachable')
        : (isLocal ? 'ESP32 Unreachable' : 'Backend Unreachable');
    final deviceLabel = runtimeStatus.isDeviceOnline == true
        ? 'Device Online'
        : runtimeStatus.isDeviceOnline == false
            ? 'Device Offline'
            : 'Device Unknown';
    final streamLabel = isLocal
        ? 'Local Polling'
        : runtimeStatus.isStreamConnected
            ? 'Live Stream Connected'
            : 'Live Stream Reconnecting';

    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connection Status',
            style: HomeFiTextTheme.kSub2HeadTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Live runtime connectivity for the active controller path.',
            style: HomeFiTextTheme.kBodyTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
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
                color: isLocal || runtimeStatus.isStreamConnected
                    ? GFTheme.success
                    : GFTheme.warning,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            endpointUrl.isEmpty
                ? (isLocal
                    ? 'Local ESP32 URL not configured.'
                    : 'Backend URL not configured.')
                : endpointUrl,
            style: HomeFiTextTheme.kBodyTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (statusMessage != null) ...[
            const SizedBox(height: 10),
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
      duration: const Duration(milliseconds: 220),
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
