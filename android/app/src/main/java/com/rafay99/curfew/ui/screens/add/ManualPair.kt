package com.rafay99.curfew.ui.screens.add

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.rafay99.curfew.core.PairLink
import com.rafay99.curfew.core.Proto
import com.rafay99.curfew.ui.components.PlainField
import com.rafay99.curfew.ui.components.SlabButton
import com.rafay99.curfew.ui.components.TextAction
import com.rafay99.curfew.ui.components.hairline
import com.rafay99.curfew.ui.theme.Space
import com.rafay99.curfew.ui.theme.Type

@Composable
internal fun ManualPair(
    address: String, onAddress: (String) -> Unit, code: String, onCode: (String) -> Unit,
    busy: Boolean, onPair: (PairLink) -> Unit, onScan: () -> Unit,
) {
    val target = Proto.parseAddress(address)
    val clean = Proto.cleanCode(code)
    Column(Modifier.fillMaxWidth().padding(top = 8.dp).hairline().padding(start = Space.Gutter, end = Space.Gutter, top = 16.dp)) {
        PlainField(
            address, { onAddress(it.trim().take(60)) }, "Address", placeholder = "192.168.1.20",
            keyboard = KeyboardOptions(keyboardType = KeyboardType.Uri, autoCorrectEnabled = false),
        )
        Spacer(Modifier.size(10.dp))
        PlainField(
            code, { onCode(it.uppercase().take(24)) }, "Code", placeholder = "ABCD-EFGH-JKLM-NPQR", style = Type.MonoValue.copy(fontSize = Type.Body.fontSize),
            keyboard = KeyboardOptions(capitalization = KeyboardCapitalization.Characters, keyboardType = KeyboardType.Ascii, autoCorrectEnabled = false),
        )
        Text("Both are shown under the square code.", style = Type.Small, modifier = Modifier.padding(top = 8.dp))
        Spacer(Modifier.size(12.dp))
        SlabButton(
            if (busy) "Pairing…" else "Pair", null, { if (target != null) onPair(PairLink(target, null, clean)) }, Modifier.fillMaxWidth(),
            enabled = target != null && clean.length == 16 && !busy,
        )
        TextAction("Scan the code instead", onScan, enabled = !busy)
    }
}
