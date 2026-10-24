package com.tsubuzaki.djdxgo.data.profile

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.webkit.CookieManager
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import com.tsubuzaki.djdxgo.data.RadarData
import com.tsubuzaki.djdxgo.data.ddr.DDRPlayStyle
import com.tsubuzaki.djdxgo.data.ddr.DDRVersionInfo
import com.tsubuzaki.djdxgo.data.iidx.IIDXVersionInfo
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordVersionInfo
import com.tsubuzaki.djdxgo.data.sdvx.SDVXVersion
import com.tsubuzaki.djdxgo.data.settingsDataStore
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import org.jsoup.Jsoup
import org.jsoup.nodes.Document

data class IIDXProfile(
    val djName: String? = null,
    val spRank: String? = null,
    val dpRank: String? = null,
    val qpro: Bitmap? = null,
    val spRadar: RadarData? = null,
    val dpRadar: RadarData? = null
) {
    val hasData: Boolean
        get() = qpro != null || djName != null || spRadar != null || dpRadar != null
}

data class SDVXProfile(
    val playerName: String? = null,
    val volforce: String? = null,
    val apCard: Bitmap? = null,
    val volforceIcon: Bitmap? = null
) {
    val hasData: Boolean
        get() = apCard != null || playerName != null || volforceIcon != null || volforce != null
}

data class PolarisChordProfile(
    val playerName: String? = null,
    val title: String? = null,
    val paClass: String? = null,
    val paSkill: String? = null,
    val paClassIcon: Bitmap? = null,
    val paSkillIcon: Bitmap? = null
) {
    val hasData: Boolean
        get() = playerName != null || title != null || paClass != null || paSkill != null
}

data class DDRProfile(
    val dancerName: String? = null,
    val flareSkill: Map<DDRPlayStyle, String> = emptyMap(),
    val flareIcon: Map<DDRPlayStyle, Bitmap> = emptyMap(),
    val danRank: Map<DDRPlayStyle, Bitmap> = emptyMap()
) {
    val hasData: Boolean
        get() = dancerName != null || flareSkill.isNotEmpty() || flareIcon.isNotEmpty() || danRank.isNotEmpty()
}

class ProfileRepository(private val context: Context) {

    private val imagesDirectory = File(context.filesDir, "images")
    private val json = Json { ignoreUnknownKeys = true }

    private val iidxState = MutableStateFlow(IIDXProfile())
    private val sdvxState = MutableStateFlow(SDVXProfile())
    private val polarisChordState = MutableStateFlow(PolarisChordProfile())
    private val ddrState = MutableStateFlow(DDRProfile())

    val iidx: StateFlow<IIDXProfile> = iidxState.asStateFlow()
    val sdvx: StateFlow<SDVXProfile> = sdvxState.asStateFlow()
    val polarisChord: StateFlow<PolarisChordProfile> = polarisChordState.asStateFlow()
    val ddr: StateFlow<DDRProfile> = ddrState.asStateFlow()

    suspend fun loadCached() = withContext(Dispatchers.IO) {
        val preferences = context.settingsDataStore.data.first()
        iidxState.value = IIDXProfile(
            djName = preferences[Keys.iidxDJName],
            spRank = preferences[Keys.iidxSPRank],
            dpRank = preferences[Keys.iidxDPRank],
            qpro = loadImage(QPRO_FILE),
            spRadar = radar(preferences, "SP"),
            dpRadar = radar(preferences, "DP")
        )
        sdvxState.value = SDVXProfile(
            playerName = preferences[Keys.sdvxPlayerName],
            volforce = preferences[Keys.sdvxVolforce],
            apCard = loadImage(SDVX_AP_CARD_FILE),
            volforceIcon = loadImage(SDVX_VOLFORCE_ICON_FILE)
        )
        polarisChordState.value = PolarisChordProfile(
            playerName = preferences[Keys.polarisChordPlayerName],
            title = preferences[Keys.polarisChordTitle],
            paClass = preferences[Keys.polarisChordPAClass],
            paSkill = preferences[Keys.polarisChordPASkill],
            paClassIcon = loadImage(POLARIS_CHORD_PA_CLASS_ICON_FILE),
            paSkillIcon = loadImage(POLARIS_CHORD_PA_SKILL_ICON_FILE)
        )
        ddrState.value = DDRProfile(
            dancerName = preferences[Keys.ddrDancerName],
            flareSkill = DDRPlayStyle.entries.mapNotNull { style ->
                preferences[Keys.ddrFlareSkill(style)]?.let { style to it }
            }.toMap(),
            flareIcon = DDRPlayStyle.entries.mapNotNull { style ->
                loadImage(ddrFlareIconFile(style))?.let { style to it }
            }.toMap(),
            danRank = DDRPlayStyle.entries.mapNotNull { style ->
                loadImage(ddrDanRankFile(style))?.let { style to it }
            }.toMap()
        )
    }

