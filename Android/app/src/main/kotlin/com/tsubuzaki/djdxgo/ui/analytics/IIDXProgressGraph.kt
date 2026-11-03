package com.tsubuzaki.djdxgo.ui.analytics

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.analytics.IIDXProgressKind
import com.tsubuzaki.djdxgo.data.analytics.IIDXProgressPoint
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.setSetting
import com.tsubuzaki.djdxgo.ui.common.IIDXClearTypeText
import com.tsubuzaki.djdxgo.ui.common.IIDXDJLevelText
import com.tsubuzaki.djdxgo.ui.common.rememberFullComboPhase
import com.tsubuzaki.djdxgo.ui.iidx.rememberSetting
import com.tsubuzaki.djdxgo.ui.theme.IIDXColors
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import kotlin.math.ceil
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlinx.coroutines.launch

enum class IIDXProgressGraphStyle(val key: String, val titleRes: Int) {
    BARS("bars", R.string.analytics_progress_style_bars),
    STACKED("stacked", R.string.analytics_progress_style_stacked);

    companion object {
        fun fromKey(key: String): IIDXProgressGraphStyle = entries.firstOrNull { it.key == key } ?: STACKED
    }
}

internal val IIDXProgressKind.titleRes: Int
    get() = when (this) {
        IIDXProgressKind.CLEARS -> R.string.analytics_progress
        IIDXProgressKind.HIGH_SCORES -> R.string.analytics_progress_high_scores
    }

private val IIDXProgressKind.hiddenSeriesKey
    get() = when (this) {
        IIDXProgressKind.CLEARS -> SettingsKeys.iidxProgressHiddenSeries
        IIDXProgressKind.HIGH_SCORES -> SettingsKeys.iidxScoreProgressHiddenSeries
    }

private val IIDXProgressKind.styleKey
    get() = when (this) {
        IIDXProgressKind.CLEARS -> SettingsKeys.iidxProgressStyle
        IIDXProgressKind.HIGH_SCORES -> SettingsKeys.iidxScoreProgressStyle
    }

private fun IIDXProgressKind.label(series: String): String = when (this) {
    IIDXProgressKind.CLEARS -> IIDXClearType.fromValue(series)?.abbreviation ?: series
    IIDXProgressKind.HIGH_SCORES -> series
}

private fun IIDXProgressKind.color(series: String): Color = when (this) {
    IIDXProgressKind.CLEARS -> IIDXColors.clearTypeColor(series)
    IIDXProgressKind.HIGH_SCORES -> IIDXColors.djLevelColor(series)
}

@Composable
private fun SeriesLabel(kind: IIDXProgressKind, series: String, style: TextStyle) {
    when (kind) {
        IIDXProgressKind.CLEARS -> IIDXClearTypeText(clearType = series, label = kind.label(series), style = style)
        IIDXProgressKind.HIGH_SCORES -> IIDXDJLevelText(djLevel = series, style = style)
    }
}

internal data class IIDXProgressSettings(
    val hiddenSeries: Set<String>,
    val style: IIDXProgressGraphStyle,
    val visibleSeries: List<String>
)

@Composable
internal fun rememberProgressSettings(kind: IIDXProgressKind): IIDXProgressSettings {
    val hiddenSeries by rememberSetting(kind.hiddenSeriesKey, kind.defaultHiddenSeries)
    val styleKey by rememberSetting(kind.styleKey, IIDXProgressGraphStyle.STACKED.key)
    return IIDXProgressSettings(
        hiddenSeries = hiddenSeries,
        style = IIDXProgressGraphStyle.fromKey(styleKey),
        visibleSeries = kind.series.filter { it !in hiddenSeries }
    )
}

