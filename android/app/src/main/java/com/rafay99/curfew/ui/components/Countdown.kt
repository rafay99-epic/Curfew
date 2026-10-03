package com.rafay99.curfew.ui.components

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.rafay99.curfew.core.formatCountdown
import com.rafay99.curfew.ui.theme.Ink
import com.rafay99.curfew.ui.theme.Space
import com.rafay99.curfew.ui.theme.Type

@Composable
fun CountdownRow(label: String, remaining: Int, enabled: Boolean, onCancel: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(start = Space.Gutter, end = Space.Gutter - 20.dp, top = 14.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(
            buildAnnotatedString {
                append("$label ")
                withStyle(Type.MonoValue.copy(fontSize = Type.Body.fontSize).toSpanStyle().merge(SpanStyle(color = Ink.Text))) {
                    append(if (remaining > 0) formatCountdown(remaining) else "now")
                }
            },
            style = Type.Body.copy(color = Ink.Dim), modifier = Modifier.weight(1f),
        )
        TextAction("Cancel", onCancel, enabled)
    }
}
