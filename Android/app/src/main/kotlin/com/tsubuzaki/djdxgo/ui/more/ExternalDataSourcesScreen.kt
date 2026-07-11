package com.tsubuzaki.djdxgo.ui.more

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.datastore.preferences.core.Preferences
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.external.ExternalDataDao
import com.tsubuzaki.djdxgo.data.external.ExternalDataReloader
import com.tsubuzaki.djdxgo.data.external.ExternalDataSource
import com.tsubuzaki.djdxgo.data.setSetting
import com.tsubuzaki.djdxgo.data.settingsDataStore
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import java.text.NumberFormat

private data class ExternalSourceInfo(
    val source: ExternalDataSource,
    val settingKey: Preferences.Key<Boolean>,
    val nameRes: Int,
    val descriptionRes: Int
)

private val externalSources = listOf(
    ExternalSourceInfo(
        ExternalDataSource.TEXTAGE_CHART_VIEWER,
        SettingsKeys.externalTextageChartViewerEnabled,
        R.string.external_textage_chart_viewer_name,
        R.string.external_textage_chart_viewer_description
    ),
    ExternalSourceInfo(
        ExternalDataSource.WIKI_IIDX,
        SettingsKeys.externalBemaniWikiEnabled,
        R.string.external_bemaniwiki_iidx_name,
        R.string.external_bemaniwiki_iidx_description
    ),
    ExternalSourceInfo(
        ExternalDataSource.BM2DX,
        SettingsKeys.externalBM2DXEnabled,
        R.string.external_bm2dx_name,
        R.string.external_bm2dx_description
    ),
    ExternalSourceInfo(
        ExternalDataSource.SDVX_IN,
        SettingsKeys.externalSDVXInEnabled,
        R.string.external_sdvxin_name,
        R.string.external_sdvxin_description
    ),
    ExternalSourceInfo(
        ExternalDataSource.WIKI_DDR,
        SettingsKeys.externalDDREnabled,
        R.string.external_ddr_name,
        R.string.external_ddr_description
    )
)

private suspend fun entryCount(dao: ExternalDataDao, source: ExternalDataSource): Int =
    when (source) {
        ExternalDataSource.TEXTAGE_CHART_VIEWER -> dao.textageChartViewerChartCount()
        ExternalDataSource.SDVX_IN -> dao.sdvxInChartCount()
        ExternalDataSource.WIKI_IIDX -> dao.iidxSongCount()
        ExternalDataSource.BM2DX -> dao.notesRadarCount()
        ExternalDataSource.WIKI_DDR -> dao.ddrSongMetaCount()
    }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExternalDataSourcesScreen(container: AppContainer, onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val dao = container.externalDataDao
    val reloader = remember { ExternalDataReloader(dao) }
    val snackbarHostState = remember { SnackbarHostState() }

    val counts = remember { mutableStateMapOf<ExternalDataSource, Int>() }
    val enabledStates = remember { mutableStateMapOf<ExternalDataSource, Boolean>() }
    var reloadingSource by remember { mutableStateOf<ExternalDataSource?>(null) }
    var progress by remember { mutableFloatStateOf(0f) }

    val numberFormat = remember { NumberFormat.getIntegerInstance() }
    val doneMessage = stringResource(R.string.external_reload_done)
    val failedMessage = stringResource(R.string.external_reload_failed)

    LaunchedEffect(Unit) {
        externalSources.forEach { info ->
            counts[info.source] = entryCount(dao, info.source)
        }
        context.settingsDataStore.data
            .map { preferences ->
                externalSources.associate { info ->
                    info.source to (preferences[info.settingKey] ?: false)
                }
            }
            .collect { states -> enabledStates.putAll(states) }
    }

    suspend fun runReload(source: ExternalDataSource): Result<Int> {
        progress = 0f
        val result = reloader.reload(source) { progress = it }
        result.onSuccess { counts[source] = it }
        return result
    }

    fun reloadSingle(source: ExternalDataSource) {
        if (reloadingSource != null) return
        reloadingSource = source
        scope.launch {
            val result = runReload(source)
            reloadingSource = null
            snackbarHostState.showSnackbar(
                result.fold(
                    onSuccess = { String.format(doneMessage, numberFormat.format(it)) },
                    onFailure = { String.format(failedMessage, it.localizedMessage ?: it.javaClass.simpleName) }
                )
            )
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.external_title)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.external_back)
                        )
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(externalSources, key = { it.source.name }) { info ->
                ExternalSourceCard(
                    info = info,
                    count = counts[info.source],
                    enabled = enabledStates[info.source] ?: false,
                    isReloading = reloadingSource == info.source,
                    reloadAllowed = reloadingSource == null,
                    progress = progress,
                    onToggle = { isOn ->
                        enabledStates[info.source] = isOn
                        scope.launch { context.setSetting(info.settingKey, isOn) }
                    },
                    onReload = { reloadSingle(info.source) }
                )
            }
        }
    }
}

@Composable
private fun ExternalSourceCard(
    info: ExternalSourceInfo,
    count: Int?,
    enabled: Boolean,
    isReloading: Boolean,
    reloadAllowed: Boolean,
    progress: Float,
    onToggle: (Boolean) -> Unit,
    onReload: () -> Unit
) {
    val numberFormat = remember { NumberFormat.getIntegerInstance() }
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = stringResource(info.nameRes),
                        style = MaterialTheme.typography.titleMedium
                    )
                    Text(
                        text = stringResource(info.descriptionRes),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Spacer(modifier = Modifier.width(12.dp))
                Switch(checked = enabled, onCheckedChange = onToggle)
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = stringResource(
                        R.string.external_entry_count,
                        numberFormat.format(count ?: 0)
                    ),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f)
                )
                FilledTonalButton(
                    onClick = onReload,
                    enabled = enabled && reloadAllowed
                ) {
                    if (isReloading) {
                        if (progress > 0f && progress < 1f) {
                            CircularProgressIndicator(
                                progress = { progress },
                                modifier = Modifier.size(18.dp),
                                strokeWidth = 2.dp
                            )
                        } else {
                            CircularProgressIndicator(
                                modifier = Modifier.size(18.dp),
                                strokeWidth = 2.dp
                            )
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                    }
                    Text(stringResource(R.string.external_reload))
                }
            }
        }
    }
}
