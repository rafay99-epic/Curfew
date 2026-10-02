package com.rafay99.curfew.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.rafay99.curfew.ui.theme.Ink
import com.rafay99.curfew.ui.theme.Space
import com.rafay99.curfew.ui.theme.Type

fun Modifier.hairline(): Modifier = drawBehind {
    drawLine(Ink.Line, Offset(0f, 0f), Offset(size.width, 0f), 1.dp.toPx())
}

@Composable
fun HairlineRow(onClick: (() -> Unit)? = null, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier.fillMaxWidth().hairline()
            .let { if (onClick != null) it.clickable(onClick = onClick) else it }
            .padding(horizontal = Space.Gutter, vertical = 15.dp),
        content = content,
    )
}

@Composable
fun SwitchRow(label: String, checked: Boolean, enabled: Boolean, onChange: (Boolean) -> Unit, line: Boolean = true) {
    Row(
        Modifier.fillMaxWidth().let { if (line) it.hairline() else it }
            .toggleable(checked, enabled = enabled, role = Role.Switch, onValueChange = onChange)
            .padding(horizontal = Space.Gutter, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = Type.Body, color = if (enabled) Ink.Text else Ink.Dim, modifier = Modifier.weight(1f))
        WhiteSwitch(checked, enabled)
    }
}

@Composable
fun WhiteSwitch(checked: Boolean, enabled: Boolean) {
    Switch(
        checked = checked, onCheckedChange = null, enabled = enabled,
        colors = SwitchDefaults.colors(
            checkedThumbColor = Ink.Page, checkedTrackColor = Ink.Text, checkedBorderColor = Ink.Text,
            uncheckedThumbColor = Ink.Dim, uncheckedTrackColor = Ink.Page, uncheckedBorderColor = Ink.Line2,
            disabledCheckedThumbColor = Ink.Page, disabledCheckedTrackColor = Ink.Faint, disabledCheckedBorderColor = Ink.Faint,
            disabledUncheckedThumbColor = Ink.Faint, disabledUncheckedTrackColor = Ink.Page, disabledUncheckedBorderColor = Ink.Line2,
        ),
    )
}
