import 'package:get/get.dart';
import 'package:home_fi/app/modules/home/bindings/home_binding.dart';
import 'package:home_fi/app/modules/home/views/home_view.dart';
import 'package:home_fi/app/modules/home/views/maintenance_view.dart';
import 'package:home_fi/app/modules/home/views/wifi_setup_view.dart';
import 'package:home_fi/app/modules/splash_screen/views/splash_screen_view.dart';

part 'app_routes.dart';

class AppPages {
  static const INITIAL = Routes.SPLASH_SCREEN;

  static final routes = [
    GetPage(
      name: _Paths.HOME,
      page: () => HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.SPLASH_SCREEN,
      page: () => SplashScreenView(),
    ),
    GetPage(
      name: _Paths.WIFI_SETUP,
      page: () => WifiSetupView(),
    ),
    GetPage(
      name: _Paths.MAINTENANCE,
      page: () => const MaintenanceView(),
    ),
  ];
}
