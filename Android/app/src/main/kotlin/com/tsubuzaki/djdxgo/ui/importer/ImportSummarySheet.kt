package com.tsubuzaki.djdxgo.ui.importer

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.ddr.DDRClearLamp
import com.tsubuzaki.djdxgo.data.ddr.DDRRank
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevel
import com.tsubuzaki.djdxgo.data.importsummary.ImportSummary
import com.tsubuzaki.djdxgo.data.importsummary.ImportSummaryEntry
import com.tsubuzaki.djdxgo.data.importsummary.ImportSummaryRating
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordClearType
import com.tsubuzaki.djdxgo.data.popn.PopnClearType
import com.tsubuzaki.djdxgo.data.sdvx.SDVXClearType
import com.tsubuzaki.djdxgo.ui.theme.DDRColors
import com.tsubuzaki.djdxgo.ui.theme.IIDXColors
import com.tsubuzaki.djdxgo.ui.theme.Palette
import com.tsubuzaki.djdxgo.ui.theme.PolarisChordColors
import com.tsubuzaki.djdxgo.ui.theme.PopnColors
import com.tsubuzaki.djdxgo.ui.theme.SDVXColors
import java.util.Locale

private data class ChangeStyle(val text: String, val color: Color)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ImportSummarySheet(
    formatDate: (Long) -> String,
    onDismiss: () -> Unit,
    load: suspend () -> ImportSummary?
) {
    var summary by remember { mutableStateOf<ImportSummary?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    LaunchedEffect(Unit) {
        summary = load()
        isLoading = false
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        Text(
            text = stringResource(R.string.import_summary_title),
            style = MaterialTheme.typography.titleLarge,
            modifier = Modifier.padding(horizontal = 16.dp)
        )
        val loaded = summary
        when {
            isLoading -> Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(32.dp),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
            loaded == null -> Text(
                text = stringResource(R.string.import_summary_unavailable),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(16.dp)
            )
            else -> ImportSummaryContent(loaded, formatDate)
        }
    }
}

@Composable
private fun ImportSummaryContent(summary: ImportSummary, formatDate: (Long) -> String) {
    val darkTheme = isSystemInDarkTheme()
    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    LabeledRow(stringResource(R.string.import_summary_import_date), formatDate(summary.importDate))
                    LabeledRow(
                        stringResource(R.string.import_summary_compared_with),
                        summary.previousImportDate?.let(formatDate)
                            ?: stringResource(R.string.import_summary_no_previous_import)
                    )
                }
            }
        }
        if (summary.ratings.isNotEmpty()) {
            item { SectionHeader(stringResource(R.string.import_summary_ratings)) }
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        summary.ratings.forEach { RatingRow(it) }
                    }
                }
            }
        }
        if (summary.previousImportDate != null) {
            item {
                SectionHeader(
                    "${stringResource(R.string.import_summary_personal_bests)} (${summary.personalBests.size})"
                )
            }
            if (summary.personalBests.isEmpty()) {
                item {
                    Text(
                        text = stringResource(R.string.import_summary_no_personal_bests),
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                items(summary.personalBests) { entry ->
                    EntryCard(summary.game, entry, darkTheme)
                }
            }
        }
    }
}

@Composable
private fun SectionHeader(text: String) {
    Text(text = text, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 4.dp))
}

