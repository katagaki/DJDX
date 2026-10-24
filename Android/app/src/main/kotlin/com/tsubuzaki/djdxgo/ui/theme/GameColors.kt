package com.tsubuzaki.djdxgo.ui.theme

import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import com.tsubuzaki.djdxgo.data.RadarAxis
import com.tsubuzaki.djdxgo.data.RadarData
import com.tsubuzaki.djdxgo.data.ddr.DDRDifficulty
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.iidx.IIDXDJLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXVersion
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordClearType
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordDifficulty
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordGrade
import com.tsubuzaki.djdxgo.data.sdvx.SDVXClearType
import com.tsubuzaki.djdxgo.data.sdvx.SDVXDifficulty
import com.tsubuzaki.djdxgo.data.sdvx.SDVXGrade

object Palette {
    val red = Color(0xFFFF3B30)
    val orange = Color(0xFFFF9500)
    val yellow = Color(0xFFFFCC00)
    val green = Color(0xFF34C759)
    val mint = Color(0xFF00C7BE)
    val teal = Color(0xFF30B0C7)
    val cyan = Color(0xFF32ADE6)
    val blue = Color(0xFF007AFF)
    val indigo = Color(0xFF5856D6)
    val purple = Color(0xFFAF52DE)
    val pink = Color(0xFFFF2D55)
    val gray = Color(0xFF8E8E93)
    val lime = Color(0xFFA6E22E)
}

object IIDXColors {
    fun levelColor(level: IIDXLevel): Color = when (level) {
        IIDXLevel.BEGINNER -> Palette.green
        IIDXLevel.NORMAL -> Palette.blue
        IIDXLevel.HYPER -> Palette.orange
        IIDXLevel.ANOTHER -> Palette.red
        IIDXLevel.LEGGENDARIA -> Palette.purple
    }

    fun clearTypeColor(clearType: String): Color = when (IIDXClearType.fromValue(clearType)) {
        IIDXClearType.FULL_COMBO_CLEAR -> Palette.blue
        IIDXClearType.CLEAR -> Palette.cyan
        IIDXClearType.EASY_CLEAR -> Palette.green
        IIDXClearType.ASSIST_CLEAR -> Palette.purple
        IIDXClearType.HARD_CLEAR -> Palette.pink
        IIDXClearType.EX_HARD_CLEAR -> Palette.yellow
        IIDXClearType.FAILED -> Palette.red
        else -> Palette.gray
    }

    fun lampColor(clearType: String, darkTheme: Boolean): Color =
        when (IIDXClearType.fromValue(clearType)) {
            IIDXClearType.CLEAR -> Palette.cyan
            IIDXClearType.EASY_CLEAR -> Palette.green
            IIDXClearType.ASSIST_CLEAR -> Palette.purple
            IIDXClearType.HARD_CLEAR -> if (darkTheme) Color.White else Palette.gray
            IIDXClearType.EX_HARD_CLEAR -> Palette.orange
            IIDXClearType.FAILED -> Palette.red
            else -> Color.Transparent
        }

    val fullComboLampBrush = Brush.verticalGradient(
        listOf(
            Color(0xFFFF3B30), Color(0xFFFF9500), Color(0xFFFFCC00),
            Color(0xFF34C759), Color(0xFF007AFF), Color(0xFF5856D6), Color(0xFFAF52DE)
        )
    )

    fun djLevelColor(djLevel: String, darkTheme: Boolean): Color =
        when (IIDXDJLevel.fromValue(djLevel)) {
            IIDXDJLevel.AAA -> if (darkTheme) Color.White else Color.Black
            IIDXDJLevel.AA -> Palette.orange
            IIDXDJLevel.A -> Palette.yellow
            IIDXDJLevel.B -> Palette.green
            IIDXDJLevel.C -> Palette.teal
            IIDXDJLevel.D -> Palette.blue
            IIDXDJLevel.E -> Palette.indigo
            IIDXDJLevel.F -> Palette.red
            else -> Palette.gray
        }

    val scoreBrush = Brush.horizontalGradient(listOf(Palette.cyan, Palette.blue))

