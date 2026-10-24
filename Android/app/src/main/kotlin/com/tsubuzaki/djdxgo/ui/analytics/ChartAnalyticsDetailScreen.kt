package com.tsubuzaki.djdxgo.ui.analytics

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.analytics.ChartAnalyticsData
import com.tsubuzaki.djdxgo.data.analytics.ChartNewEntry
import com.tsubuzaki.djdxgo.ui.Routes
import com.tsubuzaki.djdxgo.ui.common.DetailScaffold
import com.tsubuzaki.djdxgo.ui.theme.Palette

private val gradeBrush = androidx.compose.ui.graphics.Brush.verticalGradient(listOf(Palette.yellow, Palette.orange))

@Composable
fun ChartAnalyticsDetailScreen(
    container: AppContainer,
    game: Game,
    detail: String,
    param: String,
    onBack: () -> Unit
) {
    val spec = chartGameSpec(game)
    val flow = when (game) {
        Game.SOUND_VOLTEX -> container.analyticsStore.sdvx
        Game.POLARIS_CHORD -> container.analyticsStore.polarisChord
        else -> container.analyticsStore.ddr
    }
    val data by flow.collectAsState()
    val analytics = data ?: ChartAnalyticsData()
    val title = when (detail) {
        Routes.CHART_DETAIL_CLEAR_BREAKDOWN -> stringResource(spec.clearCaptionRes)
        Routes.CHART_DETAIL_GRADE_BREAKDOWN -> stringResource(spec.gradeCaptionRes)
        Routes.CHART_DETAIL_NEW_HIGH_SCORES -> stringResource(R.string.analytics_new_record)
        Routes.CHART_DETAIL_NEW_CLEARS -> spec.clearLabel(param)
        else -> param
    }
    DetailScaffold(title = title, onBack = onBack) { padding ->
        val modifier = Modifier
            .fillMaxSize()
            .padding(padding)
        when (detail) {
            Routes.CHART_DETAIL_CLEAR_BREAKDOWN -> LevelBreakdownDetail(
                spec, analytics.clearTypePerLevel, spec.clearKeys, isClear = true, modifier = modifier
            )
            Routes.CHART_DETAIL_GRADE_BREAKDOWN -> DifficultyBreakdownDetail(spec, analytics, modifier)
            Routes.CHART_DETAIL_NEW_HIGH_SCORES -> NewEntriesList(spec, analytics.newHighScores, modifier) { entry ->
                ChangeRow(
                    previous = entry.previousScore.toString(),
                    current = entry.newScore.toString(),
                    currentColor = Palette.orange,
                    suffix = stringResource(R.string.analytics_new_high_score_delta, entry.newScore - entry.previousScore)
                )
                if (entry.newGrade != entry.previousGrade) {
                    ChangeRow(
                        previous = spec.gradeLabel(entry.previousGrade),
                        current = spec.gradeLabel(entry.newGrade),
                        currentBrush = gradeBrush
                    )
                }
            }
            Routes.CHART_DETAIL_NEW_CLEARS -> NewEntriesList(spec, analytics.newClears[param].orEmpty(), modifier) { entry ->
                ChangeRow(
                    previous = spec.clearLabel(entry.previousValue),
                    current = spec.clearLabel(entry.newValue),
                    currentColor = spec.clearColor(entry.newValue, isSystemInDarkTheme())
                )
            }
            else -> NewEntriesList(spec, analytics.newGrades[param].orEmpty(), modifier) { entry ->
                ChangeRow(
                    previous = spec.gradeLabel(entry.previousValue),
                    current = spec.gradeLabel(entry.newValue),
                    currentBrush = gradeBrush
                )
            }
        }
    }
}

