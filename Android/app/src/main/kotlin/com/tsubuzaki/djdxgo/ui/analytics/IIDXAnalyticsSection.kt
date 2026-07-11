package com.tsubuzaki.djdxgo.ui.analytics

import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.Alignment
import com.tsubuzaki.djdxgo.data.compact
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ShowChart
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.EmojiEvents
import androidx.compose.material.icons.outlined.Leaderboard
import androidx.compose.material.icons.outlined.Numbers
import androidx.compose.material.icons.outlined.Report
import androidx.compose.material.icons.outlined.ShowChart
import androidx.compose.material.icons.outlined.Speed
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material.icons.outlined.VerifiedUser
import androidx.compose.material.icons.outlined.Whatshot
import androidx.compose.material.icons.outlined.WorkspacePremium
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.iidx.IIDXDJLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevelScore
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.iidx.IIDXSongRecord
import com.tsubuzaki.djdxgo.data.iidx.IIDXTowerEntry
import com.tsubuzaki.djdxgo.ui.theme.IIDXColors
import com.tsubuzaki.djdxgo.ui.theme.Palette
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private data class IIDXAnalyticsData(
    val clearTypeRows: List<StackedRow>,
    val djLevelCounts: List<Pair<String, Int>>,
    val towerEntries: List<IIDXTowerEntry>,
    val newHighScores: Int,
    val newClearCounts: Map<String, Int>,
    val newDJLevelCounts: Map<String, Int>,
    val hasRecords: Boolean
)

