package com.tsubuzaki.djdxgo.ui.games

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.compact
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordClearType
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordDifficulty
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordGrade
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordSongRecord
import com.tsubuzaki.djdxgo.data.setSetting
import com.tsubuzaki.djdxgo.data.settingFlow
import com.tsubuzaki.djdxgo.ui.theme.PolarisChordColors
import java.time.Instant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val SORT_TITLE = "Title"
private const val SORT_RATE = "Rate"
private const val SORT_LEVEL = "Level"
private const val SORT_CLEAR_TYPE = "ClearType"

@Composable
fun PolarisChordScoresScreen(
    container: AppContainer,
    contentPadding: PaddingValues,
    analyticsContent: (@Composable () -> Unit)? = null,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var selectedDateEpoch by rememberSaveable { mutableLongStateOf(Instant.now().epochSecond) }
    var records by remember { mutableStateOf(listOf<PolarisChordSongRecord>()) }
    var isLoaded by remember { mutableStateOf(false) }
    val dataVersion by container.dataVersion.collectAsState()
    LaunchedEffect(selectedDateEpoch, dataVersion) {
        records = withContext(Dispatchers.IO) {
            container.polarisChordRepository.songRecords(selectedDateEpoch)
        }
        isLoaded = true
    }

    val sortMode by context.settingFlow(SettingsKeys.polarisChordSortMode, SORT_TITLE)
        .collectAsState(SORT_TITLE)
    val sortDescending by context.settingFlow(SettingsKeys.polarisChordSortDescending, false)
        .collectAsState(false)
    val difficultyFilters by context
        .settingFlow(SettingsKeys.polarisChordDifficultyFilters, emptySet())
        .collectAsState(emptySet())
    val levelFilters by context.settingFlow(SettingsKeys.polarisChordLevelFilters, emptySet())
        .collectAsState(emptySet())
    val clearTypeFilters by context
        .settingFlow(SettingsKeys.polarisChordClearTypeFilters, emptySet())
        .collectAsState(emptySet())
    val gradeFilters by context.settingFlow(SettingsKeys.polarisChordGradeFilters, emptySet())
        .collectAsState(emptySet())

    var query by rememberSaveable { mutableStateOf("") }
    var showFilterSheet by remember { mutableStateOf(false) }

    val displayed = remember(
        records, sortMode, sortDescending,
        difficultyFilters, levelFilters, clearTypeFilters, gradeFilters
    ) {
        polarisChordDisplayRecords(
            records, "", sortMode, sortDescending,
            difficultyFilters, levelFilters, clearTypeFilters, gradeFilters
        )
    }
    val searchResults = remember(
        records, query, sortMode, sortDescending,
        difficultyFilters, levelFilters, clearTypeFilters, gradeFilters
    ) {
        if (query.isEmpty()) {
            emptyList()
        } else {
            polarisChordDisplayRecords(
                records, query, sortMode, sortDescending,
            difficultyFilters, levelFilters, clearTypeFilters, gradeFilters
            )
        }
    }

    fun toggleFilter(key: Preferences.Key<Set<String>>, current: Set<String>, value: String) {
        scope.launch {
            context.setSetting(key, if (value in current) current - value else current + value)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(contentPadding)
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(bottom = 112.dp)
        ) {
            analyticsContent?.let { content ->
                item(key = "analytics") { content() }
            }
            if (isLoaded && displayed.isEmpty()) {
                item(key = "empty") { EmptyStateCard() }
            }
            items(displayed, key = { it.id }) { record ->
                PolarisChordScoreRow(record = record)
                HorizontalDivider()
            }
        }
        ScoresToolbar(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(bottom = 12.dp),
            query = query,
            onQueryChange = { query = it },
            searchResults = searchResults,
            searchResultContent = { record ->
                PolarisChordScoreRow(record = record)
            },
            sortOptions = listOf(
                SortOption(SORT_TITLE, stringResource(R.string.games_sort_title)),
                SortOption(SORT_RATE, stringResource(R.string.polaris_sort_rate)),
                SortOption(SORT_LEVEL, stringResource(R.string.games_sort_level)),
                SortOption(SORT_CLEAR_TYPE, stringResource(R.string.games_sort_clear_type))
            ),
            sortMode = sortMode,
            sortDescending = sortDescending,
            onSortChange = { mode, descending ->
                scope.launch {
                    context.setSetting(SettingsKeys.polarisChordSortMode, mode)
                    context.setSetting(SettingsKeys.polarisChordSortDescending, descending)
                }
            },
            onFilterClick = { showFilterSheet = true }
        )
    }

    if (showFilterSheet) {
        FilterSheet(
            onDismiss = { showFilterSheet = false },
            onReset = {
                scope.launch {
                    context.setSetting(SettingsKeys.polarisChordDifficultyFilters, emptySet())
                    context.setSetting(SettingsKeys.polarisChordLevelFilters, emptySet())
                    context.setSetting(SettingsKeys.polarisChordClearTypeFilters, emptySet())
                    context.setSetting(SettingsKeys.polarisChordGradeFilters, emptySet())
                }
            }
        ) {
            FilterChipGroup(
                title = stringResource(R.string.games_filter_difficulty),
                options = PolarisChordDifficulty.entries.map { it.value to it.value },
                selected = difficultyFilters,
                onToggle = {
                    toggleFilter(SettingsKeys.polarisChordDifficultyFilters, difficultyFilters, it)
                },
                chipColor = { PolarisChordColors.difficultyColor(it) }
            )
            FilterChipGroup(
                title = stringResource(R.string.games_filter_level),
                options = (1..15).map { it.toString() to it.toString() },
                selected = levelFilters,
                onToggle = { toggleFilter(SettingsKeys.polarisChordLevelFilters, levelFilters, it) }
            )
            FilterChipGroup(
                title = stringResource(R.string.games_filter_clear_type),
                options = PolarisChordClearType.entries.map { it.value to it.abbreviation },
                selected = clearTypeFilters,
                onToggle = {
                    toggleFilter(SettingsKeys.polarisChordClearTypeFilters, clearTypeFilters, it)
                },
                chipColor = { PolarisChordColors.clearTypeColor(it) }
            )
            FilterChipGroup(
                title = stringResource(R.string.games_filter_grade),
                options = PolarisChordGrade.entries.map { it.value to it.value },
                selected = gradeFilters,
                onToggle = { toggleFilter(SettingsKeys.polarisChordGradeFilters, gradeFilters, it) }
            )
        }
    }
}

