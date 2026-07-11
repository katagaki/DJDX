package com.tsubuzaki.djdxgo.importer

import com.tsubuzaki.djdxgo.data.ddr.DDRVersionInfo
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.iidx.IIDXVersionInfo
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordVersionInfo
import com.tsubuzaki.djdxgo.data.sdvx.SDVXVersion

sealed interface WebImportResult {
    data class Success(val payload: String, val towerPayload: String?) : WebImportResult
    data class Failure(val reason: ImportFailedReason) : WebImportResult
    data object Cancelled : WebImportResult
}

data class WebImporterTowerChain(
    val towerPageURL: String,
    val isTowerPage: (String) -> Boolean,
    val extractionScript: (String) -> String
)

data class WebImporterSpec(
    val startURL: String,
    val isTargetPage: (String) -> Boolean,
    val isErrorPage: (String) -> Boolean,
    val extractionScript: (String) -> String,
    val watchdogSeconds: Int,
    val errorCodeReasons: Map<String, ImportFailedReason>,
    val emptyReason: ImportFailedReason,
    val towerChain: WebImporterTowerChain? = null
) {
    fun reasonForSentinel(sentinel: String): ImportFailedReason = when {
        sentinel == "maintenance" -> ImportFailedReason.MAINTENANCE
        sentinel == "empty" -> emptyReason
        sentinel == "network" || sentinel == "server" -> ImportFailedReason.SERVER_ERROR
        else -> errorCodeReasons[sentinel] ?: ImportFailedReason.SERVER_ERROR
    }
}

object WebImporterSpecs {

    private val iidxErrorCodes = mapOf(
        "1" to ImportFailedReason.NO_PREMIUM_COURSE,
        "2" to ImportFailedReason.NO_EAMUSEMENT_PASS,
        "3" to ImportFailedReason.NO_PLAY_DATA,
        "5" to ImportFailedReason.NO_PREMIUM_COURSE
    )

    private val sdvxErrorCodes = mapOf(
        "1" to ImportFailedReason.NO_PREMIUM_COURSE,
        "3" to ImportFailedReason.NO_EAMUSEMENT_PASS,
        "4" to ImportFailedReason.NO_PLAY_DATA
    )

    private val ddrErrorCodes = mapOf(
        "1" to ImportFailedReason.NO_PREMIUM_COURSE,
        "3" to ImportFailedReason.NO_EAMUSEMENT_PASS,
        "4" to ImportFailedReason.NO_PLAY_DATA
    )

    private val polarisChordErrorCodes = mapOf(
        "1" to ImportFailedReason.NO_PREMIUM_COURSE,
        "2" to ImportFailedReason.NO_EAMUSEMENT_PASS,
        "3" to ImportFailedReason.NO_PLAY_DATA,
        "5" to ImportFailedReason.NO_PREMIUM_COURSE
    )

    fun iidx(playType: IIDXPlayType): WebImporterSpec = WebImporterSpec(
        startURL = IIDXVersionInfo.loginPageRedirectURL(playType.code),
        isTargetPage = { it.contains("/djdata/score_download.html") },
        isErrorPage = { it.startsWith(IIDXVersionInfo.errorPageURL) },
        extractionScript = ImporterJavaScript::iidxScoreDataRead,
        watchdogSeconds = 25,
        errorCodeReasons = iidxErrorCodes,
        emptyReason = ImportFailedReason.NO_PLAY_DATA,
        towerChain = WebImporterTowerChain(
            towerPageURL = IIDXVersionInfo.downloadPageURL("tower"),
            isTowerPage = { it.contains("style=tower") },
            extractionScript = ImporterJavaScript::iidxScoreDataRead
        )
    )

    fun sdvx(version: SDVXVersion): WebImporterSpec = WebImporterSpec(
        startURL = version.loginPageRedirectURL(),
        isTargetPage = { it.contains("/playdata/download/index.html") },
        isErrorPage = { it.startsWith(version.errorPageURL) },
        extractionScript = ImporterJavaScript::sdvxScoreDataFetch,
        watchdogSeconds = 25,
        errorCodeReasons = sdvxErrorCodes,
        emptyReason = ImportFailedReason.NO_PLAY_DATA
    )

    fun polarisChord(): WebImporterSpec = WebImporterSpec(
        startURL = PolarisChordVersionInfo.loginPageRedirectURL(),
        isTargetPage = { it.contains("/playdata/music_data.html") },
        isErrorPage = { false },
        extractionScript = ImporterJavaScript::polarisChordScoreDataFetch,
        watchdogSeconds = 25,
        errorCodeReasons = polarisChordErrorCodes,
        emptyReason = ImportFailedReason.NO_PLAY_DATA
    )

    fun ddr(): WebImporterSpec = WebImporterSpec(
        startURL = DDRVersionInfo.loginPageRedirectURL(),
        isTargetPage = { it.contains("/playdata/music_data_single.html") },
        isErrorPage = { it.contains("/error/") },
        extractionScript = ImporterJavaScript::ddrScoreDataFetch,
        watchdogSeconds = 120,
        errorCodeReasons = ddrErrorCodes,
        emptyReason = ImportFailedReason.NO_PLAY_DATA
    )
}