    fun djLevelBrush(darkTheme: Boolean): Brush =
        if (darkTheme) {
            Brush.verticalGradient(listOf(Color.White, Palette.cyan))
        } else {
            Brush.verticalGradient(listOf(Palette.cyan, Palette.blue))
        }

    fun songTitleBrush(version: String): Brush =
        if (version == IIDXVersion.current.marketingName) {
            Brush.verticalGradient(listOf(Color(0xFFFEFBFF), Color(0xFFD6A9FC)))
        } else {
            Brush.verticalGradient(listOf(Color.White, Palette.gray))
        }

    fun songTitleStrokeColor(version: String): Color =
        if (version == IIDXVersion.current.marketingName) Color(0xFF3C126C) else Color(0xFF4D4D4D)

    fun versionColor(version: String, darkTheme: Boolean): Color? =
        IIDXVersion.fromMarketingName(version)?.let {
            Color(if (darkTheme) it.darkColor else it.lightColor)
        }

    fun difficultyLevelColor(difficulty: Int): Color =
        Color.hsv(
            hue = ((0.6f - 0.6f * (difficulty - 1) / 11f) * 360f).coerceIn(0f, 360f),
            saturation = 0.75f,
            value = 0.9f
        )
}

object SDVXColors {
    fun difficultyColor(difficulty: String): Color = when (SDVXDifficulty.fromValue(difficulty)) {
        SDVXDifficulty.NOVICE -> Palette.purple
        SDVXDifficulty.ADVANCED -> Color(0xFFD9A800)
        SDVXDifficulty.EXHAUST -> Palette.red
        SDVXDifficulty.INFINITE -> Palette.pink
        SDVXDifficulty.MAXIMUM -> Palette.gray
        SDVXDifficulty.GRAVITY -> Palette.orange
        SDVXDifficulty.HEAVENLY -> Palette.cyan
        SDVXDifficulty.VIVID -> Color(0xFFFF66B3)
        SDVXDifficulty.EXCEED -> Palette.blue
        SDVXDifficulty.NABLA -> Palette.green
        SDVXDifficulty.ULTIMATE -> Color(0xFF4D4D4D)
        else -> Palette.gray
    }

    fun clearTypeColor(clearType: String): Color = when (SDVXClearType.fromValue(clearType)) {
        SDVXClearType.PERFECT_ULTIMATE_CHAIN -> Palette.pink
        SDVXClearType.ULTIMATE_CHAIN -> Palette.pink
        SDVXClearType.EXCESSIVE_COMPLETE -> Palette.red
        SDVXClearType.COMPLETE -> Palette.green
        SDVXClearType.PLAYED -> Palette.gray
        else -> Palette.gray
    }

    fun gradeColor(grade: String, darkTheme: Boolean): Color = when (SDVXGrade.fromValue(grade)) {
        SDVXGrade.S -> if (darkTheme) Color.White else Color.Black
        SDVXGrade.AAA_PLUS -> Palette.pink
        SDVXGrade.AAA -> Palette.orange
        SDVXGrade.AA_PLUS -> Palette.yellow
        SDVXGrade.AA -> Palette.green
        SDVXGrade.A_PLUS -> Palette.mint
        SDVXGrade.A -> Palette.teal
        SDVXGrade.B -> Palette.blue
        SDVXGrade.C -> Palette.indigo
        SDVXGrade.D -> Palette.red
        else -> Palette.gray
    }

    val gradeBrush = Brush.horizontalGradient(listOf(Palette.yellow, Palette.orange))
}

object PolarisChordColors {
    fun difficultyColor(difficulty: String): Color =
        when (PolarisChordDifficulty.fromValue(difficulty)) {
            PolarisChordDifficulty.EASY -> Palette.blue
            PolarisChordDifficulty.NORMAL -> Palette.green
            PolarisChordDifficulty.HARD -> Color(0xFFD9A800)
            PolarisChordDifficulty.INFLUENCE -> Color(0xFFFF59B3)
            PolarisChordDifficulty.POLAR -> Color(0xFF00CCCC)
            else -> Palette.gray
        }

