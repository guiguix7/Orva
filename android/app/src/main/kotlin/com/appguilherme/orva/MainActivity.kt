package com.appguilherme.orva

import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.appguilherme.orva/device_info",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "androidSdkVersion" -> result.success(Build.VERSION.SDK_INT)
                else -> result.notImplemented()
            }
        }
    }
}
