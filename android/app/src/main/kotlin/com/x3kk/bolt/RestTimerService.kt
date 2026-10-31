package com.x3kk.bolt

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import kotlin.math.max

/**
 * The rest countdown, kept alive while Bolt is in the background or the
 * phone is locked. It runs as a short foreground service so it stays on time
 * with the screen off (a partial wake lock until the end) and shows an
 * ongoing notification: a countdown with a progress bar, −15 / +15 / Skip,
 * visible on the lock screen. On Android 16 it asks to be promoted to a Live
 * Update, the status bar chip and lock screen card that Samsung shows in
 * its Now Bar.
 *
 * Ten seconds before the end of a rest two pulses say "get set", the last 3
 * seconds tick (haptic and, if chosen, a blip in the headphones) and the end
 * plays the end cue with a strong vibration felt in a pocket.
 * The app hears about +15, Skip and the end through [listener].
 *
 * A timed set (a plank) uses the same countdown without the buttons.
 */
class RestTimerService : Service() {

    companion object {
        private const val CHANNEL = "bolt_rest_live"
        private const val NOTIFICATION = 7
        private const val START = "start"
        private const val ADD = "add"
        private const val SKIP = "skip"
        private const val STOP = "stop"

        /** Tells the app: "changed" (new end), "skipped" or "done". */
        var listener: ((String, Long) -> Unit)? = null

        /** The running service. Updates go to it directly, so a rest can
         *  follow a timed set while Bolt is in the background, where Android
         *  would refuse to start a new foreground service. */
        private var live: RestTimerService? = null

        fun start(context: Context, args: Map<String, Any?>) {
            val i = Intent(context, RestTimerService::class.java).setAction(START)
            for ((k, v) in args) {
                when (v) {
                    is Number -> i.putExtra(k, v.toLong())
                    is Boolean -> i.putExtra(k, v)
                    is String -> i.putExtra(k, v)
                }
            }
            val s = live
            if (s != null && s.running) {
                s.handle(i)
                return
            }
            try {
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(i) else context.startService(i)
            } catch (_: Exception) {
                // Not allowed from the background: the screen still counts down.
            }
        }

        fun stop() {
            live?.handle(Intent().setAction(STOP))
        }
    }

    private val main = Handler(Looper.getMainLooper())
    private var wake: PowerManager.WakeLock? = null
    private var running = false
    private var lastId = 0

