package com.x3kk.bolt

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

/**
 * About once a day, when there is a network, asks GitHub for Bolt's latest
 * release and posts one notification per new version: "Bolt 1.29.0 is out".
 * Tapping it opens Bolt on the update sheet. It runs with Bolt closed and
 * uses Android's own JobScheduler, so no extra library and no server.
 *
 * Bolt hands over the texts in the app language each time it opens
 * ([watch]); until then they are English.
 */
class UpdateCheckJob : JobService() {

    private var worker: Thread? = null

    override fun onStartJob(params: JobParameters): Boolean {
        worker = Thread {
            try {
                check(this)
            } catch (e: Exception) {
                // No network, GitHub busy or an odd answer: try again tomorrow.
            }
            jobFinished(params, false)
        }.apply { start() }
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean {
        worker?.interrupt()
        return true
    }

    companion object {
        private const val JOB_ID = 7301
        private const val CHANNEL = "bolt_updates"
        private const val PREFS = "bolt_updates"
        private const val API = "https://api.github.com/repos/rokhanna92/Bolt/releases/latest"
        private val TAG = Regex("""^v?(\d+(?:\.\d+)*)(?:\+(\d+))?$""", RegexOption.IGNORE_CASE)

        /**
         * Saves the notification texts ("title" with {version}, "body",
         * "channel") and schedules the daily check, once.
         */
        fun watch(context: Context, texts: Map<String, Any?>) {
            val edit = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            for (k in listOf("title", "body", "channel")) (texts[k] as? String)?.let { edit.putString(k, it) }
            edit.apply()
            val jobs = context.getSystemService(JobScheduler::class.java) ?: return
            if (jobs.getPendingJob(JOB_ID) != null) return
            jobs.schedule(
                JobInfo.Builder(JOB_ID, ComponentName(context, UpdateCheckJob::class.java))
                    .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                    .setPeriodic(TimeUnit.HOURS.toMillis(24))
                    .setPersisted(true)
                    .build(),
            )
        }

        private fun check(context: Context) {
            val conn = (URL(API).openConnection() as HttpURLConnection).apply {
                connectTimeout = 20_000
                readTimeout = 20_000
                setRequestProperty("Accept", "application/vnd.github+json")
            }
            val body = try {
                if (conn.responseCode != 200) return
                conn.inputStream.bufferedReader().use { it.readText() }
            } finally {
                conn.disconnect()
            }
            val json = JSONObject(body)
            val tag = json.optString("tag_name").trim()
            val m = TAG.find(tag) ?: return
            val version = m.groupValues[1]
            val build = m.groupValues[2].toIntOrNull() ?: return
            // Only once the app file is attached, so the tap can install it.
            val assets = json.optJSONArray("assets") ?: return
            val hasApk = (0 until assets.length()).any {
                assets.optJSONObject(it)?.optString("name")?.lowercase()?.endsWith(".apk") == true
            }
            if (!hasApk) return
            val mine = installedBuild(context) ?: return
            if (build <= mine) return
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (prefs.getString("told", null) == tag) return
            notify(context, version)
            prefs.edit().putString("told", tag).apply()
        }

        /** Split-per-ABI builds install as abi * 1000 + build; tags carry the plain build. */
        private fun installedBuild(context: Context): Int? = try {
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode.toInt() else @Suppress("DEPRECATION") info.versionCode
            code % 1000
        } catch (e: Exception) {
            null
        }

        private fun notify(context: Context, version: String) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val nm = context.getSystemService(NotificationManager::class.java) ?: return
            if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL,
                        prefs.getString("channel", null) ?: "App updates",
                        NotificationManager.IMPORTANCE_DEFAULT,
                    ),
                )
            }
            val open = PendingIntent.getActivity(
                context,
                JOB_ID,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("shortcut", "update")
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val title = (prefs.getString("title", null) ?: "Bolt {version} is out").replace("{version}", version)
            val body = prefs.getString("body", null) ?: "Tap to update. Your data stays on this phone."
            val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else @Suppress("DEPRECATION") Notification.Builder(context)
            b.setSmallIcon(R.drawable.ic_stat_bolt)
                .setContentTitle(title)
                .setContentText(body)
                .setContentIntent(open)
                .setAutoCancel(true)
            nm.notify(JOB_ID, b.build())
        }
    }
}
