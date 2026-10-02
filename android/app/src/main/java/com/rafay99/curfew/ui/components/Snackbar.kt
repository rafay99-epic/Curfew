package com.rafay99.curfew.ui.components

import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHostState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

fun CoroutineScope.say(snack: SnackbarHostState, text: String, long: Boolean = false) = launch {
    snack.currentSnackbarData?.dismiss()
    snack.showSnackbar(text, withDismissAction = long, duration = if (long) SnackbarDuration.Long else SnackbarDuration.Short)
}
