package com.tsubuzaki.djdxgo.ui.web

import android.annotation.SuppressLint
import android.content.Intent
import android.graphics.Bitmap
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.OpenInBrowser
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.net.toUri
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import com.tsubuzaki.djdxgo.R
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

private val textageCleanupScript = """
(function() {
    if (location.hostname === "textage-chart-viewer.vercel.app") {
        try { localStorage.setItem("hideWelcomeDialog", "true"); } catch (error) {}
        var style = document.createElement("style");
        style.textContent = "header { display: none !important; }";
        (document.head || document.documentElement).appendChild(style);
    }
})();
""".trimIndent()

private val sdvxInCleanupScript = """
(function() {
    var style = document.createElement('style');
    style.textContent = `
.btntop { display: none !important; }
#reload_btn, .rebtn2 { display: none !important; }
body > table.t_ > tbody > tr:nth-child(2) > td.tbg > table > tbody > tr > td:nth-child(3) > table > tbody
  > tr:nth-child(3) > td > table:nth-child(2) {
  display: none !important;
}
img[src*="/logo/"] { display: none !important; }
#closeBtn { display: none !important; }
`;
    (document.head || document.documentElement).appendChild(style);
})();
""".trimIndent()

data class WebSource(val label: String, val url: String)

@Composable
fun TextageViewerScreen(legacyURL: String?, chartViewerURL: String?, onBack: () -> Unit) {
    val sources = listOfNotNull(
        chartViewerURL?.let { WebSource(stringResource(R.string.textage_source_chart_viewer), it) },
        legacyURL?.let { WebSource(stringResource(R.string.textage_source_legacy), it) }
    ).ifEmpty { listOf(WebSource("", "https://textage.cc/")) }
    ChartWebViewScreen(
        title = stringResource(R.string.textage_viewer_title),
        sources = sources,
        cleanupScript = textageCleanupScript,
        fallbackMessage = stringResource(R.string.textage_fallback_message),
        onBack = onBack
    )
}

@Composable
fun SDVXInChartViewerScreen(legacyURL: String, viewerURL: String, dataURL: String, onBack: () -> Unit) {
    ChartWebViewScreen(
        title = stringResource(R.string.sdvx_in_viewer_title),
        sources = listOf(WebSource("", legacyURL)),
        cleanupScript = sdvxInCleanupScript,
        fallbackMessage = stringResource(R.string.sdvx_in_fallback_message),
        resolveURL = { legacy -> resolveSDVXInURL(legacy, viewerURL, dataURL) },
        onBack = onBack
    )
}

private suspend fun resolveSDVXInURL(legacyURL: String, viewerURL: String, dataURL: String): String =
    withContext(Dispatchers.IO) {
        runCatching {
            val connection = URL(dataURL).openConnection() as HttpURLConnection
            connection.requestMethod = "HEAD"
            connection.instanceFollowRedirects = false
            connection.useCaches = false
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000
            try {
                val isViewerChart = connection.responseCode == 200 &&
                    connection.contentType.orEmpty().contains("json")
                if (isViewerChart) viewerURL else legacyURL
            } finally {
                connection.disconnect()
            }
        }.getOrDefault(legacyURL)
    }

@SuppressLint("SetJavaScriptEnabled")
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ChartWebViewScreen(
    title: String,
    sources: List<WebSource>,
    cleanupScript: String,
    fallbackMessage: String,
    onBack: () -> Unit,
    resolveURL: (suspend (String) -> String)? = null
) {
    val context = LocalContext.current
    var selectedIndex by rememberSaveable { mutableIntStateOf(0) }
    var reloadCount by remember { mutableIntStateOf(0) }
    var isLoading by remember { mutableStateOf(true) }
    var isShowingFallback by remember { mutableStateOf(false) }
    var currentURL by remember { mutableStateOf(sources.first().url) }
    var webView by remember { mutableStateOf<WebView?>(null) }

    LaunchedEffect(selectedIndex, reloadCount, webView) {
        val view = webView ?: return@LaunchedEffect
        isLoading = true
        isShowingFallback = false
        view.alpha = 0f
        val source = sources[selectedIndex.coerceIn(0, sources.size - 1)].url
        currentURL = resolveURL?.invoke(source) ?: source
        view.loadUrl(currentURL)
        delay(4_000)
        if (isLoading) isShowingFallback = true
    }

    DisposableEffect(Unit) {
        onDispose { webView?.destroy() }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    if (sources.size > 1) {
                        SingleChoiceSegmentedButtonRow {
                            sources.forEachIndexed { index, source ->
                                SegmentedButton(
                                    selected = selectedIndex == index,
                                    onClick = { selectedIndex = index },
                                    shape = SegmentedButtonDefaults.itemShape(index, sources.size)
                                ) {
                                    Text(source.label, maxLines = 1)
                                }
                            }
                        }
                    } else {
                        Text(title, maxLines = 1)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.games_back)
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { reloadCount++ }) {
                        Icon(Icons.Default.Refresh, contentDescription = stringResource(R.string.shared_refresh))
                    }
                    IconButton(onClick = {
                        context.startActivity(Intent(Intent.ACTION_VIEW, currentURL.toUri()))
                    }) {
                        Icon(Icons.Default.OpenInBrowser, contentDescription = stringResource(R.string.shared_open_in_browser))
                    }
                }
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            Column(
                modifier = Modifier
                    .align(Alignment.Center)
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                if (isLoading) CircularProgressIndicator()
                if (isShowingFallback) {
                    Card(
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
                        )
                    ) {
                        Column(
                            modifier = Modifier.padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Text(text = fallbackMessage, textAlign = TextAlign.Center)
                            FilledTonalButton(onClick = {
                                context.startActivity(Intent(Intent.ACTION_VIEW, currentURL.toUri()))
                            }) {
                                Icon(Icons.Default.OpenInBrowser, contentDescription = null)
                                Text(
                                    stringResource(R.string.shared_open_in_browser),
                                    modifier = Modifier.padding(start = 8.dp)
                                )
                            }
                        }
                    }
                }
            }
            AndroidView(
                factory = { viewContext ->
                    WebView(viewContext).apply {
                        settings.javaScriptEnabled = true
                        settings.domStorageEnabled = true
                        settings.loadWithOverviewMode = true
                        settings.useWideViewPort = true
                        settings.builtInZoomControls = true
                        settings.displayZoomControls = false
                        alpha = 0f
                        val isDocumentStartSupported =
                            WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)
                        if (isDocumentStartSupported) {
                            WebViewCompat.addDocumentStartJavaScript(this, cleanupScript, setOf("*"))
                        }
                        webViewClient = object : WebViewClient() {
                            override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
                                if (!isDocumentStartSupported) view.evaluateJavascript(cleanupScript, null)
                            }

                            override fun onPageCommitVisible(view: WebView, url: String?) {
                                view.alpha = 1f
                                isLoading = false
                                isShowingFallback = false
                            }

                            override fun onPageFinished(view: WebView, url: String?) {
                                view.evaluateJavascript(cleanupScript, null)
                                view.alpha = 1f
                                isLoading = false
                                isShowingFallback = false
                            }
                        }
                        webView = this
                    }
                },
                modifier = Modifier.fillMaxSize()
            )
        }
    }
}
