package com.tsubuzaki.djdxgo.ui.analytics

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.datastore.preferences.core.Preferences
import com.tsubuzaki.djdxgo.data.optionalSettingFlow
import com.tsubuzaki.djdxgo.data.setSetting
import kotlinx.coroutines.launch

class CardLayoutController(
    val order: List<String>,
    val visible: Set<String>,
    val collapsed: Set<String>,
    private val onOrderChange: (List<String>) -> Unit,
    private val onVisibleChange: (Set<String>) -> Unit,
    private val onCollapsedChange: (Set<String>) -> Unit
) {
    fun isVisible(id: String): Boolean = id in visible

    fun isExpanded(section: String, isEditing: Boolean): Boolean = isEditing || section !in collapsed

    fun shown(ids: List<String>, isEditing: Boolean): List<String> =
        order.filter { it in ids && (isEditing || it in visible) }

    fun toggleVisible(id: String) {
        onVisibleChange(if (id in visible) visible - id else visible + id)
    }

    fun toggleSection(section: String) {
        onCollapsedChange(if (section in collapsed) collapsed - section else collapsed + section)
    }

    fun canMove(id: String, delta: Int, sameSection: (String) -> Boolean): Boolean =
        neighbor(id, delta, sameSection) != null

    fun move(id: String, delta: Int, sameSection: (String) -> Boolean) {
        val target = neighbor(id, delta, sameSection) ?: return
        val reordered = order.toMutableList()
        val from = reordered.indexOf(id)
        val to = reordered.indexOf(target)
        reordered[from] = target
        reordered[to] = id
        onOrderChange(reordered)
    }

    private fun neighbor(id: String, delta: Int, sameSection: (String) -> Boolean): String? {
        val sectionIDs = order.filter(sameSection)
        val index = sectionIDs.indexOf(id)
        if (index < 0) return null
        return sectionIDs.getOrNull(index + delta)
    }
}

@Composable
fun rememberCardLayout(
    orderKey: Preferences.Key<String>,
    visibleKey: Preferences.Key<Set<String>>,
    collapsedKey: Preferences.Key<Set<String>>,
    defaultOrder: List<String>,
    defaultVisible: Set<String>
): CardLayoutController {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val storedOrder by remember(orderKey) { context.optionalSettingFlow(orderKey) }
        .collectAsState(initial = null)
    val storedVisible by remember(visibleKey) { context.optionalSettingFlow(visibleKey) }
        .collectAsState(initial = null)
    val storedCollapsed by remember(collapsedKey) { context.optionalSettingFlow(collapsedKey) }
        .collectAsState(initial = null)
    val order = storedOrder
        ?.split(",")
        ?.filter { it in defaultOrder }
        ?.distinct()
        ?.let { decoded -> decoded + defaultOrder.filter { it !in decoded } }
        ?.takeIf { it.isNotEmpty() }
        ?: defaultOrder
    return CardLayoutController(
        order = order,
        visible = storedVisible ?: defaultVisible,
        collapsed = storedCollapsed.orEmpty(),
        onOrderChange = { scope.launch { context.setSetting(orderKey, it.joinToString(",")) } },
        onVisibleChange = { scope.launch { context.setSetting(visibleKey, it) } },
        onCollapsedChange = { scope.launch { context.setSetting(collapsedKey, it) } }
    )
}

@Composable
internal fun AnalyticsSectionHeader(
    title: String,
    isCollapsible: Boolean,
    isExpanded: Boolean,
    onToggle: () -> Unit,
    modifier: Modifier = Modifier
) {
    val rotation by animateFloatAsState(if (isExpanded) 0f else -90f, label = "chevron")
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .clickable(enabled = isCollapsible, onClick = onToggle)
            .padding(horizontal = 16.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold
        )
        if (isCollapsible) {
            Icon(
                imageVector = Icons.Default.KeyboardArrowDown,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier
                    .size(20.dp)
                    .rotate(rotation)
            )
        }
    }
}

@Composable
internal fun EditableCard(
    isEditing: Boolean,
    isVisible: Boolean,
    onToggle: () -> Unit,
    canMoveBackward: Boolean,
    canMoveForward: Boolean,
    onMoveBackward: () -> Unit,
    onMoveForward: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    Box(modifier = modifier) {
        Box(modifier = Modifier.alpha(if (isEditing && !isVisible) 0.4f else 1f)) {
            content()
        }
        if (isEditing) {
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .clip(RoundedCornerShape(16.dp))
                    .clickable(onClick = onToggle)
            )
            if (!isVisible) {
                Icon(
                    imageVector = Icons.Default.VisibilityOff,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier
                        .align(Alignment.Center)
                        .size(28.dp)
                )
            }
            Row(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(4.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                MoveButton(Icons.AutoMirrored.Filled.KeyboardArrowLeft, canMoveBackward, onMoveBackward)
                MoveButton(Icons.AutoMirrored.Filled.KeyboardArrowRight, canMoveForward, onMoveForward)
            }
        }
    }
}

@Composable
private fun MoveButton(icon: ImageVector, enabled: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(26.dp)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.secondaryContainer.copy(alpha = if (enabled) 1f else 0.4f))
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSecondaryContainer.copy(alpha = if (enabled) 1f else 0.4f),
            modifier = Modifier.size(18.dp)
        )
    }
}

@Composable
internal fun OverviewCard(
    caption: String,
    modifier: Modifier = Modifier,
    contentHeight: Dp = 120.dp,
    onClick: (() -> Unit)?,
    content: @Composable ColumnScope.() -> Unit
) {
    val shape = RoundedCornerShape(16.dp)
    val body: @Composable ColumnScope.() -> Unit = {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(contentHeight),
                content = content
            )
            Text(
                text = caption,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.align(Alignment.CenterHorizontally)
            )
        }
    }
    if (onClick != null) {
        ElevatedCard(onClick = onClick, modifier = modifier, shape = shape, content = body)
    } else {
        ElevatedCard(modifier = modifier, shape = shape, content = body)
    }
}

@Composable
internal fun CountCard(
    count: Int,
    title: String,
    icon: ImageVector,
    iconColor: Color,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)?
) {
    val shape = RoundedCornerShape(16.dp)
    val body: @Composable ColumnScope.() -> Unit = {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = count.toString(),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Black,
                color = if (count > 0) {
                    MaterialTheme.colorScheme.onSurface
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                }
            )
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp)
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = iconColor,
                    modifier = Modifier.size(14.dp)
                )
                Text(
                    text = title,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
    if (onClick != null) {
        ElevatedCard(onClick = onClick, modifier = modifier, shape = shape, content = body)
    } else {
        ElevatedCard(modifier = modifier, shape = shape, content = body)
    }
}
