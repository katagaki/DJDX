package com.tsubuzaki.djdxgo.data.iidx

import com.tsubuzaki.djdxgo.data.external.TextageChartViewerChart
import com.tsubuzaki.djdxgo.data.external.level
import com.tsubuzaki.djdxgo.data.external.textageScoreURL
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

class IIDXChartAnalyzer(private val cacheDirectory: File) {

    private val json = Json { ignoreUnknownKeys = true }
    private val mutex = Mutex()
    private val profiles = mutableMapOf<String, IIDXChartProfile>()
    private val inFlight = mutableMapOf<String, CompletableDeferred<IIDXChartProfile?>>()

    private val profileDirectory get() = File(cacheDirectory, "IIDXChartTraits")
    private val chartDirectory get() = File(cacheDirectory, "IIDXCharts")

    suspend fun profile(
        chart: TextageChartViewerChart,
        difficulty: IIDXLevel,
        playType: IIDXPlayType
    ): IIDXChartProfile? {
        val scoreURL = chart.textageScoreURL(difficulty, playType) ?: return null
        val level = chart.level(difficulty, playType)
        val key = listOf(chart.version.toString(), chart.songId, playType.code, difficulty.code, level.toString())
            .joinToString("_")

        val (deferred, isOwner) = mutex.withLock {
            profiles[key]?.let { return it }
            inFlight[key]?.let { return@withLock it to false }
            CompletableDeferred<IIDXChartProfile?>().also { inFlight[key] = it } to true
        }
        if (!isOwner) return deferred.await()

        val profile = withContext(Dispatchers.IO) { loadProfile(key, scoreURL, playType, level) }
        mutex.withLock {
            inFlight.remove(key)
            if (profile != null) profiles[key] = profile
        }
        deferred.complete(profile)
        return profile
    }

    private fun loadProfile(key: String, scoreURL: String, playType: IIDXPlayType, level: Int): IIDXChartProfile? {
        read<IIDXChartProfile>(profileDirectory, key)?.takeIf { it.isCurrent }?.let { return it }
        val cachedChart = read<IIDXChartData>(chartDirectory, key)
        val chartData = cachedChart ?: fetchChart(scoreURL) ?: return null
        val profile = runCatching { IIDXChartProfile.analyze(chartData, playType, level) }.getOrNull() ?: return null
        write(profileDirectory, key, json.encodeToString(IIDXChartProfile.serializer(), profile))
        if (cachedChart == null) {
            write(chartDirectory, key, json.encodeToString(IIDXChartData.serializer(), chartData))
        }
        return profile
    }

    private fun fetchChart(scoreURL: String): IIDXChartData? = runCatching {
        val connection = URL(ENDPOINT).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            connection.setRequestProperty("Content-Type", "application/json")
            val body = json.encodeToString(ChartRequest.serializer(), ChartRequest(scoreURL))
            connection.outputStream.use { it.write(body.toByteArray()) }
            if (connection.responseCode != HttpURLConnection.HTTP_OK) return null
            val response = connection.inputStream.bufferedReader().use { it.readText() }
            json.decodeFromString(ChartResponse.serializer(), response).data
        } finally {
            connection.disconnect()
        }
    }.getOrNull()

    private fun cacheFile(directory: File, key: String): File =
        File(directory, URLEncoder.encode(key, "UTF-8") + ".json")

    private inline fun <reified T> read(directory: File, key: String): T? = runCatching {
        json.decodeFromString<T>(cacheFile(directory, key).readText())
    }.getOrNull()

    private fun write(directory: File, key: String, contents: String) {
        runCatching {
            directory.mkdirs()
            cacheFile(directory, key).writeText(contents)
        }
    }

    @Serializable
    private data class ChartRequest(val url: String)

    @Serializable
    private data class ChartResponse(val data: IIDXChartData)

    private companion object {
        const val ENDPOINT = "https://textage-chart-viewer.vercel.app/api/chart"
    }
}
