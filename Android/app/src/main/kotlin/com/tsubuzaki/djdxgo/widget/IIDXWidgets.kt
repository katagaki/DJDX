package com.tsubuzaki.djdxgo.widget

import android.content.Context
import android.graphics.BitmapFactory
import android.text.format.DateFormat
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalContext
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.RadarAxis
import com.tsubuzaki.djdxgo.data.RadarData
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.iidx.IIDXDJLevel
import com.tsubuzaki.djdxgo.ui.theme.IIDXColors
import com.tsubuzaki.djdxgo.ui.theme.Palette
import com.tsubuzaki.djdxgo.ui.theme.RadarColors
import java.util.Date
import java.util.Locale

// MARK: - Qpro

class QproWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            currentState<Preferences>()
            val file = WidgetSnapshotStore.qproFile(context)
            val bitmap = if (file.exists()) BitmapFactory.decodeFile(file.path) else null
            WidgetContainer {
                if (bitmap != null) WidgetBitmap(bitmap) else WidgetNoData(R.string.widget_qpro_not_loaded)
            }
        }
    }
}

class QproWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = QproWidget()
}

// MARK: - Notes Radar

class NotesRadarWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val showTable = currentState<Preferences>()[WidgetKeys.showTable] ?: true
            val radar = WidgetSnapshotStore.read(context)?.radar
            WidgetContainer {
                if (radar == null) WidgetNoData() else NotesRadarContent(radar, showTable)
            }
        }
    }
}

class NotesRadarWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = NotesRadarWidget()
}

private const val RADAR_TABLE_WIDTH = 120f
private const val RADAR_TABLE_HEIGHT = 112f

@Composable
private fun NotesRadarContent(radar: RadarData, showTable: Boolean) {
    val context = LocalContext.current
    val size = widgetContentSize()
    val color = RadarColors.playerColor(radar)
    when (size.widgetFamily) {
        WidgetFamily.SMALL -> WidgetBitmap(WidgetCharts.radar(radar, color, 7f, size, context.widgetDensity))
        WidgetFamily.MEDIUM -> if (showTable) {
            Row(modifier = GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
                val chartSize = DpSize(size.width - (RADAR_TABLE_WIDTH + 8f).dp, size.height)
                WidgetBitmap(
                    WidgetCharts.radar(radar, color, 7f, chartSize, context.widgetDensity),
                    GlanceModifier.size(chartSize.width, chartSize.height)
                )
                Spacer(GlanceModifier.width(8.dp))
                RadarTable(radar, GlanceModifier.width(RADAR_TABLE_WIDTH.dp))
            }
        } else {
            WidgetBitmap(WidgetCharts.radar(radar, color, 7f, size, context.widgetDensity))
        }
        WidgetFamily.LARGE -> if (showTable) {
            val chartSize = DpSize(size.width, size.height - (RADAR_TABLE_HEIGHT + 8f).dp)
            WidgetBitmap(
                WidgetCharts.radar(radar, color, 10f, chartSize, context.widgetDensity),
                GlanceModifier.size(chartSize.width, chartSize.height)
            )
            Spacer(GlanceModifier.height(8.dp))
            RadarTable(radar, GlanceModifier.fillMaxWidth())
        } else {
            WidgetBitmap(WidgetCharts.radar(radar, color, 10f, size.inset(16f), context.widgetDensity))
        }
    }
}

@Composable
private fun RadarTable(radar: RadarData, modifier: GlanceModifier) {
    Column(modifier = modifier) {
        RadarAxis.displayOrder.forEach { axis ->
            TableRow(axis.label, "%.2f".format(Locale.US, radar.value(axis)), ColorProvider(RadarColors.axisColor(axis)))
        }
        TableRow("TOTAL", "%.2f".format(Locale.US, radar.sum()), GlanceTheme.colors.onSurface)
    }
}

@Composable
private fun TableRow(label: String, value: String, labelColor: ColorProvider) {
    Row(modifier = GlanceModifier.fillMaxWidth().padding(vertical = 1.dp)) {
        Text(
            text = label,
            style = TextStyle(color = labelColor, fontSize = 11.sp, fontWeight = FontWeight.Bold),
            modifier = GlanceModifier.defaultWeight()
        )
        Text(
            text = value,
            style = TextStyle(color = GlanceTheme.colors.onSurface, fontSize = 11.sp, fontWeight = FontWeight.Medium)
        )
    }
}

