package com.tsubuzaki.djdxgo.data

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

val Context.settingsDataStore by preferencesDataStore(name = "settings")

object SettingsKeys {
    val selectedGame = intPreferencesKey("Global.SelectedGame")
    val sdvxVersion = intPreferencesKey("Global.SDVX.Version")

    val showAnalytics = booleanPreferencesKey("More.General.ShowAnalytics")
    val showProfileHeader = booleanPreferencesKey("More.General.ShowProfileHeader")

    val iidxSortMode = stringPreferencesKey("ScoresView.SortMode")
    val iidxSortDescending = booleanPreferencesKey("ScoresView.SortDescending")
    val iidxPlayType = stringPreferencesKey("ScoresView.PlayTypeFilter")
    val iidxLevelFilters = stringSetPreferencesKey("ScoresView.LevelFilters")
    val iidxDifficultyFilters = stringSetPreferencesKey("ScoresView.DifficultyFilters")
    val iidxClearTypeFilters = stringSetPreferencesKey("ScoresView.ClearTypeFilters")
    val iidxDJLevelFilters = stringSetPreferencesKey("ScoresView.DJLevelFilters")
    val iidxVersionFilters = stringSetPreferencesKey("ScoresView.VersionFilters")
    val iidxScoreAvailableOnly = booleanPreferencesKey("ScoresView.ScoreAvailableOnlyFilter")
    val iidxBeginnerLevelHidden = booleanPreferencesKey("ScoresView.BeginnerLevelHidden")
    val iidxGenreVisible = booleanPreferencesKey("ScoresView.GenreVisible")
    val iidxArtistVisible = booleanPreferencesKey("ScoresView.ArtistVisible")
    val iidxLevelVisible = booleanPreferencesKey("ScoresView.LevelVisible")
    val iidxDJLevelVisible = booleanPreferencesKey("ScoresView.DJLevelVisible")
    val iidxScoreRateVisible = booleanPreferencesKey("ScoresView.ScoreRateVisible")
    val iidxScoreVisible = booleanPreferencesKey("ScoresView.ScoreVisible")
    val iidxLastPlayDateVisible = booleanPreferencesKey("ScoresView.LastPlayDateVisible")

    val sdvxSortMode = stringPreferencesKey("SDVXScoresView.SortMode")
    val sdvxSortDescending = booleanPreferencesKey("SDVXScoresView.SortDescending")
    val sdvxDifficultyFilters = stringSetPreferencesKey("SDVXScoresView.DifficultyFilters")
    val sdvxLevelFilters = stringSetPreferencesKey("SDVXScoresView.LevelBucketFilters")
    val sdvxClearTypeFilters = stringSetPreferencesKey("SDVXScoresView.ClearTypeFilters")
    val sdvxGradeFilters = stringSetPreferencesKey("SDVXScoresView.GradeFilters")

    val polarisChordSortMode = stringPreferencesKey("PolarisChordScoresView.SortMode")
    val polarisChordSortDescending = booleanPreferencesKey("PolarisChordScoresView.SortDescending")
    val polarisChordDifficultyFilters = stringSetPreferencesKey("PolarisChordScoresView.DifficultyFilters")
    val polarisChordLevelFilters = stringSetPreferencesKey("PolarisChordScoresView.LevelFilters")
    val polarisChordClearTypeFilters = stringSetPreferencesKey("PolarisChordScoresView.ClearTypeFilters")
    val polarisChordGradeFilters = stringSetPreferencesKey("PolarisChordScoresView.GradeFilters")

    val ddrSortMode = stringPreferencesKey("DDRScoresView.SortMode")
    val ddrSortDescending = booleanPreferencesKey("DDRScoresView.SortDescending")
    val ddrPlayStyle = stringPreferencesKey("Global.DDR.Style")
    val ddrDifficultyFilters = stringSetPreferencesKey("DDRScoresView.DifficultyFilters")
    val ddrLevelFilters = stringSetPreferencesKey("DDRScoresView.LevelFilters")
    val ddrClearLampFilters = stringSetPreferencesKey("DDRScoresView.ClearLampFilters")
    val ddrRankFilters = stringSetPreferencesKey("DDRScoresView.RankFilters")
    val ddrScoreAvailableOnly = booleanPreferencesKey("DDRScoresView.ScoreAvailableOnlyFilter")

