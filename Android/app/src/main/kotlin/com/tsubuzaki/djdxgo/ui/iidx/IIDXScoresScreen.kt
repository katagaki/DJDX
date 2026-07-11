package com.tsubuzaki.djdxgo.ui.iidx

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.compact
import com.tsubuzaki.djdxgo.data.external.IIDXSong
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.iidx.IIDXSongRecord
import com.tsubuzaki.djdxgo.data.setSetting
import com.tsubuzaki.djdxgo.ui.games.ScoresToolbar
import com.tsubuzaki.djdxgo.ui.games.SortOption
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun IIDXScoresScreen(
    container: AppContainer,
    contentPadding: PaddingValues,
    analyticsContent: (@Composable () -> Unit)? = null,
    onOpenSong: (title: String, playType: String, initialLevel: String, dateEpoch: Long) -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val playTypeValue by rememberSetting(SettingsKeys.iidxPlayType, IIDXPlayType.SINGLE.value)
    val sortModeValue by rememberSetting(
        SettingsKeys.iidxSortMode,
        IIDXSortMode.LAST_PLAY_DATE.value
    )
    val sortDescending by rememberSetting(SettingsKeys.iidxSortDescending, true)
    val levelFilters by rememberSetting(SettingsKeys.iidxLevelFilters, emptySet())
    val difficultyFilters by rememberSetting(SettingsKeys.iidxDifficultyFilters, emptySet())
    val clearTypeFilters by rememberSetting(SettingsKeys.iidxClearTypeFilters, emptySet())
    val djLevelFilters by rememberSetting(SettingsKeys.iidxDJLevelFilters, emptySet())
    val scoreAvailableOnly by rememberSetting(SettingsKeys.iidxScoreAvailableOnly, true)
    val beginnerHidden by rememberSetting(SettingsKeys.iidxBeginnerLevelHidden, false)
    val genreVisible by rememberSetting(SettingsKeys.iidxGenreVisible, false)
    val artistVisible by rememberSetting(SettingsKeys.iidxArtistVisible, true)
    val levelVisible by rememberSetting(SettingsKeys.iidxLevelVisible, true)
    val djLevelVisible by rememberSetting(SettingsKeys.iidxDJLevelVisible, true)
    val scoreRateVisible by rememberSetting(SettingsKeys.iidxScoreRateVisible, true)
    val scoreVisible by rememberSetting(SettingsKeys.iidxScoreVisible, true)
    val lastPlayDateVisible by rememberSetting(SettingsKeys.iidxLastPlayDateVisible, false)

    var selectedDateEpoch by rememberSaveable {
        mutableLongStateOf(System.currentTimeMillis() / 1000L)
    }
    var searchTerm by rememberSaveable { mutableStateOf("") }
    var showFilterSheet by rememberSaveable { mutableStateOf(false) }

    var records by remember { mutableStateOf<List<IIDXSongRecord>?>(null) }
    var songs by remember { mutableStateOf<Map<String, IIDXSong>>(emptyMap()) }

    val playType = IIDXPlayType.fromValue(playTypeValue)
    val sortMode = IIDXSortMode.fromValue(sortModeValue)

    LaunchedEffect(selectedDateEpoch, playTypeValue) {
        records = withContext(Dispatchers.IO) {
            container.iidxRepository.songRecords(selectedDateEpoch, playType)
        }
    }
    LaunchedEffect(Unit) {
        songs = withContext(Dispatchers.IO) {
            container.externalDataDao.allIIDXSongs().associateBy { it.titleCompact }
        }
    }

    val entries = remember(
        records, songs, playTypeValue, levelFilters, difficultyFilters,
        clearTypeFilters, djLevelFilters, scoreAvailableOnly, beginnerHidden,
        sortModeValue, sortDescending
    ) {
        filterAndSortEntries(
            records = records.orEmpty(),
            songs = songs,
            playType = playType,
            searchTerm = "",
            levelFilters = levelFilters,
            difficultyFilters = difficultyFilters,
            clearTypeFilters = clearTypeFilters,
            djLevelFilters = djLevelFilters,
            scoreAvailableOnly = scoreAvailableOnly,
            beginnerHidden = beginnerHidden,
            sortMode = sortMode,
            sortDescending = sortDescending
        )
    }
    val searchEntries = remember(
        records, songs, playTypeValue, searchTerm, levelFilters, difficultyFilters,
        clearTypeFilters, djLevelFilters, scoreAvailableOnly, beginnerHidden,
        sortModeValue, sortDescending
    ) {
        if (searchTerm.isEmpty()) {
            emptyList()
        } else {
            filterAndSortEntries(
                records = records.orEmpty(),
                songs = songs,
                playType = playType,
                searchTerm = searchTerm,
                levelFilters = levelFilters,
                difficultyFilters = difficultyFilters,
                clearTypeFilters = clearTypeFilters,
                djLevelFilters = djLevelFilters,
                scoreAvailableOnly = scoreAvailableOnly,
                beginnerHidden = beginnerHidden,
                sortMode = sortMode,
                sortDescending = sortDescending
            )
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
            if (analyticsContent != null) {
                item(key = "analytics") { analyticsContent() }
            }
            if (records != null && entries.isEmpty()) {
                item(key = "empty") {
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
                        )
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text(
                                text = stringResource(R.string.scores_empty_title),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold
                            )
                            Text(
                                text = stringResource(R.string.scores_empty_message),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(top = 4.dp)
                            )
                        }
                    }
                }
            }
            items(
                count = entries.size,
                key = { index ->
                    val entry = entries[index]
                    "${entry.record.title}_${entry.level.code}"
                }
            ) { index ->
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
                    onClick = {
                        onOpenSong(
                            entry.record.title,
                            entry.record.playType,
                            entry.level.code,
                            selectedDateEpoch
                        )
                    }
                )
                HorizontalDivider()
            }
        }

        ScoresToolbar(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(bottom = 12.dp),
            query = searchTerm,
            onQueryChange = { searchTerm = it },
            searchResults = searchEntries,
            searchResultContent = { entry ->
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
                    onClick = {
                        onOpenSong(
                            entry.record.title,
                            entry.record.playType,
                            entry.level.code,
                            selectedDateEpoch
                        )
                    }
                )
            },
            sortOptions = IIDXSortMode.entries.map { mode ->
                SortOption(mode.value, stringResource(mode.labelRes))
            },
            sortMode = sortModeValue,
            sortDescending = sortDescending,
            onSortChange = { mode, descending ->
                scope.launch {
                    context.setSetting(SettingsKeys.iidxSortMode, mode)
                    context.setSetting(SettingsKeys.iidxSortDescending, descending)
                }
            },
            onFilterClick = { showFilterSheet = true }
        )
    }

    if (showFilterSheet) {
        IIDXScoreFilterSheet(onDismiss = { showFilterSheet = false })
    }
}