@Composable
internal fun IIDXProgressGraph(
    points: List<IIDXProgressPoint>,
    kind: IIDXProgressKind,
    modifier: Modifier = Modifier,
    showsAxisLabels: Boolean = false,
    scrollsBars: Boolean = false
) {
    val settings = rememberProgressSettings(kind)
    val style = settings.style
    val visibleSeries = settings.visibleSeries
    val hasFullCombo = kind == IIDXProgressKind.CLEARS &&
        IIDXClearType.FULL_COMBO_CLEAR.value in visibleSeries
    val phase = rememberFullComboPhase(hasFullCombo)
    val visibleCount = if (scrollsBars && style == IIDXProgressGraphStyle.BARS) {
        min(points.size, 6)
    } else {
        points.size
    }.coerceAtLeast(1)
    val maxValue = points.maxOfOrNull { point ->
        val counts = visibleSeries.map { point.count(it, kind) }
        if (style == IIDXProgressGraphStyle.STACKED) counts.sum() else counts.maxOrNull() ?: 0
    }?.coerceAtLeast(1) ?: 1
    val tickStep = niceStep(maxValue / 4.0)
    val yMax = (ceil(maxValue / tickStep) * tickStep).coerceAtLeast(1.0)
    val ticks = generateSequence(0.0) { it + tickStep }.takeWhile { it <= yMax + 0.0001 }.toList()

    val textMeasurer = rememberTextMeasurer()
    val labelStyle = MaterialTheme.typography.labelSmall.copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    val gridColor = MaterialTheme.colorScheme.outlineVariant
    val dateFormatter = remember { DateTimeFormatter.ofPattern("M/d") }
    val scrollState = rememberScrollState()
    LaunchedEffect(scrollState.maxValue, visibleCount, points.size) {
        scrollState.scrollTo(scrollState.maxValue)
    }

    BoxWithConstraints(modifier = modifier) {
        val axisWidth = if (showsAxisLabels) 32.dp else 0.dp
        val plotWidth = maxWidth - axisWidth
        val contentWidth = plotWidth * (max(points.size, 1).toFloat() / visibleCount)
        val bottomInset = if (showsAxisLabels) 18.dp else 0.dp
        Row(modifier = Modifier.fillMaxHeight()) {
            Box(
                modifier = Modifier
                    .width(plotWidth)
                    .fillMaxHeight()
                    .horizontalScroll(scrollState, enabled = points.size > visibleCount)
            ) {
                Canvas(
                    modifier = Modifier
                        .width(contentWidth)
                        .fillMaxHeight()
                ) {
                    val plotHeight = size.height - bottomInset.toPx()
                    fun y(value: Double): Float = (plotHeight - value / yMax * plotHeight).toFloat()
                    ticks.forEach { tick ->
                        drawLine(gridColor, Offset(0f, y(tick)), Offset(size.width, y(tick)), strokeWidth = 1f)
                    }
                    if (points.isEmpty()) return@Canvas
                    val slotWidth = size.width / points.size
                    val groupHalf = slotWidth * if (style == IIDXProgressGraphStyle.STACKED) 0.3f else 0.4f
                    val radius = CornerRadius(2.dp.toPx())
                    fun colorFor(series: String): Color =
                        if (kind == IIDXProgressKind.CLEARS && series == IIDXClearType.FULL_COMBO_CLEAR.value) {
                            IIDXColors.fullComboRainbowColor(phase)
                        } else {
                            kind.color(series)
                        }
                    fun topRounded(left: Float, right: Float, top: Float): Path = Path().apply {
                        addRoundRect(
                            RoundRect(
                                left = left, top = top, right = right, bottom = plotHeight,
                                topLeftCornerRadius = radius, topRightCornerRadius = radius,
                                bottomRightCornerRadius = CornerRadius.Zero, bottomLeftCornerRadius = CornerRadius.Zero
                            )
                        )
                    }
                    points.forEachIndexed { index, point ->
                        val groupStart = (index + 0.5f) * slotWidth - groupHalf
                        if (style == IIDXProgressGraphStyle.STACKED) {
                            val total = visibleSeries.sumOf { point.count(it, kind) }
                            if (total == 0) return@forEachIndexed
                            clipPath(topRounded(groupStart, groupStart + groupHalf * 2f, y(total.toDouble()))) {
                                var stackStart = 0
                                visibleSeries.forEach { series ->
                                    val count = point.count(series, kind)
                                    if (count > 0) {
                                        val top = y((stackStart + count).toDouble())
                                        drawRect(
                                            colorFor(series),
                                            topLeft = Offset(groupStart, top),
                                            size = Size(groupHalf * 2f, y(stackStart.toDouble()) - top)
                                        )
                                    }
                                    stackStart += count
                                }
                            }
                        } else {
                            val barWidth = groupHalf * 2f / max(visibleSeries.size, 1)
                            visibleSeries.forEachIndexed { seriesIndex, series ->
                                val count = point.count(series, kind)
                                if (count > 0) {
                                    val left = groupStart + barWidth * seriesIndex
                                    drawPath(topRounded(left, left + barWidth, y(count.toDouble())), colorFor(series))
                                }
                            }
                        }
                    }
                    if (showsAxisLabels) {
                        val step = max(1, ceil(visibleCount / 4.0).toInt())
                        for (index in points.indices.reversed() step step) {
                            val text = Instant.ofEpochSecond(points[index].date)
                                .atZone(ZoneId.systemDefault())
                                .format(dateFormatter)
                            val layout = textMeasurer.measure(text, labelStyle)
                            val x = ((index + 0.5f) * slotWidth - groupHalf)
                                .coerceIn(0f, max(0f, size.width - layout.size.width))
                            drawText(layout, topLeft = Offset(x, plotHeight + 2.dp.toPx()))
                        }
                    }
                }
            }
            if (showsAxisLabels) {
                Canvas(
                    modifier = Modifier
                        .width(axisWidth)
                        .fillMaxHeight()
                ) {
                    val plotHeight = size.height - bottomInset.toPx()
                    ticks.forEach { tick ->
                        val layout = textMeasurer.measure(tick.toInt().toString(), labelStyle)
                        val top = (plotHeight - tick / yMax * plotHeight).toFloat() - layout.size.height / 2f
                        drawText(
                            layout,
                            topLeft = Offset(
                                4.dp.toPx(),
                                top.coerceIn(0f, max(0f, plotHeight - layout.size.height / 2f))
                            )
                        )
                    }
                }
            }
        }
    }
}

