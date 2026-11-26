package com.tsubuzaki.djdxgo.ui.share

import com.tsubuzaki.djdxgo.ui.iidx.rememberSetting
import com.tsubuzaki.djdxgo.data.setSetting
import com.tsubuzaki.djdxgo.data.SettingsKeys
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.gestures.drag
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.shape.CircleShape
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AddPhotoAlternate
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.ui.gameIconRes
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private val rowLimits = listOf(10, 20, 30, 50)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShareCardSheet(
    game: Game,
    profile: ShareCardProfile,
    entries: List<ShareCardEntry>,
    playStyle: String? = null,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val accentColor = MaterialTheme.colorScheme.primary
    val graphicsLayer = rememberGraphicsLayer()
    val colorLabel = stringResource(R.string.share_card_color)

    var background by remember { mutableStateOf<ShareCardBackground>(ShareCardBackground.Gradient(ShareCardGradient.ACCENT)) }
    var photo by remember { mutableStateOf<ImageBitmap?>(null) }
    var isProfileVisible by rememberSaveable { mutableStateOf(true) }
    var rowLimit by rememberSaveable { mutableIntStateOf(10) }
    val customColorValue by rememberSetting(SettingsKeys.shareCardCustomColor, 0x7A4DFF)
    val customColor = Color(0xFF000000.toInt() or customColorValue)

    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            val bitmap = withContext(Dispatchers.IO) { decodeSampledBitmap(context, uri) }
            if (bitmap != null) {
                photo = bitmap.asImageBitmap()
                background = ShareCardBackground.Photo
            }
        }
    }

    fun share() {
        scope.launch {
            val uri = runCatching {
                val bitmap = graphicsLayer.toImageBitmap().asAndroidBitmap()
                withContext(Dispatchers.IO) {
                    val directory = File(context.cacheDir, "exports").apply { mkdirs() }
                    val file = File(directory, "Scores-${System.currentTimeMillis() / 1000}.png")
                    file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                    FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
                }
            }.getOrNull()
            if (uri == null) {
                Toast.makeText(context, context.getString(R.string.share_card_failed), Toast.LENGTH_SHORT).show()
                return@launch
            }
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(Intent.createChooser(intent, null))
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .navigationBarsPadding()
                .padding(bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = stringResource(R.string.share_card_title),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f)
                )
                FilledTonalButton(onClick = { share() }) {
                    Icon(Icons.Outlined.Share, contentDescription = null)
                    Spacer(modifier = Modifier.size(8.dp))
                    Text(stringResource(R.string.share_card_share))
                }
            }
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                ShareCard(
                    title = game.displayName,
                    iconRes = gameIconRes(game),
                    profile = if (isProfileVisible) profile else null,
                    entries = entries.take(rowLimit),
                    totalCount = entries.size,
                    playStyle = playStyle,
                    background = background,
                    photo = photo,
                    accentColor = accentColor,
                    customColor = customColor,
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .drawWithContent {
                            graphicsLayer.record { this@drawWithContent.drawContent() }
                            drawLayer(graphicsLayer)
                        }
                )
            }
            Text(
                text = stringResource(R.string.share_card_background),
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(ShareCardGradient.entries) { gradient ->
                    val option = ShareCardBackground.Gradient(gradient)
                    Swatch(isSelected = background == option, onClick = { background = option }) {
                        Box(
                            modifier = Modifier
                                .size(52.dp)
                                .background(Brush.linearGradient(gradient.colors(accentColor)))
                        )
                    }
                }
                item {
                    Swatch(
                        isSelected = background == ShareCardBackground.Custom,
                        onClick = { background = ShareCardBackground.Custom }
                    ) {
                        Box(
                            modifier = Modifier
                                .size(52.dp)
                                .background(Brush.sweepGradient(hueColors)),
                            contentAlignment = Alignment.Center
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(22.dp)
                                    .clip(CircleShape)
                                    .background(Color.White)
                                    .padding(2.dp)
                                    .clip(CircleShape)
                                    .background(customColor)
                                    .semantics { contentDescription = colorLabel }
                            )
                        }
                    }
                }
                item {
                    Swatch(
                        isSelected = background == ShareCardBackground.Photo,
                        onClick = {
                            if (photo != null && background != ShareCardBackground.Photo) {
                                background = ShareCardBackground.Photo
                            } else {
                                photoPicker.launch(
                                    PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                                )
                            }
                        }
                    ) {
                        Box(
                            modifier = Modifier
                                .size(52.dp)
                                .background(MaterialTheme.colorScheme.surfaceContainerHighest),
                            contentAlignment = Alignment.Center
                        ) {
                            photo?.let {
                                Image(
                                    bitmap = it,
                                    contentDescription = null,
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier.size(52.dp)
                                )
                            }
                            Icon(
                                Icons.Outlined.AddPhotoAlternate,
                                contentDescription = stringResource(R.string.share_card_photo),
                                tint = if (photo != null) Color.White else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
            if (background == ShareCardBackground.Custom) {
                ShareCardColorPicker(
                    color = customColor,
                    onColorChange = { color ->
                        scope.launch { context.setSetting(SettingsKeys.shareCardCustomColor, color.toArgb() and 0xFFFFFF) }
                    },
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }
            if (!profile.isEmpty) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = stringResource(R.string.share_card_show_profile),
                        style = MaterialTheme.typography.bodyLarge,
                        modifier = Modifier.weight(1f)
                    )
                    Switch(checked = isProfileVisible, onCheckedChange = { isProfileVisible = it })
                }
            }
            Column(
                modifier = Modifier.padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = stringResource(R.string.share_card_row_limit),
                    style = MaterialTheme.typography.bodyLarge
                )
                SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                    rowLimits.forEachIndexed { index, limit ->
                        SegmentedButton(
                            selected = rowLimit == limit,
                            onClick = { rowLimit = limit },
                            shape = SegmentedButtonDefaults.itemShape(index, rowLimits.size)
                        ) {
                            Text(limit.toString())
                        }
                    }
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

@Composable
private fun Swatch(isSelected: Boolean, onClick: () -> Unit, content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .border(
                width = 3.dp,
                color = if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent,
                shape = RoundedCornerShape(15.dp)
            )
            .padding(4.dp)
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
    ) {
        content()
    }
}

private fun decodeSampledBitmap(context: Context, uri: Uri, maxDimension: Int = 2048): Bitmap? = runCatching {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
    var sampleSize = 1
    while (maxOf(bounds.outWidth, bounds.outHeight) / (sampleSize * 2) >= maxDimension) {
        sampleSize *= 2
    }
    val options = BitmapFactory.Options().apply { inSampleSize = sampleSize }
    context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
}.getOrNull()

private val hueColors = listOf(Color.Red, Color.Yellow, Color.Green, Color.Cyan, Color.Blue, Color.Magenta, Color.Red)

@Composable
private fun ShareCardColorPicker(color: Color, onColorChange: (Color) -> Unit, modifier: Modifier = Modifier) {
    val hsv = remember(color) { FloatArray(3).also { android.graphics.Color.colorToHSV(color.toArgb(), it) } }
    fun update(hue: Float = hsv[0], saturation: Float = hsv[1], value: Float = hsv[2]) {
        onColorChange(Color(android.graphics.Color.HSVToColor(floatArrayOf(hue, saturation, value))))
    }
    val hueColor = Color(android.graphics.Color.HSVToColor(floatArrayOf(hsv[0], 1f, 1f)))
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(text = stringResource(R.string.share_card_color), style = MaterialTheme.typography.bodyLarge)
        GradientSlider(hsv[0] / 360f, Brush.horizontalGradient(hueColors)) { update(hue = it * 360f) }
        GradientSlider(hsv[1], Brush.horizontalGradient(listOf(Color.White, hueColor))) { update(saturation = it) }
        GradientSlider(hsv[2], Brush.horizontalGradient(listOf(Color.Black, hueColor))) { update(value = it) }
    }
}

@Composable
private fun GradientSlider(value: Float, brush: Brush, onValueChange: (Float) -> Unit) {
    val currentOnValueChange by rememberUpdatedState(onValueChange)
    BoxWithConstraints(
        modifier = Modifier
            .fillMaxWidth()
            .height(28.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(brush)
            .pointerInput(Unit) {
                awaitEachGesture {
                    val down = awaitFirstDown()
                    currentOnValueChange((down.position.x / size.width).coerceIn(0f, 1f))
                    drag(down.id) { change ->
                        change.consume()
                        currentOnValueChange((change.position.x / size.width).coerceIn(0f, 1f))
                    }
                }
            }
    ) {
        val thumbSize = 24.dp
        Box(
            modifier = Modifier
                .offset(x = (maxWidth - thumbSize - 4.dp) * value + 2.dp)
                .align(Alignment.CenterStart)
                .size(thumbSize)
                .border(3.dp, Color.White, CircleShape)
        )
    }
}
