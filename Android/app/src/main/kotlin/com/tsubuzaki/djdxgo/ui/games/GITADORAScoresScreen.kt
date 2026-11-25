package com.tsubuzaki.djdxgo.ui.games

import com.tsubuzaki.djdxgo.ui.theme.GameFontWidth
import com.tsubuzaki.djdxgo.ui.theme.GameFonts
import com.tsubuzaki.djdxgo.ui.theme.gameFont
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
import com.tsubuzaki.djdxgo.data.gitadora.GITADORAClearType
import com.tsubuzaki.djdxgo.data.gitadora.GITADORADifficulty
import com.tsubuzaki.djdxgo.data.gitadora.GITADORAInstrument
import com.tsubuzaki.djdxgo.data.gitadora.GITADORARank
import com.tsubuzaki.djdxgo.data.gitadora.GITADORASongRecord
import com.tsubuzaki.djdxgo.data.setSetting
import com.tsubuzaki.djdxgo.data.settingFlow
import com.tsubuzaki.djdxgo.ui.theme.GITADORAColors
import java.time.Instant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Locale
import kotlinx.coroutines.withContext

private const val SORT_TITLE = "Title"
private const val SORT_RATE = "Rate"
private const val SORT_LEVEL = "Level"
private const val SORT_CLEAR_TYPE = "ClearType"
private const val SORT_SKILL = "Skill"

@Composable
fun GITADORAScoresScreen(
    container: AppContainer,
    contentPadding: PaddingValues,
    instrument: GITADORAInstrument,
    analyticsContent: (@Composable () -> Unit)? = null,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var selectedDateEpoch by rememberSaveable { mutableLongStateOf(Instant.now().epochSecond) }
    var allRecords by remember { mutableStateOf(listOf<GITADORASongRecord>()) }
    var isLoaded by remember { mutableStateOf(false) }
    val dataVersion by container.dataVersion.collectAsState()
    LaunchedEffect(selectedDateEpoch, dataVersion) {
        allRecords = withContext(Dispatchers.IO) {
            container.gitadoraRepository.songRecords(selectedDateEpoch)
        }
        isLoaded = true
    }
    val records = remember(allRecords, instrument) { allRecords.filter { it.instrument == instrument.value } }

    val sortMode by context.settingFlow(SettingsKeys.gitadoraSortMode, SORT_TITLE)
        .collectAsState(SORT_TITLE)
    val sortDescending by context.settingFlow(SettingsKeys.gitadoraSortDescending, false)
        .collectAsState(false)
    val difficultyFilters by context
        .settingFlow(SettingsKeys.gitadoraDifficultyFilters, emptySet())
        .collectAsState(emptySet())
    val levelFilters by context.settingFlow(SettingsKeys.gitadoraLevelFilters, emptySet())
        .collectAsState(emptySet())
    val clearTypeFilters by context
        .settingFlow(SettingsKeys.gitadoraClearTypeFilters, emptySet())
        .collectAsState(emptySet())
    val rankFilters by context.settingFlow(SettingsKeys.gitadoraRankFilters, emptySet())
        .collectAsState(emptySet())

    var query by rememberSaveable { mutableStateOf("") }
    var showFilterSheet by remember { mutableStateOf(false) }

    val displayed = remember(
        records, sortMode, sortDescending,
        difficultyFilters, levelFilters, clearTypeFilters, rankFilters
    ) {
        gitadoraDisplayRecords(
            records, "", sortMode, sortDescending,
            difficultyFilters, levelFilters, clearTypeFilters, rankFilters
        )
    }
    val searchResults = remember(
        records, query, sortMode, sortDescending,
        difficultyFilters, levelFilters, clearTypeFilters, rankFilters
    ) {
        if (query.isEmpty()) {
            emptyList()
        } else {
            gitadoraDisplayRecords(
                records, query, sortMode, sortDescending,
            difficultyFilters, levelFilters, clearTypeFilters, rankFilters
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
                GITADORAScoreRow(record = record)
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
                GITADORAScoreRow(record = record)
            },
            sortOptions = listOf(
                SortOption(SORT_TITLE, stringResource(R.string.games_sort_title)),
                SortOption(SORT_RATE, stringResource(R.string.polaris_sort_rate)),
                SortOption(SORT_SKILL, stringResource(R.string.gitadora_skill)),
                SortOption(SORT_LEVEL, stringResource(R.string.games_sort_level)),
                SortOption(SORT_CLEAR_TYPE, stringResource(R.string.games_sort_clear_type))
            ),
            sortMode = sortMode,
            sortDescending = sortDescending,
            onSortChange = { mode, descending ->
                scope.launch {
                    context.setSetting(SettingsKeys.gitadoraSortMode, mode)
                    context.setSetting(SettingsKeys.gitadoraSortDescending, descending)
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
                    context.setSetting(SettingsKeys.gitadoraDifficultyFilters, emptySet())
                    context.setSetting(SettingsKeys.gitadoraLevelFilters, emptySet())
                    context.setSetting(SettingsKeys.gitadoraClearTypeFilters, emptySet())
                    context.setSetting(SettingsKeys.gitadoraRankFilters, emptySet())
                }
            }
        ) {
            FilterChipGroup(
                title = stringResource(R.string.games_filter_difficulty),
                options = GITADORADifficulty.entries.map { it.value to it.value },
                selected = difficultyFilters,
                onToggle = {
                    toggleFilter(SettingsKeys.gitadoraDifficultyFilters, difficultyFilters, it)
                },
                chipColor = { GITADORAColors.difficultyColor(it) }
            )
            FilterChipGroup(
                title = stringResource(R.string.games_filter_level),
                options = (1..9).map { it.toString() to it.toString() },
                selected = levelFilters,
                onToggle = { toggleFilter(SettingsKeys.gitadoraLevelFilters, levelFilters, it) }
            )
            FilterChipGroup(
                title = stringResource(R.string.games_filter_clear_type),
                options = GITADORAClearType.entries.map { it.value to it.abbreviation },
                selected = clearTypeFilters,
                onToggle = {
                    toggleFilter(SettingsKeys.gitadoraClearTypeFilters, clearTypeFilters, it)
                },
                chipColor = { GITADORAColors.clearTypeColor(it) }
            )
            FilterChipGroup(
                title = stringResource(R.string.gitadora_rank),
                options = GITADORARank.sorted.map { it.value to it.value },
                selected = rankFilters,
                onToggle = { toggleFilter(SettingsKeys.gitadoraRankFilters, rankFilters, it) }
            )
        }
    }
}

