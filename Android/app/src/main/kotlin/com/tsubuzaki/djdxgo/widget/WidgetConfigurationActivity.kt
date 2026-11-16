package com.tsubuzaki.djdxgo.widget

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.selection.selectable
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.state.getAppWidgetState
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.lifecycle.lifecycleScope
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.ui.theme.DJDXTheme
import kotlinx.coroutines.launch

private enum class ConfigurableWidget(val defaultChartStyle: WidgetChartStyle?) {
    NOTES_RADAR(null),
    CLEAR_TYPE(WidgetChartStyle.PIE),
    DJ_LEVEL(WidgetChartStyle.BAR);

    fun widget(): GlanceAppWidget = when (this) {
        NOTES_RADAR -> NotesRadarWidget()
        CLEAR_TYPE -> ClearTypeWidget()
        DJ_LEVEL -> DJLevelWidget()
    }

    companion object {
        fun fromReceiver(className: String?): ConfigurableWidget? = when (className) {
            NotesRadarWidgetReceiver::class.java.name -> NOTES_RADAR
            ClearTypeWidgetReceiver::class.java.name -> CLEAR_TYPE
            DJLevelWidgetReceiver::class.java.name -> DJ_LEVEL
            else -> null
        }
    }
}

private data class WidgetConfiguration(val chartStyle: WidgetChartStyle?, val level: Int, val showTable: Boolean)

class WidgetConfigurationActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        val appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        val result = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_CANCELED, result)
        val kind = ConfigurableWidget.fromReceiver(
            AppWidgetManager.getInstance(this).getAppWidgetInfo(appWidgetId)?.provider?.className
        )
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID || kind == null) {
            finish()
            return
        }
        lifecycleScope.launch {
            val glanceId = runCatching { GlanceAppWidgetManager(this@WidgetConfigurationActivity).getGlanceIdBy(appWidgetId) }
                .getOrNull()
            if (glanceId == null) {
                finish()
                return@launch
            }
            val preferences = getAppWidgetState(this@WidgetConfigurationActivity, PreferencesGlanceStateDefinition, glanceId)
            val initial = WidgetConfiguration(
                chartStyle = kind.defaultChartStyle?.let { WidgetChartStyle.fromValue(preferences[WidgetKeys.chartStyle], it) },
                level = preferences[WidgetKeys.level] ?: WidgetKeys.DEFAULT_LEVEL,
                showTable = preferences[WidgetKeys.showTable] ?: true
            )
            setContent {
                DJDXTheme {
                    WidgetConfigurationScreen(initial) { configuration ->
                        save(kind, glanceId, configuration, result)
                    }
                }
            }
        }
    }

    private fun save(kind: ConfigurableWidget, glanceId: GlanceId, configuration: WidgetConfiguration, result: Intent) {
        lifecycleScope.launch {
            updateAppWidgetState(this@WidgetConfigurationActivity, glanceId) { preferences ->
                configuration.chartStyle?.let { preferences[WidgetKeys.chartStyle] = it.value }
                if (kind == ConfigurableWidget.NOTES_RADAR) {
                    preferences[WidgetKeys.showTable] = configuration.showTable
                } else {
                    preferences[WidgetKeys.level] = configuration.level
                }
            }
            kind.widget().update(this@WidgetConfigurationActivity, glanceId)
            setResult(RESULT_OK, result)
            finish()
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun WidgetConfigurationScreen(initial: WidgetConfiguration, onSave: (WidgetConfiguration) -> Unit) {
    var chartStyle by remember { mutableStateOf(initial.chartStyle) }
    var level by remember { mutableIntStateOf(initial.level) }
    var showTable by remember { mutableStateOf(initial.showTable) }
    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(stringResource(R.string.widget_configure_title)) },
                actions = {
                    TextButton(onClick = { onSave(WidgetConfiguration(chartStyle, level, showTable)) }) {
                        Text(stringResource(R.string.widget_configure_done))
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(contentPadding = padding) {
            val selectedStyle = chartStyle
            if (selectedStyle == null) {
                item {
                    ListItem(
                        headlineContent = { Text(stringResource(R.string.widget_notes_radar_show_table)) },
                        trailingContent = { Switch(checked = showTable, onCheckedChange = { showTable = it }) }
                    )
                }
            } else {
                item { SectionHeader(stringResource(R.string.widget_chart_style)) }
                WidgetChartStyle.entries.forEach { style ->
                    item {
                        ListItem(
                            headlineContent = { Text(stringResource(style.labelRes)) },
                            leadingContent = { RadioButton(selected = style == selectedStyle, onClick = null) },
                            modifier = Modifier.selectable(
                                selected = style == selectedStyle,
                                role = Role.RadioButton,
                                onClick = { chartStyle = style }
                            )
                        )
                    }
                }
                item { SectionHeader(stringResource(R.string.widget_level)) }
                item {
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.padding(horizontal = 16.dp)
                    ) {
                        (1..12).forEach { value ->
                            FilterChip(
                                selected = value == level,
                                onClick = { level = value },
                                label = { Text(stringResource(R.string.widget_level_value, value)) }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 8.dp)
    )
}
