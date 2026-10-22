package com.x3kk.bolt

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.KeyEvent
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Answers the "bolt/updates" channel: whether Bolt may install packages, the
 * settings screen to allow it, and handing a downloaded APK to the installer.
 * Android never installs silently; the installer always asks the user.
 *
 * Also "bolt/shortcuts": the app icon's long-press shortcuts arrive as a
 * "shortcut" extra, at launch ("initial") or while running ("open").
 *
 * "bolt/widget" saves what the home screen widget shows.
 *
 * "bolt/haptics" plays a named feel (see BoltHaptics).
 *
 * "bolt/rest" starts and stops the rest countdown service (RestTimerService)
 * and previews its sounds; the service reports +15, Skip and the end back.
 *
 * "bolt/screen" keeps the screen on while a workout is open ("keepOn") and,
 * when asked ("volumeKey"), turns volume down into "volumeDown" calls.
 *
 * And "bolt/backup": Android's own pickers to save a backup file anywhere
 * ("save") and to pick one to restore ("open"). Null means cancelled.
 */
class MainActivity : FlutterActivity() {

    private var shortcuts: MethodChannel? = null
    private var pending: MethodChannel.Result? = null
    private var pendingText: String? = null
    private var screen: MethodChannel? = null
    private var volumeKey = false

    /** Volume down goes to the workout page before Flutter or the volume sees it. */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (volumeKey && event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) screen?.invokeMethod("volumeDown", null)
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shortcuts = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bolt/shortcuts").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "initial" -> result.success(takeShortcut(intent))
                    "background" -> result.success(moveTaskToBack(true))
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bolt/haptics").setMethodCallHandler { call, result ->
            if (call.method == "play") {
                BoltHaptics.play(this, window?.decorView, call.arguments as String)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        val rest = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bolt/rest")
        rest.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    @Suppress("UNCHECKED_CAST")
                    RestTimerService.start(this, call.arguments as Map<String, Any?>)
                    result.success(true)
                }
                "stop" -> {
                    RestTimerService.stop()
                    result.success(true)
                }
                "preview" -> {
                    BoltTones.play(this, call.arguments as String, true)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        RestTimerService.listener = { what, end -> runOnUiThread { rest.invokeMethod(what, end) } }
        screen = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bolt/screen").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "keepOn" -> {
                        if (call.arguments as Boolean) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    "volumeKey" -> {
                        volumeKey = call.arguments as Boolean
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bolt/widget").setMethodCallHandler { call, result ->
            if (call.method == "update") {
                @Suppress("UNCHECKED_CAST")
                BoltWidget.save(this, call.arguments as Map<String, Any?>)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bolt/backup").setMethodCallHandler { call, result ->
            if (pending != null) {
                result.error("busy", "a picker is already open", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "save" -> {
                    pending = result
                    pendingText = call.argument<String>("text")
                    startActivityForResult(
                        Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/json"
                            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                        },
                        SAVE,
                    )
                }
                "open" -> {
                    pending = result
                    startActivityForResult(
                        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        },
                        OPEN,
                    )
                }
                else -> result.notImplemented()
            }
        }
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

    @Deprecated("Picker results")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE && requestCode != OPEN) return
        val result = pending ?: return
        val text = pendingText
        pending = null
        pendingText = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            if (requestCode == SAVE) {
                contentResolver.openOutputStream(uri, "wt")?.use { it.write((text ?: "").toByteArray()) }
                result.success(true)
            } else {
                result.success(contentResolver.openInputStream(uri)?.use { String(it.readBytes()) })
            }
        } catch (e: Exception) {
            result.error("io", e.message, null)
        }
    }

    override fun onDestroy() {
        RestTimerService.listener = null
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        takeShortcut(intent)?.let { shortcuts?.invokeMethod("open", it) }
    }

    /** The shortcut an intent carries, read once so it never fires twice. */
    private fun takeShortcut(intent: Intent?): String? {
        val s = intent?.getStringExtra("shortcut") ?: return null
        intent.removeExtra("shortcut")
        return s
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

    companion object {
        private const val SAVE = 41
        private const val OPEN = 42
    }
}
