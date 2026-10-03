package com.tsubuzaki.djdxgo.ui.analytics

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.EmojiEvents
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material.icons.outlined.WorkspacePremium
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.datastore.preferences.core.Preferences
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.analytics.ChartAnalytics
import com.tsubuzaki.djdxgo.data.analytics.ChartAnalyticsData
import com.tsubuzaki.djdxgo.data.analytics.DDRFilterOptions
import com.tsubuzaki.djdxgo.data.analytics.PolarisChordFilterOptions
import com.tsubuzaki.djdxgo.data.analytics.SDVXFilterOptions
import com.tsubuzaki.djdxgo.data.ddr.DDRClearLamp
import com.tsubuzaki.djdxgo.data.ddr.DDRPlayStyle
import com.tsubuzaki.djdxgo.data.ddr.DDRRank
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordClearType
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordDifficulty
import com.tsubuzaki.djdxgo.data.sdvx.SDVXClearType
import com.tsubuzaki.djdxgo.data.sdvx.SDVXDifficulty
import com.tsubuzaki.djdxgo.ui.Routes
import com.tsubuzaki.djdxgo.ui.iidx.rememberSetting
import com.tsubuzaki.djdxgo.ui.theme.DDRColors
import com.tsubuzaki.djdxgo.ui.theme.Palette
import com.tsubuzaki.djdxgo.ui.theme.PolarisChordColors
import com.tsubuzaki.djdxgo.ui.theme.SDVXColors

internal const val CHART_CARD_CLEAR_BREAKDOWN = "clearBreakdown"
internal const val CHART_CARD_GRADE_BREAKDOWN = "gradeBreakdown"
internal const val CHART_CARD_NEW_HIGH_SCORES = "newHighScores"
private const val CHART_CARD_NEW_CLEAR_PREFIX = "newClear:"
private const val CHART_CARD_NEW_GRADE_PREFIX = "newGrade:"
private const val SECTION_OVERVIEW = "overview"
private const val SECTION_LAST_PLAY = "lastPlay"

internal class ChartGameSpec(
    val game: Game,
    val orderKey: Preferences.Key<String>,
    val visibleKey: Preferences.Key<Set<String>>,
    val collapsedKey: Preferences.Key<Set<String>>,
    val clearKeys: List<String>,
    val gradeKeys: List<String>,
    val trackedClearTypes: List<String>,
    val trackedGrades: List<String>,
    val difficultyOrder: List<String>,
    val defaultVisible: (List<String>) -> Set<String>,
    val clearLabel: (String) -> String,
    val gradeLabel: (String) -> String,
    val clearColor: (String, Boolean) -> Color,
    val gradeColor: (String, Boolean) -> Color,
    val difficultyLabel: (String) -> String,
    val difficultyColor: (String) -> Color,
    val clearCaptionRes: Int,
    val gradeCaptionRes: Int,
    val clearIcon: (String) -> ImageVector
) {
    val lastPlayCards: List<String> =
        if (trackedClearTypes.isEmpty() && trackedGrades.isEmpty()) {
            emptyList()
        } else {
            listOf(CHART_CARD_NEW_HIGH_SCORES) +
                trackedClearTypes.map { CHART_CARD_NEW_CLEAR_PREFIX + it } +
                trackedGrades.map { CHART_CARD_NEW_GRADE_PREFIX + it }
        }

    val overviewCards: List<String> = listOf(CHART_CARD_CLEAR_BREAKDOWN, CHART_CARD_GRADE_BREAKDOWN)

    val defaultOrder: List<String> = overviewCards + lastPlayCards
}

