package com.tsubuzaki.djdxgo.ui.analytics

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.PieChart
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.analytics.IIDXAnalyticsData
import com.tsubuzaki.djdxgo.data.analytics.IIDXNewEntry
import com.tsubuzaki.djdxgo.data.analytics.IIDXNewEntryKind
import com.tsubuzaki.djdxgo.data.external.IIDXSong
import com.tsubuzaki.djdxgo.data.compact
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.iidx.IIDXDJLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.ui.Routes
import com.tsubuzaki.djdxgo.ui.common.DetailScaffold
import com.tsubuzaki.djdxgo.ui.iidx.IIDXScoreRow
import com.tsubuzaki.djdxgo.ui.iidx.noteCount
import com.tsubuzaki.djdxgo.ui.iidx.rememberSetting
import com.tsubuzaki.djdxgo.ui.iidx.scoreRate
import com.tsubuzaki.djdxgo.ui.theme.IIDXColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Composable
fun IIDXAnalyticsDetailScreen(
    container: AppContainer,
    detail: String,
    param: String,
    onBack: () -> Unit,
    onNavigate: (String) -> Unit
) {
    val data by container.analyticsStore.iidx.collectAsState()
    val analytics = data ?: IIDXAnalyticsData()
    val difficulty = param.toIntOrNull() ?: 0
    val separator = stringResource(R.string.analytics_per_level_title_separator)
    var showsPieChart by rememberSaveable(detail) { mutableStateOf(detail == Routes.IIDX_DETAIL_CLEAR_TYPE_LEVEL) }
    val title = when (detail) {
        Routes.IIDX_DETAIL_CLEAR_TYPE_OVERVIEW -> stringResource(R.string.analytics_clear_type_overall)
        Routes.IIDX_DETAIL_GRADE_BREAKDOWN -> stringResource(R.string.analytics_dj_level_overall)
        Routes.IIDX_DETAIL_CLEAR_TYPE_LEVEL ->
            "LEVEL $difficulty$separator${stringResource(R.string.analytics_clear_type)}"
        Routes.IIDX_DETAIL_DJ_LEVEL_LEVEL ->
            "LEVEL $difficulty$separator${stringResource(R.string.analytics_dj_level)}"
        else -> IIDXNewEntryKind.fromKey(param)?.let { newEntryTitle(it) }.orEmpty()
    }
    DetailScaffold(
        title = title,
        onBack = onBack,
        actions = {
            if (detail == Routes.IIDX_DETAIL_CLEAR_TYPE_LEVEL || detail == Routes.IIDX_DETAIL_DJ_LEVEL_LEVEL) {
                IconButton(onClick = { showsPieChart = !showsPieChart }) {
                    Icon(
                        if (showsPieChart) Icons.Outlined.BarChart else Icons.Outlined.PieChart,
                        contentDescription = null
                    )
                }
            }
        }
    ) { padding ->
        val modifier = Modifier
            .fillMaxSize()
            .padding(padding)
        when (detail) {
            Routes.IIDX_DETAIL_CLEAR_TYPE_OVERVIEW -> ClearTypeOverviewDetail(analytics, modifier)
            Routes.IIDX_DETAIL_GRADE_BREAKDOWN -> GradeBreakdownDetail(analytics, modifier)
            Routes.IIDX_DETAIL_CLEAR_TYPE_LEVEL, Routes.IIDX_DETAIL_DJ_LEVEL_LEVEL -> PerLevelDetail(
                analytics = analytics,
                difficulty = difficulty,
                isClearType = detail == Routes.IIDX_DETAIL_CLEAR_TYPE_LEVEL,
                showsPieChart = showsPieChart,
                modifier = modifier
            )
            else -> IIDXAnalyticsDetailNewEntries(
                container = container,
                kind = IIDXNewEntryKind.fromKey(param) ?: IIDXNewEntryKind.HIGH_SCORES,
                entries = IIDXNewEntryKind.fromKey(param)?.let { analytics.newEntries(it) }.orEmpty(),
                modifier = modifier,
                onNavigate = onNavigate
            )
        }
    }
}

@Composable
private fun NoDataText() {
    Text(
        text = stringResource(R.string.analytics_no_data),
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(24.dp)
    )
}

private fun clearTypeSegments(counts: Map<String, Int>): List<ChartSegment> =
    IIDXClearType.sortedWithoutNoPlay.map {
        ChartSegment(it.value, counts[it.value] ?: 0, IIDXColors.clearTypeColor(it.value))
    }

@Composable
internal fun ClearTypeLegend() {
    ChartLegend(items = IIDXClearType.sortedWithoutNoPlay.map { it.value to IIDXColors.clearTypeColor(it.value) })
}