private fun gitadoraDisplayRecords(
    records: List<GITADORASongRecord>,
    query: String,
    sortMode: String,
    sortDescending: Boolean,
    difficulties: Set<String>,
    levels: Set<String>,
    clearTypes: Set<String>,
    ranks: Set<String>
): List<GITADORASongRecord> {
    val queryCompact = query.compact
    val filtered = records.filter { record ->
        (queryCompact.isEmpty() || record.title.compact.contains(queryCompact)) &&
            (difficulties.isEmpty() || record.difficulty in difficulties) &&
            (levels.isEmpty() || record.levelBucket in levels) &&
            (clearTypes.isEmpty() || record.clearType in clearTypes) &&
            (ranks.isEmpty() || record.rank in ranks)
    }
    val primary: Comparator<GITADORASongRecord> = when (sortMode) {
        SORT_RATE -> compareBy { it.achievementRate.toDoubleOrNull() ?: 0.0 }
        SORT_LEVEL -> compareBy { it.levelValue }
        SORT_SKILL -> compareBy { it.skillValue }
        SORT_CLEAR_TYPE -> compareByDescending { GITADORAClearType.sortIndex(it.clearType) }
        else -> compareBy { it.title.compact }
    }
    val directed = if (sortDescending) primary.reversed() else primary
    val sorted = filtered.sortedWith(
        directed
            .thenBy { it.title.compact }
            .thenBy { it.levelValue }
    )
    if (sortMode != SORT_CLEAR_TYPE) return sorted
    val (cleared, uncleared) = sorted.partition { GITADORAClearType.sortIndex(it.clearType) < GITADORAClearType.sorted.size - 1 }
    return cleared + uncleared
}

@Composable
private fun GITADORAScoreRow(record: GITADORASongRecord) {
    val darkTheme = isSystemInDarkTheme()
    val clearType = GITADORAClearType.fromValue(record.clearType)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .padding(end = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        ScoreLamp(
            color = if (clearType == null || clearType == GITADORAClearType.NO_PLAY) {
                Color.Transparent
            } else {
                GITADORAColors.clearTypeColor(record.clearType)
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
            if (clearType != null && clearType != GITADORAClearType.NO_PLAY) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (record.achievementRate.isNotEmpty()) {
                        BrushedText(
                            text = "${record.achievementRate}%",
                            brush = scoreGradientBrush,
                            style = MaterialTheme.typography.labelSmall.gameFont()
                                .copy(fontWeight = FontWeight.ExtraBold)
                        )
                        MetadataDivider()
                    }
                    val rank = GITADORARank.fromValue(record.rank)
                    if (rank != null && rank != GITADORARank.NONE) {
                        BrushedText(
                            text = record.rank,
                            brush = GITADORAColors.rankBrush(record.rank, darkTheme),
                            style = MaterialTheme.typography.labelSmall.gameFont()
                                .copy(fontWeight = FontWeight.Black)
                        )
                        MetadataDivider()
                    }
                    Text(
                        text = clearType?.abbreviation ?: record.clearType,
                        style = MaterialTheme.typography.labelSmall.gameFont(),
                        fontWeight = FontWeight.Bold,
                        color = GITADORAColors.clearTypeColor(record.clearType)
                    )
                    if (record.skillValue > 0) {
                        MetadataDivider()
                        Text(
                            text = String.format(Locale.US, "%.2f", record.skillValue),
                            style = MaterialTheme.typography.labelSmall.gameFont(),
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    if (record.score > 0) {
                        MetadataDivider()
                        Text(
                            text = record.score.toString(),
                            style = MaterialTheme.typography.labelSmall.gameFont(),
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
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
                    text = record.level.ifEmpty { "-" },
                    fontSize = 18.sp,
                    fontFamily = GameFonts.family(GameFontWidth.CONDENSED),
                    fontWeight = FontWeight.ExtraBold,
                    maxLines = 1
                )
                Text(
                    text = record.difficulty,
                    fontSize = 10.sp,
                    fontFamily = GameFonts.family(GameFontWidth.CONDENSED),
                    fontWeight = FontWeight.Black,
                    color = GITADORAColors.difficultyColor(record.difficulty),
                    maxLines = 1
                )
            }
        }
    }
}
