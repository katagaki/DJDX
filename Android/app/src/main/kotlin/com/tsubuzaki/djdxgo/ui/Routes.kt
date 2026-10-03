package com.tsubuzaki.djdxgo.ui

import android.net.Uri
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.external.SDVXInChart

object Routes {
    const val SCORES = "scores"
    const val IMPORT = "import"
    const val EXTERNAL_DATA = "externalData"
    const val ATTRIBUTIONS = "attributions"
    const val RADAR_MAKER = "radarMaker"

    const val IIDX_VIEWER = "viewer/iidx?title={title}&playType={playType}&level={level}&date={date}"
    const val SDVX_VIEWER = "viewer/sdvx?title={title}&date={date}&difficulty={difficulty}"
    const val TEXTAGE_VIEWER = "viewer/textage?legacy={legacy}&chart={chart}"
    const val SDVX_IN_VIEWER = "viewer/sdvxin?legacy={legacy}&viewer={viewer}&data={data}"
    const val TOWER = "tower?mode={mode}"
    const val IIDX_ANALYTICS = "analytics/iidx/{detail}?param={param}"
    const val CHART_ANALYTICS = "analytics/chart/{game}/{detail}?param={param}"

    const val IIDX_DETAIL_CLEAR_TYPE_OVERVIEW = "clearTypeOverview"
    const val IIDX_DETAIL_GRADE_BREAKDOWN = "gradeBreakdown"
    const val IIDX_DETAIL_CLEAR_TYPE_LEVEL = "clearTypeLevel"
    const val IIDX_DETAIL_DJ_LEVEL_LEVEL = "djLevelLevel"
    const val IIDX_DETAIL_NEW_ENTRIES = "newEntries"

    const val CHART_DETAIL_CLEAR_BREAKDOWN = "clearBreakdown"
    const val CHART_DETAIL_GRADE_BREAKDOWN = "gradeBreakdown"
    const val CHART_DETAIL_NEW_HIGH_SCORES = "newHighScores"
    const val CHART_DETAIL_NEW_CLEARS = "newClears"
    const val CHART_DETAIL_NEW_GRADES = "newGrades"

    const val TOWER_RECENT = "recent"
    const val TOWER_TOTALS = "totals"

    fun iidxViewer(title: String, playType: String, level: String, date: Long): String =
        "viewer/iidx?title=${Uri.encode(title)}&playType=${Uri.encode(playType)}" +
            "&level=${Uri.encode(level)}&date=$date"

    fun sdvxViewer(title: String, date: Long, difficulty: String): String =
        "viewer/sdvx?title=${Uri.encode(title)}&date=$date&difficulty=${Uri.encode(difficulty)}"

    fun textageViewer(legacyURL: String?, chartViewerURL: String?): String =
        "viewer/textage?legacy=${Uri.encode(legacyURL.orEmpty())}&chart=${Uri.encode(chartViewerURL.orEmpty())}"

    fun sdvxInViewer(chart: SDVXInChart): String =
        "viewer/sdvxin?legacy=${Uri.encode(chart.legacyPageURL)}" +
            "&viewer=${Uri.encode(chart.viewerPageURL)}&data=${Uri.encode(chart.viewerDataURL)}"

    fun tower(mode: String): String = "tower?mode=$mode"

    fun iidxAnalytics(detail: String, param: String = ""): String =
        "analytics/iidx/$detail?param=${Uri.encode(param)}"

    fun chartAnalytics(game: Game, detail: String, param: String = ""): String =
        "analytics/chart/${game.id}/$detail?param=${Uri.encode(param)}"
}
