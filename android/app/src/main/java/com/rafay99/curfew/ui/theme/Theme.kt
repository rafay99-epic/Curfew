package com.rafay99.curfew.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp

private val CurfewShapes = Shapes(
    extraSmall = RoundedCornerShape(10.dp), small = RoundedCornerShape(12.dp), medium = RoundedCornerShape(16.dp),
    large = RoundedCornerShape(20.dp), extraLarge = RoundedCornerShape(24.dp),
)

@Composable
fun CurfewTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = CurfewColors, typography = CurfewTypography, shapes = CurfewShapes, content = content)
}
