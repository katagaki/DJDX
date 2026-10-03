package com.tsubuzaki.djdxgo.ui.more

import android.content.Intent
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
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import androidx.datastore.preferences.core.Preferences
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.external.ExternalDataSource
import com.tsubuzaki.djdxgo.data.setSetting
import com.tsubuzaki.djdxgo.data.settingsDataStore
import com.tsubuzaki.djdxgo.ui.common.DetailScaffold
import java.text.NumberFormat
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

private data class ExternalSourceInfo(
    val source: ExternalDataSource,
    val settingKey: Preferences.Key<Boolean>,
    val title: @Composable () -> String
)

private data class ExternalSourceGroup(
    val headerRes: Int,
    val footerRes: Int,
    val url: String,
    val sources: List<ExternalSourceInfo>
)

private val externalSourceGroups = listOf(
    ExternalSourceGroup(
        R.string.external_textage_chart_viewer_name,
        R.string.external_textage_chart_viewer_footer,
        "https://textage-chart-viewer.vercel.app",
        listOf(
            ExternalSourceInfo(ExternalDataSource.TEXTAGE_CHART_VIEWER, SettingsKeys.externalTextageChartViewerEnabled) {
                stringResource(R.string.external_chart_index)
            }
        )
    ),
    ExternalSourceGroup(
        R.string.external_textage_name,
        R.string.external_textage_footer,
        "https://textage.cc",
        listOf(
            ExternalSourceInfo(ExternalDataSource.TEXTAGE, SettingsKeys.externalTextageEnabled) {
                stringResource(R.string.external_chart_index)
            }
        )
    ),
    ExternalSourceGroup(
        R.string.external_sdvxin_name,
        R.string.external_sdvxin_footer,
        "https://sdvx.in",
        listOf(
            ExternalSourceInfo(ExternalDataSource.SDVX_IN, SettingsKeys.externalSDVXInEnabled) {
                stringResource(R.string.external_chart_index)
            }
        )
    ),
    ExternalSourceGroup(
        R.string.external_bemaniwiki_name,
        R.string.external_bemaniwiki_footer,
        "https://bemaniwiki.com",
        listOf(
            ExternalSourceInfo(ExternalDataSource.WIKI_IIDX, SettingsKeys.externalBemaniWikiEnabled) { "beatmania IIDX" },
            ExternalSourceInfo(ExternalDataSource.WIKI_DDR, SettingsKeys.externalDDREnabled) { "DanceDanceRevolution" }
        )
    ),
    ExternalSourceGroup(
        R.string.external_bm2dx_name,
        R.string.external_bm2dx_footer,
        "https://bm2dx.com/IIDX/notes_radar/",
        listOf(
            ExternalSourceInfo(ExternalDataSource.BM2DX, SettingsKeys.externalBM2DXEnabled) {
                stringResource(R.string.external_bm2dx_description)
            }
        )
    )
)

@Composable
fun ExternalDataSourcesScreen(container: AppContainer, onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val reloader = container.externalDataReloader
    val snackbarHostState = remember { SnackbarHostState() }

    val counts = remember { mutableStateMapOf<ExternalDataSource, Int>() }
    val enabledStates = remember { mutableStateMapOf<ExternalDataSource, Boolean>() }
    var reloadingSource by remember { mutableStateOf<ExternalDataSource?>(null) }
    var progress by remember { mutableFloatStateOf(0f) }

    val numberFormat = remember { NumberFormat.getIntegerInstance() }
    val doneMessage = stringResource(R.string.external_reload_done)
    val failedMessage = stringResource(R.string.external_reload_failed)
    val allSources = externalSourceGroups.flatMap { it.sources }

    LaunchedEffect(Unit) {
        allSources.forEach { info -> counts[info.source] = reloader.entryCount(info.source) }
        context.settingsDataStore.data
            .map { preferences -> allSources.associate { it.source to (preferences[it.settingKey] ?: false) } }
            .collect { enabledStates.putAll(it) }
    }

    fun reload(source: ExternalDataSource) {
        if (reloadingSource != null) return
        reloadingSource = source
        progress = 0f
        scope.launch {
            val result = reloader.reload(source) { progress = it }
            counts[source] = reloader.entryCount(source)
            reloadingSource = null
            if (result.isSuccess) container.notifyDataChanged()
            snackbarHostState.showSnackbar(
                result.fold(
                    onSuccess = { String.format(doneMessage, numberFormat.format(it)) },
                    onFailure = { failedMessage }
                )
            )
        }
    }

    DetailScaffold(
        title = stringResource(R.string.external_title),
        onBack = onBack,
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            externalSourceGroups.forEach { group ->
                item(key = "header_${group.headerRes}") {
                    Text(
                        text = stringResource(group.headerRes),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(top = 12.dp, start = 4.dp)
                    )
                }
                items(group.sources, key = { it.source.id }) { info ->
                    ExternalSourceCard(
                        title = info.title(),
                        count = numberFormat.format(counts[info.source] ?: 0),
                        enabled = enabledStates[info.source] ?: false,
                        isReloading = reloadingSource == info.source,
                        reloadAllowed = reloadingSource == null,
                        progress = progress,
                        onToggle = { isOn ->
                            enabledStates[info.source] = isOn
                            scope.launch { context.setSetting(info.settingKey, isOn) }
                        },
                        onReload = { reload(info.source) }
                    )
                }
                item(key = "footer_${group.headerRes}") {
                    Column(modifier = Modifier.padding(horizontal = 4.dp)) {
                        Text(
                            text = stringResource(group.footerRes),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        TextButton(
                            onClick = { context.startActivity(Intent(Intent.ACTION_VIEW, group.url.toUri())) },
                            contentPadding = PaddingValues(0.dp)
                        ) {
                            Text(stringResource(R.string.external_view_source))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ExternalSourceCard(
    title: String,
    count: String,
    enabled: Boolean,
    isReloading: Boolean,
    reloadAllowed: Boolean,
    progress: Float,
    onToggle: (Boolean) -> Unit,
    onReload: () -> Unit
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(text = title, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                Text(
                    text = count,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.width(12.dp))
                Switch(checked = enabled, onCheckedChange = onToggle)
            }
            if (enabled) {
                HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    FilledTonalButton(onClick = onReload, enabled = reloadAllowed) {
                        Text(stringResource(R.string.external_update_data))
                    }
                    Spacer(modifier = Modifier.weight(1f))
                    if (isReloading) {
                        if (progress > 0f && progress < 1f) {
                            CircularProgressIndicator(
                                progress = { progress },
                                modifier = Modifier.size(22.dp),
                                strokeWidth = 2.dp
                            )
                        } else {
                            CircularProgressIndicator(modifier = Modifier.size(22.dp), strokeWidth = 2.dp)
                        }
                    }
                }
            }
        }
    }
}
