package com.appguilherme.orva

import android.content.Intent
import android.os.Build
import com.appguilherme.orva.widgets.OrvaWidgetStore
import com.appguilherme.orva.widgets.WIDGET_ROUTE_EXTRA
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var widgetChannel: MethodChannel? = null
    private var pendingWidgetRoute: String? = null

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

        pendingWidgetRoute = intent?.getStringExtra(WIDGET_ROUTE_EXTRA)
        intent?.removeExtra(WIDGET_ROUTE_EXTRA)

        widgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.appguilherme.orva/widgets",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveSnapshot" -> {
                        val json = call.argument<String>("json")
                        if (json == null) {
                            result.error(
                                "invalid_snapshot",
                                "Snapshot ausente.",
                                null,
                            )
                        } else {
                            result.success(OrvaWidgetStore.save(this, json))
                        }
                    }
                    "consumeInitialRoute" -> {
                        val route = pendingWidgetRoute
                        pendingWidgetRoute = null
                        result.success(route)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val route = intent.getStringExtra(WIDGET_ROUTE_EXTRA) ?: return
        intent.removeExtra(WIDGET_ROUTE_EXTRA)
        pendingWidgetRoute = route
        widgetChannel?.invokeMethod("openRoute", route)
    }
}
