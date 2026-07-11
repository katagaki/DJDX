package com.tsubuzaki.djdxgo.ui.games

import androidx.compose.foundation.isSystemInDarkTheme
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
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
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
import com.tsubuzaki.djdxgo.data.ddr.DDRClearLamp
import com.tsubuzaki.djdxgo.data.ddr.DDRDifficulty
import com.tsubuzaki.djdxgo.data.ddr.DDRPlayStyle
import com.tsubuzaki.djdxgo.data.ddr.DDRRank
import com.tsubuzaki.djdxgo.data.ddr.DDRSongRecord
import com.tsubuzaki.djdxgo.data.setSetting
import com.tsubuzaki.djdxgo.data.settingFlow
import com.tsubuzaki.djdxgo.ui.theme.DDRColors
import java.time.Instant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val SORT_TITLE = "Title"
private const val SORT_SCORE = "Score"
private const val SORT_CLEAR_LAMP = "ClearLamp"
private const val SORT_LEVEL = "Level"

@Composable
fun DDRScoresScreen(
    container: AppContainer,
    contentPadding: PaddingValues,
    analyticsContent: (@Composable () -> Unit)? = null,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val playStyleValue by context
        .settingFlow(SettingsKeys.ddrPlayStyle, DDRPlayStyle.SINGLE.value)
        .collectAsState(DDRPlayStyle.SINGLE.value)
    val playStyle = DDRPlayStyle.fromValue(playStyleValue)

    var selectedDateEpoch by rememberSaveable { mutableLongStateOf(Instant.now().epochSecond) }
    var records by remember { mutableStateOf(listOf<DDRSongRecord>()) }
    var isLoaded by remember { mutableStateOf(false) }
    LaunchedEffect(selectedDateEpoch, playStyle) {
        records = withContext(Dispatchers.IO) {
            container.ddrRepository.songRecords(selectedDateEpoch, playStyle)
        }
        isLoaded = true
    }

    val sortMode by context.settingFlow(SettingsKeys.ddrSortMode, SORT_TITLE)
        .collectAsState(SORT_TITLE)
    val sortDescending by context.settingFlow(SettingsKeys.ddrSortDescending, false)
        .collectAsState(false)
    val difficultyFilters by context.settingFlow(SettingsKeys.ddrDifficultyFilters, emptySet())
        .collectAsState(emptySet())
    val levelFilters by context.settingFlow(SettingsKeys.ddrLevelFilters, emptySet())
        .collectAsState(emptySet())
    val clearLampFilters by context.settingFlow(SettingsKeys.ddrClearLampFilters, emptySet())
        .collectAsState(emptySet())
    val rankFilters by context.settingFlow(SettingsKeys.ddrRankFilters, emptySet())
        .collectAsState(emptySet())
    val scoreAvailableOnly by context.settingFlow(SettingsKeys.ddrScoreAvailableOnly, true)
        .collectAsState(true)

    var query by rememberSaveable { mutableStateOf("") }
    var showFilterSheet by remember { mutableStateOf(false) }

    val displayed = remember(
        records, sortMode, sortDescending,
        difficultyFilters, levelFilters, clearLampFilters, rankFilters, scoreAvailableOnly
    ) {
        ddrDisplayRecords(
            records, "", sortMode, sortDescending,
            difficultyFilters, levelFilters, clearLampFilters, rankFilters, scoreAvailableOnly
        )
    }
    val searchResults = remember(
        records, query, sortMode, sortDescending,
        difficultyFilters, levelFilters, clearLampFilters, rankFilters, scoreAvailableOnly
    ) {
        if (query.isEmpty()) {
            emptyList()
        } else {
            ddrDisplayRecords(
                records, query, sortMode, sortDescending,
            difficultyFilters, levelFilters, clearLampFilters, rankFilters, scoreAvailableOnly
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
                DDRScoreRow(record = record)
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
                DDRScoreRow(record = record)
            },
            sortOptions = listOf(
                SortOption(SORT_TITLE, stringResource(R.string.games_sort_title)),
                SortOption(SORT_SCORE, stringResource(R.string.games_sort_score)),
                SortOption(SORT_CLEAR_LAMP, stringResource(R.string.ddr_clear_lamp)),
                SortOption(SORT_LEVEL, stringResource(R.string.games_sort_level))
            ),
            sortMode = sortMode,
            sortDescending = sortDescending,
            onSortChange = { mode, descending ->
                scope.launch {
                    context.setSetting(SettingsKeys.ddrSortMode, mode)
                    context.setSetting(SettingsKeys.ddrSortDescending, descending)
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
                    context.setSetting(SettingsKeys.ddrDifficultyFilters, emptySet())
                    context.setSetting(SettingsKeys.ddrLevelFilters, emptySet())
                    context.setSetting(SettingsKeys.ddrClearLampFilters, emptySet())
                    context.setSetting(SettingsKeys.ddrRankFilters, emptySet())
                    context.setSetting(SettingsKeys.ddrScoreAvailableOnly, true)
                }
            }
        ) {
            Text(
                text = stringResource(R.string.ddr_play_style),
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.padding(top = 12.dp, bottom = 4.dp)
            )
            val styles = DDRPlayStyle.entries.toList()
            SegmentSwitcher(
                items = styles,
                selectedIndex = styles.indexOf(playStyle).coerceAtLeast(0),
                onSelect = { index ->
                    scope.launch {
                        context.setSetting(SettingsKeys.ddrPlayStyle, styles[index].value)
                    }
                }
            ) { style ->
                Text(
                    text = style.displayName,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1
                )
            }
            FilterChipGroup(
                title = stringResource(R.string.games_filter_difficulty),
                options = DDRDifficulty.entries.map { it.value to it.value },
                selected = difficultyFilters,
                onToggle = { toggleFilter(SettingsKeys.ddrDifficultyFilters, difficultyFilters, it) },
                chipColor = { DDRColors.difficultyColor(it) }
            )
            FilterChipGroup(
                title = stringResource(R.string.games_filter_level),
                options = (1..19).map { it.toString() to it.toString() },
                selected = levelFilters,
                onToggle = { toggleFilter(SettingsKeys.ddrLevelFilters, levelFilters, it) }
            )
            FilterChipGroup(
                title = stringResource(R.string.ddr_clear_lamp),
                options = DDRClearLamp.order.map { it to DDRClearLamp.display(it) },
                selected = clearLampFilters,
                onToggle = { toggleFilter(SettingsKeys.ddrClearLampFilters, clearLampFilters, it) }
            )
            FilterChipGroup(
                title = stringResource(R.string.ddr_rank),
                options = DDRRank.order.map { it to DDRRank.display(it) },
                selected = rankFilters,
                onToggle = { toggleFilter(SettingsKeys.ddrRankFilters, rankFilters, it) }
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = stringResource(R.string.ddr_only_played),
                    style = MaterialTheme.typography.bodyLarge
                )
                Spacer(modifier = Modifier.weight(1f))
                Switch(
                    checked = scoreAvailableOnly,
                    onCheckedChange = { checked ->
                        scope.launch {
                            context.setSetting(SettingsKeys.ddrScoreAvailableOnly, checked)
                        }
                    }
                )
            }
        }
    }
}

