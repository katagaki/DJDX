package com.tsubuzaki.djdxgo.ui.analytics

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.iidx.IIDXTowerEntry
import com.tsubuzaki.djdxgo.ui.Routes
import com.tsubuzaki.djdxgo.ui.theme.Palette
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TowerDetailScreen(container: AppContainer, initialMode: String, onBack: () -> Unit) {
    val entries by produceState(emptyList<IIDXTowerEntry>(), Unit) {
        value = withContext(Dispatchers.IO) {
            container.iidxRepository.towerEntries()
        }
    }
    var selectedMode by rememberSaveable {
        mutableIntStateOf(if (initialMode == Routes.TOWER_TOTALS) 1 else 0)
    }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.tower_iidx_tower)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.tower_back)
                        )
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                    SegmentedButton(
                        selected = selectedMode == 0,
                        onClick = { selectedMode = 0 },
                        shape = SegmentedButtonDefaults.itemShape(index = 0, count = 2)
                    ) {
                        Text(stringResource(R.string.tower_mode_recent))
                    }
                    SegmentedButton(
                        selected = selectedMode == 1,
                        onClick = { selectedMode = 1 },
                        shape = SegmentedButtonDefaults.itemShape(index = 1, count = 2)
                    ) {
                        Text(stringResource(R.string.tower_totals))
                    }
                }
            }
            item {
                ElevatedCard(shape = RoundedCornerShape(16.dp)) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        if (entries.isEmpty()) {
                            Text(
                                text = stringResource(R.string.analytics_no_data),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 48.dp),
                                textAlign = TextAlign.Center
                            )
                        } else if (selectedMode == 0) {
                            TowerRecentChart(entries = entries)
                        } else {
                            TowerTotalsContent(entries = entries)
                        }
                    }
                }
            }
            if (entries.isNotEmpty()) {
                item {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 8.dp)
                    ) {
                        Text(
                            text = stringResource(R.string.tower_play_date),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.weight(1f)
                        )
                        Text(
                            text = stringResource(R.string.tower_keys),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.width(80.dp),
                            textAlign = TextAlign.End
                        )
                        Text(
                            text = stringResource(R.string.tower_scratch),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.width(80.dp),
                            textAlign = TextAlign.End
                        )
                    }
                }
                items(entries, key = { it.id }) { entry ->
                    TowerEntryRow(entry = entry)
                }
            }
        }
    }
}

@Composable
private fun TowerRecentChart(entries: List<IIDXTowerEntry>) {
    val cutoff = Instant.now().minusSeconds(30L * 24 * 60 * 60).epochSecond
    val recent = entries.filter { it.playDate >= cutoff }
    val chartEntries = (if (recent.size >= 5) recent else entries.take(5)).reversed()
    val formatter = DateTimeFormatter.ofPattern("M/d")
    val labelStep = ((chartEntries.size + 5) / 6).coerceAtLeast(1)
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        GroupedBarChart(
            entries = chartEntries.mapIndexed { index, entry ->
                val label = if (index % labelStep == 0) {
                    Instant.ofEpochSecond(entry.playDate)
                        .atZone(ZoneId.systemDefault())
                        .toLocalDate()
                        .format(formatter)
                } else {
                    ""
                }
                Triple(label, entry.keyCount, entry.scratchCount)
            },
            firstColor = Palette.blue,
            secondColor = Palette.red,
            modifier = Modifier
                .fillMaxWidth()
                .height(240.dp)
        )
        ChartLegend(
            items = listOf(
                stringResource(R.string.tower_keys) to Palette.blue,
                stringResource(R.string.tower_scratch) to Palette.red
            )
        )
    }
}

@Composable
private fun TowerTotalsContent(entries: List<IIDXTowerEntry>) {
    val totalKeys = entries.sumOf { it.keyCount } / 100
    val totalScratch = entries.sumOf { it.scratchCount } / 100
    val keyHeightCm = totalKeys / 7
    val scratchHeightCm = totalScratch
    val heightFormat = stringResource(R.string.tower_height_cm)
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        BigTotalsBarChart(
            bars = listOf(
                Triple(stringResource(R.string.tower_keys), keyHeightCm, Palette.blue),
                Triple(stringResource(R.string.tower_scratch), scratchHeightCm, Palette.red)
            ),
            annotationFor = { String.format(heightFormat, it) },
            modifier = Modifier
                .fillMaxWidth()
                .height(240.dp)
        )
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = stringResource(R.string.tower_keys_caption),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = stringResource(R.string.tower_scratch_caption),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun TowerEntryRow(entry: IIDXTowerEntry) {
    val formatter = DateTimeFormatter.ofPattern("yyyy/MM/dd")
    val date = Instant.ofEpochSecond(entry.playDate)
        .atZone(ZoneId.systemDefault())
        .toLocalDate()
        .format(formatter)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 4.dp)
    ) {
        Text(
            text = date,
            style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = entry.keyCount.toString(),
            style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
            color = Palette.blue,
            modifier = Modifier.width(80.dp),
            textAlign = TextAlign.End
        )
        Text(
            text = entry.scratchCount.toString(),
            style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
            color = Palette.red,
            modifier = Modifier.width(80.dp),
            textAlign = TextAlign.End
        )
    }
}
