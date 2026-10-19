package com.x3kk.bolt

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.HapticFeedbackConstants
import android.view.View

/**
 * Bolt's haptics, named for the moment ("set", "record") rather than the motor.
 *
 * Small UI feels (a stepper notch, a toggle) go through the view, so they use
 * the phone maker's own tuning (Samsung's ticks on a Galaxy) and stay off when
 * the user turned touch feedback off. Android 14 added constants made for
 * steppers and switches; older phones get the closest older one.
 *
 * Bigger moments are composed from the actuator's primitives where the phone
 * supports them (crisp clicks, a rising swell), the way iPhone's Core Haptics
 * patterns are built, and fall back to tuned predefined effects, then to plain
 * amplitude waveforms.
 *
 * "warn" and "done" are the rest timer's: they must be felt in a pocket with
 * the screen off, so they play as alarm vibrations.
 */
object BoltHaptics {

    fun play(context: Context, view: View?, name: String) {
        when (name) {
            "tick" -> viewFeel(
                view,
                if (Build.VERSION.SDK_INT >= 34) HapticFeedbackConstants.SEGMENT_FREQUENT_TICK
                else HapticFeedbackConstants.CLOCK_TICK,
            )
            "detent" -> viewFeel(
                view,
                if (Build.VERSION.SDK_INT >= 34) HapticFeedbackConstants.SEGMENT_TICK
                else HapticFeedbackConstants.CONTEXT_CLICK,
            )
            "tap" -> viewFeel(view, HapticFeedbackConstants.VIRTUAL_KEY)
            "on" -> viewFeel(
                view,
                if (Build.VERSION.SDK_INT >= 34) HapticFeedbackConstants.TOGGLE_ON
                else HapticFeedbackConstants.VIRTUAL_KEY,
            )
            "off" -> viewFeel(
                view,
                if (Build.VERSION.SDK_INT >= 34) HapticFeedbackConstants.TOGGLE_OFF
                else HapticFeedbackConstants.CLOCK_TICK,
            )
            "error" -> viewFeel(
                view,
                if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.REJECT
                else HapticFeedbackConstants.LONG_PRESS,
            )
            else -> vibrate(context, name)
        }
    }

    private fun viewFeel(view: View?, constant: Int) {
        view?.performHapticFeedback(constant)
    }

    private fun vibrator(context: Context): Vibrator? =
        if (Build.VERSION.SDK_INT >= 31) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    /** The rich moments, from the best effect this phone can play. */
    fun vibrate(context: Context, name: String) {
        val v = vibrator(context) ?: return
        if (!v.hasVibrator()) return
        val alarm = name == "warn" || name == "done"
        val effect = when (name) {
            // A set ticked off: a solid click with a low thud, like a racked plate.
            "set" -> composed(v, p(CLICK, 1f), p(LOW_TICK, .6f, 30))
                ?: composed(v, p(CLICK, 1f))
                ?: predefined(VibrationEffect.EFFECT_HEAVY_CLICK)
                ?: wave(v, longArrayOf(0, 28), intArrayOf(0, 255))
            // Workout done: two taps, the second stronger, like iPhone's success.
            "success" -> composed(v, p(CLICK, .55f), p(CLICK, 1f, 110))
                ?: wave(v, longArrayOf(0, 20, 110, 32), intArrayOf(0, 150, 0, 255))
            // A personal record: a quick swell into three rising clicks.
            "record" -> composed(
                v,
                p(QUICK_RISE, .5f),
                p(CLICK, .7f, 40),
                p(CLICK, .85f, 90),
                p(CLICK, 1f, 90),
            ) ?: wave(v, longArrayOf(0, 25, 80, 25, 70, 25, 70, 45), intArrayOf(0, 120, 0, 180, 0, 220, 0, 255))
            // Each of the last 3 seconds of a rest.
            "warn" -> wave(v, longArrayOf(0, 40), intArrayOf(0, 200))
            // Rest over: three strong pulses that get through a pocket.
            "done" -> wave(v, longArrayOf(0, 70, 90, 70, 90, 220), intArrayOf(0, 255, 0, 255, 0, 255))
            else -> null
        } ?: return
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                v.vibrate(
                    effect,
                    VibrationAttributes.createForUsage(
                        if (alarm) VibrationAttributes.USAGE_ALARM else VibrationAttributes.USAGE_TOUCH,
                    ),
                )
            } else {
                @Suppress("DEPRECATION")
                v.vibrate(
                    effect,
                    AudioAttributes.Builder()
                        .setUsage(
                            if (alarm) AudioAttributes.USAGE_ALARM
                            else AudioAttributes.USAGE_ASSISTANCE_SONIFICATION,
                        )
                        .build(),
                )
            }
        } catch (_: Exception) {
        }
    }

    private class Part(val id: Int, val scale: Float, val delay: Int)

    private fun p(id: Int, scale: Float, delay: Int = 0) = Part(id, scale, delay)

    // Short names so the patterns above read as a score. LOW_TICK arrived in
    // Android 12, the others in 11; the ids are compile-time constants.
    private const val CLICK = VibrationEffect.Composition.PRIMITIVE_CLICK
    private const val QUICK_RISE = VibrationEffect.Composition.PRIMITIVE_QUICK_RISE
    private const val LOW_TICK = VibrationEffect.Composition.PRIMITIVE_LOW_TICK

    /** Null when the phone cannot play every primitive in [parts]. */
    private fun composed(v: Vibrator, vararg parts: Part): VibrationEffect? {
        if (Build.VERSION.SDK_INT < 30) return null
        if (Build.VERSION.SDK_INT < 31 && parts.any { it.id == LOW_TICK }) return null
        val ids = parts.map { it.id }.toIntArray()
        if (!v.areAllPrimitivesSupported(*ids)) return null
        val c = VibrationEffect.startComposition()
        for (part in parts) c.addPrimitive(part.id, part.scale, part.delay)
        return c.compose()
    }

    private fun predefined(id: Int): VibrationEffect? =
        if (Build.VERSION.SDK_INT >= 29) VibrationEffect.createPredefined(id) else null

    /** Amplitudes where the motor can vary them, on and off otherwise. */
    private fun wave(v: Vibrator, timings: LongArray, amps: IntArray): VibrationEffect =
        if (v.hasAmplitudeControl()) VibrationEffect.createWaveform(timings, amps, -1)
        else VibrationEffect.createWaveform(timings, -1)
}