internal val sdvxSpec = ChartGameSpec(
    game = Game.SOUND_VOLTEX,
    orderKey = SettingsKeys.sdvxCardOrder,
    visibleKey = SettingsKeys.sdvxVisibleCards,
    collapsedKey = SettingsKeys.sdvxCollapsedSections,
    clearKeys = ChartAnalytics.sdvxClearKeys,
    gradeKeys = ChartAnalytics.sdvxGradeKeys,
    trackedClearTypes = ChartAnalytics.sdvxTrackedClearTypes,
    trackedGrades = ChartAnalytics.sdvxTrackedGrades,
    difficultyOrder = ChartAnalytics.sdvxDifficultyOrder,
    defaultVisible = { order ->
        order.toSet() - listOf("AA+", "AA", "A+", "A").map { CHART_CARD_NEW_GRADE_PREFIX + it }.toSet()
    },
    clearLabel = { SDVXClearType.fromValue(it)?.abbreviation ?: it },
    gradeLabel = { it },
    clearColor = { value, _ -> SDVXColors.clearTypeColor(value) },
    gradeColor = { value, dark -> SDVXColors.gradeColor(value, dark) },
    difficultyLabel = { SDVXDifficulty.fromValue(it)?.abbreviation ?: it },
    difficultyColor = { SDVXColors.difficultyColor(it) },
    clearCaptionRes = R.string.analytics_clear_breakdown,
    gradeCaptionRes = R.string.analytics_grade_breakdown,
    clearIcon = { Icons.Outlined.CheckCircle }
)

internal val polarisChordSpec = ChartGameSpec(
    game = Game.POLARIS_CHORD,
    orderKey = SettingsKeys.polarisChordCardOrder,
    visibleKey = SettingsKeys.polarisChordVisibleCards,
    collapsedKey = SettingsKeys.polarisChordCollapsedSections,
    clearKeys = ChartAnalytics.polarisChordClearKeys,
    gradeKeys = ChartAnalytics.polarisChordGradeKeys,
    trackedClearTypes = ChartAnalytics.polarisChordTrackedClearTypes,
    trackedGrades = ChartAnalytics.polarisChordTrackedGrades,
    difficultyOrder = ChartAnalytics.polarisChordDifficultyOrder,
    defaultVisible = { it.toSet() },
    clearLabel = { PolarisChordClearType.fromValue(it)?.abbreviation ?: it },
    gradeLabel = { it },
    clearColor = { value, _ -> PolarisChordColors.clearTypeColor(value) },
    gradeColor = { value, _ -> PolarisChordColors.gradeColor(value) },
    difficultyLabel = { PolarisChordDifficulty.fromValue(it)?.abbreviation ?: it },
    difficultyColor = { PolarisChordColors.difficultyColor(it) },
    clearCaptionRes = R.string.analytics_clear_breakdown,
    gradeCaptionRes = R.string.analytics_grade_breakdown,
    clearIcon = {
        if (it == PolarisChordClearType.SUCCESS.value) Icons.Outlined.CheckCircle else Icons.Outlined.StarOutline
    }
)

internal val ddrSpec = ChartGameSpec(
    game = Game.DANCE_DANCE_REVOLUTION,
    orderKey = SettingsKeys.ddrCardOrder,
    visibleKey = SettingsKeys.ddrVisibleCards,
    collapsedKey = SettingsKeys.ddrCollapsedSections,
    clearKeys = ChartAnalytics.ddrClearKeys,
    gradeKeys = ChartAnalytics.ddrRankKeys,
    trackedClearTypes = emptyList(),
    trackedGrades = emptyList(),
    difficultyOrder = ChartAnalytics.ddrDifficultyOrder,
    defaultVisible = { it.toSet() },
    clearLabel = { DDRClearLamp.display(it) },
    gradeLabel = { DDRRank.display(it) },
    clearColor = { value, dark -> DDRColors.clearLampColor(value, dark) },
    gradeColor = { value, _ -> DDRColors.rankColor(value) },
    difficultyLabel = { it },
    difficultyColor = { DDRColors.difficultyColor(it) },
    clearCaptionRes = R.string.analytics_clear_breakdown,
    gradeCaptionRes = R.string.analytics_rank_breakdown,
    clearIcon = { Icons.Outlined.CheckCircle }
)

internal fun chartGameSpec(game: Game): ChartGameSpec = when (game) {
    Game.SOUND_VOLTEX -> sdvxSpec
    Game.POLARIS_CHORD -> polarisChordSpec
    else -> ddrSpec
}

