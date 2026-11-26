package com.tsubuzaki.djdxgo.ui.more

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.PackageManager
import android.util.Size
import android.view.WindowManager
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.QueueMusic
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.transfer.ChartCodec
import com.tsubuzaki.djdxgo.transfer.ChartDecoder
import com.tsubuzaki.djdxgo.transfer.ChartFrame
import com.tsubuzaki.djdxgo.transfer.ChartPlayfield.drawChart
import com.tsubuzaki.djdxgo.transfer.ChartReceiveState
import com.tsubuzaki.djdxgo.transfer.LampIdentity
import com.tsubuzaki.djdxgo.transfer.LampKeyStore
import com.tsubuzaki.djdxgo.ui.common.DetailScaffold
import java.util.concurrent.Executors
import kotlinx.coroutines.delay

private enum class TransferMode { OVERVIEW, SENDING, RECEIVING }

@Composable
fun LampTransferScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    var identity by remember { mutableStateOf(LampKeyStore.load(context)) }
    var mode by remember { mutableStateOf(TransferMode.OVERVIEW) }
    var received by remember { mutableStateOf<Pair<LampIdentity, String>?>(null) }
    var isReceivedInvalid by remember { mutableStateOf(false) }

    BackHandler(enabled = mode != TransferMode.OVERVIEW) { mode = TransferMode.OVERVIEW }

    when (mode) {
        TransferMode.SENDING -> identity?.let { ChartSender(it.transferMessage) { mode = TransferMode.OVERVIEW } }
        TransferMode.RECEIVING -> ChartReceiver(
            onReceived = { message ->
                mode = TransferMode.OVERVIEW
                val newIdentity = LampIdentity.fromTransferMessage(message)
                if (newIdentity == null) {
                    isReceivedInvalid = true
                } else {
                    received = newIdentity to ChartCodec.pairingNumber(message)
                }
            },
            onClose = { mode = TransferMode.OVERVIEW }
        )
        TransferMode.OVERVIEW -> DetailScaffold(title = stringResource(R.string.lamp_title), onBack = onBack) { padding ->
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                item { SectionHeader(stringResource(R.string.lamp_this_device)) }
                item {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            val current = identity
                            if (current != null) {
                                SelectionContainer {
                                    Column {
                                        LabeledValue(stringResource(R.string.lamp_contributor_id), current.contributorId)
                                        HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp))
                                        LabeledValue(stringResource(R.string.lamp_deletion_code), current.deletionCode)
                                    }
                                }
                            } else {
                                Text(
                                    stringResource(R.string.lamp_no_identity),
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                FilledTonalButton(
                                    onClick = {
                                        val newIdentity = LampIdentity.generate()
                                        if (LampKeyStore.save(context, newIdentity)) identity = newIdentity
                                    },
                                    modifier = Modifier.padding(top = 12.dp)
                                ) { Text(stringResource(R.string.lamp_create_identity)) }
                            }
                        }
                    }
                }
                item { SectionFooter(stringResource(R.string.lamp_identity_footer)) }
                item { SectionHeader(stringResource(R.string.lamp_transfer_header)) }
                item {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(
                                onClick = { mode = TransferMode.SENDING },
                                enabled = identity != null,
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Icon(Icons.AutoMirrored.Outlined.QueueMusic, contentDescription = null)
                                Text(stringResource(R.string.lamp_send), modifier = Modifier.padding(start = 8.dp))
                            }
                            FilledTonalButton(onClick = { mode = TransferMode.RECEIVING }, modifier = Modifier.fillMaxWidth()) {
                                Icon(Icons.Outlined.CameraAlt, contentDescription = null)
                                Text(stringResource(R.string.lamp_receive), modifier = Modifier.padding(start = 8.dp))
                            }
                        }
                    }
                }
                item { SectionFooter(stringResource(R.string.lamp_transfer_footer)) }
            }
        }
    }

    received?.let { (newIdentity, pairing) ->
        val replacing = identity != null && identity != newIdentity
        AlertDialog(
            onDismissRequest = { received = null },
            title = { Text(stringResource(R.string.lamp_received_title)) },
            text = {
                Text(
                    stringResource(R.string.lamp_received_message, pairing, newIdentity.contributorId) +
                        if (replacing) "\n\n" + stringResource(R.string.lamp_received_replace) else ""
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    if (LampKeyStore.save(context, newIdentity)) identity = newIdentity
                    received = null
                }) {
                    Text(
                        stringResource(R.string.lamp_received_use),
                        color = if (replacing) MaterialTheme.colorScheme.error else Color.Unspecified
                    )
                }
            },
            dismissButton = { TextButton(onClick = { received = null }) { Text(stringResource(android.R.string.cancel)) } }
        )
    }
    if (isReceivedInvalid) {
        AlertDialog(
            onDismissRequest = { isReceivedInvalid = false },
            title = { Text(stringResource(R.string.lamp_receive_invalid)) },
            confirmButton = { TextButton(onClick = { isReceivedInvalid = false }) { Text(stringResource(android.R.string.ok)) } }
        )
    }
}

