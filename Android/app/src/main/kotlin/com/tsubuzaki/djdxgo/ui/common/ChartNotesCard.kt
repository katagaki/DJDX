package com.tsubuzaki.djdxgo.ui.common

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.notes.ChartNote
import com.tsubuzaki.djdxgo.data.notes.ChartNoteTarget
import com.tsubuzaki.djdxgo.data.notes.ChartNotesRepository
import kotlinx.coroutines.delay

@Composable
fun ChartNotesCard(
    repository: ChartNotesRepository,
    game: Game,
    title: String,
    chart: String,
    showsPlaySettings: Boolean = false
) {
    var note by remember(game, title, chart) { mutableStateOf<ChartNote?>(null) }
    var savedNote by remember(game, title, chart) { mutableStateOf<ChartNote?>(null) }

    LaunchedEffect(game, title, chart) {
        val loaded = repository.note(game, title, chart)
        savedNote = loaded
        note = loaded
    }

    LaunchedEffect(note) {
        val current = note ?: return@LaunchedEffect
        if (current == savedNote) return@LaunchedEffect
        delay(600)
        repository.save(current)
        savedNote = current
    }

    val latestNote by rememberUpdatedState(note)
    val latestSaved by rememberUpdatedState(savedNote)
    DisposableEffect(game, title, chart) {
        onDispose {
            val current = latestNote
            if (current != null && current != latestSaved) {
                repository.save(current)
            }
        }
    }

    val current = note ?: return
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(
                text = stringResource(R.string.chart_notes),
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.primary
            )
            if (showsPlaySettings) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    NumberField(
                        label = stringResource(R.string.chart_notes_green_number),
                        value = current.greenNumber,
                        allowsNegative = false,
                        modifier = Modifier.weight(1f)
                    ) { note = current.copy(greenNumber = it) }
                    NumberField(
                        label = stringResource(R.string.chart_notes_lane_cover),
                        value = current.laneCover,
                        allowsNegative = false,
                        modifier = Modifier.weight(1f)
                    ) { note = current.copy(laneCover = it) }
                    NumberField(
                        label = stringResource(R.string.chart_notes_judgment_offset),
                        value = current.judgmentOffset,
                        allowsNegative = true,
                        modifier = Modifier.weight(1f)
                    ) { note = current.copy(judgmentOffset = it) }
                }
            }
            OutlinedTextField(
                value = current.text,
                onValueChange = { note = current.copy(text = it) },
                placeholder = { Text(stringResource(R.string.chart_notes_placeholder)) },
                minLines = 3,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun NumberField(
    label: String,
    value: Int?,
    allowsNegative: Boolean,
    modifier: Modifier = Modifier,
    onValueChange: (Int?) -> Unit
) {
    var text by remember { mutableStateOf(value?.toString().orEmpty()) }
    LaunchedEffect(value) {
        if (text.toIntOrNull() != value) text = value?.toString().orEmpty()
    }
    OutlinedTextField(
        value = text,
        onValueChange = { input ->
            val filtered = input.filterIndexed { index, char ->
                char.isDigit() || (allowsNegative && char == '-' && index == 0)
            }.take(5)
            text = filtered
            onValueChange(filtered.toIntOrNull())
        },
        label = { Text(label, maxLines = 1) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(
            keyboardType = if (allowsNegative) KeyboardType.Text else KeyboardType.Number
        ),
        modifier = modifier
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChartNotesSheet(
    repository: ChartNotesRepository,
    target: ChartNoteTarget,
    onDismiss: () -> Unit
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 16.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(text = target.title, style = MaterialTheme.typography.titleMedium)
                Text(
                    text = target.chartLabel,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            ChartNotesCard(
                repository = repository,
                game = target.game,
                title = target.title,
                chart = target.chart
            )
        }
    }
}
