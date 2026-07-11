package com.tsubuzaki.djdxgo.data.external

import com.tsubuzaki.djdxgo.data.compact
import com.tsubuzaki.djdxgo.data.ddr.DDRVersionInfo
import com.tsubuzaki.djdxgo.data.ddrCompact
import com.tsubuzaki.djdxgo.data.iidx.IIDXVersionInfo
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.jsoup.Jsoup
import org.jsoup.nodes.Document
import org.jsoup.nodes.Element
import org.jsoup.parser.Parser
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.GZIPInputStream

enum class ExternalDataSource {
    TEXTAGE_CHART_VIEWER,
    SDVX_IN,
    WIKI_IIDX,
    BM2DX,
    WIKI_DDR
}

class ExternalDataReloader(private val dao: ExternalDataDao) {

    suspend fun reload(
        source: ExternalDataSource,
        onProgress: (Float) -> Unit = {}
    ): Result<Int> = withContext(Dispatchers.IO) {
        runCatching {
            when (source) {
                ExternalDataSource.TEXTAGE_CHART_VIEWER -> reloadTextageChartViewer(onProgress)
                ExternalDataSource.SDVX_IN -> reloadSDVXIn(onProgress)
                ExternalDataSource.WIKI_IIDX -> reloadWikiIIDX(onProgress)
                ExternalDataSource.BM2DX -> reloadBM2DX(onProgress)
                ExternalDataSource.WIKI_DDR -> reloadWikiDDR(onProgress)
            }
        }
    }

    private fun fetchBytes(url: String): ByteArray {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = TIMEOUT_MILLIS
        connection.readTimeout = TIMEOUT_MILLIS
        connection.instanceFollowRedirects = true
        try {
            return connection.inputStream.use { it.readBytes() }
        } finally {
            connection.disconnect()
        }
    }

    private fun fetchDocument(url: String): Document =
        Jsoup.connect(url)
            .timeout(TIMEOUT_MILLIS)
            .followRedirects(true)
            .get()

    // Textage Chart Viewer

    private suspend fun reloadTextageChartViewer(onProgress: (Float) -> Unit): Int {
        onProgress(0f)
        val body = fetchBytes(TEXTAGE_CHART_VIEWER_URL).toString(Charsets.UTF_8)
        val root = Json.parseToJsonElement(body).jsonObject
        val songs = root["data"]?.jsonArray ?: return 0
        val charts = songs.mapNotNull { element ->
            val song = element.jsonObject
            val songId = song["songId"]?.jsonPrimitive?.content ?: return@mapNotNull null
            val version = song["version"]?.jsonPrimitive?.intOrNull ?: 0
            val baseTitle = song["title"]?.jsonPrimitive?.content ?: ""
            val subtitle = song["subtitle"]?.let { subtitleElement ->
                if (subtitleElement is kotlinx.serialization.json.JsonNull) null
                else subtitleElement.jsonPrimitive.content
            }
            val title = baseTitle + (subtitle ?: "")
            val levels = song["levels"]?.jsonObject ?: return@mapNotNull null
            fun level(key: String): Int = levels[key]?.jsonPrimitive?.intOrNull ?: 0
            val chart = TextageChartViewerChart(
                songId = songId,
                version = version,
                title = title,
                titleCompact = title.compact,
                spBeginner = level("spBeginner"),
                spNormal = level("spNormal"),
                spHyper = level("spHyper"),
                spAnother = level("spAnother"),
                spLeggendaria = level("spLeggendaria"),
                dpBeginner = level("dpBeginner"),
                dpNormal = level("dpNormal"),
                dpHyper = level("dpHyper"),
                dpAnother = level("dpAnother"),
                dpLeggendaria = level("dpLeggendaria")
            )
            val hasAnyChart = listOf(
                chart.spBeginner, chart.spNormal, chart.spHyper, chart.spAnother,
                chart.spLeggendaria, chart.dpBeginner, chart.dpNormal, chart.dpHyper,
                chart.dpAnother, chart.dpLeggendaria
            ).any { it > 0 }
            if (hasAnyChart && chart.title.isNotEmpty()) chart else null
        }
        dao.deleteAllTextageChartViewerCharts()
        dao.insertTextageChartViewerCharts(charts)
        onProgress(1f)
        return dao.textageChartViewerChartCount()
    }