private fun ddrDisplayRecords(
    records: List<DDRSongRecord>,
    query: String,
    sortMode: String,
    sortDescending: Boolean,
    difficulties: Set<String>,
    levels: Set<String>,
    clearLamps: Set<String>,
    ranks: Set<String>,
    scoreAvailableOnly: Boolean
): List<DDRSongRecord> {
    val queryCompact = query.compact
    val filtered = records.filter { record ->
        (queryCompact.isEmpty() || record.title.compact.contains(queryCompact)) &&
            (!scoreAvailableOnly || record.score != 0) &&
            (difficulties.isEmpty() || record.difficulty in difficulties) &&
            (levels.isEmpty() || record.level.toString() in levels) &&
            (clearLamps.isEmpty() || record.clearKind in clearLamps) &&
            (ranks.isEmpty() || record.rank in ranks)
    }
    val primary: Comparator<DDRSongRecord> = when (sortMode) {
        SORT_SCORE -> compareBy { it.score }
        SORT_CLEAR_LAMP -> compareBy { DDRClearLamp.sortIndex(it.clearKind) }
        SORT_LEVEL -> compareBy { it.level }
        else -> compareBy { it.title.compact }
    }
    val directed = if (sortDescending) primary.reversed() else primary
    return filtered.sortedWith(
        directed
            .thenBy { it.title.compact }
            .thenBy { it.level }
    )
}

@Composable
private fun DDRScoreRow(record: DDRSongRecord) {
    val darkTheme = isSystemInDarkTheme()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .padding(end = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        ScoreLamp(
            color = if (record.clearKind.isEmpty()) {
                Color.Transparent
            } else {
                DDRColors.clearColor(record.clearKind, darkTheme)
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
                    BrushedText(
                        text = record.score.toString(),
                        brush = scoreGradientBrush,
                        style = MaterialTheme.typography.labelSmall
                            .copy(fontWeight = FontWeight.ExtraBold)
                    )
                    if (record.rank.isNotEmpty()) {
                        MetadataDivider()
                        BrushedText(
                            text = DDRRank.display(record.rank),
                            brush = rankGradientBrush,
                            style = MaterialTheme.typography.labelSmall
                                .copy(fontWeight = FontWeight.Black)
                        )
                    }
                    if (record.clearKind.isNotEmpty()) {
                        MetadataDivider()
                        Text(
                            text = DDRClearLamp.display(record.clearKind),
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
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
                    text = record.difficulty,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Black,
                    color = DDRColors.difficultyColor(record.difficulty),
                    maxLines = 1
                )
                Text(
                    text = if (record.level > 0) record.level.toString() else "-",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.ExtraBold,
                    maxLines = 1
                )
            }
        }
    }
}
