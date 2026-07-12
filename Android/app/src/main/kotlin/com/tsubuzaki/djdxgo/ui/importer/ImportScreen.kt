package com.tsubuzaki.djdxgo.ui.importer

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.iidx.IIDXVersionInfo
import com.tsubuzaki.djdxgo.data.sdvx.SDVXVersion
import com.tsubuzaki.djdxgo.data.setSetting
import com.tsubuzaki.djdxgo.data.settingFlow
import com.tsubuzaki.djdxgo.importer.ImportFailedReason
import com.tsubuzaki.djdxgo.importer.WebImportResult
import com.tsubuzaki.djdxgo.importer.WebImporterSpec
import com.tsubuzaki.djdxgo.importer.WebImporterSpecs
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import androidx.core.net.toUri

private data class PendingWebImport(
    val spec: WebImporterSpec,
    val playType: IIDXPlayType?
)

private data class ImportGroupRow(
    val id: String,
    val importDate: Long
)

private sealed interface ImportState {
    data object Idle : ImportState
    data object Importing : ImportState
    data object Succeeded : ImportState
    data class Failed(val reason: ImportFailedReason) : ImportState
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ImportScreen(container: AppContainer, game: Game, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val sdvxVersionNumber by context
        .settingFlow(SettingsKeys.sdvxVersion, SDVXVersion.NABLA.number)
        .collectAsState(initial = SDVXVersion.NABLA.number)
    val sdvxVersion = SDVXVersion.fromNumber(sdvxVersionNumber)
    val iidxPlayTypeValue by context
        .settingFlow(SettingsKeys.iidxPlayType, IIDXPlayType.SINGLE.value)
        .collectAsState(initial = IIDXPlayType.SINGLE.value)
    val csvPlayType = IIDXPlayType.fromValue(iidxPlayTypeValue)

    var selectedEpochDay by rememberSaveable { mutableStateOf(LocalDate.now().toEpochDay()) }
    val selectedDate = LocalDate.ofEpochDay(selectedEpochDay)
    var isDatePickerShown by remember { mutableStateOf(false) }
    var isCsvInstructionsShown by remember { mutableStateOf(false) }
    var pendingWebImport by remember { mutableStateOf<PendingWebImport?>(null) }
    var importState by remember { mutableStateOf<ImportState>(ImportState.Idle) }
    var groupPendingDeletion by remember { mutableStateOf<ImportGroupRow?>(null) }

    val importGroups by remember(game) { importGroupRowsFlow(container, game) }
        .collectAsState(initial = emptyList())

    val dateFormatter = remember { DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM) }