@Composable
fun IIDXAnalyticsSection(
    container: AppContainer,
    dateEpoch: Long,
    playType: String,
    onOpenTower: () -> Unit
) {
    val darkTheme = isSystemInDarkTheme()
    val data by produceState<IIDXAnalyticsData?>(null, dateEpoch, playType) {
        value = withContext(Dispatchers.IO) {
            computeIIDXAnalytics(container, dateEpoch, playType)
        }
    }
    val analytics = data ?: return
    if (!analytics.hasRecords && analytics.towerEntries.isEmpty()) return
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        if (analytics.clearTypeRows.any { row -> row.segments.any { it.count > 0 } }) {
            AnalyticsCard(
                title = stringResource(R.string.analytics_clear_types),
                icon = Icons.Outlined.BarChart
            ) {
                StackedBarChart(rows = analytics.clearTypeRows)
                ChartLegend(
                    items = IIDXClearType.sortedWithoutNoPlay.map {
                        it.abbreviation to IIDXColors.clearTypeColor(it.value)
                    }
                )
            }
        }
        if (analytics.djLevelCounts.isNotEmpty()) {
            AnalyticsCard(
                title = stringResource(R.string.analytics_dj_levels),
                icon = Icons.Outlined.Leaderboard
            ) {
                HorizontalBarChart(
                    entries = analytics.djLevelCounts,
                    colorFor = { IIDXColors.djLevelColor(it, darkTheme) }
                )
            }
        }
        if (analytics.towerEntries.isNotEmpty()) {
            TowerCards(entries = analytics.towerEntries, onOpenTower = onOpenTower)
        }
        if (analytics.hasRecords) {
            Text(
                text = stringResource(R.string.analytics_last_play),
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(top = 4.dp)
            )
            val cards = newEntryCards(analytics)
            cards.chunked(2).forEach { rowCards ->
                Row(
                    modifier = Modifier.height(IntrinsicSize.Min),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    rowCards.forEach { card ->
                        NewRecordCard(
                            count = card.count,
                            icon = card.icon,
                            iconColor = card.color,
                            label = card.label,
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight()
                        )
                    }
                    repeat(2 - rowCards.size) {
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

private data class NewEntryCardSpec(
    val label: String,
    val icon: ImageVector,
    val color: Color,
    val count: Int
)

@Composable
private fun newEntryCards(data: IIDXAnalyticsData): List<NewEntryCardSpec> = listOf(
    NewEntryCardSpec(
        stringResource(R.string.analytics_new_record),
        Icons.Outlined.EmojiEvents,
        MaterialTheme.colorScheme.onSurface,
        data.newHighScores
    ),
    NewEntryCardSpec("AAA", Icons.Outlined.WorkspacePremium, Palette.orange, data.newDJLevelCounts["AAA"] ?: 0),
    NewEntryCardSpec("AA", Icons.Outlined.WorkspacePremium, Palette.orange, data.newDJLevelCounts["AA"] ?: 0),
    NewEntryCardSpec("A", Icons.Outlined.WorkspacePremium, Palette.orange, data.newDJLevelCounts["A"] ?: 0),
    NewEntryCardSpec("FULLCOMBO CLEAR", Icons.Outlined.StarOutline, Palette.blue, data.newClearCounts["FULLCOMBO CLEAR"] ?: 0),
    NewEntryCardSpec("CLEAR", Icons.Outlined.CheckCircle, Palette.cyan, data.newClearCounts["CLEAR"] ?: 0),
    NewEntryCardSpec("EASY CLEAR", Icons.Outlined.VerifiedUser, Palette.green, data.newClearCounts["EASY CLEAR"] ?: 0),
    NewEntryCardSpec("ASSIST CLEAR", Icons.Outlined.Bolt, Palette.purple, data.newClearCounts["ASSIST CLEAR"] ?: 0),
    NewEntryCardSpec("HARD CLEAR", Icons.Outlined.Speed, Palette.pink, data.newClearCounts["HARD CLEAR"] ?: 0),
    NewEntryCardSpec("EX HARD CLEAR", Icons.Outlined.Whatshot, Palette.yellow, data.newClearCounts["EX HARD CLEAR"] ?: 0),
    NewEntryCardSpec("FAILED", Icons.Outlined.Report, Palette.red, data.newClearCounts["FAILED"] ?: 0)
)

@Composable
private fun TowerCards(
    entries: List<IIDXTowerEntry>,
    onOpenTower: () -> Unit
) {
    val recentEntries = entries.take(5).reversed()
    val totalKeys = entries.sumOf { it.keyCount } / 100
    val totalScratch = entries.sumOf { it.scratchCount } / 100
    Row(
        modifier = Modifier.height(IntrinsicSize.Min),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        AnalyticsCard(
            title = stringResource(R.string.analytics_tower_recent),
            icon = Icons.AutoMirrored.Outlined.ShowChart,
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight(),
            onClick = onOpenTower
        ) {
            GroupedBarChart(
                entries = recentEntries.map { Triple("", it.keyCount, it.scratchCount) },
                firstColor = Palette.blue,
                secondColor = Palette.red,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(96.dp),
                showLabels = false
            )
        }
        val heightFormat = stringResource(R.string.tower_height_cm)
        AnalyticsCard(
            title = stringResource(R.string.analytics_tower_totals),
            icon = Icons.Outlined.Numbers,
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight(),
            onClick = onOpenTower
        ) {
            BigTotalsBarChart(
                bars = listOf(
                    Triple(stringResource(R.string.tower_keys), totalKeys / 7, Palette.blue),
                    Triple(stringResource(R.string.tower_scratch), totalScratch, Palette.red)
                ),
                annotationFor = { String.format(heightFormat, it) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(96.dp)
            )
        }
    }
}

@Composable
private fun NewRecordCard(
    count: Int,
    icon: ImageVector,
    iconColor: Color,
    label: String,
    modifier: Modifier = Modifier
) {
    ElevatedCard(modifier = modifier, shape = RoundedCornerShape(16.dp)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = iconColor,
                    modifier = Modifier.size(18.dp)
                )
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1
                )
            }
            Text(
                text = count.toString(),
                style = MaterialTheme.typography.headlineMedium,
                color = if (count > 0) {
                    MaterialTheme.colorScheme.onSurface
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                }
            )
        }
    }
}

private suspend fun computeIIDXAnalytics(
    container: AppContainer,
    dateEpoch: Long,
    playType: String
): IIDXAnalyticsData {
    val dao = container.database.iidxDao()
    val records = container.iidxRepository.songRecords(dateEpoch, IIDXPlayType.fromValue(playType))
    val clearTypeRows = (1..12).map { difficulty ->
        val counts = LinkedHashMap<String, Int>()
        records.forEach { record ->
            record.playedLevels().forEach { (_, slot) ->
                if (slot.difficulty == difficulty && slot.clearType != IIDXClearType.NO_PLAY.value) {
                    counts.merge(slot.clearType, 1, Int::plus)
                }
            }
        }
        StackedRow(
            label = difficulty.toString(),
            segments = IIDXClearType.sortedWithoutNoPlay.map { clearType ->
                StackedSegment(
                    key = clearType.value,
                    count = counts[clearType.value] ?: 0,
                    color = IIDXColors.clearTypeColor(clearType.value)
                )
            }
        )
    }
    val djLevelCounts = IIDXDJLevel.sorted.reversed().mapNotNull { djLevel ->
        val count = records.sumOf { record ->
            record.playedLevels().count { (_, slot) ->
                slot.score > 0 && slot.djLevel == djLevel.value
            }
        }
        if (count > 0) djLevel.value to count else null
    }
    val towerEntries = dao.towerEntries()
    val newRecords = computeNewRecords(container, playType)
    return IIDXAnalyticsData(
        clearTypeRows = clearTypeRows,
        djLevelCounts = djLevelCounts,
        towerEntries = towerEntries,
        newHighScores = newRecords.highScores,
        newClearCounts = newRecords.clearCounts,
        newDJLevelCounts = newRecords.djLevelCounts,
        hasRecords = records.isNotEmpty()
    )
}

private data class NewRecordCounts(
    val highScores: Int,
    val clearCounts: Map<String, Int>,
    val djLevelCounts: Map<String, Int>
)

private val trackedClearTypes = listOf(
    "FULLCOMBO CLEAR", "CLEAR", "EASY CLEAR", "ASSIST CLEAR",
    "HARD CLEAR", "EX HARD CLEAR", "FAILED"
)
private val trackedDJLevels = listOf("AAA", "AA", "A")

private suspend fun computeNewRecords(
    container: AppContainer,
    playType: String
): NewRecordCounts {
    val dao = container.database.iidxDao()
    var latest: List<IIDXSongRecord>? = null
    var previous: List<IIDXSongRecord>? = null
    for (group in dao.importGroups()) {
        val groupRecords = dao.songRecords(group.id, playType)
        if (groupRecords.isEmpty()) continue
        if (latest == null) {
            latest = groupRecords
        } else {
            previous = groupRecords
            break
        }
    }
    val clearCounts = trackedClearTypes.associateWith { 0 }.toMutableMap()
    val djLevelCounts = trackedDJLevels.associateWith { 0 }.toMutableMap()
    if (latest == null || previous == null) {
        return NewRecordCounts(0, clearCounts, djLevelCounts)
    }
    val previousSlots = HashMap<String, IIDXLevelScore>()
    previous.forEach { record ->
        record.playedLevels().forEach { (level, slot) ->
            previousSlots["${record.title.compact}|${level.code}"] = slot
        }
    }
    var newHighScores = 0
    latest.forEach { record ->
        record.playedLevels().forEach { (level, slot) ->
            if (slot.difficulty <= 0 || slot.score <= 0) return@forEach
            val previousSlot = previousSlots["${record.title.compact}|${level.code}"]

            val previousClear = previousSlot?.clearType ?: IIDXClearType.NO_PLAY.value
            if (slot.clearType in clearCounts && previousClear != slot.clearType) {
                clearCounts.merge(slot.clearType, 1, Int::plus)
            }

            val previousDJLevel = previousSlot?.djLevel ?: IIDXDJLevel.NONE.value
            if (slot.djLevel in djLevelCounts && previousDJLevel != slot.djLevel) {
                djLevelCounts.merge(slot.djLevel, 1, Int::plus)
            }

            val previousScore = previousSlot?.score ?: 0
            if (slot.score > previousScore) newHighScores++
        }
    }
    return NewRecordCounts(newHighScores, clearCounts, djLevelCounts)
}
