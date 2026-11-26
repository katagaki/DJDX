package com.tsubuzaki.djdxgo.ui.games

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Article
import androidx.compose.material.icons.outlined.SmartDisplay
import androidx.compose.material3.Card
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.compact
import com.tsubuzaki.djdxgo.ui.common.ChartNotesCard
import com.tsubuzaki.djdxgo.data.external.SDVXInChart
import com.tsubuzaki.djdxgo.data.sdvx.SDVXClearType
import com.tsubuzaki.djdxgo.data.sdvx.SDVXDifficulty
import com.tsubuzaki.djdxgo.data.sdvx.SDVXGrade
import com.tsubuzaki.djdxgo.data.sdvx.SDVXSongRecord
import com.tsubuzaki.djdxgo.ui.common.HistoryGuide
import com.tsubuzaki.djdxgo.ui.common.ScoreHistoryCard
import com.tsubuzaki.djdxgo.ui.common.zoomedHistoryMinimum
import com.tsubuzaki.djdxgo.ui.theme.Palette
import com.tsubuzaki.djdxgo.ui.theme.SDVXColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private const val SDVX_MAX_SCORE = 10_000_000

@Composable
fun SDVXScoreViewerScreen(
    container: AppContainer,
    title: String,
    dateEpoch: Long,
    initialDifficulty: String,
    onBack: () -> Unit,
    onOpenChart: (SDVXInChart) -> Unit
) {
    val darkTheme = isSystemInDarkTheme()
    var records by remember { mutableStateOf(listOf<SDVXSongRecord>()) }
    LaunchedEffect(title, dateEpoch) {
        records = withContext(Dispatchers.IO) {
            container.sdvxRepository.importGroupFor(dateEpoch)?.let { group ->
                container.database.sdvxDao().songRecordsForTitle(group.id, title)
                    .sortedBy { SDVXDifficulty.fromValue(it.difficulty)?.ordinal ?: Int.MAX_VALUE }
            } ?: emptyList()
        }
    }

    var selectedIndex by rememberSaveable { mutableIntStateOf(-1) }
    LaunchedEffect(records) {
        if (selectedIndex < 0 && records.isNotEmpty()) {
            selectedIndex = records.indexOfFirst { it.difficulty == initialDifficulty }.coerceAtLeast(0)
        }
    }
    val record = records.getOrNull(selectedIndex.coerceIn(0, (records.size - 1).coerceAtLeast(0)))

    var chart by remember { mutableStateOf<SDVXInChart?>(null) }
    LaunchedEffect(record?.id) {
        chart = record?.let { current ->
            withContext(Dispatchers.IO) {
                val slot = SDVXDifficulty.fromValue(current.difficulty)?.sdvxInSlot ?: "m"
                container.externalDataDao.sdvxInChart(current.title.compact, slot)
            }
        }
    }

    var history by remember { mutableStateOf(listOf<Int>()) }
    LaunchedEffect(record?.id) {
        history = record?.let { current ->
            withContext(Dispatchers.IO) {
                container.database.sdvxDao().scoreHistory(current.title, current.difficulty).map { it.score }
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
                            text = segment.level,
                            color = SDVXColors.difficultyColor(segment.difficulty),
                            fontWeight = FontWeight.Bold,
                            fontStyle = FontStyle.Italic,
                            maxLines = 1
                        )
                        Text(
                            text = SDVXDifficulty.fromValue(segment.difficulty)?.abbreviation
                                ?: segment.difficulty,
                            color = SDVXColors.difficultyColor(segment.difficulty),
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
            ViewerTitle(title = title)
            record?.let { current ->
                val clearType = SDVXClearType.fromValue(current.clearType)
                val grade = SDVXGrade.fromValue(current.grade)
                DetailCard {
                    DetailRow(
                        label = stringResource(R.string.sdvx_clear_type),
                        value = clearType?.abbreviation ?: current.clearType,
                        color = SDVXColors.clearTypeColor(current.clearType)
                    )
                    if (grade != null && grade != SDVXGrade.NONE) {
                        DetailRow(
                            label = stringResource(R.string.sdvx_grade),
                            value = current.grade,
                            brush = SDVXColors.gradeBrush,
                            outline = SDVXColors.gradeOutlineColor
                        )
                    }
                    DetailRow(
                        label = stringResource(R.string.sdvx_high_score),
                        value = current.highScore.toString(),
                        brush = SDVXColors.scoreBrush,
                        outline = SDVXColors.scoreOutlineColor
                    )
                    DetailRow(
                        label = stringResource(R.string.sdvx_ex_score),
                        value = current.exScore.toString(),
                        brush = SDVXColors.scoreBrush,
                        outline = SDVXColors.scoreOutlineColor
                    )
                }
                Card(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp)
                    ) {
                        CountCell(
                            label = stringResource(R.string.sdvx_plays),
                            value = current.playCount.toString(),
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        CountCell(
                            label = stringResource(R.string.sdvx_clears),
                            value = current.clearCount.toString(),
                            color = Palette.green
                        )
                        CountCell(
                            label = stringResource(R.string.sdvx_uc),
                            value = current.ultimateChainCount.toString(),
                            color = Palette.pink
                        )
                        CountCell(
                            label = stringResource(R.string.sdvx_perfect),
                            value = current.perfectCount.toString(),
                            color = Palette.yellow
                        )
                    }
                }
                ScoreHistoryCard(
                    scores = history,
                    minScore = zoomedHistoryMinimum(history, 100_000, SDVX_MAX_SCORE),
                    maxScore = SDVX_MAX_SCORE,
                    guides = listOf(
                        SDVXGrade.S to 9_900_000f,
                        SDVXGrade.AAA_PLUS to 9_800_000f,
                        SDVXGrade.AAA to 9_700_000f,
                        SDVXGrade.AA_PLUS to 9_500_000f,
                        SDVXGrade.AA to 9_300_000f
                    ).mapIndexed { index, (grade, value) ->
                        HistoryGuide(value, SDVXColors.gradeColor(grade.value, darkTheme), 0.7f - index * 0.08f)
                    }
                )
                Card(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(8.dp)
                    ) {
                        val context = androidx.compose.ui.platform.LocalContext.current
                        ChartActionButton(
                            icon = Icons.Outlined.SmartDisplay,
                            label = stringResource(R.string.games_youtube)
                        ) {
                            context.startActivity(
                                android.content.Intent(
                                    android.content.Intent.ACTION_VIEW,
                                    android.net.Uri.parse(
                                        youTubeSearchURL(
                                            "SDVX ${SDVXDifficulty.fromValue(current.difficulty)?.abbreviation.orEmpty()} $title"
                                        )
                                    )
                                )
                            )
                        }
                        chart?.let { sdvxInChart ->
                            ChartActionButton(
                                icon = Icons.Outlined.Article,
                                label = stringResource(R.string.sdvx_view_chart)
                            ) {
                                onOpenChart(sdvxInChart)
                            }
                        }
                    }
                }
                ChartNotesCard(
                    repository = container.chartNotesRepository,
                    game = Game.SOUND_VOLTEX,
                    title = title,
                    chart = current.difficulty
                )
            }
    }
}