@Composable
private fun SectionHeader(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.Bold,
        modifier = Modifier.padding(top = 12.dp, start = 4.dp)
    )
}

@Composable
private fun SectionFooter(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 4.dp)
    )
}

@Composable
private fun LabeledValue(label: String, value: String) {
    Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    Text(value, style = MaterialTheme.typography.bodyLarge, fontFamily = FontFamily.Monospace)
}

private fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

@Composable
private fun ImmersiveEffect(brighten: Boolean) {
    val view = LocalView.current
    val activity = LocalContext.current.findActivity()
    DisposableEffect(activity) {
        val window = activity?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        val previousBrightness = window?.attributes?.screenBrightness
        view.keepScreenOn = true
        controller?.hide(WindowInsetsCompat.Type.systemBars())
        if (brighten && window != null) {
            window.attributes = window.attributes.apply { screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_FULL }
        }
        onDispose {
            view.keepScreenOn = false
            controller?.show(WindowInsetsCompat.Type.systemBars())
            if (brighten && window != null && previousBrightness != null) {
                window.attributes = window.attributes.apply { screenBrightness = previousBrightness }
            }
        }
    }
}

@Composable
private fun CloseButton(onClose: () -> Unit, modifier: Modifier = Modifier) {
    FilledTonalIconButton(onClick = onClose, modifier = modifier.safeDrawingPadding().padding(12.dp)) {
        Icon(Icons.Default.Close, contentDescription = stringResource(android.R.string.cancel))
    }
}

