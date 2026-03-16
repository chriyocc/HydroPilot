import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:home_fi/app/models/device_state.dart';
import 'package:home_fi/app/models/sensor_data.dart';
import 'package:home_fi/app/modules/home/controllers/home_controller.dart';
import 'package:home_fi/app/modules/home/views/home_view.dart';
import 'package:home_fi/main.dart';
import 'package:home_fi/app/services/hydro_api_service.dart';
import 'package:home_fi/app/theme/app_theme.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'test_helpers/fake_path_provider_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Get.testMode = true;
    PathProviderPlatform.instance = FakePathProviderPlatform();
    await GetStorage.init();
    await GetStorage().erase();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('HydroPilot app shows hydroponic navigation labels',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: appThemeData[AppTheme.hydroLight],
        initialBinding: BindingsBuilder(
          () {
            Get.lazyPut<HomeController>(
              () => HomeController(
                apiService: FakeHydroApiService(),
                enableAutoRefresh: false,
              ),
            );
          },
        ),
        home: const HomeView(),
      ),
    );
    await tester.pump();

    expect(find.text('HydroPilot'), findsWidgets);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Control'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('app leaves splash and opens dashboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('System Dashboard'), findsOneWidget);
  });
}

class FakeHydroApiService extends HydroApiService {
  @override
  Future<HydroStatusSnapshot> fetchStatus(String deviceIp) async {
    return const HydroStatusSnapshot(
      sensorData: SensorData(
        ph: 6.2,
        ec: 1.8,
        waterTemperature: 24.0,
        waterLevel: 82.0,
      ),
      deviceState: DeviceState(
        pumpOn: true,
        lightOn: false,
      ),
    );
  }
}