@Composable
private fun LabeledRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(text = label, modifier = Modifier.weight(1f))
        Text(text = value, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun RatingRow(rating: ImportSummaryRating) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = rating.name, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
        rating.previousValue?.let {
            Text(text = format(it, rating.fractionDigits), color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(text = "→", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Text(text = format(rating.value, rating.fractionDigits), fontWeight = FontWeight.Bold)
        rating.delta?.let { delta ->
            Text(
                text = (if (delta >= 0) "+" else "") + format(delta, rating.fractionDigits),
                style = MaterialTheme.typography.labelMedium,
                color = when {
                    delta > 0 -> Palette.green
                    delta < 0 -> Palette.red
                    else -> MaterialTheme.colorScheme.onSurfaceVariant
                }
            )
        }
    }
}

@Composable
private fun EntryCard(game: Game, entry: ImportSummaryEntry, darkTheme: Boolean) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = entry.chart,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = difficultyColor(game, entry.difficulty)
                )
                Text(
                    text = entry.title,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            HorizontalDivider()
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                entry.score?.let { score ->
                    ChangeLabel(
                        previous = entry.previousScore?.toString(),
                        current = ChangeStyle(score.toString(), MaterialTheme.colorScheme.onSurface),
                        delta = entry.previousScore?.let { score - it }
                    )
                }
                entry.lamp?.let { lamp ->
                    ChangeLabel(
                        previous = lamp.previous?.let { lampStyle(game, it, darkTheme).text },
                        current = lampStyle(game, lamp.current, darkTheme)
                    )
                }
                entry.grade?.let { grade ->
                    ChangeLabel(
                        previous = grade.previous?.let { gradeStyle(game, it, darkTheme).text },
                        current = gradeStyle(game, grade.current, darkTheme)
                    )
                }
            }
        }
    }
}

@Composable
private fun ChangeLabel(previous: String?, current: ChangeStyle, delta: Int? = null) {
    Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
        val style = MaterialTheme.typography.labelMedium
        previous?.let {
            Text(text = it, style = style, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(text = "→", style = style, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Text(text = current.text, style = style, fontWeight = FontWeight.Bold, color = current.color)
        delta?.let { Text(text = "+$it", style = style, color = Palette.green) }
    }
}

private fun format(value: Double, fractionDigits: Int): String =
    String.format(Locale.getDefault(), "%,.${fractionDigits}f", value)

private fun difficultyColor(game: Game, difficulty: String): Color = when (game) {
    Game.IIDX_ARCADE -> IIDXLevel.fromCode(difficulty)?.let(IIDXColors::levelColor) ?: Palette.gray
    Game.SOUND_VOLTEX -> SDVXColors.difficultyColor(difficulty)
    Game.POLARIS_CHORD -> PolarisChordColors.difficultyColor(difficulty)
    Game.DANCE_DANCE_REVOLUTION -> DDRColors.difficultyColor(difficulty)
    Game.POPN -> PopnColors.difficultyColor(difficulty)
}

private fun lampStyle(game: Game, value: String, darkTheme: Boolean): ChangeStyle = when (game) {
    Game.IIDX_ARCADE -> ChangeStyle(
        IIDXClearType.fromValue(value)?.abbreviation ?: value,
        IIDXColors.clearTypeColor(value)
    )
    Game.SOUND_VOLTEX -> ChangeStyle(
        SDVXClearType.fromValue(value)?.abbreviation ?: value,
        SDVXColors.clearTypeColor(value)
    )
    Game.POLARIS_CHORD -> ChangeStyle(
        PolarisChordClearType.fromValue(value)?.abbreviation ?: value,
        PolarisChordColors.clearTypeColor(value)
    )
    Game.DANCE_DANCE_REVOLUTION -> ChangeStyle(
        DDRClearLamp.display(value),
        DDRColors.clearColor(value, darkTheme)
    )
    Game.POPN -> ChangeStyle(
        PopnClearType.fromValue(value)?.abbreviation ?: value,
        PopnColors.clearTypeColor(value)
    )
}

private fun gradeStyle(game: Game, value: String, darkTheme: Boolean): ChangeStyle = when (game) {
    Game.IIDX_ARCADE -> ChangeStyle(value, IIDXColors.djLevelColor(value))
    Game.SOUND_VOLTEX -> ChangeStyle(value, SDVXColors.gradeColor(value, darkTheme))
    Game.POLARIS_CHORD -> ChangeStyle(value, PolarisChordColors.gradeColor(value))
    Game.DANCE_DANCE_REVOLUTION -> ChangeStyle(DDRRank.display(value), DDRColors.rankColor(value, darkTheme))
    Game.POPN -> ChangeStyle(value, PopnColors.rankColor(value))
}
