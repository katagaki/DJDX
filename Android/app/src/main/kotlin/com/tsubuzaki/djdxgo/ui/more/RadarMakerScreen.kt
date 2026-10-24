package com.tsubuzaki.djdxgo.ui.more

import android.content.Intent
import android.graphics.Bitmap
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.RadarAxis
import com.tsubuzaki.djdxgo.data.RadarData
import com.tsubuzaki.djdxgo.ui.common.DetailScaffold
import com.tsubuzaki.djdxgo.ui.common.RadarChart
import com.tsubuzaki.djdxgo.ui.common.renderRadarBitmap
import com.tsubuzaki.djdxgo.ui.theme.RadarColors
import java.io.File
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val RADAR_MAKER_MAXIMUM = 200f

@Composable
fun RadarMakerScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current.density
    var notes by rememberSaveable { mutableDoubleStateOf(100.0) }
    var chord by rememberSaveable { mutableDoubleStateOf(80.0) }
    var peak by rememberSaveable { mutableDoubleStateOf(120.0) }
    var charge by rememberSaveable { mutableDoubleStateOf(60.0) }
    var scratch by rememberSaveable { mutableDoubleStateOf(90.0) }
    var soflan by rememberSaveable { mutableDoubleStateOf(70.0) }
    var paletteIndex by rememberSaveable { mutableIntStateOf(0) }
    var colorIndex by rememberSaveable { mutableIntStateOf(0) }
    var isExportFailed by rememberSaveable { mutableStateOf(false) }

    val palettes = listOf(
        stringResource(R.string.radar_maker_palette_player) to RadarColors.playerPalette,
        stringResource(R.string.radar_maker_palette_notes) to RadarColors.notesPalette
    )
    val colors = palettes[paletteIndex].second
    val selectedColor = colors[colorIndex.coerceIn(0, colors.size - 1)]
    val radar = RadarData(notes, chord, peak, charge, scratch, soflan)

    fun export() {
        scope.launch {
            val uri = withContext(Dispatchers.IO) {
                runCatching {
                    val bitmap = renderRadarBitmap(radar, selectedColor, density)
                    val directory = File(context.cacheDir, "exports").apply { mkdirs() }
                    val file = File(directory, "NotesRadar-${System.currentTimeMillis() / 1000}.png")
                    file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                    FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
                }.getOrNull()
            }
            if (uri == null) {
                isExportFailed = true
                return@launch
            }
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(Intent.createChooser(intent, null))
        }
    }

    DetailScaffold(title = stringResource(R.string.radar_maker_title), onBack = onBack) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            RadarChart(
                data = radar,
                color = selectedColor,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(300.dp)
                    .padding(vertical = 24.dp)
            )
            Text(
                text = stringResource(R.string.radar_maker_color),
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.primary
            )
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                palettes.forEachIndexed { index, (title, _) ->
                    SegmentedButton(
                        selected = paletteIndex == index,
                        onClick = {
                            paletteIndex = index
                            colorIndex = 0
                        },
                        shape = SegmentedButtonDefaults.itemShape(index, palettes.size)
                    ) {
                        Text(title)
                    }
                }
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(8.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                colors.forEachIndexed { index, color ->
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .border(
                                width = 3.dp,
                                color = if (index == colorIndex) MaterialTheme.colorScheme.onSurface else Color.Transparent,
                                shape = CircleShape
                            )
                            .padding(5.dp)
                            .clip(CircleShape)
                            .background(color)
                            .clickable { colorIndex = index }
                    )
                }
            }
            Text(
                text = stringResource(R.string.radar_maker_values),
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.primary
            )
            ValueSlider(RadarAxis.NOTES, notes) { notes = it }
            ValueSlider(RadarAxis.CHORD, chord) { chord = it }
            ValueSlider(RadarAxis.PEAK, peak) { peak = it }
            ValueSlider(RadarAxis.CHARGE, charge) { charge = it }
            ValueSlider(RadarAxis.SCRATCH, scratch) { scratch = it }
            ValueSlider(RadarAxis.SOFLAN, soflan) { soflan = it }
            Row {
                Text(
                    text = stringResource(R.string.radar_total),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = String.format(Locale.ROOT, "%.2f", radar.sum()),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
            }
            Button(onClick = ::export, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                Icon(Icons.Default.Share, contentDescription = null)
                Text(stringResource(R.string.radar_maker_export), modifier = Modifier.padding(start = 8.dp))
            }
        }
    }

    if (isExportFailed) {
        AlertDialog(
            onDismissRequest = { isExportFailed = false },
            title = { Text(stringResource(R.string.radar_maker_export_failed_title)) },
            text = { Text(stringResource(R.string.radar_maker_export_failed_message)) },
            confirmButton = {
                TextButton(onClick = { isExportFailed = false }) { Text(stringResource(R.string.shared_ok)) }
            }
        )
    }
}

@Composable
private fun ValueSlider(axis: RadarAxis, value: Double, onValueChange: (Double) -> Unit) {
    val color = RadarColors.axisColor(axis)
    Column {
        Row {
            Text(text = axis.label, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = color)
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = String.format(Locale.ROOT, "%.2f", value),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
        Slider(
            value = value.toFloat(),
            onValueChange = { onValueChange(it.toDouble()) },
            valueRange = 0f..RADAR_MAKER_MAXIMUM,
            colors = SliderDefaults.colors(thumbColor = color, activeTrackColor = color)
        )
    }
}
