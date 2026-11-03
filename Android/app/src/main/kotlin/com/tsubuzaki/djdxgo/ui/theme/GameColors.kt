package com.tsubuzaki.djdxgo.ui.theme

import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
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

fun metallicBrush(highlight: Color, base: Color, shade: Color): Brush =
    Brush.verticalGradient(
        0f to highlight,
        0.2f to highlight,
        0.48f to base,
        0.52f to shade,
        0.85f to base,
        1f to highlight
    )

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
        IIDXClearType.FULL_COMBO_CLEAR -> Color(0xFF73D9FF)
        IIDXClearType.CLEAR -> Color(0xFF4CD9FA)
        IIDXClearType.EASY_CLEAR -> Color(0xFFB2ED4C)
        IIDXClearType.ASSIST_CLEAR -> Color(0xFFB280FF)
        IIDXClearType.HARD_CLEAR -> Color(0xFFFF4752)
        IIDXClearType.EX_HARD_CLEAR -> Color(0xFFFFD138)
        IIDXClearType.FAILED -> Color(0xFFFA6645)
        else -> Color(0xFFA8ABB2)
    }

    fun clearTypeBrush(clearType: String, phase: Float = 0f): Brush =
        when (IIDXClearType.fromValue(clearType)) {
            IIDXClearType.FULL_COMBO_CLEAR -> SolidColor(fullComboRainbowColor(phase))
            IIDXClearType.FAILED -> metallicBrush(Color(0xFFFFB899), Color(0xFFFA6645), Color(0xFFDB4024))
            IIDXClearType.EASY_CLEAR -> metallicBrush(Color(0xFFEDFFBF), Color(0xFFB2ED4C), Color(0xFF80CC1F))
            IIDXClearType.ASSIST_CLEAR -> metallicBrush(Color(0xFFE6D1FF), Color(0xFFB280FF), Color(0xFF854CEB))
            IIDXClearType.CLEAR -> metallicBrush(Color(0xFFD1FFFF), Color(0xFF4CD9FA), Color(0xFF1AA8E6))
            IIDXClearType.HARD_CLEAR -> metallicBrush(Color(0xFFFFB8BD), Color(0xFFFF4752), Color(0xFFDB0F29))
            IIDXClearType.EX_HARD_CLEAR -> metallicBrush(Color(0xFFFFF7B8), Color(0xFFFFD138), Color(0xFFED8F0D))
            else -> metallicBrush(Color(0xFFE6E8EB), Color(0xFFA8ABB2), Color(0xFF80828A))
        }

    fun fullComboRainbowColor(phase: Float): Color = Color.hsv((phase % 1f) * 360f, 0.6f, 1f)

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

    fun djLevelColor(djLevel: String): Color =
        when (IIDXDJLevel.fromValue(djLevel)) {
            IIDXDJLevel.AAA -> Color(0xFFFFCC29)
            IIDXDJLevel.AA -> Color(0xFF9EA6AD)
            IIDXDJLevel.A -> Color(0xFF66E6CC)
            IIDXDJLevel.B -> Color(0xFF52D6EB)
            IIDXDJLevel.C -> Color(0xFF3DB2F5)
            IIDXDJLevel.D -> Color(0xFF3D8FFA)
            IIDXDJLevel.E -> Color(0xFF3370F5)
            IIDXDJLevel.F -> Color(0xFF2957EB)
            else -> Palette.gray
        }

    fun djLevelBrush(djLevel: String): Brush =
        when (IIDXDJLevel.fromValue(djLevel)) {
            IIDXDJLevel.AAA -> metallicBrush(Color(0xFFFFF59E), Color(0xFFFFCC29), Color(0xFFF58F00))
            IIDXDJLevel.AA -> metallicBrush(Color(0xFFFFFFFF), Color(0xFFD6DBE0), Color(0xFF9EA6AD))
            IIDXDJLevel.A -> metallicBrush(Color(0xFFCCFFF0), Color(0xFF66E6CC), Color(0xFF33C2AD))
            IIDXDJLevel.B -> metallicBrush(Color(0xFFC7FAFF), Color(0xFF52D6EB), Color(0xFF24ADD1))
            IIDXDJLevel.C -> metallicBrush(Color(0xFFBDEBFF), Color(0xFF3DB2F5), Color(0xFF1A85E0))
            IIDXDJLevel.D -> metallicBrush(Color(0xFFB2D6FF), Color(0xFF3D8FFA), Color(0xFF1A66E6))
            IIDXDJLevel.E -> metallicBrush(Color(0xFFA8C7FF), Color(0xFF3370F5), Color(0xFF144CDB))
            IIDXDJLevel.F -> metallicBrush(Color(0xFF9EB8FF), Color(0xFF2957EB), Color(0xFF0F33CC))
            else -> SolidColor(Palette.gray)
        }

    val scoreColor = Color(0xFF94EBF0)
    val scoreOutlineColor = Color(0xFF4799ED)

    fun songTitleBrush(version: String): Brush =
        if (version == IIDXVersion.current.marketingName) {
            Brush.verticalGradient(listOf(Color(0xFFFEFBFF), Color(0xFFD6A9FC)))
        } else {
            Brush.verticalGradient(listOf(Color.White, Palette.gray))
        }

    fun songTitleStrokeColor(version: String): Color =
        if (version == IIDXVersion.current.marketingName) Color(0xFF3C126C) else Color(0xFF4D4D4D)

    fun rowTitleBrush(version: String, level: IIDXLevel, darkTheme: Boolean): Brush = when {
        level == IIDXLevel.LEGGENDARIA -> Brush.verticalGradient(listOf(Color(0xFFFFECF8), Color(0xFFFF5CB6)))
        !darkTheme && version != IIDXVersion.current.marketingName ->
            Brush.verticalGradient(listOf(Color.White, Color(0xFFDBDBE0)))
        else -> songTitleBrush(version)
    }

    fun rowTitleStrokeColor(version: String, level: IIDXLevel, darkTheme: Boolean): Color = when {
        level == IIDXLevel.LEGGENDARIA -> Color(0xFF700C48)
        version != IIDXVersion.current.marketingName -> if (darkTheme) Color(0xFF202020) else Color(0xFF38383D)
        else -> songTitleStrokeColor(version)
    }

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

    fun rankColor(rankStem: String, darkTheme: Boolean): Color = when {
        rankStem.startsWith("aaa") -> Palette.yellow
        rankStem.startsWith("aa") -> Palette.gray
        rankStem.startsWith("a") -> Palette.red
        rankStem.startsWith("b") -> Palette.red
        rankStem.startsWith("c") -> Palette.yellow
        rankStem.startsWith("d") -> Palette.blue
        rankStem.startsWith("e") -> if (darkTheme) Color.White else Color.Black
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
