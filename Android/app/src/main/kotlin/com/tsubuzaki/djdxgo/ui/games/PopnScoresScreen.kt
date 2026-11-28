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
import com.tsubuzaki.djdxgo.data.popn.PopnClearType
import com.tsubuzaki.djdxgo.data.popn.PopnDifficulty
import com.tsubuzaki.djdxgo.data.popn.PopnMedal
import com.tsubuzaki.djdxgo.data.popn.PopnRank
import com.tsubuzaki.djdxgo.data.popn.PopnSongRecord
import com.tsubuzaki.djdxgo.data.setSetting
import com.tsubuzaki.djdxgo.data.settingFlow
import com.tsubuzaki.djdxgo.ui.theme.PopnColors
import java.time.Instant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val SORT_TITLE = "Title"
private const val SORT_SCORE = "Score"
private const val SORT_LEVEL = "Level"
private const val SORT_MEDAL = "Medal"

@Composable
fun PopnScoresScreen(
    container: AppContainer,
    contentPadding: PaddingValues,
    analyticsContent: (@Composable () -> Unit)? = null,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var selectedDateEpoch by rememberSaveable { mutableLongStateOf(Instant.now().epochSecond) }
    var records by remember { mutableStateOf(listOf<PopnSongRecord>()) }
    var isLoaded by remember { mutableStateOf(false) }
    val dataVersion by container.dataVersion.collectAsState()
    LaunchedEffect(selectedDateEpoch, dataVersion) {
        records = withContext(Dispatchers.IO) {
            container.popnRepository.songRecords(selectedDateEpoch)
        }
        isLoaded = true
    }

    val sortMode by context.settingFlow(SettingsKeys.popnSortMode, SORT_TITLE)
        .collectAsState(SORT_TITLE)
    val sortDescending by context.settingFlow(SettingsKeys.popnSortDescending, false)
        .collectAsState(false)
    val difficultyFilters by context
        .settingFlow(SettingsKeys.popnDifficultyFilters, emptySet())
        .collectAsState(emptySet())
    val levelFilters by context.settingFlow(SettingsKeys.popnLevelFilters, emptySet())
        .collectAsState(emptySet())
    val clearTypeFilters by context
        .settingFlow(SettingsKeys.popnClearTypeFilters, emptySet())
        .collectAsState(emptySet())
    val rankFilters by context.settingFlow(SettingsKeys.popnRankFilters, emptySet())
        .collectAsState(emptySet())

    var query by rememberSaveable { mutableStateOf("") }
    var showFilterSheet by remember { mutableStateOf(false) }

    val displayed = remember(
        records, sortMode, sortDescending,
        difficultyFilters, levelFilters, clearTypeFilters, rankFilters
    ) {
        popnDisplayRecords(
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
            popnDisplayRecords(
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
                PopnScoreRow(record = record)
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
                PopnScoreRow(record = record)
            },
            sortOptions = listOf(
                SortOption(SORT_TITLE, stringResource(R.string.games_sort_title)),
                SortOption(SORT_SCORE, stringResource(R.string.games_sort_score)),
                SortOption(SORT_LEVEL, stringResource(R.string.games_sort_level)),
                SortOption(SORT_MEDAL, stringResource(R.string.popn_medal))
            ),
            sortMode = sortMode,
            sortDescending = sortDescending,
            onSortChange = { mode, descending ->
                scope.launch {
                    context.setSetting(SettingsKeys.popnSortMode, mode)
                    context.setSetting(SettingsKeys.popnSortDescending, descending)
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
                    context.setSetting(SettingsKeys.popnDifficultyFilters, emptySet())
                    context.setSetting(SettingsKeys.popnLevelFilters, emptySet())
                    context.setSetting(SettingsKeys.popnClearTypeFilters, emptySet())
                    context.setSetting(SettingsKeys.popnRankFilters, emptySet())
                }
            }
        ) {
            FilterChipGroup(
                title = stringResource(R.string.games_filter_difficulty),
                options = PopnDifficulty.entries.map { it.value to it.value },
                selected = difficultyFilters,
                onToggle = {
                    toggleFilter(SettingsKeys.popnDifficultyFilters, difficultyFilters, it)
                },
                chipColor = { PopnColors.difficultyColor(it) }
            )
            FilterChipGroup(
                title = stringResource(R.string.games_filter_level),
                options = (1..50).map { it.toString() to it.toString() },
                selected = levelFilters,
                onToggle = { toggleFilter(SettingsKeys.popnLevelFilters, levelFilters, it) }
            )
            FilterChipGroup(
                title = stringResource(R.string.popn_medal),
                options = PopnClearType.entries.map { it.value to it.abbreviation },
                selected = clearTypeFilters,
                onToggle = {
                    toggleFilter(SettingsKeys.popnClearTypeFilters, clearTypeFilters, it)
                },
                chipColor = { PopnColors.clearTypeColor(it) }
            )
            FilterChipGroup(
                title = stringResource(R.string.popn_rank),
                options = PopnRank.sorted.map { it.value to it.value },
                selected = rankFilters,
                onToggle = { toggleFilter(SettingsKeys.popnRankFilters, rankFilters, it) }
            )
        }
    }
}

