package com.tsubuzaki.djdxgo.widget

import android.content.Context
import android.os.Build
import androidx.glance.appwidget.GlanceAppWidgetManager
import com.tsubuzaki.djdxgo.data.RadarData

object WidgetPreviews {

    private const val DAY = 86_400L
    private const val SAMPLE_START = 1_780_000_000L

    private val clearTypeLatest = mapOf(
        "FULLCOMBO CLEAR" to 4,
        "EX HARD CLEAR" to 12,
        "HARD CLEAR" to 38,
        "CLEAR" to 61,
        "EASY CLEAR" to 29,
        "ASSIST CLEAR" to 9,
        "FAILED" to 23
    )

    private val djLevelLatest = mapOf(
        "AAA" to 6,
        "AA" to 31,
        "A" to 58,
        "B" to 44,
        "C" to 17,
        "D" to 4
    )

    private fun trend(latest: Map<String, Int>, growing: Set<String>): List<WidgetTrendPoint> =
        (0 until 6).map { index ->
            val remaining = 5 - index
            val counts = latest.mapValues { (key, count) ->
                if (key in growing) (count - remaining * count / 8).coerceAtLeast(0) else count + remaining * 2
            }
            WidgetTrendPoint(SAMPLE_START + index * 7 * DAY, mapOf(WidgetKeys.DEFAULT_LEVEL to counts))
        }

    val snapshot = WidgetSnapshot(
        playType = "single",
        radar = RadarData(notes = 142.3, chord = 118.6, peak = 131.9, charge = 96.4, scratch = 104.7, soflan = 88.2),
        clearType = WidgetCountsSnapshot(
            perDifficulty = mapOf(WidgetKeys.DEFAULT_LEVEL to clearTypeLatest),
            trends = trend(clearTypeLatest, setOf("FULLCOMBO CLEAR", "EX HARD CLEAR", "HARD CLEAR", "CLEAR"))
        ),
        djLevel = WidgetCountsSnapshot(
            perDifficulty = mapOf(WidgetKeys.DEFAULT_LEVEL to djLevelLatest),
            trends = trend(djLevelLatest, setOf("AAA", "AA", "A"))
        ),
        tower = WidgetTowerSnapshot(
            totalKeyCount = 128_450,
            totalScratchCount = 9_310,
            latestEntries = listOf(
                WidgetTowerEntry(SAMPLE_START + 35 * DAY, 2_841, 212),
                WidgetTowerEntry(SAMPLE_START + 33 * DAY, 1_967, 158),
                WidgetTowerEntry(SAMPLE_START + 30 * DAY, 3_104, 247)
            )
        ),
        lastUpdated = SAMPLE_START + 35 * DAY
    )

    suspend fun publish(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) return
        val manager = GlanceAppWidgetManager(context)
        listOf(
            QproWidgetReceiver::class,
            NotesRadarWidgetReceiver::class,
            ClearTypeWidgetReceiver::class,
            DJLevelWidgetReceiver::class,
            TowerWidgetReceiver::class
        ).forEach { receiver ->
            runCatching { manager.setWidgetPreviews(receiver) }
        }
    }
}
