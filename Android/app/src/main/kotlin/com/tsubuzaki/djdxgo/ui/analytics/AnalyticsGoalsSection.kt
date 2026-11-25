package com.tsubuzaki.djdxgo.ui.analytics

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.analytics.AnalyticsGoal
import com.tsubuzaki.djdxgo.data.analytics.AnalyticsGoalKind
import com.tsubuzaki.djdxgo.data.analytics.AnalyticsGoalProgress
import com.tsubuzaki.djdxgo.data.analytics.AnalyticsGoalStatus
import com.tsubuzaki.djdxgo.data.analytics.AnalyticsGoalStore
import com.tsubuzaki.djdxgo.data.ddr.DDRPlayStyle
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.setSetting
import com.tsubuzaki.djdxgo.ui.Routes
import com.tsubuzaki.djdxgo.ui.iidx.rememberSetting
import com.tsubuzaki.djdxgo.ui.theme.Palette
import com.tsubuzaki.djdxgo.ui.theme.gameFont
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import kotlinx.coroutines.launch

@Composable
fun AnalyticsGoalsSection(
    container: AppContainer,
    game: Game,
    playStyle: String,
    onNavigate: (String) -> Unit
) {
    if (AnalyticsGoalKind.available(game).isEmpty()) return
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val isCollapsed by rememberSetting(SettingsKeys.analyticsGoalsCollapsed, false)
    val goals by remember { AnalyticsGoalStore.goalsFlow(context) }.collectAsState(initial = emptyList())
    val dataVersion by container.dataVersion.collectAsState()
    val gameGoals = goals.filter { it.gameEnum == game }
    val progresses by produceState(emptyList<AnalyticsGoalProgress>(), gameGoals, dataVersion) {
        value = container.goalEvaluator.progress(gameGoals).sortedBy { it.goal.deadline }
    }
    var isAddingGoal by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier.padding(top = 20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            AnalyticsSectionHeader(
                title = stringResource(R.string.goals_title),
                isCollapsible = true,
                isExpanded = !isCollapsed,
                onToggle = { scope.launch { context.setSetting(SettingsKeys.analyticsGoalsCollapsed, !isCollapsed) } },
                modifier = Modifier.weight(1f)
            )
            IconButton(onClick = { isAddingGoal = true }, modifier = Modifier.padding(end = 8.dp)) {
                Icon(Icons.Default.Add, contentDescription = stringResource(R.string.goals_add))
            }
        }
        if (!isCollapsed) {
            Column(
                modifier = Modifier.padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (gameGoals.isEmpty()) {
                    EmptyGoalCard(onClick = { isAddingGoal = true })
                }
                progresses.forEach { progress ->
                    AnalyticsGoalCard(progress) { onNavigate(Routes.goalDetail(progress.goal.id)) }
                }
            }
        }
    }

    if (isAddingGoal) {
        AnalyticsGoalEditorDialog(
            game = game,
            goal = null,
            defaultPlayStyle = playStyle,
            onDismiss = { isAddingGoal = false },
            onSave = { goal ->
                isAddingGoal = false
                scope.launch { AnalyticsGoalStore.upsert(context, goal) }
            }
        )
    }
}

