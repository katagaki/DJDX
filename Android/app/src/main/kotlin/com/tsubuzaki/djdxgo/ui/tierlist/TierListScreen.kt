package com.tsubuzaki.djdxgo.ui.tierlist

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.widget.Toast
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.draganddrop.dragAndDropSource
import androidx.compose.foundation.draganddrop.dragAndDropTarget
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draganddrop.DragAndDropEvent
import androidx.compose.ui.draganddrop.DragAndDropTarget
import androidx.compose.ui.draganddrop.DragAndDropTransferData
import androidx.compose.ui.draganddrop.mimeTypes
import androidx.compose.ui.draganddrop.toAndroidDragEvent
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.tierlist.TierList
import com.tsubuzaki.djdxgo.data.tierlist.TierListKey
import com.tsubuzaki.djdxgo.data.tierlist.TierListShare
import com.tsubuzaki.djdxgo.data.tierlist.TierListTier
import com.tsubuzaki.djdxgo.ui.common.DetailScaffold
import com.tsubuzaki.djdxgo.ui.common.IIDXDJLevelText
import com.tsubuzaki.djdxgo.ui.common.OutlinedText
import com.tsubuzaki.djdxgo.ui.theme.GameFontWidth
import com.tsubuzaki.djdxgo.ui.theme.gameFont
import com.tsubuzaki.djdxgo.ui.theme.IIDXColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private const val CHART_MIME_TYPE = "text/plain"

private fun tierColor(tier: TierListTier): Color = when (tier) {
    TierListTier.S -> Color(0xFFFF8080)
    TierListTier.A -> Color(0xFFFFBF80)
    TierListTier.B -> Color(0xFFFFDF80)
    TierListTier.C -> Color(0xFFFFFF80)
    TierListTier.D -> Color(0xFFBFFF80)
    TierListTier.E -> Color(0xFF80FFBF)
    TierListTier.F -> Color(0xFF80BFFF)
}