private fun polarisChordDisplayRecords(
    records: List<PolarisChordSongRecord>,
    query: String,
    sortMode: String,
    sortDescending: Boolean,
    difficulties: Set<String>,
    levels: Set<String>,
    clearTypes: Set<String>,
    grades: Set<String>
): List<PolarisChordSongRecord> {
    val queryCompact = query.compact
    val filtered = records.filter { record ->
        (queryCompact.isEmpty() || record.title.compact.contains(queryCompact)) &&
            (difficulties.isEmpty() || record.difficulty in difficulties) &&
            (levels.isEmpty() || record.level in levels) &&
            (clearTypes.isEmpty() || record.clearType in clearTypes) &&
            (grades.isEmpty() || record.grade in grades)
    }
    val primary: Comparator<PolarisChordSongRecord> = when (sortMode) {
        SORT_RATE -> compareBy { it.achievementRate.toDoubleOrNull() ?: 0.0 }
        SORT_LEVEL -> compareBy { it.level.toIntOrNull() ?: 0 }
        SORT_CLEAR_TYPE -> compareBy { PolarisChordClearType.sortIndex(it.clearType) }
        else -> compareBy { it.title.compact }
    }
    val directed = if (sortDescending) primary.reversed() else primary
    return filtered.sortedWith(
        directed
            .thenBy { it.title.compact }
            .thenBy { it.level.toIntOrNull() ?: 0 }
    )
}

@Composable
private fun PolarisChordScoreRow(record: PolarisChordSongRecord) {
    val darkTheme = isSystemInDarkTheme()
    val clearType = PolarisChordClearType.fromValue(record.clearType)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .padding(end = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        ScoreLamp(
            color = if (clearType == null || clearType == PolarisChordClearType.NO_PLAY) {
                Color.Transparent
            } else {
                PolarisChordColors.clearTypeColor(record.clearType)
            }
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = record.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            if (record.score != 0) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (record.achievementRate.isNotEmpty()) {
                        BrushedText(
                            text = "${record.achievementRate}%",
                            brush = scoreGradientBrush,
                            style = MaterialTheme.typography.labelSmall
                                .copy(fontWeight = FontWeight.ExtraBold)
                        )
                        MetadataDivider()
                    }
                    val grade = PolarisChordGrade.fromValue(record.grade)
                    if (grade != null && grade != PolarisChordGrade.NONE) {
                        BrushedText(
                            text = record.grade,
                            brush = PolarisChordColors.gradeBrush(record.grade, darkTheme),
                            style = MaterialTheme.typography.labelSmall
                                .copy(fontWeight = FontWeight.Black)
                        )
                        MetadataDivider()
                    }
                    Text(
                        text = clearType?.abbreviation ?: record.clearType,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = PolarisChordColors.clearTypeColor(record.clearType)
                    )
                    MetadataDivider()
                    Text(
                        text = record.score.toString(),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
        Card(
            modifier = Modifier
                .padding(vertical = 8.dp)
                .width(78.dp),
            shape = RoundedCornerShape(6.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceContainerHighest
            )
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 6.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(1.dp)
            ) {
                Text(
                    text = record.level,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.ExtraBold,
                    maxLines = 1
                )
                Text(
                    text = record.difficulty,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Black,
                    color = PolarisChordColors.difficultyColor(record.difficulty),
                    maxLines = 1
                )
            }
        }
    }
}
