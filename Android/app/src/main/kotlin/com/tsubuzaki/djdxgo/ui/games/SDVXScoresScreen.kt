package com.tsubuzaki.djdxgo.ui.games

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.datastore.preferences.core.Preferences
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.compact
import com.tsubuzaki.djdxgo.data.sdvx.SDVXClearType
import com.tsubuzaki.djdxgo.data.sdvx.SDVXDifficulty
import com.tsubuzaki.djdxgo.data.sdvx.SDVXGrade
import com.tsubuzaki.djdxgo.data.sdvx.SDVXSongRecord
import com.tsubuzaki.djdxgo.data.setSetting
import com.tsubuzaki.djdxgo.data.settingFlow
import com.tsubuzaki.djdxgo.ui.theme.SDVXColors
import java.time.Instant
import com.tsubuzaki.djdxgo.data.analytics.sdvxLevelBucket
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val SORT_TITLE = "Title"
private const val SORT_CLEAR_TYPE = "ClearType"
private const val SORT_SCORE = "Score"
private const val SORT_LEVEL = "Level"

@Composable
fun SDVXScoresScreen(
    container: AppContainer,
    contentPadding: PaddingValues,
    analyticsContent: (@Composable () -> Unit)? = null,
    onOpenSong: (title: String, dateEpoch: Long, difficulty: String) -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var selectedDateEpoch by rememberSaveable { mutableLongStateOf(Instant.now().epochSecond) }
    var records by remember { mutableStateOf(listOf<SDVXSongRecord>()) }
    var isLoaded by remember { mutableStateOf(false) }
    val dataVersion by container.dataVersion.collectAsState()
    LaunchedEffect(selectedDateEpoch, dataVersion) {
        records = withContext(Dispatchers.IO) {
            container.sdvxRepository.songRecords(selectedDateEpoch)
        }
        isLoaded = true
    }

    val sortMode by context.settingFlow(SettingsKeys.sdvxSortMode, SORT_TITLE)
        .collectAsState(SORT_TITLE)
    val sortDescending by context.settingFlow(SettingsKeys.sdvxSortDescending, false)
        .collectAsState(false)
    val difficultyFilters by context.settingFlow(SettingsKeys.sdvxDifficultyFilters, emptySet())
        .collectAsState(emptySet())
    val levelFilters by context.settingFlow(SettingsKeys.sdvxLevelFilters, emptySet())
        .collectAsState(emptySet())
    val clearTypeFilters by context.settingFlow(SettingsKeys.sdvxClearTypeFilters, emptySet())
        .collectAsState(emptySet())
    val gradeFilters by context.settingFlow(SettingsKeys.sdvxGradeFilters, emptySet())
        .collectAsState(emptySet())

    var query by rememberSaveable { mutableStateOf("") }
    var showFilterSheet by remember { mutableStateOf(false) }

    val displayed = remember(
        records, sortMode, sortDescending,
        difficultyFilters, levelFilters, clearTypeFilters, gradeFilters
    ) {
        sdvxDisplayRecords(
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
            sdvxDisplayRecords(
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
                SDVXScoreRow(record = record) {
                    onOpenSong(record.title, selectedDateEpoch, record.difficulty)
                }
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
                SDVXScoreRow(record = record) {
                    onOpenSong(record.title, selectedDateEpoch, record.difficulty)
                }
            },
            sortOptions = listOf(
                SortOption(SORT_TITLE, stringResource(R.string.games_sort_title)),
                SortOption(SORT_CLEAR_TYPE, stringResource(R.string.games_sort_clear_type)),
                SortOption(SORT_SCORE, stringResource(R.string.games_sort_score)),
                SortOption(SORT_LEVEL, stringResource(R.string.games_sort_level))
            ),
            sortMode = sortMode,
            sortDescending = sortDescending,
            onSortChange = { mode, descending ->
                scope.launch {
                    context.setSetting(SettingsKeys.sdvxSortMode, mode)
                    context.setSetting(SettingsKeys.sdvxSortDescending, descending)
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
                    context.setSetting(SettingsKeys.sdvxDifficultyFilters, emptySet())
                    context.setSetting(SettingsKeys.sdvxLevelFilters, emptySet())
                    context.setSetting(SettingsKeys.sdvxClearTypeFilters, emptySet())
                    context.setSetting(SettingsKeys.sdvxGradeFilters, emptySet())
                }
            }
        ) {
            FilterChipGroup(
                title = stringResource(R.string.games_filter_difficulty),
                options = SDVXDifficulty.entries.map { it.value to it.abbreviation },
                selected = difficultyFilters,
                onToggle = { toggleFilter(SettingsKeys.sdvxDifficultyFilters, difficultyFilters, it) },
                chipColor = { SDVXColors.difficultyColor(it) }
            )
            FilterChipGroup(
                title = stringResource(R.string.games_filter_level),
                options = records.map { sdvxLevelBucket(it.level) }
                    .distinct()
                    .sortedBy { it.toDoubleOrNull() ?: 0.0 }
                    .map { it to it },
                selected = levelFilters,
                onToggle = { toggleFilter(SettingsKeys.sdvxLevelFilters, levelFilters, it) }
            )
            FilterChipGroup(
                title = stringResource(R.string.games_filter_clear_type),
                options = SDVXClearType.entries.map { it.value to it.abbreviation },
                selected = clearTypeFilters,
                onToggle = { toggleFilter(SettingsKeys.sdvxClearTypeFilters, clearTypeFilters, it) },
                chipColor = { SDVXColors.clearTypeColor(it) }
            )
            FilterChipGroup(
                title = stringResource(R.string.games_filter_grade),
                options = SDVXGrade.entries.map { it.value to it.value },
                selected = gradeFilters,
                onToggle = { toggleFilter(SettingsKeys.sdvxGradeFilters, gradeFilters, it) }
            )
        }
    }
}

