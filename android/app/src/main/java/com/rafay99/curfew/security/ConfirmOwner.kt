package com.rafay99.curfew.security

import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK
import androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
import androidx.biometric.BiometricPrompt
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity

typealias ConfirmOwner = (title: String, subtitle: String?, onResult: (Boolean) -> Unit) -> Unit

fun FragmentActivity.confirmOwner(title: String, subtitle: String?, onResult: (Boolean) -> Unit) {
    val guard = guardOf(this)
    if (guard == Guard.NONE) return onResult(true)
    if (supportFragmentManager.isStateSaved) return onResult(false)
    val info = BiometricPrompt.PromptInfo.Builder().setTitle(title).setSubtitle(subtitle).setConfirmationRequired(false).apply {
        if (guard == Guard.FINGERPRINT) setAllowedAuthenticators(BIOMETRIC_STRONG).setNegativeButtonText("Cancel")
        else setAllowedAuthenticators(BIOMETRIC_WEAK or DEVICE_CREDENTIAL)
    }.build()
    if (guard == Guard.SCREEN_LOCK) AppLock.away = true
    val callback = object : BiometricPrompt.AuthenticationCallback() {
        override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) = onResult(true)
        override fun onAuthenticationError(code: Int, message: CharSequence) = onResult(false)
    }
    try {
        BiometricPrompt(this, ContextCompat.getMainExecutor(this), callback).authenticate(info)
    } catch (e: Exception) {
        onResult(false)
    }
}

val LocalConfirmOwner = staticCompositionLocalOf<ConfirmOwner> { { _, _, result -> result(true) } }
