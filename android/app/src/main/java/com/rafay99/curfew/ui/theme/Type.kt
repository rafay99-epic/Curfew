package com.rafay99.curfew.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import com.rafay99.curfew.R

@OptIn(ExperimentalTextApi::class)
private fun variable(res: Int, vararg weights: Int) = FontFamily(
    weights.map { w -> Font(res, FontWeight(w), variationSettings = FontVariation.Settings(FontVariation.weight(w))) }
)

val Serif = FontFamily(Font(R.font.instrument_serif))
val Sans = variable(R.font.geist, 400, 500, 600)
val Mono = variable(R.font.geist_mono, 400, 500)

object Type {
    val Title = TextStyle(fontFamily = Serif, fontSize = 46.sp, lineHeight = 46.sp, letterSpacing = (-0.01).em, color = Ink.Text)
    val Name = TextStyle(fontFamily = Serif, fontSize = 30.sp, lineHeight = 32.sp, color = Ink.Text)
    val SubName = TextStyle(fontFamily = Serif, fontSize = 24.sp, lineHeight = 28.sp, color = Ink.Text)
    val Credit = TextStyle(fontFamily = Serif, fontSize = 28.sp, lineHeight = 33.sp, color = Ink.Text)
    val Lede = TextStyle(fontFamily = Sans, fontSize = 17.sp, lineHeight = 25.sp, color = Ink.Lede)
    val Body = TextStyle(fontFamily = Sans, fontSize = 16.sp, lineHeight = 23.sp, color = Ink.Text)
    val Status = TextStyle(fontFamily = Sans, fontSize = 14.sp, lineHeight = 20.sp, color = Ink.Dim)
    val Small = TextStyle(fontFamily = Sans, fontSize = 13.sp, lineHeight = 19.sp, color = Ink.Dim)
    val Button = TextStyle(fontFamily = Sans, fontSize = 17.sp, lineHeight = 22.sp, fontWeight = FontWeight.SemiBold)
    val MonoValue = TextStyle(fontFamily = Mono, fontSize = 14.sp, lineHeight = 20.sp, fontWeight = FontWeight.Medium, color = Ink.Text)
    val MonoSmall = TextStyle(fontFamily = Mono, fontSize = 12.sp, lineHeight = 21.sp, color = Ink.Dim)
}

internal val CurfewTypography = Typography().let { base ->
    base.copy(
        displayLarge = base.displayLarge.copy(fontFamily = Serif),
        displayMedium = base.displayMedium.copy(fontFamily = Serif),
        displaySmall = base.displaySmall.copy(fontFamily = Serif),
        headlineLarge = base.headlineLarge.copy(fontFamily = Serif),
        headlineMedium = base.headlineMedium.copy(fontFamily = Serif),
        headlineSmall = base.headlineSmall.copy(fontFamily = Serif),
        titleLarge = base.titleLarge.copy(fontFamily = Serif, fontSize = 28.sp, lineHeight = 32.sp),
        titleMedium = base.titleMedium.copy(fontFamily = Sans),
        titleSmall = base.titleSmall.copy(fontFamily = Sans),
        bodyLarge = base.bodyLarge.copy(fontFamily = Sans),
        bodyMedium = base.bodyMedium.copy(fontFamily = Sans),
        bodySmall = base.bodySmall.copy(fontFamily = Sans),
        labelLarge = base.labelLarge.copy(fontFamily = Sans),
        labelMedium = base.labelMedium.copy(fontFamily = Sans),
        labelSmall = base.labelSmall.copy(fontFamily = Sans),
    )
}
