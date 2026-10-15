package com.x3kk.bolt

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Answers the "bolt/updates" channel: whether Bolt may install packages, the
 * settings screen to allow it, and handing a downloaded APK to the installer.
 * Android never installs silently; the installer always asks the user.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bolt/updates")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstall" -> result.success(canInstall())
                    "openInstallSettings" -> result.success(openInstallSettings())
                    "install" -> {
                        val path = call.argument<String>("path")
                        if (path == null) result.error("no_path", "install needs a path", null)
                        else result.success(install(path))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Below Android 8 the permission is granted at install time. */
    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    /** Opens "Install unknown apps" for Bolt. The user decides after this returns. */
    private fun openInstallSettings(): Boolean = try {
        startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
        true
    } catch (e: Exception) {
        false
    }

    /** True when the installer opened, not that anything was installed yet. */
    private fun install(path: String): Boolean = try {
        val file = File(path)
        if (!file.exists()) {
            false
        } else {
            val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
            startActivity(
                Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
            true
        }
    } catch (e: Exception) {
        false
    }
}