@Composable
private fun EmptyGoalCard(onClick: () -> Unit) {
    ElevatedCard(onClick = onClick, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(Icons.Outlined.Flag, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Text(
                text = stringResource(R.string.goals_empty_title),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = stringResource(R.string.goals_empty_message),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

private val shortDateFormatter: DateTimeFormatter = DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)
private val longDateFormatter: DateTimeFormatter = DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG)

private fun Long.toLocalDate(): LocalDate = Instant.ofEpochSecond(this).atZone(ZoneId.systemDefault()).toLocalDate()

private fun AnalyticsGoalStatus.color(): Color = when (this) {
    AnalyticsGoalStatus.ACHIEVED -> Palette.yellow
    AnalyticsGoalStatus.AHEAD -> Palette.green
    AnalyticsGoalStatus.ON_PACE -> Palette.blue
    AnalyticsGoalStatus.BEHIND -> Palette.orange
    AnalyticsGoalStatus.MISSED -> Palette.red
}

@Composable
private fun AnalyticsGoalStatus.label(): String = stringResource(
    when (this) {
        AnalyticsGoalStatus.ACHIEVED -> R.string.goals_status_achieved
        AnalyticsGoalStatus.AHEAD -> R.string.goals_status_ahead
        AnalyticsGoalStatus.ON_PACE -> R.string.goals_status_on_pace
        AnalyticsGoalStatus.BEHIND -> R.string.goals_status_behind
        AnalyticsGoalStatus.MISSED -> R.string.goals_status_missed
    }
)

@Composable
private fun StatusBadge(status: AnalyticsGoalStatus) {
    val color = status.color()
    Text(
        text = status.label(),
        style = MaterialTheme.typography.labelSmall.gameFont(),
        fontWeight = FontWeight.ExtraBold,
        color = color,
        maxLines = 1,
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(color.copy(alpha = 0.15f))
            .padding(horizontal = 8.dp, vertical = 3.dp)
    )
}

@Composable
private fun GoalProgressBar(progress: Double, pace: Double, color: Color) {
    val trackColor = MaterialTheme.colorScheme.surfaceVariant
    val markerColor = MaterialTheme.colorScheme.onSurface
    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(14.dp)
    ) {
        val barHeight = 8.dp.toPx()
        val y = size.height / 2f
        drawLine(trackColor, Offset(barHeight / 2f, y), Offset(size.width - barHeight / 2f, y), barHeight, StrokeCap.Round)
        if (progress > 0) {
            val end = (size.width * progress.toFloat()).coerceAtLeast(barHeight)
            drawLine(color, Offset(barHeight / 2f, y), Offset(end - barHeight / 2f, y), barHeight, StrokeCap.Round)
        }
        val x = (size.width * pace.toFloat()).coerceIn(1f, size.width - 1f)
        drawLine(markerColor, Offset(x, 0f), Offset(x, size.height), 2.dp.toPx())
    }
}

@Composable
private fun AnalyticsGoalCard(progress: AnalyticsGoalProgress, onClick: () -> Unit) {
    val goal = progress.goal
    ElevatedCard(onClick = onClick, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                AnalyticsGoalTitle(
                    goal = goal,
                    style = MaterialTheme.typography.labelLarge,
                    modifier = Modifier.weight(1f, fill = false)
                )
                Spacer(modifier = Modifier.weight(1f))
                StatusBadge(progress.status)
            }
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = goal.formatted(progress.current),
                    style = MaterialTheme.typography.headlineSmall.gameFont(),
                    fontWeight = FontWeight.Black
                )
                Text(
                    text = "/ ${goal.formatted(goal.target)}",
                    style = MaterialTheme.typography.bodyMedium.gameFont(),
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 2.dp)
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = stringResource(R.string.goals_days_left, progress.daysLeft),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 2.dp)
                )
            }
            GoalProgressBar(progress.progressFraction, progress.timeFraction, progress.status.color())
            Row {
                Text(
                    text = stringResource(R.string.goals_pace, goal.formatted(progress.expected)),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f)
                )
                Text(
                    text = stringResource(R.string.goals_due, goal.deadline.toLocalDate().format(shortDateFormatter)),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun <T> GoalDropdownRow(
    label: String,
    options: List<T>,
    selected: T,
    optionLabel: @Composable (T) -> String,
    onSelect: (T) -> Unit
) {
    var isExpanded by remember { mutableStateOf(false) }
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        Text(text = label, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        Box {
            TextButton(onClick = { isExpanded = true }) {
                Text(optionLabel(selected))
                Icon(Icons.Default.ArrowDropDown, contentDescription = null)
            }
            DropdownMenu(expanded = isExpanded, onDismissRequest = { isExpanded = false }) {
                options.forEach { option ->
                    DropdownMenuItem(
                        text = { Text(optionLabel(option)) },
                        onClick = {
                            onSelect(option)
                            isExpanded = false
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun AnalyticsGoalKind.label(game: Game): String = when (this) {
    AnalyticsGoalKind.RATING ->
        if (game == Game.DANCE_DANCE_REVOLUTION) "FLARE SKILL" else "VOLFORCE"
    AnalyticsGoalKind.CLEAR_COUNT -> stringResource(R.string.goals_kind_clear_count)
    AnalyticsGoalKind.GRADE_COUNT -> stringResource(
        if (game == Game.IIDX_ARCADE) R.string.goals_kind_dj_level_count else R.string.goals_kind_grade_count
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnalyticsGoalEditorDialog(
    game: Game,
    goal: AnalyticsGoal?,
    defaultPlayStyle: String,
    onDismiss: () -> Unit,
    onSave: (AnalyticsGoal) -> Unit
) {
    val kinds = AnalyticsGoalKind.available(game)
    var kind by remember { mutableStateOf(goal?.kind ?: kinds.first()) }
    var playStyle by remember { mutableStateOf(goal?.playStyle ?: defaultPlayStyle) }
    var level by remember { mutableStateOf(goal?.level ?: AnalyticsGoal.levelOptions(game).last()) }
    var threshold by remember { mutableStateOf(goal?.threshold ?: AnalyticsGoal.defaultThreshold(kind, game)) }
    val isDecimal = game == Game.SOUND_VOLTEX
    var targetText by remember {
        mutableStateOf(
            goal?.let { if (it.isRating && isDecimal) it.target.toString() else it.target.toInt().toString() }
                ?: if (kind == AnalyticsGoalKind.RATING) "" else "10"
        )
    }
    var deadlineEpochDay by remember {
        mutableStateOf(goal?.deadline?.toLocalDate()?.toEpochDay() ?: LocalDate.now().plusMonths(1).toEpochDay())
    }
    var isDatePickerShown by remember { mutableStateOf(false) }

    val playStyles: List<Pair<String, String>> = when (game) {
        Game.IIDX_ARCADE -> IIDXPlayType.entries.map { it.value to it.displayName }
        Game.DANCE_DANCE_REVOLUTION -> DDRPlayStyle.entries.map { it.value to it.value }
        else -> emptyList()
    }
    val target = targetText.replace(',', '.').toDoubleOrNull() ?: 0.0
    val isValid = target > 0 && (kind == AnalyticsGoalKind.RATING || threshold.isNotEmpty()) &&
        deadlineEpochDay > LocalDate.now().toEpochDay()

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(if (goal == null) R.string.goals_new else R.string.goals_edit)) },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                if (kinds.size > 1) {
                    GoalDropdownRow(stringResource(R.string.goals_kind), kinds, kind, { it.label(game) }) {
                        kind = it
                        threshold = AnalyticsGoal.defaultThreshold(it, game)
                        if (goal == null) targetText = if (it == AnalyticsGoalKind.RATING) "" else "10"
                    }
                }
                if (playStyles.isNotEmpty()) {
                    GoalDropdownRow(
                        stringResource(R.string.goals_play_type),
                        playStyles.map { it.first },
                        playStyle,
                        { value -> playStyles.firstOrNull { it.first == value }?.second ?: value }
                    ) { playStyle = it }
                }
                if (kind != AnalyticsGoalKind.RATING) {
                    GoalLevelChips(game, level) { tapped -> level = if (level == tapped) 0 else tapped }
                    GoalDropdownRow(
                        stringResource(
                            if (kind == AnalyticsGoalKind.CLEAR_COUNT) R.string.goals_clear_type else R.string.goals_grade
                        ),
                        AnalyticsGoal.thresholdOptions(kind, game),
                        threshold,
                        { AnalyticsGoal.thresholdDisplay(it, kind, game) }
                    ) { threshold = it }
                }
                OutlinedTextField(
                    value = targetText,
                    onValueChange = { targetText = it },
                    label = { Text(stringResource(R.string.goals_target)) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = if (kind == AnalyticsGoalKind.RATING && isDecimal) {
                            KeyboardType.Decimal
                        } else {
                            KeyboardType.Number
                        }
                    ),
                    modifier = Modifier.fillMaxWidth()
                )
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = stringResource(R.string.goals_deadline),
                        style = MaterialTheme.typography.bodyLarge,
                        modifier = Modifier.weight(1f)
                    )
                    TextButton(onClick = { isDatePickerShown = true }) {
                        Text(LocalDate.ofEpochDay(deadlineEpochDay).format(shortDateFormatter))
                    }
                }
                val footer = when {
                    kind != AnalyticsGoalKind.RATING -> R.string.goals_threshold_footer
                    game == Game.DANCE_DANCE_REVOLUTION -> R.string.goals_flare_skill_footer
                    else -> null
                }
                if (footer != null) {
                    Text(
                        text = stringResource(footer),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                enabled = isValid,
                onClick = {
                    val deadline = LocalDate.ofEpochDay(deadlineEpochDay).atTime(23, 59, 59)
                        .atZone(ZoneId.systemDefault()).toEpochSecond()
                    val base = goal ?: AnalyticsGoal(game = game.id, kind = kind, target = target, deadline = deadline)
                    onSave(
                        base.copy(
                            kind = kind,
                            playStyle = playStyle,
                            level = if (kind == AnalyticsGoalKind.RATING) 0 else level,
                            threshold = if (kind == AnalyticsGoalKind.RATING) "" else threshold,
                            target = target,
                            deadline = deadline
                        )
                    )
                }
            ) { Text(stringResource(R.string.goals_save)) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.shared_cancel)) }
        }
    )

    if (isDatePickerShown) {
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = deadlineEpochDay * 86_400_000L,
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long): Boolean =
                    utcTimeMillis / 86_400_000L > LocalDate.now().toEpochDay()
            }
        )
        DatePickerDialog(
            onDismissRequest = { isDatePickerShown = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let { deadlineEpochDay = it / 86_400_000L }
                    isDatePickerShown = false
                }) { Text(stringResource(R.string.shared_ok)) }
            },
            dismissButton = {
                TextButton(onClick = { isDatePickerShown = false }) { Text(stringResource(R.string.shared_cancel)) }
            }
        ) {
            DatePicker(state = datePickerState)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnalyticsGoalDetailScreen(container: AppContainer, goalID: String, onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val goals by remember { AnalyticsGoalStore.goalsFlow(context) }.collectAsState(initial = null)
    val goal = goals?.firstOrNull { it.id == goalID }
    val progress by produceState<AnalyticsGoalProgress?>(null, goal) {
        value = goal?.let { container.goalEvaluator.progress(listOf(it)).firstOrNull() }
    }
    var isEditing by remember { mutableStateOf(false) }
    var isConfirmingDelete by remember { mutableStateOf(false) }

    LaunchedEffect(goals, goal) {
        if (goals != null && goal == null) onBack()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.goals_title)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.tower_back))
                    }
                },
                actions = {
                    IconButton(onClick = { isEditing = true }, enabled = goal != null) {
                        Icon(Icons.Outlined.Edit, contentDescription = stringResource(R.string.goals_edit))
                    }
                    IconButton(onClick = { isConfirmingDelete = true }, enabled = goal != null) {
                        Icon(Icons.Outlined.Delete, contentDescription = stringResource(R.string.goals_delete))
                    }
                }
            )
        }
    ) { padding ->
        val current = progress
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            if (current != null) {
                Column(
                    modifier = Modifier.padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    AnalyticsGoalTitle(goal = current.goal, style = MaterialTheme.typography.titleSmall)
                    Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            text = current.goal.formatted(current.current),
                            style = MaterialTheme.typography.displaySmall.gameFont(),
                            fontWeight = FontWeight.Black
                        )
                        Text(
                            text = "/ ${current.goal.formatted(current.goal.target)}",
                            style = MaterialTheme.typography.titleMedium.gameFont(),
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(bottom = 4.dp)
                        )
                    }
                }
                GoalChart(
                    progress = current,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(220.dp)
                        .padding(horizontal = 16.dp)
                )
                Row(
                    modifier = Modifier.padding(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    LegendSwatch(current.status.color(), stringResource(R.string.goals_chart_progress), dashed = false)
                    LegendSwatch(
                        MaterialTheme.colorScheme.onSurfaceVariant,
                        stringResource(R.string.goals_chart_pace),
                        dashed = true
                    )
                }
                val g = current.goal
                DetailRow(stringResource(R.string.goals_status)) { StatusBadge(current.status) }
                DetailValueRow(stringResource(R.string.goals_current), g.formatted(current.current))
                DetailValueRow(stringResource(R.string.goals_target), g.formatted(g.target))
                DetailValueRow(stringResource(R.string.goals_start), g.formatted(current.baseline))
                DetailValueRow(stringResource(R.string.goals_expected), g.formatted(current.expected))
                DetailValueRow(stringResource(R.string.goals_remaining), g.formatted(current.remaining))
                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                DetailValueRow(
                    stringResource(R.string.goals_start_date),
                    g.startDate.toLocalDate().format(longDateFormatter),
                    isNumeric = false
                )
                DetailValueRow(
                    stringResource(R.string.goals_deadline),
                    g.deadline.toLocalDate().format(longDateFormatter),
                    isNumeric = false
                )
                DetailValueRow(
                    stringResource(R.string.goals_time_left),
                    stringResource(R.string.goals_days_left, current.daysLeft),
                    isNumeric = false
                )
            }
        }
    }

    if (isEditing && goal != null) {
        AnalyticsGoalEditorDialog(
            game = goal.gameEnum,
            goal = goal,
            defaultPlayStyle = goal.playStyle,
            onDismiss = { isEditing = false },
            onSave = { updated ->
                isEditing = false
                scope.launch { AnalyticsGoalStore.upsert(context, updated) }
            }
        )
    }
    if (isConfirmingDelete) {
        AlertDialog(
            onDismissRequest = { isConfirmingDelete = false },
            title = { Text(stringResource(R.string.goals_delete_confirm)) },
            confirmButton = {
                TextButton(onClick = {
                    isConfirmingDelete = false
                    scope.launch { AnalyticsGoalStore.delete(context, goalID) }
                }) { Text(stringResource(R.string.shared_delete), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { isConfirmingDelete = false }) { Text(stringResource(R.string.shared_cancel)) }
            }
        )
    }
}