    // sdvx.in

    private suspend fun reloadSDVXIn(onProgress: (Float) -> Unit): Int {
        val regex = Regex(
            "SORT([0-9]{5})([NAEMnaem])\\(\\);</script><!--(.*?)-->",
            RegexOption.DOT_MATCHES_ALL
        )
        val charts = mutableListOf<SDVXInChart>()
        onProgress(0f)
        for (level in 1..20) {
            runCatching {
                val levelSlug = level.toString().padStart(2, '0')
                val html = fetchBytes("https://sdvx.in/sort/sort_$levelSlug.htm")
                    .toString(Charsets.UTF_8)
                for (match in regex.findAll(html)) {
                    val code = match.groupValues[1]
                    val slot = match.groupValues[2].lowercase()
                    val title = Parser.unescapeEntities(match.groupValues[3], false).trim()
                    if (title.isEmpty()) continue
                    charts.add(
                        SDVXInChart(
                            code = code,
                            slot = slot,
                            title = title,
                            titleCompact = title.compact,
                            level = level
                        )
                    )
                }
            }
            onProgress(level / 20f)
        }
        dao.deleteAllSDVXInCharts()
        dao.insertSDVXInCharts(charts)
        return dao.sdvxInChartCount()
    }

    // BEMANIWiki (beatmania IIDX)

    private suspend fun reloadWikiIIDX(onProgress: (Float) -> Unit): Int {
        onProgress(0f)
        val songs = mutableListOf<IIDXSong>()
        var levels: Map<String, IIDXWikiLevels> = emptyMap()
        runCatching {
            val latestDocument = fetchDocument(IIDXVersionInfo.bemaniWikiLatestVersionPageURL)
            val documentBody = wikiDocumentBody(latestDocument)
            if (documentBody != null) {
                val children = documentBody.children()
                val indexOfHeader = children.indexOfFirst { element ->
                    (element.tagName() == "h3" || element.tagName() == "h4") &&
                        element.text().contains("総ノーツ数")
                }
                if (indexOfHeader >= 0) {
                    songs.addAll(
                        noteCountRows(children.subList(indexOfHeader, children.size))
                    )
                }
                val levelScope = if (indexOfHeader >= 0) {
                    children.subList(0, indexOfHeader)
                } else {
                    children
                }
                levels = levelRows(levelScope)
            }
        }
        onProgress(0.5f)
        runCatching {
            val existingDocument = fetchDocument(IIDXVersionInfo.bemaniWikiExistingVersionsPageURL)
            val documentBody = wikiDocumentBody(existingDocument)
            if (documentBody != null) {
                songs.addAll(noteCountRows(documentBody.children()))
            }
        }
        val merged = songs.map { song ->
            levels[song.titleCompact]?.let { entry ->
                song.copy(
                    spBeginnerLevel = entry.spBeginner,
                    spNormalLevel = entry.spNormal,
                    spHyperLevel = entry.spHyper,
                    spAnotherLevel = entry.spAnother,
                    spLeggendariaLevel = entry.spLeggendaria,
                    dpNormalLevel = entry.dpNormal,
                    dpHyperLevel = entry.dpHyper,
                    dpAnotherLevel = entry.dpAnother,
                    dpLeggendariaLevel = entry.dpLeggendaria
                )
            } ?: song
        }
        dao.deleteAllIIDXSongs()
        dao.insertIIDXSongs(merged)
        onProgress(1f)
        return dao.iidxSongCount()
    }

    private fun wikiDocumentBody(document: Document): Element? =
        document.body().select("#contents").first()?.select("#body")?.first()

    private fun wikiTableRows(elements: List<Element>): List<List<String>> {
        val rows = mutableListOf<List<String>>()
        for (element in elements) {
            for (table in element.select("div.ie5")) {
                for (tableRow in table.select("tr")) {
                    val columns = tableRow.select("td")
                    if (columns.size == 13) {
                        rows.add(columns.map { it.text() })
                    }
                }
            }
        }
        return rows
    }