@Composable
fun SDVXAnalyticsSection(container: AppContainer, isEditing: Boolean, onNavigate: (String) -> Unit) {
    val difficulties by rememberSetting(SettingsKeys.sdvxDifficultyFilters, emptySet())
    val levels by rememberSetting(SettingsKeys.sdvxLevelFilters, emptySet())
    val clearTypes by rememberSetting(SettingsKeys.sdvxClearTypeFilters, emptySet())
    val grades by rememberSetting(SettingsKeys.sdvxGradeFilters, emptySet())
    val dataVersion by container.dataVersion.collectAsState()
    val filters = SDVXFilterOptions(difficulties, levels, clearTypes, grades)
    LaunchedEffect(filters, dataVersion) { container.analyticsStore.reloadSDVX(filters) }
    val data by container.analyticsStore.sdvx.collectAsState()
    ChartAnalyticsSection(sdvxSpec, data ?: ChartAnalyticsData(), isEditing, onNavigate)
}

@Composable
fun PolarisChordAnalyticsSection(container: AppContainer, isEditing: Boolean, onNavigate: (String) -> Unit) {
    val difficulties by rememberSetting(SettingsKeys.polarisChordDifficultyFilters, emptySet())
    val levels by rememberSetting(SettingsKeys.polarisChordLevelFilters, emptySet())
    val clearTypes by rememberSetting(SettingsKeys.polarisChordClearTypeFilters, emptySet())
    val grades by rememberSetting(SettingsKeys.polarisChordGradeFilters, emptySet())
    val dataVersion by container.dataVersion.collectAsState()
    val filters = PolarisChordFilterOptions(difficulties, levels, clearTypes, grades)
    LaunchedEffect(filters, dataVersion) { container.analyticsStore.reloadPolarisChord(filters) }
    val data by container.analyticsStore.polarisChord.collectAsState()
    ChartAnalyticsSection(polarisChordSpec, data ?: ChartAnalyticsData(), isEditing, onNavigate)
}

@Composable
fun DDRAnalyticsSection(
    container: AppContainer,
    playStyle: DDRPlayStyle,
    isEditing: Boolean,
    onNavigate: (String) -> Unit
) {
    val onlyPlayed by rememberSetting(SettingsKeys.ddrScoreAvailableOnly, true)
    val difficulties by rememberSetting(SettingsKeys.ddrDifficultyFilters, emptySet())
    val levels by rememberSetting(SettingsKeys.ddrLevelFilters, emptySet())
    val clearLamps by rememberSetting(SettingsKeys.ddrClearLampFilters, emptySet())
    val ranks by rememberSetting(SettingsKeys.ddrRankFilters, emptySet())
    val dataVersion by container.dataVersion.collectAsState()
    val filters = DDRFilterOptions(onlyPlayed, difficulties, levels, clearLamps, ranks)
    LaunchedEffect(playStyle, filters, dataVersion) { container.analyticsStore.reloadDDR(playStyle, filters) }
    val data by container.analyticsStore.ddr.collectAsState()
    ChartAnalyticsSection(ddrSpec, data ?: ChartAnalyticsData(), isEditing, onNavigate)
}

