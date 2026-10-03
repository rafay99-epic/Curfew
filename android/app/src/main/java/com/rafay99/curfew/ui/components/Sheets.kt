package com.rafay99.curfew.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rafay99.curfew.core.formatLength
import com.rafay99.curfew.core.timerSteps
import com.rafay99.curfew.ui.theme.Ink
import com.rafay99.curfew.ui.theme.Space
import com.rafay99.curfew.ui.theme.Type
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Sheet(onDismiss: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    ModalBottomSheet(
        onDismissRequest = onDismiss, containerColor = Ink.Sheet, contentColor = Ink.Text,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    ) {
        Column(Modifier.padding(start = Space.Gutter, end = Space.Gutter, bottom = 20.dp), content = content)
    }
}

@Composable
fun ConfirmSheet(
    title: String, text: String, confirm: String,
    onConfirm: () -> Unit, onDismiss: () -> Unit, extra: @Composable ColumnScope.() -> Unit = {},
) {
    Sheet(onDismiss) {
        Text(title, style = Type.Name)
        if (text.isNotEmpty()) {
            Spacer(Modifier.size(10.dp))
            Text(text, style = Type.Lede.copy(color = Ink.Dim))
        }
        extra()
        Spacer(Modifier.size(24.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            GhostButton("Cancel", null, onDismiss, Modifier.weight(1f))
            SlabButton(confirm, null, onConfirm, Modifier.weight(1f))
        }
    }
}

@Composable
fun RenameSheet(title: String, current: String, hint: String, onSave: (String) -> Unit, onDismiss: () -> Unit) {
    var text by remember { mutableStateOf(current) }
    ConfirmSheet(title, hint, "Save", onConfirm = { onSave(text) }, onDismiss = onDismiss) {
        Spacer(Modifier.size(16.dp))
        PlainField(text, { text = it.take(40) }, "Name", keyboard = KeyboardOptions(capitalization = KeyboardCapitalization.Words))
    }
}

@Composable
fun MinutesSheet(title: String, onStart: (Int) -> Unit, onDismiss: () -> Unit) {
    val steps = remember { timerSteps() }
    var at by remember { mutableFloatStateOf(steps.indexOf(90 * 60).coerceAtLeast(0).toFloat()) }
    val seconds = steps[at.roundToInt().coerceIn(steps.indices)]
    ConfirmSheet(title, "", "Start", onConfirm = { onStart(seconds) }, onDismiss = onDismiss) {
        Spacer(Modifier.size(16.dp))
        Text(formatLength(seconds), style = Type.MonoValue.copy(fontSize = 34.sp, lineHeight = 40.sp))
        Spacer(Modifier.size(8.dp))
        Slider(
            value = at, onValueChange = { at = it.roundToInt().toFloat() }, valueRange = 0f..(steps.size - 1).toFloat(),
            colors = SliderDefaults.colors(
                thumbColor = Ink.Text, activeTrackColor = Ink.Text, inactiveTrackColor = Ink.Line2,
                activeTickColor = Ink.Text, inactiveTickColor = Ink.Line2,
            ),
        )
        Text("From ${formatLength(steps.first())} to ${formatLength(steps.last())}.", style = Type.Small)
    }
}

@Composable
fun TextSheet(title: String, text: String, onDismiss: () -> Unit) {
    Sheet(onDismiss) {
        Text(title, style = Type.Name)
        Spacer(Modifier.size(12.dp))
        Column(Modifier.fillMaxWidth().weight(1f, fill = false).verticalScroll(rememberScrollState())) {
            Text(text, style = Type.MonoSmall.copy(lineHeight = 18.sp))
        }
    }
}
