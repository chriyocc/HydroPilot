import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_fi/app/modules/home/controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        body: SafeArea(child: controller.navBarSwitcher()),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: controller.currentIndex,
          onTap: controller.setCurrentIndex,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune_rounded),
              label: 'Control',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