    suspend fun refreshIIDX() = withContext(Dispatchers.IO) {
        runCatching {
            val document = fetchDocument(IIDXVersionInfo.statusPageURL)
            document.select("div.qpro-img img").first()?.attr("src")?.takeIf { it.isNotEmpty() }
                ?.let { downloadImage(absoluteURL(it), QPRO_FILE) }
            var djName: String? = null
            document.select("div.dj-profile table tr").forEach { row ->
                val cells = row.select("td")
                if (cells.size == 2 && cells[0].text() == "DJ NAME") djName = cells[1].text()
            }
            var spRank: String? = null
            var dpRank: String? = null
            document.select("div.dj-rank").forEach { section ->
                if (section.select("div.cat-name").first()?.text() != "段位認定") return@forEach
                section.select("div.rank-cat").forEach { category ->
                    val label = category.select("span").first()?.text()
                    val children = category.children()
                    if (children.size == 2) {
                        val rank = children[1].text()
                        if (label == "SP") spRank = rank else if (label == "DP") dpRank = rank
                    }
                }
            }
            var spRadar: RadarData? = null
            var dpRadar: RadarData? = null
            document.select("div#notes div.rank-cat").forEach { category ->
                val label = category.select("span").first()?.text() ?: return@forEach
                val values = mutableMapOf<String, Double>()
                category.select("ul li").forEach { item ->
                    val paragraphs = item.select("p")
                    if (paragraphs.size == 2) {
                        paragraphs[1].text().toDoubleOrNull()?.let { values[paragraphs[0].text()] = it }
                    }
                }
                val radar = RadarData(
                    notes = values["NOTES"] ?: 0.0,
                    chord = values["CHORD"] ?: 0.0,
                    peak = values["PEAK"] ?: 0.0,
                    charge = values["CHARGE"] ?: 0.0,
                    scratch = values["SCRATCH"] ?: 0.0,
                    soflan = values["SOF-LAN"] ?: 0.0
                )
                if (label == "SP") spRadar = radar else if (label == "DP") dpRadar = radar
            }
            context.settingsDataStore.edit { preferences ->
                preferences.setOrRemove(Keys.iidxDJName, djName)
                preferences.setOrRemove(Keys.iidxSPRank, spRank)
                preferences.setOrRemove(Keys.iidxDPRank, dpRank)
                spRadar?.let { preferences.setRadar("SP", it) }
                dpRadar?.let { preferences.setRadar("DP", it) }
            }
        }
        loadCached()
    }

    suspend fun refreshSDVX(version: SDVXVersion) = withContext(Dispatchers.IO) {
        runCatching {
            val document = fetchDocument(version.profilePageURL)
            document.select("#apcard img").first()?.attr("src")?.takeIf { it.isNotEmpty() }
                ?.let { downloadImage(absoluteURL(it), SDVX_AP_CARD_FILE) }
            val name = document.select("#player_name p").map { it.text().trim() }
                .filter { it.isNotEmpty() }
                .joinToString("\n")
            val forceNumber = document.select(".force_class").first()?.id()?.removePrefix("force_")
            if (!forceNumber.isNullOrEmpty()) {
                downloadImage(version.volforceIconURL(forceNumber), SDVX_VOLFORCE_ICON_FILE)
            }
            val volforce = document.select("#force_point").first()?.text()?.trim()
            context.settingsDataStore.edit { preferences ->
                if (name.isNotEmpty()) preferences[Keys.sdvxPlayerName] = name
                if (!volforce.isNullOrEmpty()) preferences[Keys.sdvxVolforce] = volforce
            }
        }
        loadCached()
    }

