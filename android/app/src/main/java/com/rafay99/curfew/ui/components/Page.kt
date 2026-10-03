package com.rafay99.curfew.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Snackbar
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.rafay99.curfew.ui.theme.Ink
import com.rafay99.curfew.ui.theme.Space
import com.rafay99.curfew.ui.theme.Type

@Composable
fun Page(
    snack: SnackbarHostState,
    bottom: (@Composable () -> Unit)? = null,
    content: LazyListScope.() -> Unit,
) {
    Scaffold(
        containerColor = Ink.Page,
        snackbarHost = {
            SnackbarHost(snack) { data ->
                Snackbar(data, containerColor = Ink.Text, contentColor = Ink.Page, actionColor = Ink.Page, dismissActionContentColor = Ink.Page)
            }
        },
        bottomBar = {
            if (bottom != null) Box(Modifier.navigationBarsPadding().fillMaxWidth().padding(horizontal = Space.Gutter, vertical = 16.dp)) { bottom() }
        },
    ) { pad ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().imePadding(),
            contentPadding = PaddingValues(top = pad.calculateTopPadding(), bottom = pad.calculateBottomPadding() + 28.dp),
            content = content,
        )
    }
}

@Composable
fun Hint(text: String, modifier: Modifier = Modifier) {
    Text(text, style = Type.Small, modifier = modifier.fillMaxWidth().padding(horizontal = Space.Gutter, vertical = 6.dp))
}
