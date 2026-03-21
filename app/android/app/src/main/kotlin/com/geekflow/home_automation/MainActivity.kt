package com.geekflow.home_fi

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private lateinit var deviceProvisioningChannel: DeviceProvisioningChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        deviceProvisioningChannel = DeviceProvisioningChannel(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "hydropilot/provisioning",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAutoProvisioningSupported" ->
                    deviceProvisioningChannel.isAutoProvisioningSupported(result)
                "connectToDeviceAp" -> deviceProvisioningChannel.connect(call, result)
                "disconnectFromDeviceAp" -> deviceProvisioningChannel.disconnect(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (deviceProvisioningChannel.onRequestPermissionsResult(requestCode, grantResults)) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