private fun sdvxDisplayRecords(
    records: List<SDVXSongRecord>,
    query: String,
    sortMode: String,
    sortDescending: Boolean,
    difficulties: Set<String>,
    levels: Set<String>,
    clearTypes: Set<String>,
    grades: Set<String>
): List<SDVXSongRecord> {
    val queryCompact = query.compact
    val filtered = records.filter { record ->
        (queryCompact.isEmpty() || record.title.compact.contains(queryCompact)) &&
            (difficulties.isEmpty() || record.difficulty in difficulties) &&
            (levels.isEmpty() || sdvxLevelBucket(record.level) in levels) &&
            (clearTypes.isEmpty() || record.clearType in clearTypes) &&
            (grades.isEmpty() || record.grade in grades)
    }
    val primary: Comparator<SDVXSongRecord> = when (sortMode) {
        SORT_CLEAR_TYPE -> compareBy { SDVXClearType.sortIndex(it.clearType) }
        SORT_SCORE -> compareBy { it.highScore }
        SORT_LEVEL -> compareBy { it.level.toDoubleOrNull() ?: 0.0 }
        else -> compareBy { it.title.compact }
    }
    val directed = if (sortDescending) primary.reversed() else primary
    return filtered.sortedWith(
        directed
            .thenBy { it.title.compact }
            .thenBy { it.level.toDoubleOrNull() ?: 0.0 }
    )
}

@Composable
private fun SDVXScoreRow(record: SDVXSongRecord, onClick: () -> Unit) {
    val clearType = SDVXClearType.fromValue(record.clearType)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .height(IntrinsicSize.Min)
            .padding(end = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        ScoreLamp(
            color = if (clearType == null || clearType == SDVXClearType.NO_PLAY) {
                Color.Transparent
            } else {
                SDVXColors.clearTypeColor(record.clearType)
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
            if (record.highScore != 0) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val grade = SDVXGrade.fromValue(record.grade)
                    if (grade != null && grade != SDVXGrade.NONE) {
                        BrushedText(
                            text = record.grade,
                            brush = SDVXColors.gradeBrush,
                            style = MaterialTheme.typography.labelSmall
                                .copy(fontWeight = FontWeight.Black)
                        )
                        MetadataDivider()
                    }
                    BrushedText(
                        text = record.highScore.toString(),
                        brush = scoreGradientBrush,
                        style = MaterialTheme.typography.labelSmall
                            .copy(fontWeight = FontWeight.ExtraBold)
                    )
                    MetadataDivider()
                    Text(
                        text = clearType?.abbreviation ?: record.clearType,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = SDVXColors.clearTypeColor(record.clearType)
                    )
                }
            }
        }
        Box(
            modifier = Modifier
                .padding(vertical = 8.dp)
                .width(92.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(SDVXColors.difficultyColor(record.difficulty))
                .padding(horizontal = 8.dp, vertical = 8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = SDVXDifficulty.fromValue(record.difficulty)?.abbreviation
                        ?: record.difficulty,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    maxLines = 1
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = record.level,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    maxLines = 1
                )
            }
        }
    }
}
