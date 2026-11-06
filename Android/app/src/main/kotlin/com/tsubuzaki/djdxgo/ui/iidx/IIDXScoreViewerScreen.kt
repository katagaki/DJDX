package com.tsubuzaki.djdxgo.ui.iidx

import com.tsubuzaki.djdxgo.ui.theme.GameFontWidth
import com.tsubuzaki.djdxgo.ui.theme.GameFonts
import com.tsubuzaki.djdxgo.ui.theme.gameFont
import com.tsubuzaki.djdxgo.ui.common.OutlinedText
import com.tsubuzaki.djdxgo.ui.common.IIDXDJLevelText
import com.tsubuzaki.djdxgo.ui.common.IIDXClearTypeText
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Article
import androidx.compose.material.icons.outlined.SmartDisplay
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.compact
import com.tsubuzaki.djdxgo.data.external.IIDXSong
import com.tsubuzaki.djdxgo.data.external.NotesRadarEntry
import com.tsubuzaki.djdxgo.data.external.IIDXPlaySide
import com.tsubuzaki.djdxgo.data.external.TextageChart
import com.tsubuzaki.djdxgo.data.external.TextageChartViewerChart
import com.tsubuzaki.djdxgo.data.external.pageURL
import com.tsubuzaki.djdxgo.data.toRadarData
import com.tsubuzaki.djdxgo.ui.common.RadarChart
import com.tsubuzaki.djdxgo.ui.common.RadarValuesList
import androidx.compose.foundation.layout.height
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.iidx.IIDXDJLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevelScore
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.iidx.IIDXSongRecord
import com.tsubuzaki.djdxgo.ui.games.ChartActionButton
import com.tsubuzaki.djdxgo.ui.games.ExpressiveLevelSelector
import com.tsubuzaki.djdxgo.ui.games.ViewerWithSelector
import com.tsubuzaki.djdxgo.ui.theme.IIDXColors
import com.tsubuzaki.djdxgo.ui.theme.RadarColors
import java.net.URLEncoder
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun IIDXScoreViewerScreen(
    container: AppContainer,
    title: String,
    playType: String,
    initialLevel: String,
    dateEpoch: Long,
    onBack: () -> Unit,
    onOpenTextage: (legacyURL: String?, chartViewerURL: String?) -> Unit
) {
    val darkTheme = isSystemInDarkTheme()
    val playTypeEnum = IIDXPlayType.fromValue(playType)
    val beginnerHidden by rememberSetting(SettingsKeys.iidxBeginnerLevelHidden, true)

    var record by remember { mutableStateOf<IIDXSongRecord?>(null) }
    var song by remember { mutableStateOf<IIDXSong?>(null) }
    var scoreHistory by remember { mutableStateOf<Map<String, List<Int>>>(emptyMap()) }
    var radarEntries by remember { mutableStateOf<Map<String, NotesRadarEntry>>(emptyMap()) }
    var textageChart by remember { mutableStateOf<TextageChartViewerChart?>(null) }
    var legacyTextageChart by remember { mutableStateOf<TextageChart?>(null) }
    var selectedLevelCode by rememberSaveable { mutableStateOf(initialLevel) }

    LaunchedEffect(title, playType, dateEpoch) {
        withContext(Dispatchers.IO) {
            val loaded = container.iidxRepository.songRecords(dateEpoch, playTypeEnum)
                .firstOrNull { it.title == title }
            val titleCompact = title.compact
            val loadedSong = container.externalDataDao.iidxSong(titleCompact)
            val loadedTextage = container.externalDataDao.textageChartViewerChart(titleCompact)
            val loadedLegacyTextage = container.externalDataDao.textageChart(titleCompact)

            val dao = container.database.iidxDao()
            val groupDates = container.iidxRepository.importGroups().associate { it.id to it.importDate }
            val historyRecords = dao.songRecordsForTitle(title, playType)
                .filter { it.importGroupID in groupDates }
                .sortedBy { groupDates[it.importGroupID] ?: 0L }
            val history = IIDXLevel.entries.associate { level ->
                level.code to historyRecords.mapNotNull { historyRecord ->
                    historyRecord.slot(level).score.takeIf { it > 0 }
                }
            }

            val radar = loaded?.playedLevels().orEmpty().mapNotNull { (level, _) ->
                val radarPlayType =
                    if (level == IIDXLevel.BEGINNER) "SP" else playTypeEnum.code
                container.externalDataDao
                    .notesRadar(titleCompact, radarPlayType, level.ordinal)
                    ?.let { level.code to it }
            }.toMap()

            withContext(Dispatchers.Main) {
                record = loaded
                song = loadedSong
                textageChart = loadedTextage
                legacyTextageChart = loadedLegacyTextage
                scoreHistory = history
                radarEntries = radar
            }
        }
    }

    val availableLevels = remember(record, beginnerHidden) {
        record?.playedLevels().orEmpty()
            .filterNot { (level, _) -> level == IIDXLevel.BEGINNER && beginnerHidden }
    }

    LaunchedEffect(availableLevels) {
        if (availableLevels.isNotEmpty() &&
            availableLevels.none { it.first.code == selectedLevelCode }
        ) {
            selectedLevelCode = availableLevels.last().first.code
        }
    }

    ViewerWithSelector(
        onBack = onBack,
        topBarActions = {
            val songVersion = record?.version.orEmpty()
            if (songVersion.isNotEmpty()) {
                Text(
                    text = songVersion,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.ExtraBold,
                    fontStyle = FontStyle.Italic,
                    color = IIDXColors.versionColor(songVersion, darkTheme)
                        ?: MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(end = 16.dp)
                )
            }
        },
        selector = if (availableLevels.size > 1) {
            {
                val selectedIndex = availableLevels.indexOfFirst { it.first.code == selectedLevelCode }
                ExpressiveLevelSelector(
                    items = availableLevels,
                    selectedIndex = selectedIndex,
                    onSelect = { index -> selectedLevelCode = availableLevels[index].first.code }
                ) { (level, score) ->
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(1.dp)
                    ) {
                        Text(
                            text = score.difficulty.toString(),
                            color = IIDXColors.levelColor(level),
                            fontWeight = FontWeight.Bold,
                            fontStyle = FontStyle.Italic
                        )
                        Text(
                            text = level.csvPrefix,
                            color = IIDXColors.levelColor(level),
                            fontWeight = FontWeight.Bold,
                            maxLines = 1,
                            autoSize = TextAutoSize.StepBased(
                                minFontSize = 6.sp,
                                maxFontSize = 10.sp
                            )
                        )
                    }
                }
            }
        } else {
            null
        }
    ) {
        val loadedRecord = record
        if (loadedRecord != null) {
            ViewerHeader(loadedRecord)
            val selected = availableLevels
                .firstOrNull { it.first.code == selectedLevelCode }
            if (selected != null) {
                val (level, score) = selected
                val noteCount = song?.noteCount(
                    if (level == IIDXLevel.BEGINNER) IIDXPlayType.SINGLE else playTypeEnum,
                    level
                )
                ScoreSection(
                    title = title,
                    level = level,
                    score = score,
                    noteCount = noteCount,
                    playTypeEnum = playTypeEnum,
                    darkTheme = darkTheme,
                    history = scoreHistory[level.code].orEmpty(),
                    radarEntry = radarEntries[level.code],
                    textageChart = textageChart,
                    legacyTextageChart = legacyTextageChart,
                    onOpenTextage = onOpenTextage
                )
            }
        }
    }
}