    val csvLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenMultipleDocuments()
    ) { uris ->
        if (uris.isEmpty()) return@rememberLauncherForActivityResult
        val defaultImportDate = importDateEpochSeconds(selectedDate)
        importState = ImportState.Importing
        scope.launch(Dispatchers.IO) {
            uris.forEach { uri ->
                val content = runCatching {
                    context.contentResolver.openInputStream(uri)
                        ?.bufferedReader(Charsets.UTF_8)
                        ?.use { it.readText() }
                }.getOrNull() ?: return@forEach
                when (game) {
                    Game.IIDX_ARCADE -> container.iidxRepository.importCSV(
                        content,
                        fileNameImportDate(context, uri) ?: defaultImportDate,
                        csvPlayType
                    )
                    Game.SOUND_VOLTEX -> container.sdvxRepository.importCSV(
                        content,
                        defaultImportDate,
                        sdvxVersion
                    )
                    else -> Unit
                }
            }
            withContext(Dispatchers.Main) {
                importState = ImportState.Succeeded
            }
        }
    }

    val pending = pendingWebImport
    if (pending != null) {
        WebImporterScreen(spec = pending.spec) { result ->
            pendingWebImport = null
            when (result) {
                WebImportResult.Cancelled -> Unit
                is WebImportResult.Failure -> importState = ImportState.Failed(result.reason)
                is WebImportResult.Success -> {
                    importState = ImportState.Importing
                    val importDate = importDateEpochSeconds(selectedDate)
                    scope.launch(Dispatchers.IO) {
                        when (game) {
                            Game.IIDX_ARCADE -> {
                                container.iidxRepository.importCSV(
                                    result.payload,
                                    importDate,
                                    pending.playType ?: IIDXPlayType.SINGLE
                                )
                                result.towerPayload?.let {
                                    container.iidxRepository.importTowerCSV(it)
                                }
                            }
                            Game.SOUND_VOLTEX -> container.sdvxRepository.importCSV(
                                result.payload, importDate, sdvxVersion
                            )
                            Game.POLARIS_CHORD -> container.polarisChordRepository.importJSON(
                                result.payload, importDate
                            )
                            Game.DANCE_DANCE_REVOLUTION -> container.ddrRepository.importJSON(
                                result.payload, importDate
                            )
                        }
                        withContext(Dispatchers.Main) {
                            importState = ImportState.Succeeded
                        }
                    }
                }
            }
        }
    } else {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text(stringResource(R.string.import_title)) },
                    navigationIcon = {
                        IconButton(onClick = onDismiss) {
                            Icon(
                                Icons.Filled.Close,
                                contentDescription = stringResource(R.string.import_close)
                            )
                        }
                    }
                )
            }
        ) { innerPadding ->
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (game == Game.IIDX_ARCADE) {
                    item {
                        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                            IIDXPlayType.entries.forEachIndexed { index, type ->
                                SegmentedButton(
                                    selected = csvPlayType == type,
                                    onClick = {
                                        scope.launch {
                                            context.setSetting(SettingsKeys.iidxPlayType, type.value)
                                        }
                                    },
                                    shape = SegmentedButtonDefaults.itemShape(
                                        index = index,
                                        count = IIDXPlayType.entries.size
                                    )
                                ) {
                                    Text(type.displayName)
                                }
                            }
                        }
                    }
                }
                item {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        ListItem(
                            headlineContent = { Text(stringResource(R.string.import_to_date)) },
                            trailingContent = {
                                TextButton(onClick = { isDatePickerShown = true }) {
                                    Text(selectedDate.format(dateFormatter))
                                }
                            },
                            colors = ListItemDefaults.colors(containerColor = Color.Transparent)
                        )
                    }
                }
                item {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                        Button(
                            onClick = {
                                pendingWebImport = PendingWebImport(
                                    when (game) {
                                        Game.IIDX_ARCADE -> WebImporterSpecs.iidx(csvPlayType)
                                        Game.SOUND_VOLTEX -> WebImporterSpecs.sdvx(sdvxVersion)
                                        Game.POLARIS_CHORD -> WebImporterSpecs.polarisChord()
                                        Game.DANCE_DANCE_REVOLUTION -> WebImporterSpecs.ddr()
                                    },
                                    if (game == Game.IIDX_ARCADE) csvPlayType else null
                                )
                            },
                            contentPadding = PaddingValues(horizontal = 24.dp, vertical = 16.dp),
                            modifier = Modifier.weight(1f)
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(Icons.Filled.Language, contentDescription = null)
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(stringResource(R.string.import_via_web))
                            }
                        }
                        if (game == Game.IIDX_ARCADE || game == Game.SOUND_VOLTEX) {
                            Button(
                                onClick = { isCsvInstructionsShown = true },
                                contentPadding = PaddingValues(horizontal = 24.dp, vertical = 16.dp),
                                modifier = Modifier.weight(1f)
                            ) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Icon(Icons.Filled.Description, contentDescription = null)
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text(stringResource(R.string.import_via_csv))
                                }
                            }
                        }
                    }
                }
                item {
                    Text(
                        text = stringResource(R.string.import_history),
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
                if (importGroups.isEmpty()) {
                    item {
                        Text(
                            text = stringResource(R.string.import_history_empty),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                } else {
                    items(importGroups, key = { it.id }) { group ->
                        Card(modifier = Modifier.fillMaxWidth()) {
                            ListItem(
                                headlineContent = {
                                    Text(formatEpochDate(group.importDate, dateFormatter))
                                },
                                trailingContent = {
                                    IconButton(onClick = { groupPendingDeletion = group }) {
                                        Icon(
                                            Icons.Outlined.Delete,
                                            contentDescription = stringResource(R.string.import_delete)
                                        )
                                    }
                                },
                                colors = ListItemDefaults.colors(containerColor = Color.Transparent)
                            )
                        }
                    }
                }
            }
        }
    }

    if (isDatePickerShown) {
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = selectedEpochDay * 86_400_000L,
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long): Boolean =
                    utcTimeMillis / 86_400_000L <= LocalDate.now().toEpochDay()
            }
        )
        DatePickerDialog(
            onDismissRequest = { isDatePickerShown = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        datePickerState.selectedDateMillis?.let { millis ->
                            selectedEpochDay = millis / 86_400_000L
                        }
                        isDatePickerShown = false
                    }
                ) {
                    Text(stringResource(R.string.import_ok))
                }
            },
            dismissButton = {
                TextButton(onClick = { isDatePickerShown = false }) {
                    Text(stringResource(R.string.import_cancel))
                }
            }
        ) {
            DatePicker(state = datePickerState)
        }
    }

    if (isCsvInstructionsShown) {
        AlertDialog(
            onDismissRequest = { isCsvInstructionsShown = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        isCsvInstructionsShown = false
                        csvLauncher.launch(
                            arrayOf(
                                "text/comma-separated-values",
                                "text/csv",
                                "text/plain"
                            )
                        )
                    }
                ) {
                    Text(stringResource(R.string.import_csv_load_button))
                }
            },
            dismissButton = {
                TextButton(onClick = { isCsvInstructionsShown = false }) {
                    Text(stringResource(R.string.import_cancel))
                }
            },
            title = { Text(stringResource(R.string.import_csv_instructions_title)) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(stringResource(R.string.import_csv_instructions_message))
                    TextButton(
                        onClick = { openDownloadPage(context, game, sdvxVersion) },
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        Text(stringResource(R.string.import_csv_download_button))
                    }
                }
            }
        )
    }

    when (val state = importState) {
        ImportState.Importing -> AlertDialog(
            onDismissRequest = {},
            confirmButton = {},
            title = { Text(stringResource(R.string.import_status_importing)) },
            text = { LinearProgressIndicator(modifier = Modifier.fillMaxWidth()) }
        )
        ImportState.Succeeded -> AlertDialog(
            onDismissRequest = { importState = ImportState.Idle },
            confirmButton = {
                TextButton(onClick = { importState = ImportState.Idle }) {
                    Text(stringResource(R.string.import_ok))
                }
            },
            title = { Text(stringResource(R.string.import_success_title)) },
            text = { Text(stringResource(R.string.import_success_message)) }
        )
        is ImportState.Failed -> AlertDialog(
            onDismissRequest = { importState = ImportState.Idle },
            confirmButton = {
                TextButton(onClick = { importState = ImportState.Idle }) {
                    Text(stringResource(R.string.import_ok))
                }
            },
            title = { Text(stringResource(R.string.import_error_title)) },
            text = { Text(stringResource(state.reason.messageResource())) }
        )
        ImportState.Idle -> Unit
    }

    groupPendingDeletion?.let { group ->
        AlertDialog(
            onDismissRequest = { groupPendingDeletion = null },
            confirmButton = {
                TextButton(
                    onClick = {
                        groupPendingDeletion = null
                        scope.launch(Dispatchers.IO) {
                            deleteImportGroup(container, game, group.id)
                        }
                    }
                ) {
                    Text(stringResource(R.string.import_delete))
                }
            },
            dismissButton = {
                TextButton(onClick = { groupPendingDeletion = null }) {
                    Text(stringResource(R.string.import_cancel))
                }
            },
            title = { Text(stringResource(R.string.import_delete_confirm_title)) },
            text = {
                Text(
                    stringResource(
                        R.string.import_delete_confirm_message,
                        formatEpochDate(group.importDate, dateFormatter)
                    )
                )
            }
        )
    }
}

