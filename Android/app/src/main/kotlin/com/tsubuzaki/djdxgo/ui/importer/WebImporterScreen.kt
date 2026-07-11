package com.tsubuzaki.djdxgo.ui.importer

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.importer.ImportFailedReason
import com.tsubuzaki.djdxgo.importer.ImporterJavaScript
import com.tsubuzaki.djdxgo.importer.WebImportResult
import com.tsubuzaki.djdxgo.importer.WebImporterSpec
import java.util.UUID
import kotlin.math.min
import androidx.core.net.toUri

private enum class WebImporterPhase {
    CONNECTING,
    LOADING,
    IMPORTING,
    IDLE
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WebImporterScreen(spec: WebImporterSpec, onResult: (WebImportResult) -> Unit) {
    val currentOnResult by rememberUpdatedState(onResult)
    var phase by remember { mutableStateOf(WebImporterPhase.CONNECTING) }
    var isWebViewShown by remember { mutableStateOf(false) }
    var scrapeProgress by remember { mutableIntStateOf(0) }
    val controller = remember(spec) {
        WebImporterController(
            spec = spec,
            onPhaseChanged = { phase = it },
            onWebViewShownChanged = { isWebViewShown = it },
            onProgressChanged = { scrapeProgress = it },
            onResolved = { currentOnResult(it) }
        )
    }
    DisposableEffect(controller) {
        onDispose { controller.detach() }
    }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.import_web_title)) },
                navigationIcon = {
                    IconButton(onClick = { controller.cancel() }) {
                        Icon(
                            Icons.Filled.Close,
                            contentDescription = stringResource(R.string.import_close)
                        )
                    }
                }
            )
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            AndroidView(
                factory = { context -> WebView(context).also { controller.attach(it) } },
                modifier = Modifier.fillMaxSize()
            )
            if (!isWebViewShown) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(MaterialTheme.colorScheme.surface),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    if (scrapeProgress > 0) {
                        LinearProgressIndicator(
                            progress = { scrapeProgress / 100f },
                            modifier = Modifier.fillMaxWidth(0.6f)
                        )
                    } else {
                        LinearProgressIndicator(modifier = Modifier.fillMaxWidth(0.6f))
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = stringResource(
                            when (phase) {
                                WebImporterPhase.CONNECTING -> R.string.import_status_connecting
                                WebImporterPhase.LOADING -> R.string.import_status_loading
                                else -> R.string.import_status_importing
                            }
                        ),
                        style = MaterialTheme.typography.bodyLarge
                    )
                }
            } else if (phase == WebImporterPhase.CONNECTING || phase == WebImporterPhase.LOADING) {
                LinearProgressIndicator(
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.TopCenter)
                )
            }
        }
    }
}