// MARK: - Clear Type / DJ Level

class ClearTypeWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val state = currentState<Preferences>()
            val counts = WidgetSnapshotStore.read(context)?.clearType
            WidgetContainer {
                CountsContent(
                    counts = counts,
                    style = WidgetChartStyle.fromValue(state[WidgetKeys.chartStyle], WidgetChartStyle.PIE),
                    level = state[WidgetKeys.level] ?: WidgetKeys.DEFAULT_LEVEL,
                    order = clearTypeOrder,
                    barKeys = null,
                    color = IIDXColors::clearTypeColor
                )
            }
        }
    }

    companion object {
        val clearTypeOrder = IIDXClearType.sortedWithoutNoPlay.map { it.value }
    }
}

class ClearTypeWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ClearTypeWidget()
}

class DJLevelWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val state = currentState<Preferences>()
            val counts = WidgetSnapshotStore.read(context)?.djLevel
            WidgetContainer {
                CountsContent(
                    counts = counts,
                    style = WidgetChartStyle.fromValue(state[WidgetKeys.chartStyle], WidgetChartStyle.BAR),
                    level = state[WidgetKeys.level] ?: WidgetKeys.DEFAULT_LEVEL,
                    order = djLevelOrder,
                    barKeys = djLevelBarKeys,
                    color = IIDXColors::djLevelColor
                )
            }
        }
    }

    companion object {
        val djLevelOrder = IIDXDJLevel.sorted.map { it.value }
        val djLevelBarKeys = listOf(IIDXDJLevel.C, IIDXDJLevel.B, IIDXDJLevel.A, IIDXDJLevel.AA, IIDXDJLevel.AAA)
            .map { it.value }
    }
}

class DJLevelWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DJLevelWidget()
}

@Composable
private fun CountsContent(
    counts: WidgetCountsSnapshot?,
    style: WidgetChartStyle,
    level: Int,
    order: List<String>,
    barKeys: List<String>?,
    color: (String) -> Color
) {
    val context = LocalContext.current
    val size = widgetContentSize()
    val density = context.widgetDensity
    val bitmap = when (style) {
        WidgetChartStyle.PIE, WidgetChartStyle.BAR -> {
            val levelCounts = counts?.perDifficulty?.get(level).orEmpty()
            if (levelCounts.values.sum() <= 0) {
                null
            } else if (style == WidgetChartStyle.PIE) {
                val segments = order.mapNotNull { key ->
                    levelCounts[key]?.takeIf { it > 0 }?.let { WidgetChartSegment(color(key), it) }
                }
                WidgetCharts.pie(segments, size, density)
            } else {
                val keys = barKeys ?: order.filter { (levelCounts[it] ?: 0) > 0 }
                WidgetCharts.bars(keys.map { WidgetChartSegment(color(it), levelCounts[it] ?: 0) }, size, density)
            }
        }
        WidgetChartStyle.TREND -> {
            val trends = counts?.trends.orEmpty().sortedBy { it.date }
            val series = order.reversed().map { key ->
                WidgetChartSeries(color(key), trends.map { it.counts[level]?.get(key) ?: 0 })
            }
            if (series.sumOf { it.values.sum() } <= 0) {
                null
            } else {
                WidgetCharts.stackedArea(series, trends.map { it.date }, size, density)
            }
        }
    }
    if (bitmap == null) WidgetNoData() else WidgetBitmap(bitmap)
}

// MARK: - Tower

class TowerWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            currentState<Preferences>()
            val tower = WidgetSnapshotStore.read(context)?.tower
            WidgetContainer {
                if (tower == null) WidgetNoData() else TowerContent(tower)
            }
        }
    }
}

class TowerWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TowerWidget()
}

private const val TOWER_LABEL_HEIGHT = 18f
private const val TOWER_NUMBERS_WIDTH = 96f
private const val TOWER_TABLE_HEIGHT = 76f

@Composable
private fun TowerContent(tower: WidgetTowerSnapshot) {
    val size = widgetContentSize()
    when (size.widgetFamily) {
        WidgetFamily.SMALL -> TowerChart(tower, size)
        WidgetFamily.MEDIUM -> Row(modifier = GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            TowerChart(tower, DpSize(size.width - (TOWER_NUMBERS_WIDTH + 8f).dp, size.height))
            Spacer(GlanceModifier.width(8.dp))
            TowerNumbers(tower)
        }
        WidgetFamily.LARGE -> {
            TowerChart(tower, DpSize(size.width, size.height - (TOWER_TABLE_HEIGHT + 8f).dp))
            Spacer(GlanceModifier.height(8.dp))
            TowerRecentEntries(tower.latestEntries)
        }
    }
}