    private fun noteCountRows(elements: List<Element>): List<IIDXSong> =
        wikiTableRows(elements).map { columns ->
            val title = columns[0]
            val spColumns = columns.subList(1, 6)
            val dpColumns = columns.subList(6, 10)
            val hasSP = !spColumns.all { it == "-" }
            val hasDP = !dpColumns.all { it == "-" }
            IIDXSong(
                title = title,
                titleCompact = title.compact,
                spBeginnerNoteCount = if (hasSP) columns[1].toIntOrNull() else null,
                spNormalNoteCount = if (hasSP) columns[2].toIntOrNull() else null,
                spHyperNoteCount = if (hasSP) columns[3].toIntOrNull() else null,
                spAnotherNoteCount = if (hasSP) columns[4].toIntOrNull() else null,
                spLeggendariaNoteCount = if (hasSP) columns[5].toIntOrNull() else null,
                dpNormalNoteCount = if (hasDP) columns[6].toIntOrNull() else null,
                dpHyperNoteCount = if (hasDP) columns[7].toIntOrNull() else null,
                dpAnotherNoteCount = if (hasDP) columns[8].toIntOrNull() else null,
                dpLeggendariaNoteCount = if (hasDP) columns[9].toIntOrNull() else null,
                time = columns[10],
                movie = columns[11],
                layer = columns[12]
            )
        }

    private fun levelRows(elements: List<Element>): Map<String, IIDXWikiLevels> {
        val bracketRegex = Regex("\\[[^\\]]*\\]")
        fun level(raw: String): Int? {
            val value = raw.replace(bracketRegex, "").trim().toIntOrNull() ?: return null
            return if (value in 1..12) value else null
        }
        val levels = mutableMapOf<String, IIDXWikiLevels>()
        for (columns in wikiTableRows(elements)) {
            val title = columns[11]
            if (title.isEmpty()) continue
            levels[title.compact] = IIDXWikiLevels(
                spBeginner = level(columns[0]),
                spNormal = level(columns[1]),
                spHyper = level(columns[2]),
                spAnother = level(columns[3]),
                spLeggendaria = level(columns[4]),
                dpNormal = level(columns[5]),
                dpHyper = level(columns[6]),
                dpAnother = level(columns[7]),
                dpLeggendaria = level(columns[8])
            )
        }
        return levels
    }

    private data class IIDXWikiLevels(
        val spBeginner: Int?,
        val spNormal: Int?,
        val spHyper: Int?,
        val spAnother: Int?,
        val spLeggendaria: Int?,
        val dpNormal: Int?,
        val dpHyper: Int?,
        val dpAnother: Int?,
        val dpLeggendaria: Int?
    )

    // bm2dx.com

    private suspend fun reloadBM2DX(onProgress: (Float) -> Unit): Int {
        onProgress(0f)
        val raw = fetchBytes(BM2DX_NOTES_RADAR_URL)
        val decompressed = runCatching {
            GZIPInputStream(raw.inputStream()).use { it.readBytes() }
        }.getOrDefault(raw)
        val root = Json.parseToJsonElement(decompressed.toString(Charsets.UTF_8)).jsonObject
        val midDict = root["mid"]?.jsonObject ?: return 0
        val notesRadar = root["notes_radar"]?.jsonObject ?: return 0

        data class RadarAccumulator(var noteCount: Int, val values: MutableMap<String, Double>)

        val lookup = mutableMapOf<String, MutableMap<String, MutableMap<Int, RadarAccumulator>>>()
        for ((playType, radarTypesElement) in notesRadar) {
            val radarTypes = radarTypesElement.jsonObject
            for ((radarType, entriesElement) in radarTypes) {
                for (entryElement in entriesElement.jsonArray) {
                    val entry = entryElement.jsonObject
                    val mid = entry["mid"]?.jsonPrimitive?.content ?: continue
                    val difficulty = entry["difficult"]?.jsonPrimitive?.intOrNull ?: continue
                    val noteCount = entry["note"]?.jsonPrimitive?.intOrNull ?: continue
                    val value = entry["value"]?.jsonPrimitive?.doubleOrNull ?: continue
                    val accumulator = lookup
                        .getOrPut(playType) { mutableMapOf() }
                        .getOrPut(mid) { mutableMapOf() }
                        .getOrPut(difficulty) { RadarAccumulator(noteCount, mutableMapOf()) }
                    accumulator.noteCount = noteCount
                    accumulator.values[radarType] = value
                }
            }
        }

        val entries = mutableListOf<NotesRadarEntry>()
        for ((playType, mids) in lookup) {
            for ((mid, difficulties) in mids) {
                val title = midDict[mid]?.jsonPrimitive?.content ?: continue
                for ((difficulty, data) in difficulties) {
                    entries.add(
                        NotesRadarEntry(
                            title = title,
                            titleCompact = title.compact,
                            playType = playType,
                            difficulty = difficulty,
                            noteCount = data.noteCount,
                            notes = data.values["NOTES"] ?: 0.0,
                            chord = data.values["CHORD"] ?: 0.0,
                            peak = data.values["PEAK"] ?: 0.0,
                            charge = data.values["CHARGE"] ?: 0.0,
                            scratch = data.values["SCRATCH"] ?: 0.0,
                            soflan = data.values["SOFLAN"] ?: 0.0
                        )
                    )
                }
            }
        }
        dao.deleteAllNotesRadarEntries()
        dao.insertNotesRadarEntries(entries)
        onProgress(1f)
        return dao.notesRadarCount()
    }

