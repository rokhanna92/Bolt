package com.x3kk.bolt

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Home screen widget. Bolt writes what to show into shared preferences
 * through the "bolt/widget" channel; this only draws it. Text from an
 * earlier day is swapped for a nudge to open Bolt.
 */
class BoltWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { manager.updateAppWidget(it, views(context)) }
    }

    companion object {
        private const val PREFS = "bolt_widget"

        /** Saves what Bolt sent and redraws every widget. */
        fun save(context: Context, data: Map<String, Any?>) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
                for ((k, v) in data) {
                    when (v) {
                        is String -> putString(k, v)
                        is Number -> putLong(k, v.toLong())
                        null -> remove(k)
                    }
                }
            }.apply()
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, BoltWidget::class.java))
            ids.forEach { manager.updateAppWidget(it, views(context)) }
        }

        private fun views(context: Context): RemoteViews {
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val v = RemoteViews(context.packageName, R.layout.bolt_widget)
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val fresh = p.getString("date", null) == today
            // Days off: Bolt sends a line for each of the coming days, so the
            // widget turns orange on the right day even when Bolt stays closed.
            val off = p.getString("off_$today", null)
            v.setTextViewText(R.id.kicker, off ?: if (fresh) p.getString("kicker", "") else "")
            v.setTextViewText(
                R.id.title,
                when {
                    fresh -> p.getString("title", "Bolt")
                    off != null -> p.getString("offTitle", "Bolt")
                    else -> p.getString("stale", "Bolt")
                },
            )
            v.setTextViewText(R.id.sub, if (fresh) p.getString("sub", "") else "")
            v.setTextColor(R.id.kicker, if (off != null) 0xFFFF7A45.toInt() else 0xFF9CA393.toInt())
            v.setTextColor(R.id.title, if (off != null) 0xFFFF7A45.toInt() else 0xFFF1F4EC.toInt())
            v.setInt(R.id.root, "setBackgroundResource", if (off != null) R.drawable.widget_bg_alert else R.drawable.widget_bg)
            v.setTextViewText(R.id.footer, p.getString("footer", ""))
            v.setTextViewText(R.id.scan, p.getString("scan", "SCAN"))
            val since = p.getLong("gymSince", 0)
            if (since > 0) {
                v.setViewVisibility(R.id.timer, View.VISIBLE)
                v.setChronometer(R.id.timer, SystemClock.elapsedRealtime() - (System.currentTimeMillis() - since), null, true)
            } else {
                v.setViewVisibility(R.id.timer, View.GONE)
                v.setChronometer(R.id.timer, SystemClock.elapsedRealtime(), null, false)
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            v.setOnClickPendingIntent(
                R.id.root,
                PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java), flags),
            )
            val scan = Intent(context, MainActivity::class.java)
                .setAction("com.x3kk.bolt.SHORTCUT")
                .putExtra("shortcut", "scan")
            v.setOnClickPendingIntent(R.id.scan, PendingIntent.getActivity(context, 1, scan, flags))
            return v
        }
    }
}