@Composable
private fun TowerChart(tower: WidgetTowerSnapshot, size: DpSize) {
    val context = LocalContext.current
    val chartSize = DpSize(size.width, size.height - TOWER_LABEL_HEIGHT.dp)
    val bars = listOf(
        WidgetChartSegment(Palette.blue, tower.totalKeyCount / 7),
        WidgetChartSegment(Palette.red, tower.totalScratchCount)
    )
    Column(modifier = GlanceModifier.size(size.width, size.height)) {
        Box(modifier = GlanceModifier.size(chartSize.width, chartSize.height)) {
            WidgetBitmap(WidgetCharts.bars(bars, chartSize, context.widgetDensity, spacing = 12f))
        }
        Row(modifier = GlanceModifier.fillMaxWidth().height(TOWER_LABEL_HEIGHT.dp), verticalAlignment = Alignment.Bottom) {
            listOf(R.string.tower_keys, R.string.tower_scratch).forEach { label ->
                Text(
                    text = context.getString(label),
                    style = TextStyle(
                        color = GlanceTheme.colors.onSurfaceVariant,
                        fontSize = 11.sp,
                        textAlign = TextAlign.Center
                    ),
                    modifier = GlanceModifier.defaultWeight()
                )
            }
        }
    }
}

@Composable
private fun TowerNumbers(tower: WidgetTowerSnapshot) {
    val context = LocalContext.current
    Column(modifier = GlanceModifier.width(TOWER_NUMBERS_WIDTH.dp)) {
        listOf(
            Triple(R.string.tower_keys, tower.totalKeyCount / 7, Palette.blue),
            Triple(R.string.tower_scratch, tower.totalScratchCount, Palette.red)
        ).forEach { (label, height, color) ->
            Text(
                text = context.getString(label),
                style = TextStyle(color = GlanceTheme.colors.onSurfaceVariant, fontSize = 11.sp)
            )
            Text(
                text = context.getString(R.string.tower_height_cm, height),
                style = TextStyle(color = ColorProvider(color), fontSize = 16.sp, fontWeight = FontWeight.Bold),
                modifier = GlanceModifier.padding(bottom = 6.dp)
            )
        }
    }
}

@Composable
private fun TowerRecentEntries(entries: List<WidgetTowerEntry>) {
    val context = LocalContext.current
    if (entries.isEmpty()) return
    val dateFormat = java.text.SimpleDateFormat(DateFormat.getBestDateTimePattern(Locale.getDefault(), "Md"), Locale.getDefault())
    val headerStyle = TextStyle(
        color = GlanceTheme.colors.onSurfaceVariant,
        fontSize = 10.sp,
        fontWeight = FontWeight.Medium
    )
    Column(modifier = GlanceModifier.fillMaxWidth()) {
        Row(modifier = GlanceModifier.fillMaxWidth()) {
            Text(context.getString(R.string.tower_play_date), style = headerStyle, modifier = GlanceModifier.defaultWeight())
            Text(context.getString(R.string.tower_keys), style = headerStyle.copy(textAlign = TextAlign.End), modifier = GlanceModifier.width(60.dp))
            Text(context.getString(R.string.tower_scratch), style = headerStyle.copy(textAlign = TextAlign.End), modifier = GlanceModifier.width(60.dp))
        }
        entries.forEach { entry ->
            val valueStyle = TextStyle(color = GlanceTheme.colors.onSurface, fontSize = 11.sp)
            Row(modifier = GlanceModifier.fillMaxWidth().padding(top = 2.dp)) {
                Text(dateFormat.format(Date(entry.playDate * 1000L)), style = valueStyle, modifier = GlanceModifier.defaultWeight())
                Text(
                    entry.keyCount.toString(),
                    style = valueStyle.copy(color = ColorProvider(Palette.blue), textAlign = TextAlign.End),
                    modifier = GlanceModifier.width(60.dp)
                )
                Text(
                    entry.scratchCount.toString(),
                    style = valueStyle.copy(color = ColorProvider(Palette.red), textAlign = TextAlign.End),
                    modifier = GlanceModifier.width(60.dp)
                )
            }
        }
    }
}
