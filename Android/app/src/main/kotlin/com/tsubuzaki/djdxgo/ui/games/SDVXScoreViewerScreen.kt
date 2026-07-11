package com.tsubuzaki.djdxgo.ui.games

import androidx.compose.foundation.layout.Row
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
import com.tsubuzaki.djdxgo.data.compact
import com.tsubuzaki.djdxgo.data.external.SDVXInChart
import com.tsubuzaki.djdxgo.data.sdvx.SDVXClearType
import com.tsubuzaki.djdxgo.data.sdvx.SDVXDifficulty
import com.tsubuzaki.djdxgo.data.sdvx.SDVXGrade
import com.tsubuzaki.djdxgo.data.sdvx.SDVXSongRecord
import com.tsubuzaki.djdxgo.ui.theme.Palette
import com.tsubuzaki.djdxgo.ui.theme.SDVXColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Composable
fun SDVXScoreViewerScreen(
    container: AppContainer,
    title: String,
    dateEpoch: Long,
    onBack: () -> Unit,
    onOpenWeb: (String) -> Unit
) {
    var records by remember { mutableStateOf(listOf<SDVXSongRecord>()) }
    LaunchedEffect(title, dateEpoch) {
        records = withContext(Dispatchers.IO) {
            container.sdvxRepository.importGroupFor(dateEpoch)?.let { group ->
                container.database.sdvxDao().songRecordsForTitle(group.id, title)
                    .sortedBy { SDVXDifficulty.fromValue(it.difficulty)?.ordinal ?: Int.MAX_VALUE }
            } ?: emptyList()
        }
    }

    var selectedIndex by rememberSaveable { mutableIntStateOf(0) }
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

    ViewerWithSelector(
        onBack = onBack,
        selector = if (records.size > 1) {
            {
                ExpressiveLevelSelector(
                    items = records,
                    selectedIndex = selectedIndex.coerceIn(0, records.size - 1),
                    onSelect = { selectedIndex = it }
                ) { segment ->
                    Text(
                        text = SDVXDifficulty.fromValue(segment.difficulty)?.abbreviation
                            ?: segment.difficulty,
                        color = SDVXColors.difficultyColor(segment.difficulty),
                        fontWeight = FontWeight.Black,
                        maxLines = 1
                    )
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
                            brush = SDVXColors.gradeBrush
                        )
                    }
                    DetailRow(
                        label = stringResource(R.string.sdvx_high_score),
                        value = current.highScore.toString(),
                        brush = scoreGradientBrush
                    )
                    DetailRow(
                        label = stringResource(R.string.sdvx_ex_score),
                        value = current.exScore.toString(),
                        brush = scoreGradientBrush
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
                                    android.net.Uri.parse(youTubeSearchURL("SDVX $title"))
                                )
                            )
                        }
                        chart?.let { sdvxInChart ->
                            ChartActionButton(
                                icon = Icons.Outlined.Article,
                                label = stringResource(R.string.sdvx_view_chart)
                            ) {
                                onOpenWeb(sdvxInChart.pageURL)
                            }
                        }
                    }
                }
            }
    }
}