@Composable
fun TierListScreen(
    container: AppContainer,
    initialGame: Game,
    initialPlayType: String,
    initialShare: TierListShare?,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val darkTheme = isSystemInDarkTheme()
    val store = container.tierListStore
    val lists by store.lists.collectAsState()

    var game by remember { mutableStateOf(initialShare?.game?.let(::gameForTierListCode) ?: initialGame) }
    var playType by remember { mutableStateOf(initialShare?.playType?.takeIf { it.isNotEmpty() } ?: initialPlayType) }
    var level by remember { mutableStateOf(initialShare?.level.orEmpty()) }
    var charts by remember { mutableStateOf<List<TierListChart>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var pendingShare by remember { mutableStateOf(initialShare) }
    var isEnteringCode by remember { mutableStateOf(false) }
    var codeEntry by remember { mutableStateOf("") }
    var isImportFailed by remember { mutableStateOf(false) }
    var isConfirmingReset by remember { mutableStateOf(false) }
    var isMenuExpanded by remember { mutableStateOf(false) }
    var searchTerm by remember { mutableStateOf("") }

    val key = TierListKey(game.tierListCode, if (game.supportsTierListPlayType) playType else "", level)
    val list = lists[key.storageKey] ?: TierList()
    val levelPrefix = "${game.tierListCode}/${key.playType}/"
    val levels = (charts.map { it.level } + lists.keys.filter { it.startsWith(levelPrefix) }
        .map { it.removePrefix(levelPrefix) })
        .distinct()
        .sortedWith(compareBy({ tierListLevelSortKey(it).first }, { it }))
    val chartsAtLevel = charts.filter { it.level == level }.associateBy { it.id }
    val term = searchTerm.trim()
    val matchesSearch: (TierListChart) -> Boolean = { term.isEmpty() || it.title.contains(term, ignoreCase = true) }
    val unplaced = chartsAtLevel.values.filter { list.tierOf(it.id) == null && matchesSearch(it) }
        .sortedBy { it.title.lowercase() }

    LaunchedEffect(game, playType, darkTheme) {
        isLoading = true
        charts = withContext(Dispatchers.IO) { loadTierListCharts(container, game, playType, darkTheme) }
        isLoading = false
    }

    LaunchedEffect(levels) {
        if (level !in levels) level = levels.lastOrNull().orEmpty()
    }

    fun place(id: String, tier: TierListTier?, beforeID: String?) {
        store.update(key) { it.placing(id, tier, beforeID) }
    }

    fun beginImport(input: String) {
        val share = TierListShare.decode(input)
        if (share == null) isImportFailed = true else pendingShare = share
    }

    fun share() {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, TierListShare.from(key, list).url)
        }
        context.startActivity(Intent.createChooser(intent, null))
    }

    fun copyCode() {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("DJDX", TierListShare.from(key, list).code))
        Toast.makeText(context, R.string.tier_list_code_copied, Toast.LENGTH_SHORT).show()
    }

    fun pasteCode(): String {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        return clipboard.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.coerceToText(context)?.toString().orEmpty()
    }

    DetailScaffold(
        title = stringResource(R.string.tier_list_title),
        onBack = onBack,
        actions = {
            Box {
                IconButton(onClick = { isMenuExpanded = true }) {
                    Icon(Icons.Default.Share, contentDescription = stringResource(R.string.tier_list_share))
                }
                DropdownMenu(expanded = isMenuExpanded, onDismissRequest = { isMenuExpanded = false }) {
                    DropdownMenuItem(
                        text = { Text(stringResource(R.string.tier_list_share_link)) },
                        enabled = !list.isEmpty,
                        onClick = { isMenuExpanded = false; share() }
                    )
                    DropdownMenuItem(
                        text = { Text(stringResource(R.string.tier_list_copy_code)) },
                        enabled = !list.isEmpty,
                        onClick = { isMenuExpanded = false; copyCode() }
                    )
                    HorizontalDivider()
                    DropdownMenuItem(
                        text = { Text(stringResource(R.string.tier_list_import_clipboard)) },
                        onClick = { isMenuExpanded = false; beginImport(pasteCode()) }
                    )
                    DropdownMenuItem(
                        text = { Text(stringResource(R.string.tier_list_enter_code)) },
                        onClick = { isMenuExpanded = false; codeEntry = ""; isEnteringCode = true }
                    )
                    HorizontalDivider()
                    DropdownMenuItem(
                        text = { Text(stringResource(R.string.tier_list_reset)) },
                        enabled = !list.isEmpty,
                        onClick = { isMenuExpanded = false; isConfirmingReset = true }
                    )
                }
            }
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                GamePicker(game = game, onSelect = { game = it })
                if (game.supportsTierListPlayType) {
                    SingleChoiceSegmentedButtonRow {
                        listOf("SP", "DP").forEachIndexed { index, value ->
                            SegmentedButton(
                                selected = playType == value,
                                onClick = { playType = value },
                                shape = SegmentedButtonDefaults.itemShape(index, 2)
                            ) { Text(value) }
                        }
                    }
                }
            }
            OutlinedTextField(
                value = searchTerm,
                onValueChange = { searchTerm = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text(stringResource(R.string.games_search_hint)) },
                leadingIcon = { Icon(Icons.Outlined.Search, contentDescription = null) },
                trailingIcon = {
                    if (searchTerm.isNotEmpty()) {
                        IconButton(onClick = { searchTerm = "" }) {
                            Icon(Icons.Outlined.Close, contentDescription = stringResource(R.string.games_clear_search))
                        }
                    }
                },
                singleLine = true
            )
            if (levels.isNotEmpty()) {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(levels) { value ->
                        FilterChip(
                            selected = level == value,
                            onClick = { level = value },
                            label = { Text("LEVEL $value", fontWeight = FontWeight.Bold) }
                        )
                    }
                }
            }
            when {
                isLoading -> Box(Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                charts.isEmpty() && list.isEmpty -> Column(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 48.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(stringResource(R.string.tier_list_no_data_title), style = MaterialTheme.typography.titleMedium)
                    Text(
                        stringResource(R.string.tier_list_no_data_message),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                else -> {
                    TierListTier.entries.forEach { tier ->
                        TierRow(
                            tier = tier,
                            charts = list.charts(tier)
                                .map { chartsAtLevel[it] ?: placeholderTierListChart(it, level, game) }
                                .filter(matchesSearch),
                            onPlace = ::place
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                    Text(
                        stringResource(R.string.tier_list_unplaced, unplaced.size),
                        style = MaterialTheme.typography.titleSmall
                    )
                    TierRow(tier = null, charts = unplaced, onPlace = ::place)
                    Text(
                        stringResource(R.string.tier_list_hint),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }

    pendingShare?.let { share ->
        val gameName = gameForTierListCode(share.game)?.shortName ?: share.game
        val description = listOf(gameName, share.playType, "LEVEL ${share.level}").filter { it.isNotEmpty() }.joinToString(" ")
        AlertDialog(
            onDismissRequest = { pendingShare = null },
            title = { Text(stringResource(R.string.tier_list_import_title)) },
            text = { Text(stringResource(R.string.tier_list_import_message, description)) },
            confirmButton = {
                TextButton(onClick = {
                    gameForTierListCode(share.game)?.let { game = it }
                    if (share.playType.isNotEmpty()) playType = share.playType
                    level = share.level
                    store.replace(share.key, TierList(share.tiers))
                    pendingShare = null
                }) { Text(stringResource(R.string.tier_list_import_replace)) }
            },
            dismissButton = {
                TextButton(onClick = { pendingShare = null }) { Text(stringResource(R.string.tier_list_cancel)) }
            }
        )
    }

    if (isEnteringCode) {
        AlertDialog(
            onDismissRequest = { isEnteringCode = false },
            title = { Text(stringResource(R.string.tier_list_enter_code)) },
            text = {
                OutlinedTextField(
                    value = codeEntry,
                    onValueChange = { codeEntry = it },
                    placeholder = { Text(stringResource(R.string.tier_list_code_placeholder)) },
                    singleLine = true
                )
            },
            confirmButton = {
                TextButton(onClick = { isEnteringCode = false; beginImport(codeEntry) }) {
                    Text(stringResource(R.string.tier_list_import))
                }
            },
            dismissButton = {
                TextButton(onClick = { isEnteringCode = false }) { Text(stringResource(R.string.tier_list_cancel)) }
            }
        )
    }

    if (isImportFailed) {
        AlertDialog(
            onDismissRequest = { isImportFailed = false },
            text = { Text(stringResource(R.string.tier_list_import_failed)) },
            confirmButton = {
                TextButton(onClick = { isImportFailed = false }) { Text(stringResource(android.R.string.ok)) }
            }
        )
    }

    if (isConfirmingReset) {
        AlertDialog(
            onDismissRequest = { isConfirmingReset = false },
            title = { Text(stringResource(R.string.tier_list_reset_title)) },
            confirmButton = {
                TextButton(onClick = {
                    isConfirmingReset = false
                    store.replace(key, TierList())
                }) { Text(stringResource(R.string.tier_list_reset_confirm)) }
            },
            dismissButton = {
                TextButton(onClick = { isConfirmingReset = false }) { Text(stringResource(R.string.tier_list_cancel)) }
            }
        )
    }
}

@Composable
private fun GamePicker(game: Game, onSelect: (Game) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        TextButton(onClick = { expanded = true }) {
            Text(game.shortName)
            Icon(Icons.Default.ArrowDropDown, contentDescription = null)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            Game.entries.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option.shortName) },
                    onClick = { expanded = false; onSelect(option) }
                )
            }
        }
    }
}

private fun chartIDs(event: DragAndDropEvent): List<String> {
    val clip = event.toAndroidDragEvent().clipData ?: return emptyList()
    return (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).text?.toString() }
}