@Composable
private fun ChartSender(message: ByteArray, onClose: () -> Unit) {
    val bits = remember(message) { ChartCodec.chart(message) ?: BooleanArray(0) }
    val pairing = remember(message) { ChartCodec.pairingNumber(message) }
    var time by remember { mutableDoubleStateOf(0.0) }
    ImmersiveEffect(brighten = true)
    LaunchedEffect(Unit) {
        val start = withFrameNanos { it }
        while (true) withFrameNanos { time = (it - start) / 1e9 }
    }
    Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
        Canvas(modifier = Modifier.fillMaxSize()) { drawChart(bits, time) }
        Row(
            modifier = Modifier.align(Alignment.BottomStart).fillMaxWidth().safeDrawingPadding().padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            FilledTonalIconButton(onClick = onClose) {
                Icon(Icons.Default.Close, contentDescription = stringResource(android.R.string.cancel))
            }
            Column {
                Text(
                    stringResource(R.string.lamp_pairing_number, pairing),
                    color = Color.White,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    stringResource(R.string.lamp_send_hint),
                    color = Color.White.copy(alpha = 0.7f),
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
    }
}

@Composable
private fun ChartReceiver(onReceived: (ByteArray) -> Unit, onClose: () -> Unit) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val currentOnReceived by rememberUpdatedState(onReceived)
    var hasPermission by remember {
        mutableStateOf(ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED)
    }
    var isDenied by remember { mutableStateOf(false) }
    var state by remember { mutableStateOf(ChartReceiveState()) }
    var flash by remember { mutableStateOf(0) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        hasPermission = granted
        isDenied = !granted
    }
    val previewView = remember { PreviewView(context).apply { scaleType = PreviewView.ScaleType.FILL_CENTER } }

    ImmersiveEffect(brighten = false)
    LaunchedEffect(Unit) { if (!hasPermission) launcher.launch(Manifest.permission.CAMERA) }

    DisposableEffect(hasPermission) {
        if (!hasPermission) return@DisposableEffect onDispose {}
        val executor = Executors.newSingleThreadExecutor()
        val mainExecutor = ContextCompat.getMainExecutor(context)
        val decoder = ChartDecoder()
        var delivered = false
        val providerFuture = ProcessCameraProvider.getInstance(context)
        var provider: ProcessCameraProvider? = null
        providerFuture.addListener({
            val cameraProvider = providerFuture.get().also { provider = it }
            val preview = Preview.Builder().build().also { it.setSurfaceProvider(previewView.surfaceProvider) }
            val analysis = ImageAnalysis.Builder()
                .setResolutionSelector(
                    ResolutionSelector.Builder()
                        .setResolutionStrategy(
                            ResolutionStrategy(Size(1280, 720), ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER)
                        )
                        .build()
                )
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
            analysis.setAnalyzer(executor) { image ->
                val time = image.imageInfo.timestamp / 1e9
                val frame = image.use { chartFrame(it) }
                val newState = decoder.process(frame, time)
                mainExecutor.execute {
                    if (newState.receivedBlocks.size > state.receivedBlocks.size) flash++
                    state = newState
                    val message = newState.message
                    if (message != null && !delivered) {
                        delivered = true
                        currentOnReceived(message)
                    }
                }
            }
            cameraProvider.unbindAll()
            cameraProvider.bindToLifecycle(lifecycleOwner, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
        }, mainExecutor)
        onDispose {
            provider?.unbindAll()
            executor.shutdown()
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
        if (hasPermission) {
            AndroidView(factory = { previewView }, modifier = Modifier.fillMaxSize())
            Canvas(modifier = Modifier.fillMaxSize()) {
                val corners = state.corners ?: return@Canvas
                if (state.frameWidth == 0) return@Canvas
                val scale = maxOf(size.width / state.frameWidth, size.height / state.frameHeight)
                val dx = (size.width - state.frameWidth * scale) / 2
                val dy = (size.height - state.frameHeight * scale) / 2
                val points = corners.map { Offset(it.first * scale + dx, it.second * scale + dy) }
                val path = Path().apply {
                    moveTo(points[0].x, points[0].y)
                    points.drop(1).forEach { lineTo(it.x, it.y) }
                    close()
                }
                drawPath(path, Color.Yellow, style = Stroke(width = 2.dp.toPx()))
                points.forEach { drawCircle(Color.Yellow, 10.dp.toPx(), it, style = Stroke(width = 2.dp.toPx())) }
            }
        } else if (isDenied) {
            Text(
                stringResource(R.string.lamp_receive_camera_denied),
                color = Color.White,
                textAlign = TextAlign.Center,
                modifier = Modifier.align(Alignment.Center).padding(32.dp)
            )
        }
        ReceiverStatus(state, Modifier.align(Alignment.TopCenter))
        if (flash > 0) JudgementFlash(flash, Modifier.align(Alignment.Center))
        CloseButton(onClose, Modifier.align(Alignment.TopEnd))
    }
}

@Composable
private fun ReceiverStatus(state: ChartReceiveState, modifier: Modifier) {
    Column(
        modifier = modifier
            .safeDrawingPadding()
            .padding(top = 12.dp, start = 72.dp, end = 72.dp)
            .background(Color.Black.copy(alpha = 0.55f), RoundedCornerShape(20.dp))
            .padding(horizontal = 16.dp, vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        val status = when {
            state.corners != null -> stringResource(R.string.lamp_receive_reading)
            state.hasLocked -> stringResource(R.string.lamp_receive_reacquiring)
            else -> stringResource(R.string.lamp_receive_searching)
        }
        Text(
            status,
            color = if (state.corners != null) Color.Yellow else Color.White,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold
        )
        val count = state.blockCount
        if (count != null) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                repeat(count) { index ->
                    Box(
                        modifier = Modifier
                            .width(22.dp)
                            .size(width = 22.dp, height = 6.dp)
                            .background(
                                if (index in state.receivedBlocks) Color.Yellow else Color.White.copy(alpha = 0.3f),
                                RoundedCornerShape(3.dp)
                            )
                    )
                }
            }
            Text(
                stringResource(R.string.lamp_receive_blocks, state.receivedBlocks.size, count),
                color = Color.White,
                style = MaterialTheme.typography.labelSmall
            )
        } else {
            Text(
                stringResource(R.string.lamp_receive_hint),
                color = Color.White,
                style = MaterialTheme.typography.labelSmall,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun JudgementFlash(key: Int, modifier: Modifier) {
    var visible by remember(key) { mutableStateOf(true) }
    LaunchedEffect(key) {
        delay(700)
        visible = false
    }
    if (visible) {
        Text(
            "PGREAT",
            modifier = modifier,
            color = Color(0xFFFFD54F),
            fontSize = 44.sp,
            fontWeight = FontWeight.Black,
            fontStyle = FontStyle.Italic
        )
    }
}

private fun chartFrame(image: ImageProxy): ChartFrame {
    val plane = image.planes[0]
    val buffer = plane.buffer
    val rowStride = plane.rowStride
    val pixelStride = plane.pixelStride
    val bytes = ByteArray(buffer.remaining()).also { buffer.get(it) }
    val width = image.width
    val height = image.height
    val rotation = image.imageInfo.rotationDegrees
    val rotatedWidth = if (rotation % 180 == 0) width else height
    val rotatedHeight = if (rotation % 180 == 0) height else width
    val factor = maxOf(1, minOf(rotatedWidth, rotatedHeight) / 360)
    val outWidth = rotatedWidth / factor
    val outHeight = rotatedHeight / factor
    val luma = FloatArray(outWidth * outHeight)
    val green = FloatArray(outWidth * outHeight)
    val norm = 1f / (255f * factor * factor)
    for (oy in 0 until outHeight) {
        for (ox in 0 until outWidth) {
            var r = 0
            var g = 0
            var b = 0
            for (sy in 0 until factor) {
                for (sx in 0 until factor) {
                    val rx = ox * factor + sx
                    val ry = oy * factor + sy
                    val x: Int
                    val y: Int
                    when (rotation) {
                        90 -> { x = ry; y = height - 1 - rx }
                        180 -> { x = width - 1 - rx; y = height - 1 - ry }
                        270 -> { x = width - 1 - ry; y = rx }
                        else -> { x = rx; y = ry }
                    }
                    val i = y * rowStride + x * pixelStride
                    r += bytes[i].toInt() and 0xFF
                    g += bytes[i + 1].toInt() and 0xFF
                    b += bytes[i + 2].toInt() and 0xFF
                }
            }
            val fr = r * norm
            val fg = g * norm
            val fb = b * norm
            val index = oy * outWidth + ox
            luma[index] = maxOf(fr, fg, fb)
            green[index] = if (fg > 0.3f) fg - maxOf(fr, fb) else 0f
        }
    }
    return ChartFrame(outWidth, outHeight, luma, green)
}
