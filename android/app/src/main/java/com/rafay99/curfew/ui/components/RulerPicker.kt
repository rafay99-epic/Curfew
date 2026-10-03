package com.rafay99.curfew.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.unit.dp
import com.rafay99.curfew.core.TIMER_PRESETS
import com.rafay99.curfew.ui.theme.Ink
import com.rafay99.curfew.ui.theme.Space
import com.rafay99.curfew.ui.theme.Type

@Composable
fun RulerPicker(labels: List<String>, selected: Int?, enabled: Boolean, onPick: (Int) -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = Space.Gutter).padding(top = 4.dp).drawBehind {
            val y = size.height - 0.5.dp.toPx()
            drawLine(Ink.Line2, Offset(0f, y), Offset(size.width, y), 1.dp.toPx())
        },
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        labels.forEachIndexed { i, label ->
            val on = i == selected
            Box(
                Modifier.sizeIn(minWidth = Space.Touch, minHeight = Space.Touch).clickable(enabled = enabled) { onPick(i) },
                contentAlignment = when (i) {
                    0 -> Alignment.BottomStart
                    labels.lastIndex -> Alignment.BottomEnd
                    else -> Alignment.BottomCenter
                },
            ) {
                Text(
                    label, style = Type.MonoValue, color = if (on && enabled) Ink.Text else if (enabled) Ink.Dim else Ink.Faint,
                    modifier = Modifier.padding(bottom = 10.dp).drawBehind {
                        if (on) {
                            val pad = 4.dp.toPx()
                            val h = 2.dp.toPx()
                            drawRect(Ink.Text, Offset(-pad, size.height + 10.dp.toPx() - h), Size(size.width + pad * 2, h))
                        }
                    },
                )
            }
        }
    }
}

@Composable
fun TimerRuler(picked: Int?, enabled: Boolean, sheetTitle: String, onPick: (Int) -> Unit) {
    var custom by remember { mutableStateOf(false) }
    val labels = TIMER_PRESETS.map { "${it / 60}" } + "Set"
    val selected = picked?.let { p -> TIMER_PRESETS.indexOf(p).takeIf { it >= 0 } ?: TIMER_PRESETS.size }
    RulerPicker(labels, selected, enabled) { i -> if (i < TIMER_PRESETS.size) onPick(TIMER_PRESETS[i]) else custom = true }
    if (custom) MinutesSheet(sheetTitle, onStart = { custom = false; onPick(it) }, onDismiss = { custom = false })
}
