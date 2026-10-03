package com.rafay99.curfew.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.rafay99.curfew.core.Part
import com.rafay99.curfew.ui.theme.Ink
import com.rafay99.curfew.ui.theme.Space
import com.rafay99.curfew.ui.theme.Type

@Composable
fun TopRow(start: String, onStart: (() -> Unit)? = null, end: @Composable RowScope.() -> Unit = {}) {
    Row(
        Modifier.fillMaxWidth().padding(start = Space.Gutter, end = Space.Gutter - 12.dp, top = 4.dp).heightIn(min = Space.Touch),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val label = if (onStart != null) "‹ $start" else start
        Box(
            Modifier.weight(1f).heightIn(min = Space.Touch).let { if (onStart != null) it.clickable(onClick = onStart) else it },
            contentAlignment = Alignment.CenterStart,
        ) { Text(label, style = Type.Small, maxLines = 1, overflow = TextOverflow.Ellipsis) }
        end()
    }
}

@Composable
fun SerifTitle(text: String, trailing: (@Composable () -> Unit)? = null) {
    Row(Modifier.fillMaxWidth().padding(start = Space.Gutter, end = Space.Gutter - 12.dp, top = 2.dp, bottom = 6.dp), verticalAlignment = Alignment.Bottom) {
        Text(text, style = Type.Title, modifier = Modifier.weight(1f).padding(end = 8.dp))
        if (trailing != null) trailing()
    }
}

@Composable
fun Lede(parts: List<Part>, modifier: Modifier = Modifier) {
    val text = buildAnnotatedString {
        parts.forEach { p ->
            if (p.strong) withStyle(SpanStyle(color = Ink.Text, fontWeight = FontWeight.SemiBold)) { append(p.text) } else append(p.text)
        }
    }
    Text(text, style = Type.Lede, modifier = modifier.fillMaxWidth().padding(start = Space.Gutter, end = Space.Gutter, top = 6.dp, bottom = 18.dp))
}
