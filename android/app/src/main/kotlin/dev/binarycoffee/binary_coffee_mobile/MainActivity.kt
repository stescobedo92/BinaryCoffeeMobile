package dev.binarycoffee.binary_coffee_mobile

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "binarycoffee/app_icon")
            .setMethodCallHandler { call, result ->
                if (call.method != "setDarkIcon") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val dark = call.argument<Boolean>("dark") ?: true
                setLauncherIcon(dark)
                result.success(null)
            }
    }

    private fun setLauncherIcon(dark: Boolean) {
        val packageManager = packageManager
        val light = ComponentName(this, "$packageName.MainActivityLightIcon")
        val darkIcon = ComponentName(this, "$packageName.MainActivityDarkIcon")

        packageManager.setComponentEnabledSetting(
            if (dark) darkIcon else light,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        packageManager.setComponentEnabledSetting(
            if (dark) light else darkIcon,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }
}
