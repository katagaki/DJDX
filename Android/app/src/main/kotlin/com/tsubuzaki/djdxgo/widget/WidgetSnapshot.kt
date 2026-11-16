package com.tsubuzaki.djdxgo.widget

import android.content.Context
import com.tsubuzaki.djdxgo.data.RadarData
import java.io.File
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
data class WidgetTrendPoint(val date: Long, val counts: Map<Int, Map<String, Int>>)

@Serializable
data class WidgetCountsSnapshot(
    val perDifficulty: Map<Int, Map<String, Int>> = emptyMap(),
    val trends: List<WidgetTrendPoint> = emptyList()
)

@Serializable
data class WidgetTowerEntry(val playDate: Long, val keyCount: Int, val scratchCount: Int)

@Serializable
data class WidgetTowerSnapshot(
    val totalKeyCount: Int = 0,
    val totalScratchCount: Int = 0,
    val latestEntries: List<WidgetTowerEntry> = emptyList()
)

@Serializable
data class WidgetSnapshot(
    val playType: String = "single",
    val radar: RadarData? = null,
    val clearType: WidgetCountsSnapshot = WidgetCountsSnapshot(),
    val djLevel: WidgetCountsSnapshot = WidgetCountsSnapshot(),
    val tower: WidgetTowerSnapshot? = null,
    val lastUpdated: Long = 0
)

object WidgetSnapshotStore {
    private val json = Json { ignoreUnknownKeys = true }

    private fun directory(context: Context): File = File(context.filesDir, "widgets")

    private fun snapshotFile(context: Context): File = File(directory(context), "Snapshot.json")

    fun qproFile(context: Context): File = File(directory(context), "Qpro.png")

    fun read(context: Context): WidgetSnapshot? = runCatching {
        val file = snapshotFile(context)
        if (file.exists()) json.decodeFromString<WidgetSnapshot>(file.readText()) else null
    }.getOrNull()

    fun write(context: Context, snapshot: WidgetSnapshot, qpro: File?) {
        val directory = directory(context)
        directory.mkdirs()
        val temporary = File(directory, "Snapshot.json.tmp")
        temporary.writeText(json.encodeToString(snapshot))
        temporary.renameTo(snapshotFile(context))
        if (qpro != null && qpro.exists()) {
            qpro.copyTo(qproFile(context), overwrite = true)
        } else {
            qproFile(context).delete()
        }
    }
}
