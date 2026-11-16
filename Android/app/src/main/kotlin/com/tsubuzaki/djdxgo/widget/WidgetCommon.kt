package com.tsubuzaki.djdxgo.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ColumnScope
import androidx.glance.layout.ContentScale
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import com.tsubuzaki.djdxgo.MainActivity
import com.tsubuzaki.djdxgo.R

enum class WidgetFamily { SMALL, MEDIUM, LARGE }

enum class WidgetChartStyle(val value: String, val labelRes: Int) {
    PIE("pie", R.string.widget_chart_style_pie),
    BAR("bar", R.string.widget_chart_style_bar),
    TREND("trend", R.string.widget_chart_style_trend);

    companion object {
        fun fromValue(value: String?, default: WidgetChartStyle): WidgetChartStyle =
            entries.firstOrNull { it.value == value } ?: default
    }
}

object WidgetKeys {
    val chartStyle = stringPreferencesKey("Widget.ChartStyle")
    val level = intPreferencesKey("Widget.Level")
    val showTable = booleanPreferencesKey("Widget.NotesRadar.ShowTable")

    const val DEFAULT_LEVEL = 12
}

val DpSize.widgetFamily: WidgetFamily
    get() = when {
        width < 200.dp -> WidgetFamily.SMALL
        height < 200.dp -> WidgetFamily.MEDIUM
        else -> WidgetFamily.LARGE
    }

fun DpSize.inset(padding: Float): DpSize =
    DpSize((width - (padding * 2).dp).coerceAtLeast(1.dp), (height - (padding * 2).dp).coerceAtLeast(1.dp))

val Context.widgetDensity: Float
    get() = resources.displayMetrics.density

fun openIIDXIntent(context: Context): Intent =
    Intent(Intent.ACTION_VIEW, Uri.parse("djdx://open/iidx"), context, MainActivity::class.java)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

@Composable
fun WidgetContainer(
    padding: Float = WIDGET_PADDING,
    content: @Composable ColumnScope.() -> Unit
) {
    val context = LocalContext.current
    GlanceTheme {
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .appWidgetBackground()
                .cornerRadius(16.dp)
                .background(GlanceTheme.colors.widgetBackground)
                .padding(padding.dp)
                .clickable(actionStartActivity(openIIDXIntent(context))),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalAlignment = Alignment.CenterVertically,
            content = content
        )
    }
}

@Composable
fun WidgetNoData(message: Int = R.string.analytics_no_data) {
    val context = LocalContext.current
    Box(modifier = GlanceModifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(
            text = context.getString(message),
            style = TextStyle(
                color = GlanceTheme.colors.onSurfaceVariant,
                fontSize = 12.sp,
                textAlign = TextAlign.Center
            )
        )
    }
}

@Composable
fun WidgetBitmap(bitmap: android.graphics.Bitmap, modifier: GlanceModifier = GlanceModifier.fillMaxSize()) {
    Image(
        provider = ImageProvider(bitmap),
        contentDescription = null,
        contentScale = ContentScale.Fit,
        modifier = modifier
    )
}

@Composable
fun widgetContentSize(padding: Float = WIDGET_PADDING): DpSize = LocalSize.current.inset(padding)

const val WIDGET_PADDING = 12f
