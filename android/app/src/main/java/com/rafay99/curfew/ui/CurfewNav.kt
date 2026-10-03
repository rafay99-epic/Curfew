package com.rafay99.curfew.ui

import android.net.Uri
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.lifecycle.Lifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.rafay99.curfew.data.Repo
import com.rafay99.curfew.ui.components.say
import com.rafay99.curfew.ui.screens.about.AboutScreen
import com.rafay99.curfew.ui.screens.account.AccountScreen
import com.rafay99.curfew.ui.screens.add.AddScreen
import com.rafay99.curfew.ui.screens.computer.ComputerScreen
import com.rafay99.curfew.ui.screens.home.HomeScreen

@Composable
fun CurfewNav(repo: Repo) {
    val nav = rememberNavController()
    val snack = remember { SnackbarHostState() }
    LaunchedEffect(Unit) { repo.notices.collect { say(snack, it, long = true) } }

    fun inFront() = nav.currentBackStackEntry?.lifecycle?.currentState == Lifecycle.State.RESUMED
    fun go(route: String) { if (inFront()) nav.navigate(route) }
    fun back() { if (inFront()) nav.popBackStack() }
    fun home() { nav.popBackStack("home", inclusive = false) }

    NavHost(
        nav, startDestination = "home",
        enterTransition = { fadeIn(tween(220)) + slideInHorizontally(tween(220)) { it / 10 } },
        exitTransition = { fadeOut(tween(150)) },
        popEnterTransition = { fadeIn(tween(220)) },
        popExitTransition = { fadeOut(tween(150)) + slideOutHorizontally(tween(220)) { it / 10 } },
    ) {
        composable("home") {
            HomeScreen(repo, snack, onOpen = { go("computer/$it") }, onAdd = { go("add") }, onAbout = { go("about") })
        }
        composable("about") {
            AboutScreen(onBack = ::back)
        }
        composable("add") {
            AddScreen(repo, snack, onBack = ::back, onDone = ::home)
        }
        composable("computer/{id}") { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            ComputerScreen(repo, snack, id, onBack = ::back, onGone = ::home, onUser = { go("user/$id/${Uri.encode(it)}") })
        }
        composable("user/{id}/{user}") { entry ->
            val id = entry.arguments?.getString("id").orEmpty()
            AccountScreen(repo, snack, id, entry.arguments?.getString("user").orEmpty(), onBack = ::back, onGone = ::home)
        }
    }
}
