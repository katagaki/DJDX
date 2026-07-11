package com.tsubuzaki.djdxgo.ui.games

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.Sort
import androidx.compose.material.icons.outlined.ArrowDownward
import androidx.compose.material.icons.outlined.ArrowUpward
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.Card
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.ui.theme.Palette
import java.net.URLEncoder

internal val scoreGradientBrush = Brush.horizontalGradient(listOf(Palette.cyan, Palette.blue))
internal val rankGradientBrush = Brush.horizontalGradient(listOf(Palette.yellow, Palette.orange))

internal fun youTubeSearchURL(query: String): String =
    "https://www.youtube.com/results?search_query=" + URLEncoder.encode(query, "UTF-8")

internal data class SortOption(val key: String, val label: String)

@Composable
internal fun ScoreDataHeader() {
    Text(
        text = stringResource(R.string.games_score_data),
        style = MaterialTheme.typography.titleMedium,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
    )
}

@Composable
internal fun ScoreLamp(color: Color) {
    Box(
        modifier = Modifier
            .width(10.dp)
            .fillMaxHeight()
            .background(color)
    )
}

@Composable
internal fun MetadataDivider() {
    Box(
        modifier = Modifier
            .width(1.dp)
            .height(12.dp)
            .background(MaterialTheme.colorScheme.outlineVariant)
    )
}

@Composable
internal fun BrushedText(text: String, brush: Brush, style: TextStyle, maxLines: Int = 1) {
    Text(
        text = text,
        style = style.merge(TextStyle(brush = brush)),
        maxLines = maxLines,
        overflow = TextOverflow.Ellipsis
    )
}

@Composable
internal fun EmptyStateCard() {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = stringResource(R.string.games_empty_title),
                style = MaterialTheme.typography.titleMedium,
                textAlign = TextAlign.Center
            )
            Text(
                text = stringResource(R.string.games_empty_message),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )
        }
    }
}

@OptIn(
    ExperimentalMaterial3Api::class,
    androidx.compose.material3.ExperimentalMaterial3ExpressiveApi::class
)
@Composable
internal fun <T> ScoresToolbar(
    query: String,
    onQueryChange: (String) -> Unit,
    searchResults: List<T>,
    searchResultContent: @Composable (T) -> Unit,
    sortOptions: List<SortOption>,
    sortMode: String,
    sortDescending: Boolean,
    onSortChange: (String, Boolean) -> Unit,
    onFilterClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    var showSortMenu by remember { mutableStateOf(false) }
    var showSearchSheet by remember { mutableStateOf(false) }

    androidx.compose.material3.HorizontalFloatingToolbar(
        expanded = true,
        colors = androidx.compose.material3.FloatingToolbarDefaults
            .vibrantFloatingToolbarColors(),
        modifier = modifier
    ) {
        if (query.isNotEmpty()) {
            FilledIconButton(onClick = { showSearchSheet = true }) {
                Icon(
                    Icons.Outlined.Search,
                    contentDescription = stringResource(R.string.games_search_hint)
                )
            }
        } else {
            IconButton(onClick = { showSearchSheet = true }) {
                Icon(
                    Icons.Outlined.Search,
                    contentDescription = stringResource(R.string.games_search_hint)
                )
            }
        }
        Box {
            IconButton(onClick = { showSortMenu = true }) {
                Icon(
                    Icons.AutoMirrored.Outlined.Sort,
                    contentDescription = stringResource(R.string.games_sort)
                )
            }
            DropdownMenu(
                expanded = showSortMenu,
                onDismissRequest = { showSortMenu = false }
            ) {
                sortOptions.forEach { option ->
                    val selected = option.key == sortMode
                    DropdownMenuItem(
                        text = { Text(option.label) },
                        leadingIcon = {
                            if (selected) {
                                Icon(Icons.Outlined.Check, contentDescription = null)
                            }
                        },
                        trailingIcon = {
                            if (selected) {
                                Icon(
                                    if (sortDescending) {
                                        Icons.Outlined.ArrowDownward
                                    } else {
                                        Icons.Outlined.ArrowUpward
                                    },
                                    contentDescription = null
                                )
                            }
                        },
                        onClick = {
                            if (selected) {
                                onSortChange(option.key, !sortDescending)
                            } else {
                                onSortChange(option.key, sortDescending)
                            }
                        }
                    )
                }
            }
        }
        IconButton(onClick = onFilterClick) {
            Icon(
                Icons.Outlined.Tune,
                contentDescription = stringResource(R.string.games_filter)
            )
        }
    }

    if (showSearchSheet) {
        SearchSheet(
            query = query,
            onQueryChange = onQueryChange,
            results = searchResults,
            resultContent = searchResultContent,
            onDismiss = { showSearchSheet = false }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun <T> SearchSheet(
    query: String,
    onQueryChange: (String) -> Unit,
    results: List<T>,
    resultContent: @Composable (T) -> Unit,
    onDismiss: () -> Unit
) {
    val focusRequester = remember { androidx.compose.ui.focus.FocusRequester() }
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = androidx.compose.material3.rememberModalBottomSheetState(
            skipPartiallyExpanded = true
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.92f)
        ) {
            OutlinedTextField(
                value = query,
                onValueChange = onQueryChange,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .focusRequester(focusRequester),
                placeholder = { Text(stringResource(R.string.games_search_hint)) },
                leadingIcon = { Icon(Icons.Outlined.Search, contentDescription = null) },
                trailingIcon = {
                    if (query.isNotEmpty()) {
                        IconButton(onClick = { onQueryChange("") }) {
                            Icon(
                                Icons.Outlined.Close,
                                contentDescription = stringResource(R.string.games_clear_search)
                            )
                        }
                    }
                },
                singleLine = true,
                shape = MaterialTheme.shapes.extraLarge
            )
            if (query.isNotEmpty() && results.isEmpty()) {
                Text(
                    text = stringResource(R.string.games_search_no_results),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(16.dp)
                )
            }
            androidx.compose.foundation.lazy.LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .padding(top = 8.dp)
            ) {
                items(results.size) { index ->
                    resultContent(results[index])
                    HorizontalDivider()
                }
            }
        }
    }
    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun FilterSheet(
    onDismiss: () -> Unit,
    onReset: () -> Unit,
    content: @Composable ColumnScope.() -> Unit
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .padding(bottom = 24.dp)
        ) {
            content()
            TextButton(
                onClick = onReset,
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .padding(top = 12.dp)
            ) {
                Text(stringResource(R.string.games_filter_reset))
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun FilterChipGroup(
    title: String,
    options: List<Pair<String, String>>,
    selected: Set<String>,
    onToggle: (String) -> Unit,
    chipColor: ((String) -> Color)? = null
) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleSmall,
        modifier = Modifier.padding(top = 12.dp, bottom = 4.dp)
    )
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        options.forEach { (value, label) ->
            FilterChip(
                selected = value in selected,
                onClick = { onToggle(value) },
                label = {
                    Text(
                        text = label,
                        color = chipColor?.invoke(value) ?: Color.Unspecified,
                        fontWeight = FontWeight.Bold
                    )
                }
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ViewerScaffold(
    onBack: () -> Unit,
    content: @Composable (PaddingValues) -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {},
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.games_back)
                        )
                    }
                }
            )
        },
        content = content
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ViewerWithSelector(
    onBack: () -> Unit,
    selector: (@Composable () -> Unit)?,
    topBarActions: @Composable RowScope.() -> Unit = {},
    content: @Composable ColumnScope.() -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {},
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.games_back)
                        )
                    }
                },
                actions = topBarActions
            )
        }
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp)
                    .padding(bottom = if (selector != null) 104.dp else 24.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                content = content
            )
            if (selector != null) {
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .navigationBarsPadding()
                        .padding(horizontal = 20.dp, vertical = 12.dp)
                ) {
                    selector()
                }
            }
        }
    }
}

