package com.tsubuzaki.djdxgo.data.tierlist

import android.content.Context
import android.net.Uri
import android.util.Base64
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.zip.Deflater
import java.util.zip.Inflater
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

enum class TierListTier(val code: String) {
    S("S"), A("A"), B("B"), C("C"), D("D"), E("E"), F("F")
}

data class TierListKey(val game: String, val playType: String, val level: String) {
    val storageKey: String get() = "$game/$playType/$level"
}

@Serializable
data class TierList(val tiers: Map<String, List<String>> = emptyMap()) {
    fun charts(tier: TierListTier): List<String> = tiers[tier.code].orEmpty()

    fun tierOf(chartID: String): TierListTier? =
        TierListTier.entries.firstOrNull { charts(it).contains(chartID) }

    val isEmpty: Boolean get() = tiers.values.all { it.isEmpty() }

    fun removing(chartID: String): TierList =
        TierList(tiers.mapValues { (_, ids) -> ids.filter { it != chartID } })

    fun placing(chartID: String, tier: TierListTier?, beforeID: String? = null): TierList {
        val removed = removing(chartID)
        if (tier == null) return removed
        val ids = removed.charts(tier).toMutableList()
        val index = beforeID?.let { ids.indexOf(it) } ?: -1
        if (index >= 0) ids.add(index, chartID) else ids.add(chartID)
        return TierList(removed.tiers + (tier.code to ids))
    }
}

@Serializable
data class TierListShare(
    @SerialName("v") val version: Int = 1,
    @SerialName("g") val game: String,
    @SerialName("p") val playType: String,
    @SerialName("l") val level: String,
    @SerialName("t") val tiers: Map<String, List<String>>
) {
    val key: TierListKey get() = TierListKey(game, playType, level)

    val code: String
        get() {
            val json = shareJson.encodeToString(serializer(), this).toByteArray(Charsets.UTF_8)
            val deflater = Deflater(Deflater.BEST_COMPRESSION, true)
            deflater.setInput(json)
            deflater.finish()
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(1024)
            while (!deflater.finished()) {
                output.write(buffer, 0, deflater.deflate(buffer))
            }
            deflater.end()
            return Base64.encodeToString(
                output.toByteArray(), Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP
            )
        }

    val url: String get() = "djdx://tierlist?code=$code"

    companion object {
        private val shareJson = Json { ignoreUnknownKeys = true; encodeDefaults = true }

        fun from(key: TierListKey, list: TierList): TierListShare = TierListShare(
            game = key.game,
            playType = key.playType,
            level = key.level,
            tiers = list.tiers.filterValues { it.isNotEmpty() }
        )

        fun decode(input: String): TierListShare? = runCatching {
            var code = input.trim()
            if (code.startsWith("djdx:")) {
                code = Uri.parse(code).getQueryParameter("code") ?: return null
            }
            val compressed = Base64.decode(code, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
            val inflater = Inflater(true)
            inflater.setInput(compressed)
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(1024)
            while (!inflater.finished()) {
                val count = inflater.inflate(buffer)
                if (count == 0 && (inflater.needsInput() || inflater.needsDictionary())) break
                output.write(buffer, 0, count)
            }
            inflater.end()
            shareJson.decodeFromString(serializer(), output.toString(Charsets.UTF_8.name()))
        }.getOrNull()
    }
}

class TierListStore(context: Context) {

    @Serializable
    private data class Snapshot(val version: Int = 1, val lists: Map<String, TierList> = emptyMap())

    private val file = File(context.filesDir, "TierLists.json")
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val state = MutableStateFlow(load())
    val lists: StateFlow<Map<String, TierList>> = state.asStateFlow()

    private fun load(): Map<String, TierList> = runCatching {
        json.decodeFromString(Snapshot.serializer(), file.readText()).lists
    }.getOrDefault(emptyMap())

    fun list(key: TierListKey): TierList = state.value[key.storageKey] ?: TierList()

    @Synchronized
    fun update(key: TierListKey, transform: (TierList) -> TierList) {
        replace(key, transform(list(key)))
    }

    @Synchronized
    fun replace(key: TierListKey, list: TierList) {
        val updated = if (list.isEmpty) state.value - key.storageKey else state.value + (key.storageKey to list)
        state.value = updated
        runCatching {
            file.writeText(json.encodeToString(Snapshot.serializer(), Snapshot(lists = updated)))
        }
    }
}