    suspend fun refreshPolarisChord() = withContext(Dispatchers.IO) {
        runCatching {
            val body = fetchBytes(
                PolarisChordVersionInfo.playDataEndpointURL,
                postBody = "service_kind=profile&pdata_kind=profile"
            ).toString(Charsets.UTF_8)
            val root = json.parseToJsonElement(body) as? JsonObject ?: return@runCatching
            val playData = ((root["data"] as? JsonObject)?.get("play_data") as? JsonObject)
                ?: return@runCatching
            val profile = playData["usr_profile"] as? JsonObject
            val name = profile?.string("usr_name")
            val paClass = profile?.string("pa_class")
            val paSkill = profile?.string("pa_skill")
            val title = (playData["usr_nametag"] as? JsonObject)?.string("set_title_name")?.trim()
            if (paClass != null) {
                downloadImage(PolarisChordVersionInfo.paClassIconURL, POLARIS_CHORD_PA_CLASS_ICON_FILE)
            }
            if (paSkill != null) {
                downloadImage(
                    PolarisChordVersionInfo.paSkillIconURL(paSkill.toDoubleOrNull() ?: 0.0),
                    POLARIS_CHORD_PA_SKILL_ICON_FILE
                )
            }
            context.settingsDataStore.edit { preferences ->
                if (!name.isNullOrEmpty()) preferences[Keys.polarisChordPlayerName] = name
                if (paClass != null) preferences[Keys.polarisChordPAClass] = paClass
                if (paSkill != null) preferences[Keys.polarisChordPASkill] = paSkill
                if (!title.isNullOrEmpty()) preferences[Keys.polarisChordTitle] = title
            }
        }
        loadCached()
    }

    suspend fun refreshDDR() = withContext(Dispatchers.IO) {
        runCatching {
            val document = fetchDocument(DDRVersionInfo.profilePageURL)
            var dancerName: String? = null
            for (row in document.select("#sougou tr")) {
                if (row.select("th").first()?.text()?.trim() != "DANCER NAME") continue
                dancerName = row.select("td").first()?.text()?.trim()?.takeIf { it.isNotEmpty() }
                break
            }
            val flareSkills = mutableMapOf<DDRPlayStyle, String>()
            document.select("td.total-flare-skill").forEachIndexed { index, cell ->
                val style = DDRPlayStyle.entries.getOrNull(index) ?: return@forEachIndexed
                cell.select(".total-flare-skill-value").first()?.text()?.trim()
                    ?.takeIf { it.isNotEmpty() }
                    ?.let { flareSkills[style] = it }
                cell.select("img.flare-rank").first()?.attr("src")?.takeIf { it.isNotEmpty() }
                    ?.let { downloadImage(absoluteURL(it), ddrFlareIconFile(style)) }
            }
            document.select(".danrank-grade img").forEachIndexed { index, image ->
                val style = DDRPlayStyle.entries.getOrNull(index) ?: return@forEachIndexed
                image.attr("src").takeIf { it.isNotEmpty() }
                    ?.let { downloadImage(absoluteURL(it), ddrDanRankFile(style)) }
            }
            context.settingsDataStore.edit { preferences ->
                dancerName?.let { preferences[Keys.ddrDancerName] = it }
                flareSkills.forEach { (style, value) -> preferences[Keys.ddrFlareSkill(style)] = value }
            }
        }
        loadCached()
    }

    private fun JsonObject.string(key: String): String? {
        val primitive = this[key] as? JsonPrimitive ?: return null
        return primitive.content.takeIf { it.isNotEmpty() && it != "null" }
    }

    private fun absoluteURL(source: String): String =
        if (source.startsWith("http")) source else URL(URL(IIDXVersionInfo.EAGATE_BASE_URL), source).toString()

    private suspend fun cookies(url: String): String? =
        withContext(Dispatchers.Main) { CookieManager.getInstance().getCookie(url) }

    private suspend fun fetchBytes(url: String, postBody: String? = null): ByteArray {
        val cookie = cookies(url)
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = TIMEOUT_MILLIS
        connection.readTimeout = TIMEOUT_MILLIS
        connection.instanceFollowRedirects = true
        cookie?.let { connection.setRequestProperty("Cookie", it) }
        if (postBody != null) {
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
            connection.outputStream.use { it.write(postBody.toByteArray()) }
        }
        try {
            val status = connection.responseCode
            if (status !in 200..299) throw IOException("HTTP $status")
            return connection.inputStream.use { it.readBytes() }
        } finally {
            connection.disconnect()
        }
    }