@Composable
private fun LevelBreakdownDetail(
    spec: ChartGameSpec,
    perLevel: Map<Int, Map<String, Int>>,
    keys: List<String>,
    isClear: Boolean,
    modifier: Modifier
) {
    val darkTheme = isSystemInDarkTheme()
    val populated = perLevel.filter { (_, counts) -> counts.values.any { it > 0 } }.keys.sorted()
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        if (populated.isEmpty()) {
            item { NoData() }
        } else {
            item {
                ChartLegend(items = keys.map {
                    (if (isClear) spec.clearLabel(it) else spec.gradeLabel(it)) to
                        (if (isClear) spec.clearColor(it, darkTheme) else spec.gradeColor(it, darkTheme))
                })
            }
            item {
                Text(text = stringResource(R.string.analytics_level), style = MaterialTheme.typography.titleMedium)
            }
        }
        items(populated) { level ->
            val counts = perLevel[level].orEmpty()
            LevelBreakdownRow(
                label = "LEVEL $level",
                total = counts.values.sum(),
                segments = keys.map {
                    ChartSegment(
                        it,
                        counts[it] ?: 0,
                        if (isClear) spec.clearColor(it, darkTheme) else spec.gradeColor(it, darkTheme)
                    )
                }
            )
        }
    }
}

@Composable
private fun DifficultyBreakdownDetail(spec: ChartGameSpec, analytics: ChartAnalyticsData, modifier: Modifier) {
    val darkTheme = isSystemInDarkTheme()
    val populated = spec.difficultyOrder.filter { difficulty ->
        analytics.gradePerDifficulty[difficulty]?.values?.any { it > 0 } == true
    }
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        if (populated.isEmpty()) item { NoData() }
        items(populated) { difficulty ->
            val counts = analytics.gradePerDifficulty[difficulty].orEmpty()
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = spec.difficultyLabel(difficulty),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Black,
                    color = spec.difficultyColor(difficulty)
                )
                VerticalStackedBarChart(
                    columns = spec.gradeKeys.map { grade ->
                        BarColumn(
                            spec.gradeLabel(grade),
                            listOf(ChartSegment(grade, counts[grade] ?: 0, spec.gradeColor(grade, darkTheme)))
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
private fun NoData() {
    Text(
        text = stringResource(R.string.analytics_no_data),
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(8.dp)
    )
}

@Composable
private fun NewEntriesList(
    spec: ChartGameSpec,
    entries: List<ChartNewEntry>,
    modifier: Modifier,
    changes: @Composable (ChartNewEntry) -> Unit
) {
    LazyColumn(modifier = modifier, contentPadding = PaddingValues(bottom = 24.dp)) {
        if (entries.isEmpty()) item { NoData() }
        items(entries) { entry ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(text = entry.title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold)
                    changes(entry)
                }
                ChartLevelLabel(
                    difficulty = spec.difficultyLabel(entry.difficulty),
                    color = spec.difficultyColor(entry.difficulty),
                    level = entry.level
                )
            }
            HorizontalDivider()
        }
    }
}

@Composable
private fun ChangeRow(
    previous: String,
    current: String,
    currentColor: Color = Color.Unspecified,
    currentBrush: androidx.compose.ui.graphics.Brush? = null,
    suffix: String? = null
) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = previous,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textDecoration = TextDecoration.LineThrough
        )
        Icon(
            Icons.AutoMirrored.Filled.ArrowForward,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(12.dp)
        )
        Text(
            text = current,
            style = MaterialTheme.typography.labelMedium.merge(
                if (currentBrush != null) TextStyle(brush = currentBrush) else TextStyle(color = currentColor)
            ),
            fontWeight = FontWeight.Black
        )
        if (suffix != null) {
            Text(text = suffix, style = MaterialTheme.typography.labelSmall, color = Palette.orange.copy(alpha = 0.8f))
        }
    }
}

@Composable
private fun ChartLevelLabel(difficulty: String, color: Color, level: String) {
    Card(
        modifier = Modifier.width(78.dp),
        shape = RoundedCornerShape(6.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHighest)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 6.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(text = difficulty, fontSize = 10.sp, fontWeight = FontWeight.Black, color = color, maxLines = 1)
            Text(text = level, fontSize = 18.sp, fontWeight = FontWeight.ExtraBold, maxLines = 1)
        }
    }
}
