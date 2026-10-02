package com.rafay99.curfew.security

import android.app.KeyguardManager
import android.content.Context
import android.os.SystemClock
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

object AppLock {
    var locked by mutableStateOf(true)
    var visit by mutableIntStateOf(0)
    var away = false
    private var stoppedAt = 0L

    fun onStop() {
        stoppedAt = SystemClock.elapsedRealtime()
        if (!away) locked = true
    }

    fun onStart(guard: Guard) {
        if (away && SystemClock.elapsedRealtime() - stoppedAt > 60_000) locked = true
        if (guard == Guard.NONE) locked = false
        away = false
        visit++
    }
}

enum class Guard { FINGERPRINT, SCREEN_LOCK, NONE }

fun guardOf(context: Context): Guard = when {
    BiometricManager.from(context).canAuthenticate(BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS -> Guard.FINGERPRINT
    (context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isDeviceSecure -> Guard.SCREEN_LOCK
    else -> Guard.NONE
}