@Composable
private fun StrokedText(
    text: String,
    style: TextStyle,
    fontWeight: FontWeight,
    strokeColor: Color,
    fillColor: Color = Color.Unspecified,
    fillBrush: androidx.compose.ui.graphics.Brush? = null,
    strokeWidth: androidx.compose.ui.unit.Dp = 3.dp
) {
    val strokePx = with(androidx.compose.ui.platform.LocalDensity.current) { strokeWidth.toPx() }
    Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Text(
            text = text,
            style = style.merge(
                TextStyle(
                    color = strokeColor,
                    drawStyle = androidx.compose.ui.graphics.drawscope.Stroke(width = strokePx)
                )
            ),
            fontWeight = fontWeight,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Text(
            text = text,
            style = if (fillBrush != null) {
                style.merge(TextStyle(brush = fillBrush))
            } else {
                style.merge(TextStyle(color = fillColor))
            },
            fontWeight = fontWeight,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun ViewerHeader(record: IIDXSongRecord) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        if (record.genre.isNotEmpty()) {
            StrokedText(
                text = record.genre,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Black,
                fillColor = Color.White,
                strokeColor = Color.Black.copy(alpha = 0.7f)
            )
        }
        StrokedText(
            text = record.title,
            style = MaterialTheme.typography.headlineMedium.gameFont(GameFontWidth.COMPRESSED),
            fontWeight = FontWeight.Black,
            fillBrush = IIDXColors.songTitleBrush(record.version),
            strokeColor = IIDXColors.songTitleStrokeColor(record.version)
        )
        if (record.artist.isNotEmpty()) {
            StrokedText(
                text = record.artist,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Black,
                fillColor = Color.White,
                strokeColor = Color.Black.copy(alpha = 0.7f)
            )
        }
        if (record.lastPlayDate != 0L) {
            HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
            val formatted = remember(record.lastPlayDate) {
                Instant.ofEpochSecond(record.lastPlayDate)
                    .atZone(ZoneId.systemDefault())
                    .format(
                        DateTimeFormatter.ofLocalizedDateTime(
                            FormatStyle.MEDIUM,
                            FormatStyle.SHORT
                        )
                    )
            }
            Text(
                text = stringResource(R.string.scores_viewer_last_play_date, formatted),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun ScoreSection(
    title: String,
    level: IIDXLevel,
    score: IIDXLevelScore,
    noteCount: Int?,
    playTypeEnum: IIDXPlayType,
    darkTheme: Boolean,
    history: List<Int>,
    radarEntry: NotesRadarEntry?,
    textageChart: TextageChartViewerChart?,
    legacyTextageChart: TextageChart?,
    onOpenTextage: (String?, String?) -> Unit
) {
    val hasDJLevel = IIDXDJLevel.fromValue(score.djLevel)
        ?.let { it != IIDXDJLevel.NONE } == true

    if (hasDJLevel) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(modifier = Modifier.weight(1f)) {
                IIDXDJLevelText(
                    djLevel = score.djLevel,
                    style = TextStyle(fontSize = 40.sp),
                    outlineWidth = 0.6.dp,
                    fontWidth = GameFontWidth.EXTRA_EXPANDED,
                    fontWeight = GameFonts.maximumWeight
                )
            }
            val rate = scoreRate(score.score, noteCount)
            if (rate != null) {
                Text(
                    text = String.format(Locale.ROOT, "%.1f%%", rate * 100f),
                    style = TextStyle().gameFont(GameFontWidth.EXTRA_EXPANDED),
                    fontSize = 32.sp,
                    fontWeight = GameFonts.maximumWeight,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
            )
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                DetailRow(
                    label = stringResource(R.string.scores_viewer_clear_type)
                ) {
                    IIDXClearTypeText(
                        clearType = score.clearType,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWidth = GameFontWidth.EXTRA_EXPANDED,
                        fontWeight = GameFonts.maximumWeight
                    )
                }
                DetailRow(label = stringResource(R.string.scores_viewer_score)) {
                    OutlinedText(
                        text = score.score.toString(),
                        style = MaterialTheme.typography.bodyLarge.gameFont(GameFontWidth.EXTRA_EXPANDED),
                        fontWeight = GameFonts.maximumWeight,
                        fill = IIDXColors.scoreColor,
                        outline = IIDXColors.scoreOutlineColor,
                        outlineWidth = 0.3.dp
                    )
                }
                DetailRow(label = stringResource(R.string.scores_viewer_miss_count)) {
                    OutlinedText(
                        text = score.missCount.toString(),
                        style = MaterialTheme.typography.bodyLarge.gameFont(GameFontWidth.EXTRA_EXPANDED),
                        fontWeight = GameFonts.maximumWeight,
                        fill = IIDXColors.scoreColor,
                        outline = IIDXColors.scoreOutlineColor,
                        outlineWidth = 0.3.dp
                    )
                }
                HorizontalDivider()
                IIDXJudgmentBreakdown(
                    entries = listOf(
                        IIDXJudgment.PERFECT_GREAT to score.perfectGreatCount,
                        IIDXJudgment.GREAT to score.greatCount,
                        IIDXJudgment.MISS to score.missCount
                    )
                )
            }
        }
    } else {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
            )
        ) {
            Text(
                text = stringResource(R.string.scores_viewer_no_data),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(16.dp)
            )
        }
        if (score.clearType != IIDXClearType.NO_PLAY.value) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
                )
            ) {
                DetailRow(
                    label = stringResource(R.string.scores_viewer_clear_type),
                    modifier = Modifier.padding(16.dp)
                ) {
                    IIDXClearTypeText(
                        clearType = score.clearType,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWidth = GameFontWidth.EXTRA_EXPANDED,
                        fontWeight = GameFonts.maximumWeight
                    )
                }
            }
        }
    }

    if (hasDJLevel && history.size >= 2) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
            )
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = stringResource(R.string.scores_viewer_history),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold
                )
                IIDXScoreHistoryChart(scores = history, noteCount = noteCount)
            }
        }
    }

    if (radarEntry != null) {
        var showRadarValues by rememberSaveable { mutableStateOf(false) }
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { showRadarValues = !showRadarValues },
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
            )
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                val radar = radarEntry.toRadarData()
                if (showRadarValues) {
                    RadarValuesList(data = radar, modifier = Modifier.padding(vertical = 4.dp))
                } else {
                    RadarChart(
                        data = radar,
                        color = RadarColors.chartColor(radar),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(220.dp)
                    )
                }
            }
        }
    }

    val context = androidx.compose.ui.platform.LocalContext.current
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp)
        ) {
            ChartActionButton(
                icon = Icons.Outlined.SmartDisplay,
                label = stringResource(R.string.scores_viewer_youtube)
            ) {
                val query = URLEncoder.encode("IIDX ${playTypeEnum.code}${level.code} $title", "UTF-8")
                context.startActivity(
                    android.content.Intent(
                        android.content.Intent.ACTION_VIEW,
                        android.net.Uri.parse("https://www.youtube.com/results?search_query=$query")
                    )
                )
            }
            if (level != IIDXLevel.BEGINNER) {
                val chartViewerURL = textageChart?.pageURL(level, playTypeEnum)
                val sides = if (playTypeEnum == IIDXPlayType.SINGLE) {
                    listOf(
                        IIDXPlaySide.SIDE_1P to R.string.scores_viewer_textage_1p,
                        IIDXPlaySide.SIDE_2P to R.string.scores_viewer_textage_2p
                    )
                } else {
                    listOf(IIDXPlaySide.NOT_APPLICABLE to R.string.scores_viewer_textage_dp)
                }
                sides.forEach { (side, labelRes) ->
                    val legacyURL = legacyTextageChart?.pageURL(level, playTypeEnum, side)
                    if (legacyURL != null || chartViewerURL != null) {
                        ChartActionButton(
                            icon = Icons.Outlined.Article,
                            label = stringResource(labelRes)
                        ) {
                            onOpenTextage(legacyURL, chartViewerURL)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DetailRow(
    label: String,
    modifier: Modifier = Modifier,
    value: @Composable () -> Unit
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge.gameFont(GameFontWidth.EXTRA_EXPANDED),
            fontWeight = GameFonts.maximumWeight,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f)
        )
        value()
    }
}