private fun ImportFailedReason.messageResource(): Int = when (this) {
    ImportFailedReason.NO_PREMIUM_COURSE -> R.string.import_error_no_premium_course
    ImportFailedReason.NO_EAMUSEMENT_PASS -> R.string.import_error_no_eamusement_pass
    ImportFailedReason.NO_PLAY_DATA -> R.string.import_error_no_play_data
    ImportFailedReason.SERVER_ERROR -> R.string.import_error_server
    ImportFailedReason.MAINTENANCE -> R.string.import_error_maintenance
}

private fun importGroupRowsFlow(container: AppContainer, game: Game): Flow<List<ImportGroupRow>> =
    when (game) {
        Game.IIDX_ARCADE -> container.database.iidxDao().importGroupsFlow()
            .map { groups -> groups.map { ImportGroupRow(it.id, it.importDate) } }
        Game.SOUND_VOLTEX -> container.database.sdvxDao().importGroupsFlow()
            .map { groups -> groups.map { ImportGroupRow(it.id, it.importDate) } }
        Game.POLARIS_CHORD -> container.database.polarisChordDao().importGroupsFlow()
            .map { groups -> groups.map { ImportGroupRow(it.id, it.importDate) } }
        Game.DANCE_DANCE_REVOLUTION -> container.database.ddrDao().importGroupsFlow()
            .map { groups -> groups.map { ImportGroupRow(it.id, it.importDate) } }
    }

