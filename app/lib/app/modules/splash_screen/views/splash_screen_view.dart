import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_fi/app/modules/home/bindings/home_binding.dart';
import 'package:home_fi/app/modules/home/views/home_view.dart';
import 'package:home_fi/app/theme/text_theme.dart';

class SplashScreenView extends StatefulWidget {
  const SplashScreenView({super.key});

  @override
  State<SplashScreenView> createState() => _SplashScreenViewState();
}

class _SplashScreenViewState extends State<SplashScreenView> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _navigationTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) {
        return;
      }
      Get.offAll(
        () => const HomeView(),
        binding: HomeBinding(),
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Container(
          width: Get.width * 0.72,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            boxShadow: [kCardShadow],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.water_drop_rounded,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'HydroPilot',
                style: HomeFiTextTheme.kHeadTextStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hydroponic monitoring and control',
                textAlign: TextAlign.center,
                style: HomeFiTextTheme.kBodyTextStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
