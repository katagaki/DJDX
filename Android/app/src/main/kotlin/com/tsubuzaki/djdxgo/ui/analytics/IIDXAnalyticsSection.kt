package com.tsubuzaki.djdxgo.ui.analytics

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.EmojiEvents
import androidx.compose.material.icons.outlined.Report
import androidx.compose.material.icons.outlined.Speed
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material.icons.outlined.VerifiedUser
import androidx.compose.material.icons.outlined.Whatshot
import androidx.compose.material.icons.outlined.WorkspacePremium
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.analytics.IIDXAnalyticsData
import com.tsubuzaki.djdxgo.data.analytics.IIDXFilterOptions
import com.tsubuzaki.djdxgo.data.analytics.IIDXNewEntryKind
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.iidx.IIDXDJLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.ui.Routes
import com.tsubuzaki.djdxgo.ui.iidx.rememberSetting
import com.tsubuzaki.djdxgo.ui.theme.IIDXColors
import com.tsubuzaki.djdxgo.ui.theme.Palette

private const val SECTION_OVERVIEW = "overview"
private const val SECTION_LAST_PLAY = "lastPlay"
private const val SECTION_PER_LEVEL = "perLevel"

private const val CARD_CLEAR_TYPE_OVERALL = "clearTypeOverall"
private const val CARD_GRADE_BREAKDOWN = "gradeBreakdown"
private const val CARD_TOWER_RECENT = "towerRecent"
private const val CARD_TOWER_TOTALS = "towerTotals"

private val overviewCards = listOf(
    CARD_CLEAR_TYPE_OVERALL, CARD_GRADE_BREAKDOWN, CARD_TOWER_TOTALS, CARD_TOWER_RECENT
)
private val summaryCards = listOf(
    IIDXNewEntryKind.HIGH_SCORES, IIDXNewEntryKind.AAA, IIDXNewEntryKind.AA, IIDXNewEntryKind.A,
    IIDXNewEntryKind.FULL_COMBO_CLEAR, IIDXNewEntryKind.CLEAR, IIDXNewEntryKind.EASY_CLEAR,
    IIDXNewEntryKind.ASSIST_CLEAR, IIDXNewEntryKind.HARD_CLEAR, IIDXNewEntryKind.EX_HARD_CLEAR,
    IIDXNewEntryKind.FAILED
)
private val defaultCardOrder = overviewCards + summaryCards.map { it.key }
private val defaultVisibleCards = setOf(
    CARD_GRADE_BREAKDOWN, CARD_TOWER_TOTALS,
    IIDXNewEntryKind.HIGH_SCORES.key, IIDXNewEntryKind.CLEAR.key, IIDXNewEntryKind.ASSIST_CLEAR.key
)

enum class PerLevelCategory(val key: String) {
    CLEAR_RATE("clearRate"),
    CLEAR_RATE_TREND("clearRateTrend"),
    DJ_LEVEL("djLevel"),
    DJ_LEVEL_TREND("djLevelTrend");

    val isClearType: Boolean
        get() = this == CLEAR_RATE || this == CLEAR_RATE_TREND

    val showsBar: Boolean
        get() = this == CLEAR_RATE || this == DJ_LEVEL
}

private fun perLevelCardID(difficulty: Int, category: PerLevelCategory) = "${difficulty}_${category.key}"

private val defaultPerLevelOrder = (1..12).flatMap { difficulty ->
    PerLevelCategory.entries.map { perLevelCardID(difficulty, it) }
}
private val defaultVisiblePerLevelCards = listOf(1, 12).flatMap { difficulty ->
    listOf(PerLevelCategory.CLEAR_RATE, PerLevelCategory.CLEAR_RATE_TREND)
        .map { perLevelCardID(difficulty, it) }
}.toSet()