private class WebImporterController(
    private val spec: WebImporterSpec,
    private val onPhaseChanged: (WebImporterPhase) -> Unit,
    private val onWebViewShownChanged: (Boolean) -> Unit,
    private val onProgressChanged: (Int) -> Unit,
    private val onResolved: (WebImportResult) -> Unit
) {
    private val handler = Handler(Looper.getMainLooper())
    private var webView: WebView? = null
    private var hasResolved = false
    private var hasStartedExtraction = false
    private var hasStartedTowerExtraction = false
    private var awaitingTower = false
    private var scorePayload: String? = null
    private var expectedToken = ""
    private var watchdog: Runnable? = null
    private var isDocumentStartScriptSupported = false

    @SuppressLint("SetJavaScriptEnabled")
    fun attach(view: WebView) {
        webView = view
        view.settings.javaScriptEnabled = true
        view.settings.domStorageEnabled = true
        view.addJavascriptInterface(Bridge(), ImporterJavaScript.BRIDGE_NAME)
        isDocumentStartScriptSupported =
            WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)
        if (isDocumentStartScriptSupported) {
            WebViewCompat.addDocumentStartJavaScript(
                view, ImporterJavaScript.loginPageDarkMode, setOf("*")
            )
            WebViewCompat.addDocumentStartJavaScript(
                view, ImporterJavaScript.otpAutofill, setOf("*")
            )
        }
        view.webViewClient = Client()
        view.alpha = 0f
        view.loadUrl(spec.startURL)
    }

    fun cancel() {
        resolve(WebImportResult.Cancelled)
    }

    fun detach() {
        watchdog?.let(handler::removeCallbacks)
        watchdog = null
        webView?.removeJavascriptInterface(ImporterJavaScript.BRIDGE_NAME)
        webView?.destroy()
        webView = null
    }

    private fun startExtraction(view: WebView, script: (String) -> String, isTower: Boolean) {
        val token = UUID.randomUUID().toString()
        expectedToken = token
        view.evaluateJavascript(script(token), null)
        startWatchdog(isTower)
    }

    private fun startWatchdog(isTower: Boolean) {
        watchdog?.let(handler::removeCallbacks)
        val runnable = Runnable {
            if (isTower) {
                resolve(WebImportResult.Success(scorePayload.orEmpty(), null))
            } else {
                resolve(WebImportResult.Failure(ImportFailedReason.SERVER_ERROR))
            }
        }
        watchdog = runnable
        handler.postDelayed(runnable, spec.watchdogSeconds * 1000L)
    }

    private fun handleExtractionResult(token: String, result: String) {
        if (hasResolved || token != expectedToken) return
        watchdog?.let(handler::removeCallbacks)
        watchdog = null
        val isError = result.startsWith("ERR:")
        if (hasStartedTowerExtraction) {
            resolve(
                WebImportResult.Success(scorePayload.orEmpty(), if (isError) null else result)
            )
            return
        }
        if (isError) {
            resolve(WebImportResult.Failure(spec.reasonForSentinel(result.removePrefix("ERR:"))))
            return
        }
        val towerChain = spec.towerChain
        if (towerChain != null) {
            scorePayload = result
            awaitingTower = true
            startWatchdog(isTower = true)
            webView?.loadUrl(towerChain.towerPageURL)
        } else {
            resolve(WebImportResult.Success(result, null))
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun hideWebView(view: WebView) {
        view.alpha = 0f
        view.setOnTouchListener { _, _ -> true }
        onWebViewShownChanged(false)
    }

    private fun showWebView(view: WebView) {
        view.alpha = 1f
        view.setOnTouchListener(null)
        onWebViewShownChanged(true)
    }

    private fun resolve(result: WebImportResult) {
        if (hasResolved) return
        hasResolved = true
        watchdog?.let(handler::removeCallbacks)
        watchdog = null
        onResolved(result)
    }

    private inner class Bridge {
        @JavascriptInterface
        fun onExtractionResult(token: String, result: String) {
            handler.post { handleExtractionResult(token, result) }
        }

        @JavascriptInterface
        fun onScrapeProgress(pages: Int) {
            handler.post { onProgressChanged(min(90, pages * 90 / 52)) }
        }
    }

    private inner class Client : WebViewClient() {
        override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
            if (!isDocumentStartScriptSupported) {
                view.evaluateJavascript(ImporterJavaScript.loginPageDarkMode, null)
                view.evaluateJavascript(ImporterJavaScript.otpAutofill, null)
            }
            if (!hasStartedExtraction) onPhaseChanged(WebImporterPhase.CONNECTING)
        }

        override fun onPageCommitVisible(view: WebView, url: String?) {
            if (!hasStartedExtraction) onPhaseChanged(WebImporterPhase.LOADING)
        }

        override fun onPageFinished(view: WebView, url: String?) {
            val pageURL = url ?: return
            view.evaluateJavascript(ImporterJavaScript.cleanupScript, null)
            val towerChain = spec.towerChain
            when {
                spec.isErrorPage(pageURL) -> {
                    val code = pageURL.toUri().getQueryParameter("err")
                    resolve(WebImportResult.Failure(spec.reasonForSentinel(code ?: "server")))
                }
                awaitingTower && towerChain != null && towerChain.isTowerPage(pageURL) -> {
                    if (!hasStartedTowerExtraction) {
                        hasStartedTowerExtraction = true
                        startExtraction(view, towerChain.extractionScript, isTower = true)
                    }
                }
                spec.isTargetPage(pageURL) && !awaitingTower -> {
                    if (!hasStartedExtraction) {
                        hasStartedExtraction = true
                        hideWebView(view)
                        onPhaseChanged(WebImporterPhase.IMPORTING)
                        startExtraction(view, spec.extractionScript, isTower = false)
                    }
                }
                !hasStartedExtraction -> {
                    showWebView(view)
                    onPhaseChanged(WebImporterPhase.IDLE)
                }
            }
        }
    }
}