private fun popnDisplayRecords(
    records: List<PopnSongRecord>,
    query: String,
    sortMode: String,
    sortDescending: Boolean,
    difficulties: Set<String>,
    levels: Set<String>,
    clearTypes: Set<String>,
    ranks: Set<String>
): List<PopnSongRecord> {
    val queryCompact = query.compact
    val filtered = records.filter { record ->
        (queryCompact.isEmpty() || record.title.compact.contains(queryCompact) ||
            record.genre.compact.contains(queryCompact)) &&
            (difficulties.isEmpty() || record.difficulty in difficulties) &&
            (levels.isEmpty() || record.level.toString() in levels) &&
            (clearTypes.isEmpty() || record.clearType in clearTypes) &&
            (ranks.isEmpty() || record.rank in ranks)
    }
    val primary: Comparator<PopnSongRecord> = when (sortMode) {
        SORT_SCORE -> compareBy { it.score }
        SORT_LEVEL -> compareBy { it.level }
        SORT_MEDAL -> compareByDescending { PopnMedal.sortIndex(it.medal) }
        else -> compareBy { it.title.compact }
    }
    val directed = if (sortDescending) primary.reversed() else primary
    val sorted = filtered.sortedWith(
        directed
            .thenBy { it.title.compact }
            .thenBy { it.level }
    )
    if (sortMode != SORT_MEDAL) return sorted
    val (played, unplayed) = sorted.partition { it.medalEnum != PopnMedal.NO_PLAY }
    return played + unplayed
}

@Composable
private fun PopnScoreRow(record: PopnSongRecord) {
    val darkTheme = isSystemInDarkTheme()
    val medal = record.medalEnum
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .padding(end = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        ScoreLamp(
            color = if (medal == PopnMedal.NO_PLAY) {
                Color.Transparent
            } else {
                PopnColors.clearTypeColor(record.clearType)
            }
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            if (record.genre.isNotEmpty()) {
                Text(
                    text = record.genre,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Text(
                text = record.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            if (medal != PopnMedal.NO_PLAY) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    BrushedText(
                        text = record.score.toString(),
                        brush = scoreGradientBrush,
                        style = MaterialTheme.typography.labelSmall.gameFont()
                            .copy(fontWeight = FontWeight.ExtraBold)
                    )
                    if (record.rank != PopnRank.NONE.value) {
                        MetadataDivider()
                        BrushedText(
                            text = record.rank,
                            brush = PopnColors.rankBrush(record.rank, darkTheme),
                            style = MaterialTheme.typography.labelSmall.gameFont()
                                .copy(fontWeight = FontWeight.Black)
                        )
                    }
                    MetadataDivider()
                    Text(
                        text = medal.abbreviation,
                        style = MaterialTheme.typography.labelSmall.gameFont(),
                        fontWeight = FontWeight.Bold,
                        color = PopnColors.clearTypeColor(record.clearType)
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
                    text = if (record.level > 0) record.level.toString() else "-",
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
                    color = PopnColors.difficultyColor(record.difficulty),
                    maxLines = 1
                )
            }
        }
    }
}