@Composable
fun rememberIIDXFilterOptions(): IIDXFilterOptions {
    val onlyScores by rememberSetting(SettingsKeys.iidxScoreAvailableOnly, true)
    val levels by rememberSetting(SettingsKeys.iidxLevelFilters, emptySet())
    val difficulties by rememberSetting(SettingsKeys.iidxDifficultyFilters, emptySet())
    val clearTypes by rememberSetting(SettingsKeys.iidxClearTypeFilters, emptySet())
    val djLevels by rememberSetting(SettingsKeys.iidxDJLevelFilters, emptySet())
    val versions by rememberSetting(SettingsKeys.iidxVersionFilters, emptySet())
    return IIDXFilterOptions(onlyScores, levels, difficulties, clearTypes, djLevels, versions)
}

@Composable
fun IIDXAnalyticsSection(
    container: AppContainer,
    playType: IIDXPlayType,
    isEditing: Boolean,
    onNavigate: (String) -> Unit
) {
    val filters = rememberIIDXFilterOptions()
    val dataVersion by container.dataVersion.collectAsState()
    LaunchedEffect(playType, filters, dataVersion) {
        container.analyticsStore.reloadIIDX(playType, filters)
    }
    val data by container.analyticsStore.iidx.collectAsState()
    val analytics = data ?: IIDXAnalyticsData()
    val layout = rememberCardLayout(
        SettingsKeys.iidxCardOrder, SettingsKeys.iidxVisibleCards, SettingsKeys.iidxCollapsedSections,
        defaultCardOrder, defaultVisibleCards
    )
    val perLevelLayout = rememberCardLayout(
        SettingsKeys.iidxPerLevelCardOrder, SettingsKeys.iidxVisiblePerLevelCards,
        SettingsKeys.iidxCollapsedSections, defaultPerLevelOrder, defaultVisiblePerLevelCards
    )

    Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
        val shownOverview = layout.shown(overviewCards, isEditing)
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
                        canMoveBackward = layout.canMove(id, -1) { it in overviewCards },
                        canMoveForward = layout.canMove(id, 1) { it in overviewCards },
                        onMoveBackward = { layout.move(id, -1) { it in overviewCards } },
                        onMoveForward = { layout.move(id, 1) { it in overviewCards } }
                    ) {
                        OverviewCardContent(id, analytics, isEditing, onNavigate)
                    }
                }
            }
        }

        val summaryIDs = summaryCards.map { it.key }
        val shownSummary = layout.shown(summaryIDs, isEditing)
        if (shownSummary.isNotEmpty()) {
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
                    shownSummary.forEach { id ->
                        val kind = IIDXNewEntryKind.fromKey(id) ?: return@forEach
                        val isGradeCard = kind == IIDXNewEntryKind.AAA ||
                            kind == IIDXNewEntryKind.AA || kind == IIDXNewEntryKind.A
                        EditableCard(
                            isEditing = isEditing,
                            isVisible = layout.isVisible(id),
                            onToggle = { layout.toggleVisible(id) },
                            canMoveBackward = layout.canMove(id, -1) { it in summaryIDs },
                            canMoveForward = layout.canMove(id, 1) { it in summaryIDs },
                            onMoveBackward = { layout.move(id, -1) { it in summaryIDs } },
                            onMoveForward = { layout.move(id, 1) { it in summaryIDs } },
                            modifier = Modifier
                                .width(if (isGradeCard) 96.dp else 150.dp)
                                .fillMaxHeight()
                        ) {
                            CountCard(
                                count = analytics.newEntries(kind).size,
                                title = newEntryTitle(kind),
                                icon = newEntryIcon(kind),
                                iconColor = newEntryColor(kind),
                                modifier = Modifier.fillMaxSize(),
                                onClick = if (isEditing) {
                                    null
                                } else {
                                    { onNavigate(Routes.iidxAnalytics(Routes.IIDX_DETAIL_NEW_ENTRIES, kind.key)) }
                                }
                            )
                        }
                    }
                }
            }
        }

        val shownPerLevel = perLevelLayout.shown(defaultPerLevelOrder, isEditing)
        if (shownPerLevel.isNotEmpty()) {
            AnalyticsSection(
                title = stringResource(R.string.analytics_section_per_level),
                section = SECTION_PER_LEVEL,
                layout = perLevelLayout,
                isEditing = isEditing
            ) {
                Column(
                    modifier = Modifier.padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    shownPerLevel.forEach { id ->
                        val difficulty = id.substringBefore("_").toIntOrNull() ?: return@forEach
                        val category = PerLevelCategory.entries
                            .firstOrNull { it.key == id.substringAfter("_") } ?: return@forEach
                        EditableCard(
                            isEditing = isEditing,
                            isVisible = perLevelLayout.isVisible(id),
                            onToggle = { perLevelLayout.toggleVisible(id) },
                            canMoveBackward = perLevelLayout.canMove(id, -1) { true },
                            canMoveForward = perLevelLayout.canMove(id, 1) { true },
                            onMoveBackward = { perLevelLayout.move(id, -1) { true } },
                            onMoveForward = { perLevelLayout.move(id, 1) { true } }
                        ) {
                            PerLevelCard(
                                difficulty = difficulty,
                                category = category,
                                analytics = analytics,
                                onClick = if (isEditing) {
                                    null
                                } else {
                                    {
                                        onNavigate(
                                            Routes.iidxAnalytics(
                                                if (category.isClearType) {
                                                    Routes.IIDX_DETAIL_CLEAR_TYPE_LEVEL
                                                } else {
                                                    Routes.IIDX_DETAIL_DJ_LEVEL_LEVEL
                                                },
                                                difficulty.toString()
                                            )
                                        )
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
internal fun AnalyticsSection(
    title: String,
    section: String,
    layout: CardLayoutController,
    isEditing: Boolean,
    content: @Composable () -> Unit
) {
    val isExpanded = layout.isExpanded(section, isEditing)
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        AnalyticsSectionHeader(
            title = title,
            isCollapsible = !isEditing,
            isExpanded = isExpanded,
            onToggle = { layout.toggleSection(section) }
        )
        if (isExpanded) content()
    }
}

@Composable
internal fun CardGrid(ids: List<String>, card: @Composable (String) -> Unit) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        ids.chunked(2).forEach { row ->
            Row(
                modifier = Modifier.height(IntrinsicSize.Min),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                row.forEach { id ->
                    Box(modifier = Modifier.weight(1f).fillMaxHeight()) { card(id) }
                }
                if (row.size == 1) Spacer(modifier = Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun OverviewCardContent(
    id: String,
    analytics: IIDXAnalyticsData,
    isEditing: Boolean,
    onNavigate: (String) -> Unit
) {
    val darkTheme = isSystemInDarkTheme()
    val nowEpoch = System.currentTimeMillis() / 1000L
    when (id) {
        CARD_CLEAR_TYPE_OVERALL -> OverviewCard(
            caption = stringResource(R.string.analytics_clear_type_overall),
            onClick = if (isEditing || analytics.clearTypePerDifficulty.isEmpty()) {
                null
            } else {
                { onNavigate(Routes.iidxAnalytics(Routes.IIDX_DETAIL_CLEAR_TYPE_OVERVIEW)) }
            }
        ) {
            val populated = analytics.clearTypePerDifficulty
                .filter { (_, counts) -> counts.values.any { it > 0 } }
                .keys.sorted().takeLast(3)
            StackedBarChart(
                rows = populated.map { difficulty ->
                    StackedRow(
                        label = difficulty.toString(),
                        segments = IIDXClearType.sortedWithoutNoPlay.map { clearType ->
                            StackedSegment(
                                clearType.value,
                                analytics.clearTypePerDifficulty[difficulty]?.get(clearType.value) ?: 0,
                                IIDXColors.clearTypeColor(clearType.value)
                            )
                        }
                    )
                }
            )
        }
        CARD_GRADE_BREAKDOWN -> OverviewCard(
            caption = stringResource(R.string.analytics_dj_level_overall),
            onClick = if (isEditing || analytics.djLevelPerDifficulty.isEmpty()) {
                null
            } else {
                { onNavigate(Routes.iidxAnalytics(Routes.IIDX_DETAIL_GRADE_BREAKDOWN)) }
            }
        ) {
            HorizontalBarChart(
                entries = analytics.totalDJLevelCounts.filter { it.second > 0 }.take(3),
                colorFor = { IIDXColors.djLevelColor(it, darkTheme) }
            )
        }
        CARD_TOWER_TOTALS, CARD_TOWER_RECENT -> {
            val isRecent = id == CARD_TOWER_RECENT
            OverviewCard(
                caption = stringResource(
                    if (isRecent) R.string.tower_mode_recent else R.string.tower_iidx_tower
                ),
                onClick = if (isEditing) {
                    null
                } else {
                    { onNavigate(Routes.tower(if (isRecent) Routes.TOWER_RECENT else Routes.TOWER_TOTALS)) }
                }
            ) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    val chartModifier = Modifier
                        .fillMaxSize()
                        .alpha(if (analytics.towerEntries.isEmpty()) 0.25f else 1f)
                    if (isRecent) {
                        GroupedBarChart(
                            entries = analytics.towerChartEntries(nowEpoch)
                                .map { Triple("", it.keyCount, it.scratchCount) },
                            firstColor = Palette.blue,
                            secondColor = Palette.red,
                            modifier = chartModifier,
                            showLabels = false
                        )
                    } else {
                        val heightFormat = stringResource(R.string.tower_height_cm)
                        BigTotalsBarChart(
                            bars = listOf(
                                Triple(stringResource(R.string.tower_keys), analytics.towerTotalKeyCount / 7, Palette.blue),
                                Triple(stringResource(R.string.tower_scratch), analytics.towerTotalScratchCount, Palette.red)
                            ),
                            annotationFor = { String.format(heightFormat, it) },
                            modifier = chartModifier
                        )
                    }
                    if (analytics.towerEntries.isEmpty()) {
                        Text(
                            text = stringResource(R.string.analytics_no_data),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PerLevelCard(
    difficulty: Int,
    category: PerLevelCategory,
    analytics: IIDXAnalyticsData,
    onClick: (() -> Unit)?
) {
    val darkTheme = isSystemInDarkTheme()
    val segments = if (category.isClearType) {
        IIDXClearType.sortedWithoutNoPlay.map { clearType ->
            ChartSegment(
                clearType.abbreviation,
                analytics.clearTypePerDifficulty[difficulty]?.get(clearType.value) ?: 0,
                IIDXColors.clearTypeColor(clearType.value)
            )
        }
    } else {
        IIDXDJLevel.sorted.reversed().map { djLevel ->
            ChartSegment(
                djLevel.value,
                analytics.djLevelPerDifficulty[difficulty]?.get(djLevel.value) ?: 0,
                IIDXColors.djLevelColor(djLevel.value, darkTheme)
            )
        }
    }
    val trend = if (category.isClearType) {
        trendPoints(analytics.clearTypeTrends.map { it.date to it.counts[difficulty].orEmpty() }) {
            IIDXColors.clearTypeColor(it)
        }
    } else {
        trendPoints(analytics.djLevelTrends.map { it.date to it.counts[difficulty].orEmpty() }) {
            IIDXColors.djLevelColor(it, darkTheme)
        }
    }
    val shape = RoundedCornerShape(16.dp)
    val body: @Composable () -> Unit = {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(72.dp)
        ) {
            StackedAreaChart(
                points = trend,
                showAxes = false,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(top = 20.dp)
                    .alpha(if (category.showsBar) 0.2f else 1f)
            )
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(12.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        text = "LEVEL $difficulty",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = "|",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.outlineVariant
                    )
                    Text(
                        text = stringResource(
                            if (category.isClearType) R.string.analytics_clear_type else R.string.analytics_dj_level
                        ),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Spacer(modifier = Modifier.weight(1f))
                if (category.showsBar) {
                    SegmentedBar(segments = segments)
                    Row(
                        modifier = Modifier.padding(top = 6.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        segments.filter { it.count > 0 }.forEach { segment ->
                            Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                                Text(
                                    text = segment.label,
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = segment.color
                                )
                                Text(
                                    text = segment.count.toString(),
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    if (onClick != null) {
        ElevatedCard(onClick = onClick, shape = shape) { body() }
    } else {
        ElevatedCard(shape = shape) { body() }
    }
}

internal fun trendPoints(
    points: List<Pair<Long, Map<String, Int>>>,
    colorFor: (String) -> Color
): List<AreaSeriesPoint> = points.map { (date, counts) ->
    AreaSeriesPoint(date, counts.map { (key, count) -> ChartSegment(key, count, colorFor(key)) })
}

@Composable
internal fun newEntryTitle(kind: IIDXNewEntryKind): String = when (kind) {
    IIDXNewEntryKind.HIGH_SCORES -> stringResource(R.string.analytics_new_record)
    IIDXNewEntryKind.AAA -> "AAA"
    IIDXNewEntryKind.AA -> "AA"
    IIDXNewEntryKind.A -> "A"
    IIDXNewEntryKind.FULL_COMBO_CLEAR -> IIDXClearType.FULL_COMBO_CLEAR.value
    IIDXNewEntryKind.CLEAR -> IIDXClearType.CLEAR.value
    IIDXNewEntryKind.EASY_CLEAR -> IIDXClearType.EASY_CLEAR.value
    IIDXNewEntryKind.ASSIST_CLEAR -> IIDXClearType.ASSIST_CLEAR.value
    IIDXNewEntryKind.HARD_CLEAR -> IIDXClearType.HARD_CLEAR.value
    IIDXNewEntryKind.EX_HARD_CLEAR -> IIDXClearType.EX_HARD_CLEAR.value
    IIDXNewEntryKind.FAILED -> IIDXClearType.FAILED.value
}

private fun newEntryIcon(kind: IIDXNewEntryKind): ImageVector = when (kind) {
    IIDXNewEntryKind.HIGH_SCORES -> Icons.Outlined.EmojiEvents
    IIDXNewEntryKind.AAA, IIDXNewEntryKind.AA, IIDXNewEntryKind.A -> Icons.Outlined.WorkspacePremium
    IIDXNewEntryKind.FULL_COMBO_CLEAR -> Icons.Outlined.StarOutline
    IIDXNewEntryKind.CLEAR -> Icons.Outlined.CheckCircle
    IIDXNewEntryKind.EASY_CLEAR -> Icons.Outlined.VerifiedUser
    IIDXNewEntryKind.ASSIST_CLEAR -> Icons.Outlined.Bolt
    IIDXNewEntryKind.HARD_CLEAR -> Icons.Outlined.Speed
    IIDXNewEntryKind.EX_HARD_CLEAR -> Icons.Outlined.Whatshot
    IIDXNewEntryKind.FAILED -> Icons.Outlined.Report
}

@Composable
private fun newEntryColor(kind: IIDXNewEntryKind): Color = when (kind) {
    IIDXNewEntryKind.HIGH_SCORES -> MaterialTheme.colorScheme.onSurface
    IIDXNewEntryKind.AAA, IIDXNewEntryKind.AA, IIDXNewEntryKind.A -> Palette.orange
    IIDXNewEntryKind.FULL_COMBO_CLEAR -> Palette.blue
    IIDXNewEntryKind.CLEAR -> Palette.cyan
    IIDXNewEntryKind.EASY_CLEAR -> Palette.green
    IIDXNewEntryKind.ASSIST_CLEAR -> Palette.purple
    IIDXNewEntryKind.HARD_CLEAR -> Palette.pink
    IIDXNewEntryKind.EX_HARD_CLEAR -> Palette.yellow
    IIDXNewEntryKind.FAILED -> Palette.red
}