private suspend fun deleteImportGroup(container: AppContainer, game: Game, groupID: String) {
    when (game) {
        Game.IIDX_ARCADE -> container.iidxRepository.deleteImportGroup(groupID)
        Game.SOUND_VOLTEX -> container.sdvxRepository.deleteImportGroup(groupID)
        Game.POLARIS_CHORD -> container.polarisChordRepository.deleteImportGroup(groupID)
        Game.DANCE_DANCE_REVOLUTION -> container.ddrRepository.deleteImportGroup(groupID)
    }
}

private fun importDateEpochSeconds(date: LocalDate): Long =
    if (date == LocalDate.now()) {
        Instant.now().epochSecond
    } else {
        date.atTime(12, 0).atZone(ZoneId.systemDefault()).toEpochSecond()
    }

private fun formatEpochDate(epochSeconds: Long, formatter: DateTimeFormatter): String =
    Instant.ofEpochSecond(epochSeconds)
        .atZone(ZoneId.systemDefault())
        .toLocalDate()
        .format(formatter)

private fun fileNameImportDate(context: Context, uri: Uri): Long? {
    val name = context.contentResolver
        .query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        ?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
        ?: uri.lastPathSegment
        ?: return null
    val match = Regex("""\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}""").find(name)?.value ?: return null
    return runCatching {
        LocalDateTime.parse(match, DateTimeFormatter.ofPattern("yyyy-MM-dd-HH-mm-ss"))
            .atZone(ZoneId.systemDefault())
            .toEpochSecond()
    }.getOrNull()
}

private fun openDownloadPage(context: Context, game: Game, sdvxVersion: SDVXVersion) {
    val url = when (game) {
        Game.IIDX_ARCADE -> IIDXVersionInfo.downloadPageBaseURL
        Game.SOUND_VOLTEX -> sdvxVersion.downloadPageURL()
        else -> return
    }
    context.startActivity(Intent(Intent.ACTION_VIEW, url.toUri()))
}
