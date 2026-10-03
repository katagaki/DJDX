package com.tsubuzaki.djdxgo.data.external

import com.tsubuzaki.djdxgo.data.compact
import com.tsubuzaki.djdxgo.data.ddr.DDRVersionInfo
import com.tsubuzaki.djdxgo.data.ddrCompact
import com.tsubuzaki.djdxgo.data.iidx.IIDXVersionInfo
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import org.jsoup.Jsoup
import org.jsoup.nodes.Document
import org.jsoup.nodes.Element
import org.jsoup.parser.Parser
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.Charset
import java.util.zip.GZIPInputStream

enum class ExternalDataSource(val id: String) {
    TEXTAGE("textage"),
    TEXTAGE_CHART_VIEWER("textageChartViewer"),
    SDVX_IN("sdvxIn"),
    WIKI_IIDX("wikiIidx"),
    BM2DX("bm2dx"),
    WIKI_DDR("wikiDdr");

    companion object {
        fun fromId(id: String): ExternalDataSource? =
            entries.firstOrNull { it.id.equals(id, ignoreCase = true) }
    }
}

class ExternalDataUnavailableException : IOException()

class ExternalDataReloader(private val dao: ExternalDataDao) {

    private val json = Json { ignoreUnknownKeys = true }

    suspend fun reload(
        source: ExternalDataSource,
        onProgress: (Float) -> Unit = {}
    ): Result<Int> = withContext(Dispatchers.IO) {
        runCatching {
            when (source) {
                ExternalDataSource.TEXTAGE -> reloadTextage(onProgress)
                ExternalDataSource.TEXTAGE_CHART_VIEWER -> reloadTextageChartViewer(onProgress)
                ExternalDataSource.SDVX_IN -> reloadSDVXIn(onProgress)
                ExternalDataSource.WIKI_IIDX -> reloadWikiIIDX(onProgress)
                ExternalDataSource.BM2DX -> reloadBM2DX(onProgress)
                ExternalDataSource.WIKI_DDR -> reloadWikiDDR(onProgress)
            }
        }
    }

    suspend fun entryCount(source: ExternalDataSource): Int = when (source) {
        ExternalDataSource.TEXTAGE -> dao.textageChartCount()
        ExternalDataSource.TEXTAGE_CHART_VIEWER -> dao.textageChartViewerChartCount()
        ExternalDataSource.SDVX_IN -> dao.sdvxInChartCount()
        ExternalDataSource.WIKI_IIDX -> dao.iidxSongCount()
        ExternalDataSource.BM2DX -> dao.notesRadarCount()
        ExternalDataSource.WIKI_DDR -> dao.ddrSongMetaCount()
    }

    private fun fetchBytes(url: String): ByteArray {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = TIMEOUT_MILLIS
        connection.readTimeout = TIMEOUT_MILLIS
        connection.instanceFollowRedirects = true
        connection.setRequestProperty("User-Agent", USER_AGENT)
        try {
            val status = connection.responseCode
            if (status !in 200..299) throw IOException("HTTP $status: $url")
            return connection.inputStream.use { it.readBytes() }
        } finally {
            connection.disconnect()
        }
    }

    private fun fetchText(url: String, charset: Charset = Charsets.UTF_8): String =
        fetchBytes(url).toString(charset)

    private fun fetchDocument(url: String): Document =
        Jsoup.connect(url)
            .userAgent(USER_AGENT)
            .timeout(TIMEOUT_MILLIS)
            .maxBodySize(0)
            .followRedirects(true)
            .get()

    private fun ungzipped(bytes: ByteArray): ByteArray =
        if (bytes.size >= 2 && bytes[0] == 0x1f.toByte() && bytes[1] == 0x8b.toByte()) {
            GZIPInputStream(bytes.inputStream()).use { it.readBytes() }
        } else {
            bytes
        }

    private fun <T> requireEntries(entries: List<T>): List<T> {
        if (entries.isEmpty()) throw ExternalDataUnavailableException()
        return entries
    }

    private suspend fun reloadTextage(onProgress: (Float) -> Unit): Int {
        onProgress(0f)
        val charset = textageCharset()
        val titleTable = fetchText(TEXTAGE_TITLE_TABLE_URL, charset)
        onProgress(0.5f)
        val accessTable = fetchText(TEXTAGE_ACCESS_TABLE_URL, charset)
        onProgress(1f)
        val charts = requireEntries(
            TextageTableParser.charts(titleTable, accessTable)
                .distinctBy { it.titleCompact }
        )
        dao.replaceTextageCharts(charts)
        return dao.textageChartCount()
    }

    private fun textageCharset(): Charset =
        listOf("windows-31j", "MS932", "Shift_JIS").firstNotNullOf { name ->
            runCatching { Charset.forName(name) }.getOrNull()
        }