    private suspend fun fetchDocument(url: String): Document =
        Jsoup.parse(fetchBytes(url).toString(Charsets.UTF_8), url)

    private suspend fun downloadImage(url: String, fileName: String) {
        runCatching {
            val bytes = fetchBytes(url)
            if (BitmapFactory.decodeByteArray(bytes, 0, bytes.size) == null) return
            imagesDirectory.mkdirs()
            File(imagesDirectory, fileName).writeBytes(bytes)
        }
    }

    private fun loadImage(fileName: String): Bitmap? {
        val file = File(imagesDirectory, fileName)
        if (!file.exists()) return null
        return BitmapFactory.decodeFile(file.path)
    }

    private fun radar(preferences: Preferences, playType: String): RadarData? {
        val notes = preferences[Keys.radar(playType, "Notes")] ?: return null
        return RadarData(
            notes = notes,
            chord = preferences[Keys.radar(playType, "Chord")] ?: 0.0,
            peak = preferences[Keys.radar(playType, "Peak")] ?: 0.0,
            charge = preferences[Keys.radar(playType, "Charge")] ?: 0.0,
            scratch = preferences[Keys.radar(playType, "Scratch")] ?: 0.0,
            soflan = preferences[Keys.radar(playType, "Soflan")] ?: 0.0
        )
    }

    private fun androidx.datastore.preferences.core.MutablePreferences.setRadar(
        playType: String,
        radar: RadarData
    ) {
        this[Keys.radar(playType, "Notes")] = radar.notes
        this[Keys.radar(playType, "Chord")] = radar.chord
        this[Keys.radar(playType, "Peak")] = radar.peak
        this[Keys.radar(playType, "Charge")] = radar.charge
        this[Keys.radar(playType, "Scratch")] = radar.scratch
        this[Keys.radar(playType, "Soflan")] = radar.soflan
    }

    private fun androidx.datastore.preferences.core.MutablePreferences.setOrRemove(
        key: Preferences.Key<String>,
        value: String?
    ) {
        if (value != null) this[key] = value else remove(key)
    }

    private fun ddrFlareIconFile(style: DDRPlayStyle) = "DDRProfile.FlareIcon.${style.value}.png"

    private fun ddrDanRankFile(style: DDRPlayStyle) = "DDRProfile.DanRank.${style.value}.png"

    private object Keys {
        val iidxDJName = stringPreferencesKey("Profile.IIDX.DJName")
        val iidxSPRank = stringPreferencesKey("Profile.IIDX.SPRank")
        val iidxDPRank = stringPreferencesKey("Profile.IIDX.DPRank")
        val sdvxPlayerName = stringPreferencesKey("SDVXProfile.PlayerName")
        val sdvxVolforce = stringPreferencesKey("SDVXProfile.Volforce")
        val polarisChordPlayerName = stringPreferencesKey("PolarisChordProfile.PlayerName")
        val polarisChordTitle = stringPreferencesKey("PolarisChordProfile.Title")
        val polarisChordPAClass = stringPreferencesKey("PolarisChordProfile.PAClass")
        val polarisChordPASkill = stringPreferencesKey("PolarisChordProfile.PASkill")
        val ddrDancerName = stringPreferencesKey("DDRProfile.DancerName")

        fun ddrFlareSkill(style: DDRPlayStyle) = stringPreferencesKey("DDRProfile.FlareSkill.${style.value}")

        fun radar(playType: String, axis: String) = doublePreferencesKey("NotesRadar.$playType.$axis")
    }

    companion object {
        private const val TIMEOUT_MILLIS = 20_000
        private const val QPRO_FILE = "Qpro.png"
        private const val SDVX_AP_CARD_FILE = "APCard.png"
        private const val SDVX_VOLFORCE_ICON_FILE = "VolforceIcon.png"
        private const val POLARIS_CHORD_PA_CLASS_ICON_FILE = "PolarisChordProfile.PAClassIcon.png"
        private const val POLARIS_CHORD_PA_SKILL_ICON_FILE = "PolarisChordProfile.PASkillIcon.png"
    }
}