@Composable
internal fun DJLevelLegend() {
    val darkTheme = isSystemInDarkTheme()
    ChartLegend(items = IIDXDJLevel.sorted.reversed().map { it.value to IIDXColors.djLevelColor(it.value, darkTheme) })
}

@Composable
private fun ClearTypeOverviewDetail(analytics: IIDXAnalyticsData, modifier: Modifier) {
    val populated = analytics.clearTypePerDifficulty
        .filter { (_, counts) -> counts.values.any { it > 0 } }
        .keys.sorted()
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            VerticalStackedBarChart(
                columns = (1..12).map { difficulty ->
                    BarColumn(
                        difficulty.toString(),
                        clearTypeSegments(analytics.clearTypePerDifficulty[difficulty].orEmpty())
                    )
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(280.dp)
            )
        }
        item { ClearTypeLegend() }
        item {
            Text(
                text = stringResource(R.string.analytics_level),
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(top = 8.dp)
            )
        }
        items(populated) { difficulty ->
            val counts = analytics.clearTypePerDifficulty[difficulty].orEmpty()
            LevelBreakdownRow(
                label = "LEVEL $difficulty",
                total = counts.values.sum(),
                segments = clearTypeSegments(counts)
            )
        }
    }
}

@Composable
internal fun LevelBreakdownRow(label: String, total: Int, segments: List<ChartSegment>) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(text = label, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = pluralStringResource(R.plurals.analytics_song_count, total, total),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        SegmentedBar(segments = segments, height = 16.dp, cornerRadius = 4.dp)
    }
}

@Composable
private fun GradeBreakdownDetail(analytics: IIDXAnalyticsData, modifier: Modifier) {
    val darkTheme = isSystemInDarkTheme()
    val populated = analytics.djLevelPerDifficulty
        .filter { (_, counts) -> counts.values.any { it > 0 } }
        .keys.sorted()
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        if (populated.isEmpty()) item { NoDataText() }
        items(populated) { difficulty ->
            val counts = analytics.djLevelPerDifficulty[difficulty].orEmpty()
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(text = "LEVEL $difficulty", style = MaterialTheme.typography.titleSmall)
                VerticalStackedBarChart(
                    columns = IIDXDJLevel.sorted.reversed().map { djLevel ->
                        BarColumn(
                            djLevel.value,
                            listOf(
                                ChartSegment(
                                    djLevel.value,
                                    counts[djLevel.value] ?: 0,
                                    IIDXColors.djLevelColor(djLevel.value, darkTheme)
                                )
                            )
                        )
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(140.dp)
                )
            }
        }
    }
}

@Composable
private fun PerLevelDetail(
    analytics: IIDXAnalyticsData,
    difficulty: Int,
    isClearType: Boolean,
    showsPieChart: Boolean,
    modifier: Modifier
) {
    val darkTheme = isSystemInDarkTheme()
    val segments = if (isClearType) {
        clearTypeSegments(analytics.clearTypePerDifficulty[difficulty].orEmpty())
    } else {
        val counts = analytics.djLevelPerDifficulty[difficulty].orEmpty()
        IIDXDJLevel.sorted.reversed().map {
            ChartSegment(it.value, counts[it.value] ?: 0, IIDXColors.djLevelColor(it.value, darkTheme))
        }
    }
    val trend = if (isClearType) {
        trendPoints(analytics.clearTypeTrends.map { it.date to it.counts[difficulty].orEmpty() }) {
            IIDXColors.clearTypeColor(it)
        }
    } else {
        trendPoints(analytics.djLevelTrends.map { it.date to it.counts[difficulty].orEmpty() }) {
            IIDXColors.djLevelColor(it, darkTheme)
        }
    }
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        item {
            DetailSection(stringResource(R.string.analytics_per_level_breakdown)) {
                val chartModifier = Modifier
                    .fillMaxWidth()
                    .height(240.dp)
                    .padding(16.dp)
                if (showsPieChart) {
                    PieChart(segments = segments, modifier = chartModifier)
                } else {
                    val barSegments = if (isClearType) {
                        segments.reversed()
                    } else {
                        segments.filter { it.label in listOf("C", "B", "A", "AA", "AAA") }
                    }
                    VerticalStackedBarChart(
                        columns = barSegments.map {
                            BarColumn(
                                if (isClearType) {
                                    IIDXClearType.fromValue(it.label)?.abbreviation ?: it.label
                                } else {
                                    it.label
                                },
                                listOf(it)
                            )
                        },
                        modifier = chartModifier
                    )
                }
            }
        }
        item {
            DetailSection(stringResource(R.string.analytics_per_level_trend)) {
                StackedAreaChart(
                    points = trend,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(240.dp)
                )
            }
        }
        item { if (isClearType) ClearTypeLegend() else DJLevelLegend() }
    }
}

