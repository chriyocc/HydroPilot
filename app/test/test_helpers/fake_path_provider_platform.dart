import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    final directory = await Directory.systemTemp.createTemp('hydropilot_test');
    return directory.path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return getApplicationDocumentsPath();
  }

  @override
  Future<String?> getTemporaryPath() async {
    return getApplicationDocumentsPath();
  }
}
