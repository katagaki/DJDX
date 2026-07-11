package com.tsubuzaki.djdxgo.ui.analytics

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Leaderboard
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.AppContainer
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.ddr.DDRClearLamp
import com.tsubuzaki.djdxgo.data.ddr.DDRPlayStyle
import com.tsubuzaki.djdxgo.data.ddr.DDRRank
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordClearType
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordGrade
import com.tsubuzaki.djdxgo.data.sdvx.SDVXClearType
import com.tsubuzaki.djdxgo.data.sdvx.SDVXGrade
import com.tsubuzaki.djdxgo.ui.theme.DDRColors
import com.tsubuzaki.djdxgo.ui.theme.Palette
import com.tsubuzaki.djdxgo.ui.theme.PolarisChordColors
import com.tsubuzaki.djdxgo.ui.theme.SDVXColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private data class BreakdownData(
    val clearEntries: List<Pair<String, Int>>,
    val clearColors: Map<String, Color>,
    val gradeEntries: List<Pair<String, Int>>,
    val gradeColors: Map<String, Color>
)

@Composable
private fun BreakdownSection(
    data: BreakdownData?,
    gradeTitle: String
) {
    val breakdown = data ?: return
    if (breakdown.clearEntries.isEmpty() && breakdown.gradeEntries.isEmpty()) return
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        if (breakdown.clearEntries.isNotEmpty()) {
            AnalyticsCard(
                title = stringResource(R.string.analytics_clear_breakdown),
                icon = Icons.Outlined.BarChart
            ) {
                HorizontalBarChart(
                    entries = breakdown.clearEntries,
                    colorFor = { breakdown.clearColors[it] ?: Palette.gray }
                )
            }
        }
        if (breakdown.gradeEntries.isNotEmpty()) {
            AnalyticsCard(
                title = gradeTitle,
                icon = Icons.Outlined.Leaderboard
            ) {
                HorizontalBarChart(
                    entries = breakdown.gradeEntries,
                    colorFor = { breakdown.gradeColors[it] ?: Palette.gray }
                )
            }
        }
    }
}

@Composable
fun SDVXAnalyticsSection(container: AppContainer, dateEpoch: Long) {
    val darkTheme = isSystemInDarkTheme()
    val data by produceState<BreakdownData?>(null, dateEpoch, darkTheme) {
        value = withContext(Dispatchers.IO) {
            val records = container.sdvxRepository.songRecords(dateEpoch)
            val clearTypes = SDVXClearType.sorted.filter { it != SDVXClearType.NO_PLAY }
            val clearEntries = clearTypes.mapNotNull { clearType ->
                val count = records.count { it.clearType == clearType.value }
                if (count > 0) clearType.abbreviation to count else null
            }
            val clearColors = clearTypes.associate {
                it.abbreviation to SDVXColors.clearTypeColor(it.value)
            }
            val grades = SDVXGrade.sorted.filter { it != SDVXGrade.NONE }
            val gradeEntries = grades.mapNotNull { grade ->
                val count = records.count { it.grade == grade.value }
                if (count > 0) grade.value to count else null
            }
            val gradeColors = grades.associate {
                it.value to SDVXColors.gradeColor(it.value, darkTheme)
            }
            BreakdownData(clearEntries, clearColors, gradeEntries, gradeColors)
        }
    }
    BreakdownSection(data = data, gradeTitle = stringResource(R.string.analytics_grade_breakdown))
}

@Composable
fun PolarisChordAnalyticsSection(container: AppContainer, dateEpoch: Long) {
    val data by produceState<BreakdownData?>(null, dateEpoch) {
        value = withContext(Dispatchers.IO) {
            val records = container.polarisChordRepository.songRecords(dateEpoch)
            val clearTypes = PolarisChordClearType.sorted
                .filter { it != PolarisChordClearType.NO_PLAY }
            val clearEntries = clearTypes.mapNotNull { clearType ->
                val count = records.count { it.clearType == clearType.value }
                if (count > 0) clearType.abbreviation to count else null
            }
            val clearColors = clearTypes.associate {
                it.abbreviation to PolarisChordColors.clearTypeColor(it.value)
            }
            val grades = PolarisChordGrade.sorted.filter { it != PolarisChordGrade.NONE }
            val gradeEntries = grades.mapNotNull { grade ->
                val count = records.count { it.grade == grade.value }
                if (count > 0) grade.value to count else null
            }
            val gradeColors = grades.associate { it.value to polarisChordGradeColor(it) }
            BreakdownData(clearEntries, clearColors, gradeEntries, gradeColors)
        }
    }
    BreakdownSection(data = data, gradeTitle = stringResource(R.string.analytics_grade_breakdown))
}

private fun polarisChordGradeColor(grade: PolarisChordGrade): Color = when (grade) {
    PolarisChordGrade.SSS_PLUS_PLUS,
    PolarisChordGrade.SSS_PLUS,
    PolarisChordGrade.SSS -> Palette.pink
    PolarisChordGrade.SS -> Palette.orange
    PolarisChordGrade.S -> Palette.yellow
    PolarisChordGrade.AAA -> Palette.green
    PolarisChordGrade.AA -> Palette.mint
    PolarisChordGrade.A -> Palette.teal
    PolarisChordGrade.B -> Palette.blue
    PolarisChordGrade.C -> Palette.indigo
    PolarisChordGrade.D -> Palette.purple
    else -> Palette.gray
}

@Composable
fun DDRAnalyticsSection(container: AppContainer, dateEpoch: Long) {
    val darkTheme = isSystemInDarkTheme()
    val data by produceState<BreakdownData?>(null, dateEpoch, darkTheme) {
        value = withContext(Dispatchers.IO) {
            val records = container.ddrRepository.songRecords(dateEpoch, DDRPlayStyle.SINGLE) +
                container.ddrRepository.songRecords(dateEpoch, DDRPlayStyle.DOUBLE)
            val clearEntries = DDRClearLamp.order.mapNotNull { stem ->
                val count = records.count { it.clearKind == stem }
                if (count > 0) DDRClearLamp.display(stem) to count else null
            }
            val clearColors = DDRClearLamp.order.associate {
                DDRClearLamp.display(it) to DDRColors.clearColor(it, darkTheme)
            }
            val rankEntries = DDRRank.order.mapNotNull { stem ->
                val count = records.count { it.rank == stem }
                if (count > 0) DDRRank.display(stem) to count else null
            }
            val rankColors = DDRRank.order.associate {
                DDRRank.display(it) to DDRColors.rankColor(it)
            }
            BreakdownData(clearEntries, clearColors, rankEntries, rankColors)
        }
    }
    BreakdownSection(data = data, gradeTitle = stringResource(R.string.analytics_rank_breakdown))
}
