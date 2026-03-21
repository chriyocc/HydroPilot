package com.geekflow.home_fi

import android.Manifest
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DeviceProvisioningChannel(
    private val activity: FlutterActivity,
) {
    private val connectivityManager: ConnectivityManager =
        activity.getSystemService(ConnectivityManager::class.java)
    private val handler = Handler(Looper.getMainLooper())

    private var activeNetworkCallback: ConnectivityManager.NetworkCallback? = null
    private var timeoutRunnable: Runnable? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingPermissionRequest: PendingPermissionRequest? = null

    fun isAutoProvisioningSupported(result: MethodChannel.Result) {
        result.success(mapOf("supported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)))
    }

    fun connect(call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success(mapOf("code" to "unsupported_android_version"))
            return
        }

        val ssid = call.argument<String>("ssid")
        val password = call.argument<String>("password")
        if (ssid.isNullOrBlank() || password.isNullOrBlank()) {
            result.success(
                mapOf(
                    "code" to "connection_failed",
                    "message" to "SSID and password are required.",
                ),
            )
            return
        }

        val missingPermissions = requiredPermissions().filterNot { permission ->
            ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED
        }
        if (missingPermissions.isNotEmpty()) {
            pendingPermissionRequest = PendingPermissionRequest(ssid, password, result)
            ActivityCompat.requestPermissions(
                activity,
                missingPermissions.toTypedArray(),
                REQUEST_CODE_WIFI_PERMISSIONS,
            )
            return
        }

        connectToAccessPoint(ssid, password, result)
    }

    fun disconnect(result: MethodChannel.Result) {
        clearActiveConnection()
        result.success(emptyMap<String, Any>())
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE_WIFI_PERMISSIONS) {
            return false
        }

        val request = pendingPermissionRequest
        pendingPermissionRequest = null

        if (request == null) {
            return true
        }

        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }

        if (!granted) {
            request.result.success(mapOf("code" to "user_denied"))
            return true
        }

        connectToAccessPoint(request.ssid, request.password, request.result)
        return true
    }

    private fun connectToAccessPoint(
        ssid: String,
        password: String,
        result: MethodChannel.Result,
    ) {
        clearActiveConnection()

        val specifier = WifiNetworkSpecifier.Builder()
            .setSsid(ssid)
            .setWpa2Passphrase(password)
            .build()

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .setNetworkSpecifier(specifier)
            .build()

        pendingResult = result

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                handler.removeCallbacks(timeoutRunnable ?: return)
                timeoutRunnable = null
                activeNetworkCallback = this
                connectivityManager.bindProcessToNetwork(network)
                pendingResult?.success(mapOf("code" to "connected"))
                pendingResult = null
            }

            override fun onUnavailable() {
                finishPendingConnection(mapOf("code" to "user_denied"))
            }

            override fun onLost(network: Network) {
                if (pendingResult != null) {
                    finishPendingConnection(mapOf("code" to "connection_failed"))
                    return
                }
                connectivityManager.bindProcessToNetwork(null)
                if (activeNetworkCallback === this) {
                    safeUnregister(this)
                    activeNetworkCallback = null
                }
            }
        }

        activeNetworkCallback = callback
        timeoutRunnable = Runnable {
            finishPendingConnection(mapOf("code" to "connection_timeout"))
        }.also { handler.postDelayed(it, CONNECTION_TIMEOUT_MS) }

        connectivityManager.requestNetwork(request, callback)
    }

    private fun finishPendingConnection(response: Map<String, String>) {
        handler.removeCallbacks(timeoutRunnable ?: return)
        timeoutRunnable = null
        pendingResult?.success(response)
        pendingResult = null
        clearActiveConnection()
    }

    private fun clearActiveConnection() {
        timeoutRunnable?.let(handler::removeCallbacks)
        timeoutRunnable = null
        connectivityManager.bindProcessToNetwork(null)
        activeNetworkCallback?.let { callback ->
            safeUnregister(callback)
        }
        activeNetworkCallback = null
    }

    private fun safeUnregister(callback: ConnectivityManager.NetworkCallback) {
        runCatching {
            connectivityManager.unregisterNetworkCallback(callback)
        }
    }

    private fun requiredPermissions(): List<String> {
        val permissions = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions += Manifest.permission.NEARBY_WIFI_DEVICES
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            permissions += Manifest.permission.ACCESS_FINE_LOCATION
        }
        return permissions
    }

    private data class PendingPermissionRequest(
        val ssid: String,
        val password: String,
        val result: MethodChannel.Result,
    )

    companion object {
        private const val REQUEST_CODE_WIFI_PERMISSIONS = 4041
        private const val CONNECTION_TIMEOUT_MS = 30_000L
    }
}
