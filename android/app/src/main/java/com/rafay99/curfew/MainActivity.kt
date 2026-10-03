package com.rafay99.curfew

import android.graphics.Color
import android.os.Bundle
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.fragment.app.FragmentActivity
import com.rafay99.curfew.security.AppLock
import com.rafay99.curfew.security.LocalConfirmOwner
import com.rafay99.curfew.security.LockScreen
import com.rafay99.curfew.security.confirmOwner
import com.rafay99.curfew.security.guardOf
import com.rafay99.curfew.ui.CurfewNav
import com.rafay99.curfew.ui.theme.CurfewTheme

class MainActivity : FragmentActivity() {
    private val repo get() = (application as CurfewApp).repo
    private var asking = false

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(SystemBarStyle.dark(Color.TRANSPARENT), SystemBarStyle.dark(Color.TRANSPARENT))
        super.onCreate(savedInstanceState)
        setContent {
            CurfewTheme {
                if (AppLock.locked) LockScreen(::unlock)
                else CompositionLocalProvider(LocalConfirmOwner provides ::confirmOwner) { CurfewNav(repo) }
            }
        }
    }

    private fun unlock() {
        if (asking) return
        asking = true
        confirmOwner("Unlock Curfew", null) { yes ->
            asking = false
            if (yes) AppLock.locked = false
        }
    }

    override fun onStart() {
        super.onStart()
        AppLock.onStart(guardOf(this))
        repo.onForeground()
    }

    override fun onStop() {
        asking = false
        AppLock.onStop()
        repo.onBackground()
        super.onStop()
    }
}