    val externalTextageEnabled = booleanPreferencesKey("ExternalData.Textage.Enabled")
    val externalTextageChartViewerEnabled = booleanPreferencesKey("ExternalData.TextageChartViewer.Enabled")
    val externalSDVXInEnabled = booleanPreferencesKey("ExternalData.SDVXIn.Enabled")
    val externalBemaniWikiEnabled = booleanPreferencesKey("ExternalData.BemaniWiki2nd.Enabled")
    val externalBM2DXEnabled = booleanPreferencesKey("ExternalData.BM2DX.Enabled")
    val externalDDREnabled = booleanPreferencesKey("ExternalData.DDR.Enabled")

    val iidxCardOrder = stringPreferencesKey("Analytics.CardOrder")
    val iidxVisibleCards = stringSetPreferencesKey("Analytics.VisibleCards")
    val iidxPerLevelCardOrder = stringPreferencesKey("Analytics.PerLevelCardOrder")
    val iidxVisiblePerLevelCards = stringSetPreferencesKey("Analytics.VisiblePerLevelCards")
    val iidxCollapsedSections = stringSetPreferencesKey("Analytics.CollapsedSections")
    val sdvxCardOrder = stringPreferencesKey("Analytics.SDVX.CardOrder")
    val sdvxVisibleCards = stringSetPreferencesKey("Analytics.SDVX.VisibleCards")
    val sdvxCollapsedSections = stringSetPreferencesKey("Analytics.SDVX.CollapsedSections")
    val polarisChordCardOrder = stringPreferencesKey("Analytics.PolarisChord.CardOrder")
    val polarisChordVisibleCards = stringSetPreferencesKey("Analytics.PolarisChord.VisibleCards")
    val polarisChordCollapsedSections = stringSetPreferencesKey("Analytics.PolarisChord.CollapsedSections")
    val ddrCardOrder = stringPreferencesKey("Analytics.DDR.CardOrder")
    val ddrVisibleCards = stringSetPreferencesKey("Analytics.DDR.VisibleCards")
    val ddrCollapsedSections = stringSetPreferencesKey("Analytics.DDR.CollapsedSections")

    val onboardingLastSeenVersion = stringPreferencesKey("Onboarding.LastSeenVersion")
}

val analyticsLayoutKeys: List<Preferences.Key<*>> = listOf(
    SettingsKeys.iidxCardOrder,
    SettingsKeys.iidxVisibleCards,
    SettingsKeys.iidxPerLevelCardOrder,
    SettingsKeys.iidxVisiblePerLevelCards,
    SettingsKeys.iidxCollapsedSections,
    SettingsKeys.sdvxCardOrder,
    SettingsKeys.sdvxVisibleCards,
    SettingsKeys.sdvxCollapsedSections,
    SettingsKeys.polarisChordCardOrder,
    SettingsKeys.polarisChordVisibleCards,
    SettingsKeys.polarisChordCollapsedSections,
    SettingsKeys.ddrCardOrder,
    SettingsKeys.ddrVisibleCards,
    SettingsKeys.ddrCollapsedSections
)

fun <T> Context.settingFlow(key: Preferences.Key<T>, default: T): Flow<T> =
    settingsDataStore.data.map { it[key] ?: default }

fun <T> Context.optionalSettingFlow(key: Preferences.Key<T>): Flow<T?> =
    settingsDataStore.data.map { it[key] }

suspend fun <T> Context.setSetting(key: Preferences.Key<T>, value: T) {
    settingsDataStore.edit { it[key] = value }
}

suspend fun Context.removeSettings(keys: List<Preferences.Key<*>>) {
    settingsDataStore.edit { preferences -> keys.forEach { preferences.remove(it) } }
}