@Composable
private fun LegendSwatch(color: Color, label: String, dashed: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Canvas(modifier = Modifier.size(width = 16.dp, height = 8.dp)) {
            drawLine(
                color, Offset(0f, size.height / 2f), Offset(size.width, size.height / 2f), 2.dp.toPx(),
                pathEffect = if (dashed) PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx())) else null
            )
        }
        Text(text = label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun DetailRow(label: String, trailing: @Composable () -> Unit) {
    ListItem(
        headlineContent = { Text(label) },
        trailingContent = trailing,
        modifier = Modifier.padding(horizontal = 0.dp)
    )
}

@Composable
private fun DetailValueRow(label: String, value: String, isNumeric: Boolean = true) {
    DetailRow(label) {
        Text(
            text = value,
            style = if (isNumeric) MaterialTheme.typography.bodyLarge.gameFont() else MaterialTheme.typography.bodyLarge,
            fontWeight = if (isNumeric) FontWeight.SemiBold else null,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun GoalLevelChips(game: Game, level: Int, onToggle: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        Text(
            text = stringResource(R.string.goals_level),
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = if (level > 0) "☆$level" else stringResource(R.string.goals_level_all),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        AnalyticsGoal.levelOptions(game).forEach { option ->
            FilterChip(
                selected = option == level,
                onClick = { onToggle(option) },
                label = { Text(option.toString()) }
            )
        }
    }
}

@Composable
private fun GoalChart(progress: AnalyticsGoalProgress, modifier: Modifier = Modifier) {
    val goal = progress.goal
    val lineColor = progress.status.color()
    val paceColor = MaterialTheme.colorScheme.onSurfaceVariant
    val gridColor = MaterialTheme.colorScheme.outlineVariant
    val points = listOf(goal.startDate to progress.baseline) +
        progress.history.filter { it.date >= goal.startDate }.map { it.date to it.value }
    Canvas(modifier = modifier) {
        val start = goal.startDate.toFloat()
        val end = maxOf(goal.deadline, goal.startDate + 86_400L).toFloat()
        val values = points.map { it.second } + listOf(goal.target, progress.baseline)
        val minValue = values.min()
        val maxValue = values.max()
        val range = (maxValue - minValue).takeIf { it > 0 } ?: 1.0
        val padding = 6.dp.toPx()
        fun x(date: Long): Float = padding + (date - start) / (end - start) * (size.width - padding * 2)
        fun y(value: Double): Float = size.height - padding - ((value - minValue) / range).toFloat() * (size.height - padding * 2)

        drawLine(gridColor, Offset(0f, y(goal.target)), Offset(size.width, y(goal.target)), 1.dp.toPx())
        val todayX = x(progress.now).coerceIn(0f, size.width)
        drawLine(gridColor, Offset(todayX, 0f), Offset(todayX, size.height), 1.dp.toPx())
        drawLine(
            paceColor, Offset(x(goal.startDate), y(progress.baseline)), Offset(x(goal.deadline), y(goal.target)),
            1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 4.dp.toPx()))
        )
        points.zipWithNext().forEach { (a, b) ->
            drawLine(lineColor, Offset(x(a.first), y(a.second)), Offset(x(b.first), y(b.second)), 2.5.dp.toPx(), StrokeCap.Round)
        }
        points.forEach { (date, value) ->
            drawCircle(lineColor, radius = 3.5.dp.toPx(), center = Offset(x(date), y(value)))
        }
    }
}