private fun niceStep(raw: Double): Double {
    if (raw <= 1.0) return 1.0
    val magnitude = 10.0.pow(kotlin.math.floor(log10(raw)))
    val normalized = raw / magnitude
    val nice = when {
        normalized <= 1.0 -> 1.0
        normalized <= 2.0 -> 2.0
        normalized <= 5.0 -> 5.0
        else -> 10.0
    }
    return nice * magnitude
}

@Composable
internal fun IIDXProgressCustomizeMenu(kind: IIDXProgressKind) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val settings = rememberProgressSettings(kind)
    var expanded by remember { mutableStateOf(false) }
    IconButton(onClick = { expanded = true }) {
        Icon(Icons.Outlined.Tune, contentDescription = stringResource(R.string.analytics_progress_customize))
    }
    DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
        MenuHeader(stringResource(R.string.analytics_progress_style))
        IIDXProgressGraphStyle.entries.forEach { style ->
            DropdownMenuItem(
                text = { Text(stringResource(style.titleRes)) },
                leadingIcon = { CheckSlot(settings.style == style) },
                onClick = { scope.launch { context.setSetting(kind.styleKey, style.key) } }
            )
        }
        HorizontalDivider()
        MenuHeader(stringResource(R.string.analytics_progress_series))
        kind.series.forEach { series ->
            val isShowing = series !in settings.hiddenSeries
            DropdownMenuItem(
                text = { Text(series) },
                leadingIcon = { CheckSlot(isShowing) },
                onClick = {
                    val hidden = if (isShowing) settings.hiddenSeries + series else settings.hiddenSeries - series
                    scope.launch { context.setSetting(kind.hiddenSeriesKey, hidden) }
                }
            )
        }
    }
}

@Composable
internal fun MenuHeader(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
    )
}

@Composable
internal fun CheckSlot(isChecked: Boolean) {
    Box(modifier = Modifier.size(24.dp), contentAlignment = Alignment.Center) {
        if (isChecked) Icon(Icons.Default.Check, contentDescription = null)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun IIDXProgressDetail(
    points: List<IIDXProgressPoint>,
    kind: IIDXProgressKind,
    modifier: Modifier
) {
    val visibleSeries = rememberProgressSettings(kind).visibleSeries
    val dateFormatter = remember { DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM) }
    LazyColumn(modifier = modifier, contentPadding = PaddingValues(bottom = 24.dp)) {
        if (points.isEmpty()) {
            item {
                Text(
                    text = stringResource(R.string.analytics_no_data),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(24.dp)
                )
            }
            return@LazyColumn
        }
        item {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                IIDXProgressGraph(
                    points = points,
                    kind = kind,
                    showsAxisLabels = true,
                    scrollsBars = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(240.dp)
                )
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    visibleSeries.forEach { series ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .background(kind.color(series), CircleShape)
                            )
                            SeriesLabel(kind, series, MaterialTheme.typography.labelSmall)
                        }
                    }
                }
            }
        }
        items(points.reversed()) { point ->
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = Instant.ofEpochSecond(point.date).atZone(ZoneId.systemDefault()).format(dateFormatter),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold
                )
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    visibleSeries.forEach { series ->
                        val count = point.count(series, kind)
                        Row(
                            modifier = Modifier.width(96.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(3.dp)
                        ) {
                            SeriesLabel(kind, series, MaterialTheme.typography.labelMedium)
                            Text(
                                text = count.toString(),
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = if (count > 0) {
                                    MaterialTheme.colorScheme.onSurface
                                } else {
                                    MaterialTheme.colorScheme.onSurfaceVariant
                                }
                            )
                        }
                    }
                }
            }
            HorizontalDivider()
        }
    }
}
