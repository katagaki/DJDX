package com.tsubuzaki.djdxgo.ui.iidx

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.ui.common.HitlineJudgmentText
import com.tsubuzaki.djdxgo.ui.common.HitlineRainbowText
import com.tsubuzaki.djdxgo.ui.theme.HitlineJudgmentStyle

enum class IIDXJudgment(
    val label: String,
    val accessibilityName: String,
    val style: HitlineJudgmentStyle?
) {
    PERFECT_GREAT("GREAT", "P-GREAT", null),
    GREAT("GREAT", "GREAT", HitlineJudgmentStyle.great),
    GOOD("GOOD", "GOOD", HitlineJudgmentStyle.good),
    BAD("BAD", "BAD", HitlineJudgmentStyle.bad),
    POOR("POOR", "POOR", HitlineJudgmentStyle.poor),
    MISS("MISS", "MISS", HitlineJudgmentStyle.poor)
}

private const val JUDGMENT_OUTLINE_SCALE = 0.6f

@Composable
fun IIDXJudgmentLabel(
    judgment: IIDXJudgment,
    size: Dp,
    modifier: Modifier = Modifier,
    text: String? = null
) {
    val displayText = text ?: judgment.label
    val semantics = modifier.clearAndSetSemantics {
        contentDescription = text ?: judgment.accessibilityName
    }
    val style = judgment.style
    if (style != null) {
        HitlineJudgmentText(
            text = displayText,
            size = size,
            style = { style },
            modifier = semantics,
            outlineScale = JUDGMENT_OUTLINE_SCALE
        )
    } else {
        HitlineRainbowText(
            text = displayText,
            size = size,
            modifier = semantics,
            outlineScale = JUDGMENT_OUTLINE_SCALE
        )
    }
}

@Composable
fun IIDXJudgmentBreakdown(
    entries: List<Pair<IIDXJudgment, Int>>,
    modifier: Modifier = Modifier
) {
    val size = 24.dp
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        entries.forEach { (judgment, value) ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IIDXJudgmentLabel(judgment = judgment, size = size)
                IIDXJudgmentLabel(judgment = judgment, size = size, text = value.toString())
            }
        }
    }
}
