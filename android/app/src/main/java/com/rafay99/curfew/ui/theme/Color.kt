package com.rafay99.curfew.ui.theme

import androidx.compose.material3.darkColorScheme
import androidx.compose.ui.graphics.Color

object Ink {
    val Page = Color.Black
    val Text = Color.White
    val Lede = Color(0xFFEAEAEA)
    val Dim = Color(0xFFB4B4B4)
    val Faint = Color(0xFF6E6E6E)
    val Line = Color(0xFF1D1D1D)
    val Line2 = Color(0xFF333333)
    val Sheet = Color(0xFF0E0E0E)
}

internal val CurfewColors = darkColorScheme(
    primary = Ink.Text, onPrimary = Ink.Page, primaryContainer = Ink.Text, onPrimaryContainer = Ink.Page,
    secondary = Ink.Text, onSecondary = Ink.Page, tertiary = Ink.Text, onTertiary = Ink.Page,
    background = Ink.Page, onBackground = Ink.Text, surface = Ink.Page, onSurface = Ink.Text,
    surfaceVariant = Ink.Sheet, onSurfaceVariant = Ink.Dim, surfaceTint = Ink.Page,
    surfaceContainerLowest = Ink.Page, surfaceContainerLow = Ink.Sheet, surfaceContainer = Ink.Sheet,
    surfaceContainerHigh = Ink.Sheet, surfaceContainerHighest = Ink.Sheet,
    inverseSurface = Ink.Text, inverseOnSurface = Ink.Page, inversePrimary = Ink.Page,
    error = Ink.Text, onError = Ink.Page, errorContainer = Ink.Sheet, onErrorContainer = Ink.Text,
    outline = Ink.Line2, outlineVariant = Ink.Line, scrim = Color.Black,
)