    private suspend fun reloadTextageChartViewer(onProgress: (Float) -> Unit): Int {
        onProgress(0f)
        val root = json.parseToJsonElement(fetchText(TEXTAGE_CHART_VIEWER_URL)).jsonObject
        val songs = root["data"] as? JsonArray ?: throw ExternalDataUnavailableException()
        val charts = songs.mapNotNull { element ->
            val song = element as? JsonObject ?: return@mapNotNull null
            val songId = song.string("songId") ?: return@mapNotNull null
            val title = (song.string("title") ?: "") + (song.string("subtitle") ?: "")
            val levels = song["levels"] as? JsonObject ?: return@mapNotNull null
            fun level(key: String): Int = levels.int(key) ?: 0
            val chart = TextageChartViewerChart(
                songId = songId,
                version = song.int("version") ?: 0,
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
        dao.replaceTextageChartViewerCharts(requireEntries(charts.distinctBy { it.titleCompact }))
        onProgress(1f)
        return dao.textageChartViewerChartCount()
    }

    private suspend fun reloadSDVXIn(onProgress: (Float) -> Unit): Int {
        onProgress(0f)
        val fileCount = sdvxInSongFileCount()
        val charts = mutableListOf<SDVXInChart>()
        for (fileNumber in 1..fileCount) {
            runCatching {
                val slug = fileNumber.toString().padStart(2, '0')
                val songs = json.parseToJsonElement(
                    fetchText("https://sdvx.in/sdvx/_/json/songs$slug.json")
                ).jsonArray
                songs.forEach { element ->
                    (element as? JsonObject)?.let { charts.addAll(sdvxInCharts(it)) }
                }
            }
            onProgress(fileNumber / fileCount.toFloat())
        }
        dao.replaceSDVXInCharts(requireEntries(charts.distinctBy { it.titleCompact to it.slot }))
        return dao.sdvxInChartCount()
    }

    private fun sdvxInSongFileCount(): Int = runCatching {
        Regex("FILE_COUNT:\\s*(\\d+)")
            .find(fetchText(SDVX_IN_DATA_SCRIPT_URL))
            ?.groupValues?.get(1)?.toIntOrNull()
            ?.takeIf { it > 0 }
    }.getOrNull() ?: SDVX_IN_FALLBACK_FILE_COUNT

    private fun sdvxInCharts(song: JsonObject): List<SDVXInChart> {
        val digits = song.string("id")?.filter { it.isDigit() }.orEmpty()
        if (digits.isEmpty()) return emptyList()
        val code = digits.padStart(5, '0').takeLast(5)
        val title = Parser.unescapeEntities(song.string("title").orEmpty(), false).trim()
        if (title.isEmpty()) return emptyList()
        val levels = song["levels"] as? JsonObject ?: return emptyList()
        return SDVX_IN_SLOTS.mapNotNull { (key, slot) ->
            val rawLevel = levels.string(key) ?: return@mapNotNull null
            if (rawLevel.startsWith("_")) return@mapNotNull null
            val level = rawLevel.dropWhile { !it.isDigit() }
                .takeWhile { it.isDigit() }
                .take(2)
                .toIntOrNull()
                ?.takeIf { it > 0 } ?: return@mapNotNull null
            SDVXInChart(
                code = code,
                slot = slot,
                title = title,
                titleCompact = title.compact,
                level = level
            )
        }
    }

    private suspend fun reloadWikiIIDX(onProgress: (Float) -> Unit): Int {
        onProgress(0f)
        val songs = mutableListOf<IIDXSong>()
        var levels: Map<String, IIDXWikiLevels> = emptyMap()
        val latestDocument = runCatching {
            fetchDocument(IIDXVersionInfo.bemaniWikiLatestVersionPageURL)
        }.getOrNull()
        wikiDocumentBody(latestDocument)?.let { documentBody ->
            val children = documentBody.children()
            val indexOfHeader = children.indexOfFirst { element ->
                (element.tagName() == "h3" || element.tagName() == "h4") &&
                    element.text().contains("総ノーツ数")
            }
            if (indexOfHeader >= 0) {
                songs.addAll(noteCountRows(children.subList(indexOfHeader, children.size)))
            }
            levels = levelRows(
                if (indexOfHeader >= 0) children.subList(0, indexOfHeader) else children
            )
        }
        onProgress(0.5f)
        val existingDocument = runCatching {
            fetchDocument(IIDXVersionInfo.bemaniWikiExistingVersionsPageURL)
        }.getOrNull()
        wikiDocumentBody(existingDocument)?.let { documentBody ->
            songs.addAll(noteCountRows(documentBody.children()))
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
        dao.replaceIIDXSongs(requireEntries(merged.distinctBy { it.titleCompact }))
        onProgress(1f)
        return dao.iidxSongCount()
    }

    private fun wikiDocumentBody(document: Document?): Element? =
        document?.body()?.select("#contents")?.first()?.select("#body")?.first()

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
        wikiTableRows(elements).mapNotNull { columns ->
            val title = columns[0]
            if (title.isEmpty()) return@mapNotNull null
            val hasSP = !columns.subList(1, 6).all { it == "-" }
            val hasDP = !columns.subList(6, 10).all { it == "-" }
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

    private suspend fun reloadBM2DX(onProgress: (Float) -> Unit): Int {
        onProgress(0f)
        val payload = ungzipped(fetchBytes(BM2DX_NOTES_RADAR_URL)).toString(Charsets.UTF_8)
        val root = json.parseToJsonElement(payload).jsonObject
        val titles = root["mid"] as? JsonObject ?: throw ExternalDataUnavailableException()
        val entries = mutableListOf<NotesRadarEntry>()
        for ((playType, key) in listOf("SP" to "radar_sp", "DP" to "radar_dp")) {
            val charts = root[key] as? JsonArray ?: continue
            for (chartElement in charts) {
                val chart = chartElement as? JsonArray ?: continue
                if (chart.size < 10) continue
                val mid = chart[0].content() ?: continue
                val title = titles.string(mid) ?: continue
                val difficulty = chart[1].double()?.toInt() ?: continue
                entries.add(
                    NotesRadarEntry(
                        title = title,
                        titleCompact = title.compact,
                        playType = playType,
                        difficulty = difficulty,
                        noteCount = chart[3].double()?.toInt() ?: 0,
                        notes = chart[4].double() ?: 0.0,
                        chord = chart[5].double() ?: 0.0,
                        peak = chart[6].double() ?: 0.0,
                        charge = chart[7].double() ?: 0.0,
                        scratch = chart[8].double() ?: 0.0,
                        soflan = chart[9].double() ?: 0.0
                    )
                )
            }
        }
        dao.replaceNotesRadarEntries(
            requireEntries(entries.distinctBy { Triple(it.title, it.playType, it.difficulty) })
        )
        onProgress(1f)
        return dao.notesRadarCount()
    }

    private suspend fun reloadWikiDDR(onProgress: (Float) -> Unit): Int {
        onProgress(0f)
        val metas = mutableListOf<DDRSongMeta>()
        runCatching { fetchDocument(DDRVersionInfo.bemaniWikiOldSongsPageURL) }
            .getOrNull()
            ?.let { metas.addAll(parseDDRSongs(it, baseVersion = null)) }
        onProgress(0.5f)
        runCatching { fetchDocument(DDRVersionInfo.bemaniWikiNewSongsPageURL) }
            .getOrNull()
            ?.let {
                metas.addAll(parseDDRSongs(it, baseVersion = DDRVersionInfo.WORLD_VERSION_NUMBER))
            }
        dao.replaceDDRSongMetas(requireEntries(metas.distinctBy { it.titleCompact }))
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
        return result
    }

    private fun JsonObject.string(key: String): String? = this[key].content()

    private fun JsonObject.int(key: String): Int? = this[key].double()?.toInt()

    private fun JsonElement?.content(): String? =
        (this as? JsonPrimitive)?.takeUnless { it is JsonNull }?.content

    private fun JsonElement?.double(): Double? {
        val primitive = this as? JsonPrimitive ?: return null
        return primitive.doubleOrNull ?: primitive.intOrNull?.toDouble()
    }

    companion object {
        private const val TIMEOUT_MILLIS = 30_000
        private const val USER_AGENT =
            "Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 (KHTML, like Gecko) " +
                "Chrome/130.0.0.0 Mobile Safari/537.36"
        private const val TEXTAGE_TITLE_TABLE_URL = "https://textage.cc/score/titletbl.js"
        private const val TEXTAGE_ACCESS_TABLE_URL = "https://textage.cc/score/actbl.js"
        private const val TEXTAGE_CHART_VIEWER_URL =
            "https://textage-chart-viewer.vercel.app/api/songs"
        private const val SDVX_IN_DATA_SCRIPT_URL = "https://sdvx.in/sdvx/_/data.js"
        private const val SDVX_IN_FALLBACK_FILE_COUNT = 7
        private val SDVX_IN_SLOTS = listOf(
            "nov" to "n", "adv" to "a", "exh" to "e", "mxm" to "m", "ult" to "u"
        )
        private const val BM2DX_NOTES_RADAR_URL =
            "https://bm2dx.com/IIDX/notes_radar/notes_radar_data.json.gz"
    }
}
