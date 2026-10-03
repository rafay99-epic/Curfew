package com.rafay99.curfew.ui.screens.home

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rafay99.curfew.core.Glance
import com.rafay99.curfew.core.Link
import com.rafay99.curfew.core.homeLede
import com.rafay99.curfew.data.Live
import com.rafay99.curfew.data.Repo
import com.rafay99.curfew.security.Guard
import com.rafay99.curfew.security.guardOf
import com.rafay99.curfew.ui.components.Every
import com.rafay99.curfew.ui.components.Hint
import com.rafay99.curfew.ui.components.Lede
import com.rafay99.curfew.ui.components.Page
import com.rafay99.curfew.ui.components.SerifTitle
import com.rafay99.curfew.ui.components.SlabButton
import com.rafay99.curfew.ui.components.TopRow
import com.rafay99.curfew.ui.components.hairline
import com.rafay99.curfew.ui.components.secondsLeft
import com.rafay99.curfew.ui.theme.Ink

@Composable
fun HomeScreen(repo: Repo, snack: SnackbarHostState, onOpen: (String) -> Unit, onAdd: () -> Unit, onAbout: () -> Unit) {
    val store by repo.store.collectAsStateWithLifecycle()
    val live by repo.live.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val unguarded = remember { guardOf(context) == Guard.NONE }
    Every(4000) { repo.refreshAll() }
    val soonest = store.computers.mapNotNull { c -> live[c.id]?.takeIf { it.link == Link.ON }?.timerEndsAt?.let { c.id to it } }
        .minByOrNull { it.second }
    val soonestLeft = secondsLeft(soonest?.second)
    val lede = homeLede(store.computers.map { c ->
        val l = live[c.id] ?: Live()
        Glance(c.title, l.link, if (c.id == soonest?.first) soonestLeft else null)
    })
    Page(snack, bottom = { SlabButton("Add a computer", Icons.Rounded.Add, onAdd, Modifier.fillMaxWidth()) }) {
        item {
            TopRow("Home Wi-Fi") {
                IconButton(onClick = onAbout) { Icon(Icons.Outlined.Info, contentDescription = "About Curfew", tint = Ink.Dim, modifier = Modifier.size(20.dp)) }
            }
        }
        item { SerifTitle("Your computers") }
        item { Lede(lede) }
        items(store.computers, key = { it.id }) { c ->
            val twin = store.computers.count { it.title == c.title } > 1
            ComputerRow(c, live[c.id] ?: Live(), if (twin) c.id.takeLast(4) else null) { onOpen(c.id) }
        }
        if (store.computers.isEmpty()) item {
            Hint("On the computer, run sudo curfew pair in a terminal. Then add it here.", Modifier.hairline().padding(top = 12.dp))
        }
        if (unguarded) item {
            Hint("This phone has no screen lock, so anyone holding it can open Curfew.", Modifier.padding(top = 16.dp))
        }
    }
}