@Composable
private fun ChartAnalyticsSection(
    spec: ChartGameSpec,
    data: ChartAnalyticsData,
    isEditing: Boolean,
    onNavigate: (String) -> Unit
) {
    val darkTheme = isSystemInDarkTheme()
    val layout = rememberCardLayout(
        spec.orderKey, spec.visibleKey, spec.collapsedKey,
        spec.defaultOrder, spec.defaultVisible(spec.defaultOrder)
    )
    Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
        val shownOverview = layout.shown(spec.overviewCards, isEditing)
        if (shownOverview.isNotEmpty()) {
            AnalyticsSection(
                title = stringResource(R.string.analytics_section_overview),
                section = SECTION_OVERVIEW,
                layout = layout,
                isEditing = isEditing
            ) {
                CardGrid(shownOverview) { id ->
                    EditableCard(
                        isEditing = isEditing,
                        isVisible = layout.isVisible(id),
                        onToggle = { layout.toggleVisible(id) },
                        canMoveBackward = layout.canMove(id, -1) { it in spec.overviewCards },
                        canMoveForward = layout.canMove(id, 1) { it in spec.overviewCards },
                        onMoveBackward = { layout.move(id, -1) { it in spec.overviewCards } },
                        onMoveForward = { layout.move(id, 1) { it in spec.overviewCards } }
                    ) {
                        val isClear = id == CHART_CARD_CLEAR_BREAKDOWN
                        val totals = if (isClear) {
                            data.totalClearCounts(spec.clearKeys)
                        } else {
                            data.totalGradeCounts(spec.gradeKeys)
                        }.filter { it.second > 0 }
                        OverviewCard(
                            caption = stringResource(if (isClear) spec.clearCaptionRes else spec.gradeCaptionRes),
                            contentHeight = 160.dp,
                            onClick = if (isEditing) {
                                null
                            } else {
                                {
                                    onNavigate(
                                        Routes.chartAnalytics(
                                            spec.game,
                                            if (isClear) {
                                                Routes.CHART_DETAIL_CLEAR_BREAKDOWN
                                            } else {
                                                Routes.CHART_DETAIL_GRADE_BREAKDOWN
                                            }
                                        )
                                    )
                                }
                            }
                        ) {
                            val labels = totals.associate {
                                (if (isClear) spec.clearLabel(it.first) else spec.gradeLabel(it.first)) to it.first
                            }
                            HorizontalBarChart(
                                entries = totals.map {
                                    (if (isClear) spec.clearLabel(it.first) else spec.gradeLabel(it.first)) to it.second
                                },
                                colorFor = { label ->
                                    val key = labels[label] ?: label
                                    if (isClear) spec.clearColor(key, darkTheme) else spec.gradeColor(key, darkTheme)
                                },
                                fillsHeight = true
                            )
                        }
                    }
                }
            }
        }

        val shownLastPlay = layout.shown(spec.lastPlayCards, isEditing)
        if (shownLastPlay.isNotEmpty()) {
            AnalyticsSection(
                title = stringResource(R.string.analytics_section_last_play),
                section = SECTION_LAST_PLAY,
                layout = layout,
                isEditing = isEditing
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState())
                        .padding(horizontal = 16.dp)
                        .height(IntrinsicSize.Min),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    shownLastPlay.forEach { id ->
                        val clearType = id.removePrefix(CHART_CARD_NEW_CLEAR_PREFIX).takeIf { id.startsWith(CHART_CARD_NEW_CLEAR_PREFIX) }
                        val grade = id.removePrefix(CHART_CARD_NEW_GRADE_PREFIX).takeIf { id.startsWith(CHART_CARD_NEW_GRADE_PREFIX) }
                        val count = when {
                            clearType != null -> data.newClears[clearType]?.size ?: 0
                            grade != null -> data.newGrades[grade]?.size ?: 0
                            else -> data.newHighScores.size
                        }
                        val route = when {
                            clearType != null -> Routes.chartAnalytics(spec.game, Routes.CHART_DETAIL_NEW_CLEARS, clearType)
                            grade != null -> Routes.chartAnalytics(spec.game, Routes.CHART_DETAIL_NEW_GRADES, grade)
                            else -> Routes.chartAnalytics(spec.game, Routes.CHART_DETAIL_NEW_HIGH_SCORES)
                        }
                        EditableCard(
                            isEditing = isEditing,
                            isVisible = layout.isVisible(id),
                            onToggle = { layout.toggleVisible(id) },
                            canMoveBackward = layout.canMove(id, -1) { it in spec.lastPlayCards },
                            canMoveForward = layout.canMove(id, 1) { it in spec.lastPlayCards },
                            onMoveBackward = { layout.move(id, -1) { it in spec.lastPlayCards } },
                            onMoveForward = { layout.move(id, 1) { it in spec.lastPlayCards } },
                            modifier = Modifier
                                .width(if (id == CHART_CARD_NEW_HIGH_SCORES) 150.dp else 110.dp)
                                .fillMaxHeight()
                        ) {
                            CountCard(
                                count = count,
                                title = when {
                                    clearType != null -> spec.clearLabel(clearType)
                                    grade != null -> grade
                                    else -> stringResource(R.string.analytics_new_record)
                                },
                                icon = when {
                                    clearType != null -> spec.clearIcon(clearType)
                                    grade != null -> Icons.Outlined.WorkspacePremium
                                    else -> Icons.Outlined.EmojiEvents
                                },
                                iconColor = when {
                                    clearType != null -> spec.clearColor(clearType, darkTheme)
                                    grade != null -> Palette.orange
                                    else -> MaterialTheme.colorScheme.onSurface
                                },
                                modifier = Modifier.fillMaxSize(),
                                onClick = if (isEditing) null else { { onNavigate(route) } }
                            )
                        }
                    }
                }
            }
        }
    }
}
