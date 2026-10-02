package com.rafay99.curfew.ui.components

import android.os.SystemClock
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.delay

private fun secondsFrom(ms: Long) = ((ms + 999) / 1000).toInt().coerceAtLeast(0)

@Composable
fun secondsLeft(endsAt: Long?): Int? {
    val v by produceState(endsAt?.let { secondsFrom(it - SystemClock.elapsedRealtime()) }, endsAt) {
        if (endsAt == null) {
            value = null
            return@produceState
        }
        while (true) {
            val ms = endsAt - SystemClock.elapsedRealtime()
            value = secondsFrom(ms)
            if (ms <= 0) break
            delay((ms - 1) % 1000 + 1)
        }
    }
    return v
}

@Composable
fun Every(ms: Long, key: String = "", block: suspend () -> Unit) {
    val owner = LocalLifecycleOwner.current
    LaunchedEffect(key, owner) {
        owner.repeatOnLifecycle(Lifecycle.State.STARTED) {
            while (true) {
                block()
                delay(ms)
            }
        }
    }
}
