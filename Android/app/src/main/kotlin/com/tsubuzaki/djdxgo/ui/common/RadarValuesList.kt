package com.tsubuzaki.djdxgo.ui.common

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.RadarAxis
import com.tsubuzaki.djdxgo.data.RadarData
import com.tsubuzaki.djdxgo.ui.theme.RadarColors
import java.util.Locale

@Composable
fun RadarValuesList(
    data: RadarData,
    modifier: Modifier = Modifier,
    fontSize: TextUnit = 12.sp,
    showsTotal: Boolean = false
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        RadarAxis.displayOrder.forEach { axis ->
            Row(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = axis.label,
                    fontSize = fontSize,
                    fontWeight = FontWeight.Bold,
                    color = RadarColors.axisColor(axis)
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = String.format(Locale.ROOT, "%.2f", data.value(axis)),
                    fontSize = fontSize,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
        if (showsTotal) {
            HorizontalDivider(modifier = Modifier.padding(vertical = 2.dp))
            Row(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = stringResource(R.string.radar_total),
                    fontSize = fontSize,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = String.format(Locale.ROOT, "%.2f", data.sum()),
                    fontSize = fontSize,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}
