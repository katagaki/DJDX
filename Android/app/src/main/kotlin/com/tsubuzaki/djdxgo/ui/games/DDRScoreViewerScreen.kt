package com.tsubuzaki.djdxgo.ui.games

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.ddr.DDRClearLamp
import com.tsubuzaki.djdxgo.data.ddr.DDRPlayStyle
import com.tsubuzaki.djdxgo.data.ddr.DDRRank
import com.tsubuzaki.djdxgo.data.ddr.DDRSongRecord
import com.tsubuzaki.djdxgo.ui.common.ChartNotesCard
import com.tsubuzaki.djdxgo.ui.common.HistoryGuide
import com.tsubuzaki.djdxgo.ui.common.ScoreHistoryCard
import com.tsubuzaki.djdxgo.ui.common.zoomedHistoryMinimum
import com.tsubuzaki.djdxgo.ui.theme.DDRColors
import com.tsubuzaki.djdxgo.ui.theme.Palette
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private const val DDR_MAX_SCORE = 1_000_000

@Composable
fun DDRScoreViewerScreen(
    container: AppContainer,
    songIndex: String,
    dateEpoch: Long,
    style: String,
    initialDifficulty: String,
    onBack: () -> Unit
) {
    val darkTheme = isSystemInDarkTheme()
    var records by remember { mutableStateOf(listOf<DDRSongRecord>()) }
    LaunchedEffect(songIndex, dateEpoch, style) {
        records = withContext(Dispatchers.IO) {
            container.ddrRepository.songRecordsForSong(dateEpoch, songIndex, DDRPlayStyle.fromValue(style))
        }
    }

    var selectedIndex by rememberSaveable { mutableIntStateOf(-1) }
    LaunchedEffect(records) {
        if (selectedIndex < 0 && records.isNotEmpty()) {
            selectedIndex = records.indexOfFirst { it.difficulty == initialDifficulty }.coerceAtLeast(0)
        }
    }
    val record = records.getOrNull(selectedIndex.coerceIn(0, (records.size - 1).coerceAtLeast(0)))

    var history by remember { mutableStateOf(listOf<Int>()) }
    LaunchedEffect(record?.id) {
        history = record?.let { current ->
            withContext(Dispatchers.IO) {
                container.database.ddrDao()
                    .scoreHistory(current.songIndex, current.style, current.difficulty)
                    .map { it.score }
            }
        }.orEmpty()
    }

    ViewerWithSelector(
        onBack = onBack,
        selector = if (records.size > 1) {
            {
                ExpressiveLevelSelector(
                    items = records,
                    selectedIndex = selectedIndex.coerceIn(0, records.size - 1),
                    onSelect = { selectedIndex = it }
                ) { segment ->
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = if (segment.level > 0) segment.level.toString() else "-",
                            color = DDRColors.difficultyColor(segment.difficulty),
                            fontWeight = FontWeight.Bold,
                            maxLines = 1
                        )
                        Text(
                            text = segment.difficulty,
                            color = DDRColors.difficultyColor(segment.difficulty),
                            fontWeight = FontWeight.Black,
                            style = MaterialTheme.typography.labelSmall,
                            maxLines = 1
                        )
                    }
                }
            }
        } else {
            null
        }
    ) {
        ViewerTitle(title = records.firstOrNull()?.title.orEmpty())
        record?.let { current ->
            DetailCard {
                DetailRow(
                    label = stringResource(R.string.ddr_clear_lamp),
                    value = current.clearKind.takeIf { it.isNotEmpty() }?.let { DDRClearLamp.display(it) } ?: "-",
                    color = DDRColors.clearColor(current.clearKind, darkTheme)
                )
                DetailRow(
                    label = stringResource(R.string.ddr_rank),
                    value = current.rank.takeIf { it.isNotEmpty() }?.let { DDRRank.display(it) } ?: "-",
                    color = DDRColors.rankColor(current.rank, darkTheme)
                )
                DetailRow(
                    label = stringResource(R.string.ddr_score),
                    value = current.score.toString(),
                    brush = scoreGradientBrush
                )
                DetailRow(
                    label = stringResource(R.string.ddr_flare_rank),
                    value = current.flareRank.takeIf { it.isNotEmpty() }?.uppercase() ?: "-",
                    color = Palette.orange
                )
                DetailRow(
                    label = stringResource(R.string.ddr_flare_skill),
                    value = current.flareSkill.toString(),
                    color = Palette.orange
                )
            }
            ScoreHistoryCard(
                scores = history,
                minScore = zoomedHistoryMinimum(history, 50_000, DDR_MAX_SCORE),
                maxScore = DDR_MAX_SCORE,
                guides = listOf(
                    "aaa" to 990_000f,
                    "aa_p" to 950_000f,
                    "aa" to 900_000f,
                    "a_p" to 850_000f
                ).mapIndexed { index, (rank, value) ->
                    HistoryGuide(value, DDRColors.rankColor(rank, darkTheme), 0.7f - index * 0.1f)
                }
            )
            record?.let { current ->
                ChartNotesCard(
                    repository = container.chartNotesRepository,
                    game = Game.DANCE_DANCE_REVOLUTION,
                    title = current.title,
                    chart = "${current.style}-${current.difficulty}"
                )
            }
        }
    }
}