private class ChartDropTarget(
    private val onDropIDs: (List<String>) -> Unit,
    private val onTargeted: (Boolean) -> Unit = {}
) : DragAndDropTarget {
    override fun onDrop(event: DragAndDropEvent): Boolean {
        onTargeted(false)
        val ids = chartIDs(event)
        if (ids.isEmpty()) return false
        onDropIDs(ids)
        return true
    }

    override fun onEntered(event: DragAndDropEvent) = onTargeted(true)
    override fun onExited(event: DragAndDropEvent) = onTargeted(false)
    override fun onEnded(event: DragAndDropEvent) = onTargeted(false)
}

@OptIn(ExperimentalLayoutApi::class, ExperimentalFoundationApi::class)
@Composable
private fun TierRow(
    tier: TierListTier?,
    charts: List<TierListChart>,
    onPlace: (String, TierListTier?, String?) -> Unit
) {
    var isTargeted by remember { mutableStateOf(false) }
    val rowTarget = remember(tier, onPlace) {
        ChartDropTarget({ ids -> ids.forEach { onPlace(it, tier, null) } }, { isTargeted = it })
    }
    val acceptsCharts: (DragAndDropEvent) -> Boolean = { event ->
        event.mimeTypes().contains(CHART_MIME_TYPE)
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .clip(RoundedCornerShape(8.dp))
            .background(
                if (isTargeted) MaterialTheme.colorScheme.primaryContainer
                else MaterialTheme.colorScheme.surfaceContainer
            )
            .dragAndDropTarget(shouldStartDragAndDrop = acceptsCharts, target = rowTarget)
    ) {
        if (tier != null) {
            Box(
                modifier = Modifier
                    .width(44.dp)
                    .fillMaxHeight()
                    .background(tierColor(tier)),
                contentAlignment = Alignment.Center
            ) {
                Text(tier.code, fontSize = 22.sp, fontWeight = FontWeight.Black, color = Color.Black)
            }
        }
        FlowRow(
            modifier = Modifier
                .weight(1f)
                .heightIn(min = 60.dp)
                .padding(4.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            charts.forEach { chart ->
                val tileTarget = remember(chart.id, tier, onPlace) {
                    ChartDropTarget({ ids -> ids.filter { it != chart.id }.forEach { onPlace(it, tier, chart.id) } })
                }
                TierTile(
                    chart = chart,
                    modifier = Modifier
                        .dragAndDropSource { _ ->
                            DragAndDropTransferData(ClipData.newPlainText("chart", chart.id))
                        }
                        .dragAndDropTarget(shouldStartDragAndDrop = acceptsCharts, target = tileTarget)
                )
            }
        }
    }
}

@Composable
private fun TierTile(
    chart: TierListChart,
    modifier: Modifier = Modifier
) {
    val darkTheme = isSystemInDarkTheme()
    Box(modifier = modifier) {
        Row(
            modifier = Modifier
                .width(156.dp)
                .height(IntrinsicSize.Min)
                .clip(RoundedCornerShape(6.dp))
                .background(MaterialTheme.colorScheme.surfaceContainerHighest)
                .border(1.dp, chart.lampColor.copy(alpha = 0.5f), RoundedCornerShape(6.dp))
        ) {
            Box(
                Modifier
                    .width(5.dp)
                    .fillMaxHeight()
                    .background(chart.lampColor)
            )
            val iidxLevel = chart.iidxLevel
            Column(modifier = Modifier.padding(horizontal = 6.dp, vertical = 4.dp)) {
                if (iidxLevel != null) {
                    OutlinedText(
                        text = chart.title,
                        style = MaterialTheme.typography.bodyMedium.gameFont(GameFontWidth.COMPRESSED),
                        fontWeight = FontWeight.Black,
                        fill = IIDXColors.rowTitleBrush(chart.songVersion, iidxLevel, darkTheme),
                        outline = IIDXColors.rowTitleStrokeColor(chart.songVersion, iidxLevel, darkTheme),
                        outlineWidth = if (darkTheme) 0.35.dp else 0.5.dp,
                        squashed = true
                    )
                } else {
                    Text(
                        chart.title,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    TierLevelLabel(chart = chart, darkTheme = darkTheme, modifier = Modifier.weight(1f))
                    if (chart.grade.isNotEmpty()) {
                        if (iidxLevel != null) {
                            IIDXDJLevelText(djLevel = chart.grade, style = MaterialTheme.typography.labelMedium)
                        } else {
                            Text(
                                chart.grade,
                                color = chart.gradeColor,
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.Black,
                                maxLines = 1
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TierLevelLabel(chart: TierListChart, darkTheme: Boolean, modifier: Modifier = Modifier) {
    val baseColor = chart.iidxLevel?.let { IIDXColors.levelColor(it) } ?: chart.difficultyColor
    val color = if (darkTheme) lerp(Color.White, baseColor, 0.2f) else baseColor
    val glow = if (darkTheme) Shadow(color = baseColor, blurRadius = 12f) else null
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            text = chart.level,
            color = color,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            fontStyle = FontStyle.Italic,
            style = MaterialTheme.typography.titleMedium.copy(shadow = glow),
            maxLines = 1
        )
        Text(
            text = chart.iidxLevel?.name ?: chart.difficultyLabel,
            color = color,
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            style = MaterialTheme.typography.labelSmall.copy(shadow = glow),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}
