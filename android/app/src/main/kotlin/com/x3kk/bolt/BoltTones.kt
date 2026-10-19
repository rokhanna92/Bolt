package com.x3kk.bolt

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import android.os.Handler
import android.os.Looper
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.min
import kotlin.math.sin

/**
 * Rest timer sounds, made here rather than shipped as files: short soft
 * blips for the last 3 seconds and an end cue, as a clean "beep" or a
 * two-note "chime".
 *
 * They play as navigation-style prompts, the way running apps speak: into
 * headphones when they are in, at the media volume, and they duck music for
 * the end cue instead of cutting it. That works with Bolt in the background
 * while the rest timer service runs.
 */
object BoltTones {

    private const val RATE = 44100
    private val main = Handler(Looper.getMainLooper())

    /** One partial of a tone: frequency, loudness and how fast it fades. */
    private class Partial(val hz: Double, val amp: Double, val decay: Double)

    private fun render(ms: Int, notes: List<Pair<Int, List<Partial>>>): ShortArray {
        val n = RATE * ms / 1000
        val out = DoubleArray(n)
        for ((startMs, partials) in notes) {
            val s0 = RATE * startMs / 1000
            for (i in s0 until n) {
                val t = (i - s0).toDouble() / RATE
                // 4 ms attack so nothing clicks.
                val attack = min(1.0, t / .004)
                var v = 0.0
                for (p in partials) v += p.amp * exp(-t * p.decay) * sin(2 * PI * p.hz * t)
                out[i] += v * attack
            }
        }
        return ShortArray(n) { i -> (out[i].coerceIn(-1.0, 1.0) * Short.MAX_VALUE).toInt().toShort() }
    }

    private val blipBeep by lazy { render(90, listOf(0 to listOf(Partial(880.0, .32, 45.0)))) }
    private val endBeep by lazy {
        render(420, listOf(0 to listOf(Partial(1046.5, .38, 9.0), Partial(2093.0, .05, 14.0))))
    }
    private val blipChime by lazy {
        render(120, listOf(0 to listOf(Partial(1568.0, .22, 38.0), Partial(3136.0, .04, 60.0))))
    }

    // A bell: a strong fundamental with inharmonic partials, E6 then A6.
    private fun bell(hz: Double) = listOf(Partial(hz, .26, 4.5), Partial(hz * 2.76, .08, 7.0), Partial(hz * 5.4, .03, 11.0))
    private val endChime by lazy { render(1100, listOf(0 to bell(1318.5), 130 to bell(1760.0))) }

    /** [sound] is "beep" or "chime"; [end] picks the end cue over a blip. */
    fun play(context: Context, sound: String, end: Boolean) {
        val pcm = when {
            sound == "beep" && end -> endBeep
            sound == "beep" -> blipBeep
            sound == "chime" && end -> endChime
            sound == "chime" -> blipChime
            else -> return
        }
        try {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val track = AudioTrack.Builder()
                .setAudioAttributes(attrs)
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(RATE)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setTransferMode(AudioTrack.MODE_STATIC)
                .setBufferSizeInBytes(pcm.size * 2)
                .build()
            track.write(pcm, 0, pcm.size)
            val audio = context.getSystemService(AudioManager::class.java)
            val focus = if (end && Build.VERSION.SDK_INT >= 26) {
                AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                    .setAudioAttributes(attrs)
                    .build()
                    .also { audio?.requestAudioFocus(it) }
            } else {
                null
            }
            track.play()
            val ms = pcm.size * 1000L / RATE + 80
            main.postDelayed({
                try {
                    track.release()
                } catch (_: Exception) {
                }
                if (focus != null && Build.VERSION.SDK_INT >= 26) audio?.abandonAudioFocusRequest(focus)
            }, ms)
        } catch (_: Exception) {
            // A sound is a nicety; the vibration and the screen still tell.
        }
    }
}
