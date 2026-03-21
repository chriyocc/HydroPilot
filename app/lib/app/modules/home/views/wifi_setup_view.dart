import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_fi/app/modules/home/controllers/home_controller.dart';
import 'package:home_fi/app/theme/text_theme.dart';

class WifiSetupView extends StatefulWidget {
  const WifiSetupView({super.key});

  @override
  State<WifiSetupView> createState() => _WifiSetupViewState();
}

class _WifiSetupViewState extends State<WifiSetupView> {
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  HomeController get controller => Get.find<HomeController>();

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Setup')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Connect the controller to Wi-Fi',
            style: HomeFiTextTheme.kHeadTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join the controller access point first. This recovery flow sends your network credentials to `192.168.4.1`.',
            style: HomeFiTextTheme.kBodyTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [kCardShadow],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _ssidController,
                    decoration: const InputDecoration(labelText: 'SSID'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'SSID is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(_isSubmitting ? 'Connecting...' : 'Connect'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await controller.configureWifi(
        ssid: _ssidController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        Get.snackbar(
          'Setup request sent',
          'Credentials posted to 192.168.4.1.',
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        Get.snackbar(
          'Setup failed',
          'Unable to send Wi-Fi credentials to the controller.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
