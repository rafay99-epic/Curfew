package com.rafay99.curfew.security

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Fingerprint
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.rafay99.curfew.core.Part
import com.rafay99.curfew.ui.components.Lede
import com.rafay99.curfew.ui.components.SerifTitle
import com.rafay99.curfew.ui.components.SlabButton
import com.rafay99.curfew.ui.components.TopRow
import com.rafay99.curfew.ui.theme.Ink
import com.rafay99.curfew.ui.theme.Space

@Composable
fun LockScreen(onUnlock: () -> Unit) {
    LaunchedEffect(AppLock.visit) { onUnlock() }
    Column(Modifier.fillMaxSize().background(Ink.Page).systemBarsPadding()) {
        TopRow("Locked")
        SerifTitle("Curfew")
        Lede(listOf(Part("Only the owner of this phone can open it.")))
        Spacer(Modifier.weight(1f).heightIn(min = 24.dp))
        SlabButton("Unlock", Icons.Rounded.Fingerprint, onUnlock, Modifier.fillMaxWidth().padding(horizontal = Space.Gutter, vertical = 16.dp))
    }
}