    // BEMANIWiki (DanceDanceRevolution)

    private suspend fun reloadWikiDDR(onProgress: (Float) -> Unit): Int {
        onProgress(0f)
        val metas = mutableListOf<DDRSongMeta>()
        runCatching {
            val oldSongsDocument = fetchDocument(DDRVersionInfo.bemaniWikiOldSongsPageURL)
            metas.addAll(parseDDRSongs(oldSongsDocument, baseVersion = null))
        }
        onProgress(0.5f)
        runCatching {
            val newSongsDocument = fetchDocument(DDRVersionInfo.bemaniWikiNewSongsPageURL)
            metas.addAll(
                parseDDRSongs(newSongsDocument, baseVersion = DDRVersionInfo.WORLD_VERSION_NUMBER)
            )
        }
        dao.deleteAllDDRSongMetas()
        dao.insertDDRSongMetas(metas)
        onProgress(1f)
        return dao.ddrSongMetaCount()
    }

    private fun parseDDRSongs(document: Document, baseVersion: Int?): List<DDRSongMeta> {
        val result = mutableListOf<DDRSongMeta>()
        var versionIndex = 0
        for (table in document.body().select("table")) {
            for (row in table.select("tr")) {
                val cells = row.select("td, th")
                val count = cells.size
                if (count == 1) {
                    val text = cells.first()?.text() ?: ""
                    if (text.contains("DDR") || text.contains("DanceDance")) {
                        versionIndex += 1
                    }
                    continue
                }
                if (count < 14) continue
                val texts = cells.map { it.text() }
                val title = texts[count - 14].trim()
                if (title.isEmpty()) continue
                val levelStrings = texts.subList(count - 9, count)
                fun level(index: Int): Int =
                    levelStrings.getOrNull(index)
                        ?.filter { it.isDigit() }
                        ?.toIntOrNull() ?: 0
                result.add(
                    DDRSongMeta(
                        titleCompact = title.ddrCompact,
                        title = title,
                        version = baseVersion ?: versionIndex,
                        spBeginner = level(0),
                        spBasic = level(1),
                        spDifficult = level(2),
                        spExpert = level(3),
                        spChallenge = level(4),
                        dpBasic = level(5),
                        dpDifficult = level(6),
                        dpExpert = level(7),
                        dpChallenge = level(8)
                    )
                )
            }
        }
        return result.distinctBy { it.titleCompact }
    }

    companion object {
        private const val TIMEOUT_MILLIS = 30_000
        private const val TEXTAGE_CHART_VIEWER_URL =
            "https://textage-chart-viewer.vercel.app/api/songs"
        private const val BM2DX_NOTES_RADAR_URL =
            "https://bm2dx.com/IIDX/notes_radar/notes_radar.json.gz"
    }
}