@Composable
internal fun ViewerTitle(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.headlineSmall,
        fontWeight = FontWeight.Black,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp)
    )
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3ExpressiveApi::class)
@Composable
internal fun <T> ExpressiveLevelSelector(
    items: List<T>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
    label: @Composable (T) -> Unit
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        items.forEachIndexed { index, item ->
            androidx.compose.material3.ToggleButton(
                checked = index == selectedIndex,
                onCheckedChange = { onSelect(index) },
                modifier = Modifier
                    .weight(1f)
                    .semantics { role = Role.RadioButton },
                contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 12.dp)
            ) {
                label(item)
            }
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3ExpressiveApi::class)
@Composable
internal fun <T> SegmentSwitcher(
    items: List<T>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    label: @Composable (T) -> Unit
) {
    ExpressiveLevelSelector(
        items = items,
        selectedIndex = selectedIndex,
        onSelect = onSelect,
        label = label
    )
}

@Composable
internal fun DetailCard(content: @Composable ColumnScope.() -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            content = content
        )
    }
}

@Composable
internal fun DetailRow(
    label: String,
    value: String,
    color: Color = Color.Unspecified,
    brush: Brush? = null,
    valueStyle: TextStyle? = null
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(modifier = Modifier.weight(1f))
        val style = (valueStyle ?: MaterialTheme.typography.titleMedium)
            .copy(fontWeight = FontWeight.Black)
        if (brush != null) {
            Text(text = value, style = style.merge(TextStyle(brush = brush)))
        } else {
            Text(text = value, style = style, color = color)
        }
    }
}

@Composable
internal fun RowScope.CountCell(label: String, value: String, color: Color) {
    Column(
        modifier = Modifier.weight(1f),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Black,
            color = color
        )
    }
}

@Composable
internal fun RowScope.ChartActionButton(icon: ImageVector, label: String, onClick: () -> Unit) {
    TextButton(
        onClick = onClick,
        modifier = Modifier.weight(1f)
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier.padding(vertical = 8.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(26.dp),
                tint = LocalContentColor.current
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.Center
            )
        }
    }
}