@Composable
internal fun DetailSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        content()
    }
}

@Composable
private fun IIDXAnalyticsDetailNewEntries(
    container: AppContainer,
    kind: IIDXNewEntryKind,
    entries: List<IIDXNewEntry>,
    modifier: Modifier,
    onNavigate: (String) -> Unit
) {
    val playTypeValue by rememberSetting(SettingsKeys.iidxPlayType, IIDXPlayType.SINGLE.value)
    val playType = IIDXPlayType.fromValue(playTypeValue)
    val genreVisible by rememberSetting(SettingsKeys.iidxGenreVisible, false)
    val artistVisible by rememberSetting(SettingsKeys.iidxArtistVisible, true)
    val levelVisible by rememberSetting(SettingsKeys.iidxLevelVisible, true)
    val djLevelVisible by rememberSetting(SettingsKeys.iidxDJLevelVisible, true)
    val scoreRateVisible by rememberSetting(SettingsKeys.iidxScoreRateVisible, true)
    val scoreVisible by rememberSetting(SettingsKeys.iidxScoreVisible, true)
    val lastPlayDateVisible by rememberSetting(SettingsKeys.iidxLastPlayDateVisible, false)
    val songs by produceState<Map<String, IIDXSong>>(emptyMap()) {
        value = withContext(Dispatchers.IO) {
            container.externalDataDao.allIIDXSongs().associateBy { it.titleCompact }
        }
    }
    var isLevelBreakdownExpanded by rememberSaveable { mutableStateOf(true) }
    var isClearTypeBreakdownExpanded by rememberSaveable { mutableStateOf(true) }
    val levelItems = (1..12).mapNotNull { difficulty ->
        val count = entries.count { it.score.difficulty == difficulty }
        if (count > 0) ChartSegment("LEVEL $difficulty", count, IIDXColors.difficultyLevelColor(difficulty)) else null
    }
    val clearTypeItems = IIDXClearType.sortedWithoutNoPlay.mapNotNull { clearType ->
        val count = entries.count { it.score.clearType == clearType.value }
        if (count > 0) ChartSegment(clearType.abbreviation, count, IIDXColors.clearTypeColor(clearType.value)) else null
    }
    val nowEpoch = System.currentTimeMillis() / 1000L
    LazyColumn(modifier = modifier, contentPadding = PaddingValues(bottom = 24.dp)) {
        if (entries.isEmpty()) {
            item { NoDataText() }
        } else {
            item {
                Column(
                    modifier = Modifier.padding(vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(20.dp)
                ) {
                    BreakdownSection(
                        title = stringResource(R.string.analytics_breakdown_level),
                        isExpanded = isLevelBreakdownExpanded,
                        onToggle = { isLevelBreakdownExpanded = !isLevelBreakdownExpanded },
                        items = levelItems
                    )
                    if (kind == IIDXNewEntryKind.HIGH_SCORES) {
                        BreakdownSection(
                            title = stringResource(R.string.analytics_breakdown_clear_type),
                            isExpanded = isClearTypeBreakdownExpanded,
                            onToggle = { isClearTypeBreakdownExpanded = !isClearTypeBreakdownExpanded },
                            items = clearTypeItems
                        )
                    }
                }
            }
            items(entries.size) { index ->
                val entry = entries[index]
                IIDXScoreRow(
                    record = entry.record,
                    level = entry.level,
                    score = entry.score,
                    scoreRate = scoreRate(
                        entry.score.score,
                        songs[entry.record.title.compact]?.noteCount(playType, entry.level)
                    ),
                    genreVisible = genreVisible,
                    artistVisible = artistVisible,
                    levelVisible = levelVisible,
                    djLevelVisible = djLevelVisible,
                    scoreRateVisible = scoreRateVisible,
                    scoreVisible = scoreVisible,
                    lastPlayDateVisible = lastPlayDateVisible,
                    scoreDelta = if (kind == IIDXNewEntryKind.HIGH_SCORES) {
                        entry.score.score - entry.previousScore
                    } else {
                        null
                    },
                    onClick = {
                        onNavigate(
                            Routes.iidxViewer(entry.record.title, entry.record.playType, entry.level.code, nowEpoch)
                        )
                    }
                )
                HorizontalDivider()
            }
        }
    }
}

@Composable
private fun BreakdownSection(
    title: String,
    isExpanded: Boolean,
    onToggle: () -> Unit,
    items: List<ChartSegment>
) {
    if (items.isEmpty()) return
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        AnalyticsSectionHeader(title = title, isCollapsible = true, isExpanded = isExpanded, onToggle = onToggle)
        if (isExpanded) {
            BreakdownBar(items = items, modifier = Modifier.padding(horizontal = 16.dp))
        }
    }
}