    fun clearTypeColor(clearType: String): Color =
        when (PolarisChordClearType.fromValue(clearType)) {
            PolarisChordClearType.ALL_PERFECT -> Palette.yellow
            PolarisChordClearType.FULL_COMBO -> Palette.cyan
            PolarisChordClearType.SUCCESS -> Palette.green
            PolarisChordClearType.FAILED -> Palette.red
            else -> Palette.gray
        }

    fun gradeColor(grade: String): Color = when (PolarisChordGrade.fromValue(grade)) {
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

    fun gradeBrush(grade: String, darkTheme: Boolean): Brush {
        val parsed = PolarisChordGrade.fromValue(grade)
        return when {
            parsed == PolarisChordGrade.SSS_PLUS_PLUS ||
                parsed == PolarisChordGrade.SSS_PLUS ||
                parsed == PolarisChordGrade.SSS ->
                if (darkTheme) {
                    Brush.horizontalGradient(listOf(Palette.cyan, Color(0xFFFFF2A8), Palette.pink))
                } else {
                    Brush.horizontalGradient(listOf(Palette.blue, Palette.yellow, Palette.pink))
                }
            parsed == PolarisChordGrade.SS || parsed == PolarisChordGrade.S ->
                Brush.horizontalGradient(listOf(Palette.yellow, Palette.orange))
            else -> Brush.horizontalGradient(listOf(Palette.cyan, Palette.blue))
        }
    }
}

object DDRColors {
    fun difficultyColor(difficulty: String): Color = when (DDRDifficulty.fromValue(difficulty)) {
        DDRDifficulty.BEGINNER -> Color(0xFF00B3FF)
        DDRDifficulty.BASIC -> Color(0xFFF2B300)
        DDRDifficulty.DIFFICULT -> Palette.red
        DDRDifficulty.EXPERT -> Palette.green
        DDRDifficulty.CHALLENGE -> Color(0xFFA633E6)
        else -> Palette.gray
    }

    fun clearColor(clearKind: String, darkTheme: Boolean): Color = when (clearKind) {
        "marv" -> if (darkTheme) Color.White else Color.Black
        "perf" -> Palette.yellow
        "great" -> Palette.green
        "good" -> Palette.blue
        "li4clear" -> Palette.red
        "clear" -> Palette.cyan
        "assist" -> Palette.purple
        "fail" -> Palette.gray
        else -> Palette.gray
    }

    fun clearLampColor(clearKind: String, darkTheme: Boolean): Color =
        if (clearKind == "noclear") Palette.gray else clearColor(clearKind, darkTheme)

    fun rankColor(rankStem: String): Color = when {
        rankStem.startsWith("aaa") -> Palette.yellow
        rankStem.startsWith("aa") -> Palette.gray
        rankStem.startsWith("a") -> Palette.red
        rankStem.startsWith("b") -> Palette.red
        rankStem.startsWith("c") -> Palette.yellow
        rankStem.startsWith("d") -> Palette.blue
        rankStem.startsWith("e") -> Color.Black
        else -> Palette.gray
    }
}

object RadarColors {
    fun axisColor(axis: RadarAxis): Color = when (axis) {
        RadarAxis.NOTES -> Color(0xFFFF40EB)
        RadarAxis.CHORD -> Color(0xFF85E100)
        RadarAxis.PEAK -> Color(0xFFFF6C00)
        RadarAxis.CHARGE -> Color(0xFF8957DD)
        RadarAxis.SCRATCH -> Color(0xFFDD0000)
        RadarAxis.SOFLAN -> Color(0xFF0086E5)
    }

    fun chartColor(data: RadarData): Color {
        val sum = data.sum()
        return when {
            sum > 600.0 -> Palette.purple
            sum > 400.0 -> Palette.red
            sum > 200.0 -> Palette.yellow
            else -> Palette.cyan
        }
    }

    fun playerColor(data: RadarData): Color = axisColor(data.highestAxis())

    val notesPalette: List<Color> = listOf(
        Palette.cyan, Palette.yellow, Palette.red, Palette.purple, Palette.green
    )

    val playerPalette: List<Color> = RadarAxis.displayOrder.map(::axisColor)
}
