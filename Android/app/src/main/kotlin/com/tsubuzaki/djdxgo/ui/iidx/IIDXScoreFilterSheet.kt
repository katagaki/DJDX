package com.tsubuzaki.djdxgo.ui.iidx

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.datastore.preferences.core.Preferences
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.iidx.IIDXDJLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.setSetting
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun IIDXScoreFilterSheet(onDismiss: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    val playType by rememberSetting(SettingsKeys.iidxPlayType, IIDXPlayType.SINGLE.value)
    val levelFilters by rememberSetting(SettingsKeys.iidxLevelFilters, emptySet())
    val difficultyFilters by rememberSetting(SettingsKeys.iidxDifficultyFilters, emptySet())
    val clearTypeFilters by rememberSetting(SettingsKeys.iidxClearTypeFilters, emptySet())
    val djLevelFilters by rememberSetting(SettingsKeys.iidxDJLevelFilters, emptySet())
    val scoreAvailableOnly by rememberSetting(SettingsKeys.iidxScoreAvailableOnly, true)
    val beginnerHidden by rememberSetting(SettingsKeys.iidxBeginnerLevelHidden, false)
    val genreVisible by rememberSetting(SettingsKeys.iidxGenreVisible, false)
    val artistVisible by rememberSetting(SettingsKeys.iidxArtistVisible, true)
    val levelVisible by rememberSetting(SettingsKeys.iidxLevelVisible, true)
    val djLevelVisible by rememberSetting(SettingsKeys.iidxDJLevelVisible, true)
    val scoreRateVisible by rememberSetting(SettingsKeys.iidxScoreRateVisible, true)
    val scoreVisible by rememberSetting(SettingsKeys.iidxScoreVisible, true)
    val lastPlayDateVisible by rememberSetting(SettingsKeys.iidxLastPlayDateVisible, false)

    fun <T> set(key: Preferences.Key<T>, value: T) {
        scope.launch { context.setSetting(key, value) }
    }

    fun toggle(key: Preferences.Key<Set<String>>, current: Set<String>, value: String) {
        set(key, if (value in current) current - value else current + value)
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = stringResource(R.string.scores_filter),
                    style = MaterialTheme.typography.titleLarge,
                    modifier = Modifier.weight(1f)
                )
                TextButton(
                    onClick = {
                        set(SettingsKeys.iidxLevelFilters, emptySet())
                        set(SettingsKeys.iidxDifficultyFilters, emptySet())
                        set(SettingsKeys.iidxClearTypeFilters, emptySet())
                        set(SettingsKeys.iidxDJLevelFilters, emptySet())
                    }
                ) {
                    Icon(Icons.Default.Refresh, contentDescription = null)
                    Text(
                        text = stringResource(R.string.scores_filter_reset_all),
                        modifier = Modifier.padding(start = 4.dp)
                    )
                }
            }

            SectionLabel(stringResource(R.string.scores_filter_play_type))
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                IIDXPlayType.entries.forEachIndexed { index, type ->
                    SegmentedButton(
                        selected = playType == type.value,
                        onClick = { set(SettingsKeys.iidxPlayType, type.value) },
                        shape = SegmentedButtonDefaults.itemShape(
                            index = index,
                            count = IIDXPlayType.entries.size
                        )
                    ) {
                        Text(type.displayName)
                    }
                }
            }

            SectionLabel(stringResource(R.string.scores_filter_level))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                IIDXLevel.entries.forEach { level ->
                    FilterChip(
                        selected = level.code in levelFilters,
                        onClick = { toggle(SettingsKeys.iidxLevelFilters, levelFilters, level.code) },
                        label = { Text(level.name) }
                    )
                }
            }

            SectionLabel(stringResource(R.string.scores_filter_difficulty))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                (1..12).forEach { difficulty ->
                    val value = difficulty.toString()
                    FilterChip(
                        selected = value in difficultyFilters,
                        onClick = {
                            toggle(SettingsKeys.iidxDifficultyFilters, difficultyFilters, value)
                        },
                        label = { Text(value) }
                    )
                }
            }

            SectionLabel(stringResource(R.string.scores_filter_clear_type))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                IIDXClearType.sorted.forEach { clearType ->
                    FilterChip(
                        selected = clearType.value in clearTypeFilters,
                        onClick = {
                            toggle(SettingsKeys.iidxClearTypeFilters, clearTypeFilters, clearType.value)
                        },
                        label = { Text(clearType.value) }
                    )
                }
            }

            SectionLabel(stringResource(R.string.scores_filter_dj_level))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                IIDXDJLevel.sorted.reversed().forEach { djLevel ->
                    FilterChip(
                        selected = djLevel.value in djLevelFilters,
                        onClick = {
                            toggle(SettingsKeys.iidxDJLevelFilters, djLevelFilters, djLevel.value)
                        },
                        label = { Text(djLevel.value) }
                    )
                }
            }

            SwitchRow(
                label = stringResource(R.string.scores_filter_score_only),
                checked = scoreAvailableOnly
            ) { set(SettingsKeys.iidxScoreAvailableOnly, it) }
            SwitchRow(
                label = stringResource(R.string.scores_filter_hide_beginner),
                checked = beginnerHidden
            ) { set(SettingsKeys.iidxBeginnerLevelHidden, it) }

            SectionLabel(stringResource(R.string.scores_display_header))
            SwitchRow(
                label = stringResource(R.string.scores_display_genre),
                checked = genreVisible
            ) { set(SettingsKeys.iidxGenreVisible, it) }
            SwitchRow(
                label = stringResource(R.string.scores_display_artist),
                checked = artistVisible
            ) { set(SettingsKeys.iidxArtistVisible, it) }
            SwitchRow(
                label = stringResource(R.string.scores_display_level),
                checked = levelVisible
            ) { set(SettingsKeys.iidxLevelVisible, it) }
            SwitchRow(
                label = stringResource(R.string.scores_display_dj_level),
                checked = djLevelVisible
            ) { set(SettingsKeys.iidxDJLevelVisible, it) }
            SwitchRow(
                label = stringResource(R.string.scores_display_score_rate),
                checked = scoreRateVisible
            ) { set(SettingsKeys.iidxScoreRateVisible, it) }
            SwitchRow(
                label = stringResource(R.string.scores_display_score),
                checked = scoreVisible
            ) { set(SettingsKeys.iidxScoreVisible, it) }
            SwitchRow(
                label = stringResource(R.string.scores_display_last_play_date),
                checked = lastPlayDateVisible
            ) { set(SettingsKeys.iidxLastPlayDateVisible, it) }
        }
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary
    )
}

@Composable
private fun SwitchRow(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.weight(1f)
        )
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}
