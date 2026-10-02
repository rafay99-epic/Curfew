package com.rafay99.curfew.ui.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import com.rafay99.curfew.ui.theme.Ink
import com.rafay99.curfew.ui.theme.Type

@Composable
fun PlainField(
    value: String, onChange: (String) -> Unit, label: String, modifier: Modifier = Modifier,
    placeholder: String? = null, keyboard: KeyboardOptions = KeyboardOptions.Default, style: TextStyle = Type.Body,
) {
    OutlinedTextField(
        value = value, onValueChange = onChange, singleLine = true, textStyle = style,
        label = { Text(label, style = Type.Small) },
        placeholder = placeholder?.let { { Text(it, style = style.copy(color = Ink.Faint)) } },
        keyboardOptions = keyboard,
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = Ink.Text, unfocusedTextColor = Ink.Text, cursorColor = Ink.Text,
            focusedBorderColor = Ink.Text, unfocusedBorderColor = Ink.Line2,
            focusedLabelColor = Ink.Text, unfocusedLabelColor = Ink.Dim,
            focusedContainerColor = Ink.Page, unfocusedContainerColor = Ink.Page,
        ),
        shape = RoundedCornerShape(12.dp),
        modifier = modifier.fillMaxWidth(),
    )
}