    private var end = 0L
    private var totalMs = 1L
    private var title = ""
    private var body = ""
    private var sound = "off"
    private var countdown = true
    private var haptics = true
    private var rest = true
    private var minus = "−15"
    private var plus = "+15"
    private var skip = "Skip"
    private var channelName = "Rest timer"
    private var channelAbout = ""

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        live = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        lastId = startId
        handle(intent)
        return START_NOT_STICKY
    }

    private fun handle(intent: Intent?) {
        when (intent?.action) {
            START -> {
                // A countdown that is just running out (a timed set handing
                // over to its rest) still gets its end cue.
                if (running && end - System.currentTimeMillis() <= 500) cueEnd()
                end = intent.getLongExtra("end", 0)
                totalMs = max(1000L, intent.getLongExtra("total", 1) * 1000)
                title = intent.getStringExtra("title") ?: ""
                body = intent.getStringExtra("body") ?: ""
                sound = intent.getStringExtra("sound") ?: "off"
                countdown = intent.getBooleanExtra("countdown", true)
                haptics = intent.getBooleanExtra("haptics", true)
                rest = intent.getBooleanExtra("rest", true)
                minus = intent.getStringExtra("minus") ?: minus
                plus = intent.getStringExtra("plus") ?: plus
                skip = intent.getStringExtra("skipLabel") ?: skip
                channelName = intent.getStringExtra("channel") ?: channelName
                channelAbout = intent.getStringExtra("channelAbout") ?: channelAbout
                begin()
            }
            ADD -> {
                if (!running) return
                val d = intent.getLongExtra("secs", 0) * 1000
                end = max(System.currentTimeMillis() + 1000, end + d)
                totalMs = max(1000L, totalMs + d)
                schedule()
                listener?.invoke("changed", end)
            }
            SKIP -> {
                listener?.invoke("skipped", 0)
                finish()
            }
            STOP -> finish()
            else -> if (!running) finish()
        }
    }

    private fun begin() {
        channel()
        val n = build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION, n)
        }
        running = true
        schedule()
    }

    /** The cues, the end and a notification update every second. */
    private fun schedule() {
        main.removeCallbacksAndMessages(null)
        val left = end - System.currentTimeMillis()
        wake?.let { if (it.isHeld) it.release() }
        wake = getSystemService(PowerManager::class.java)
            ?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "bolt:rest")
            ?.apply { acquire(max(0, left) + 10_000) }
        val soon = left - 10_000
        if (rest && haptics && totalMs > 20_000 && soon > 0) {
            main.postDelayed({ BoltHaptics.vibrate(this, "soon") }, soon)
        }
        if (countdown) {
            for (s in 3 downTo 1) {
                val at = left - s * 1000
                if (at > 0) {
                    main.postDelayed({
                        if (haptics) BoltHaptics.vibrate(this, "warn")
                        BoltTones.play(this, sound, false)
                    }, at)
                }
            }
        }
        main.postDelayed({ done() }, max(0, left))
        tick()
    }

    private fun tick() {
        if (end - System.currentTimeMillis() <= 0) return
        getSystemService(NotificationManager::class.java)?.notify(NOTIFICATION, build())
        val toNextSecond = (end - System.currentTimeMillis()) % 1000
        main.postDelayed({ tick() }, if (toNextSecond < 50) 1000 + toNextSecond else toNextSecond)
    }

    private fun cueEnd() {
        if (haptics) BoltHaptics.vibrate(this, "done")
        BoltTones.play(this, sound, true)
    }

    private fun done() {
        cueEnd()
        listener?.invoke("done", end)
        // A timed set waits a moment for the rest that follows it.
        if (rest) finish() else main.postDelayed({ finish() }, 1500)
    }

    private fun finish() {
        main.removeCallbacksAndMessages(null)
        running = false
        wake?.let { if (it.isHeld) it.release() }
        wake = null
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
        stopSelf(lastId)
    }

    private fun channel() {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        if (nm.getNotificationChannel(CHANNEL) != null) return
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, channelName, NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = channelAbout
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            },
        )
    }

    private fun action(what: String, secs: Long, code: Int): PendingIntent =
        PendingIntent.getService(
            this,
            code,
            Intent(this, RestTimerService::class.java).setAction(what).putExtra("secs", secs),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun clock(ms: Long): String {
        val s = (max(0, ms) + 999) / 1000
        return "${s / 60}:${(s % 60).toString().padStart(2, '0')}"
    }

    private fun build(): Notification {
        val left = end - System.currentTimeMillis()
        val done = ((totalMs - left).toDouble() / totalMs).coerceIn(0.0, 1.0)
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else @Suppress("DEPRECATION") Notification.Builder(this)
        b.setSmallIcon(R.drawable.ic_stat_bolt)
            // The countdown is drawn into the title rather than left to
            // setUsesChronometer(), which Android butts straight against the
            // title with no gap ("Rest01:17"). This service already rebuilds
            // the notification every second, so it costs nothing to own it.
            .setContentTitle("$title · ${clock(left)}")
            .setContentText(body)
            .setColor(0xFFC6FF1A.toInt())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_STOPWATCH)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(
                PendingIntent.getActivity(
                    this,
                    0,
                    Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        if (rest) {
            b.addAction(Notification.Action.Builder(null, minus, action(ADD, -15, 1)).build())
            b.addAction(Notification.Action.Builder(null, plus, action(ADD, 15, 2)).build())
            b.addAction(Notification.Action.Builder(null, skip, action(SKIP, 0, 3)).build())
        }
        if (Build.VERSION.SDK_INT >= 36) {
            b.setStyle(
                Notification.ProgressStyle()
                    .setProgressSegments(listOf(Notification.ProgressStyle.Segment(1000).setColor(0xFFC6FF1A.toInt())))
                    .setProgress((done * 1000).toInt()),
            )
            // setRequestPromotedOngoing() only arrived after the Android 16
            // SDK; this extra is what it sets and what Android 16 reads.
            b.addExtras(Bundle().apply { putBoolean("android.requestPromotedOngoing", true) })
            b.setShortCriticalText(clock(left))
        } else {
            b.setProgress(1000, (done * 1000).toInt(), false)
        }
        return b.build()
    }

    override fun onDestroy() {
        if (live === this) live = null
        main.removeCallbacksAndMessages(null)
        wake?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }
}
