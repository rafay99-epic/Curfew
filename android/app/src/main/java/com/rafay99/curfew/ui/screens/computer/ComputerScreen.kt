package com.rafay99.curfew.ui.screens.computer

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.LightMode
import androidx.compose.material.icons.rounded.PowerSettingsNew
import androidx.compose.material.icons.rounded.RestartAlt
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rafay99.curfew.core.Link
import com.rafay99.curfew.core.computerLede
import com.rafay99.curfew.core.formatLength
import com.rafay99.curfew.core.isMac
import com.rafay99.curfew.core.lengthArgs
import com.rafay99.curfew.core.userLine
import com.rafay99.curfew.data.Live
import com.rafay99.curfew.data.Repo
import com.rafay99.curfew.ui.components.ConfirmSheet
import com.rafay99.curfew.ui.components.CountdownRow
import com.rafay99.curfew.ui.components.Every
import com.rafay99.curfew.ui.components.GhostButton
import com.rafay99.curfew.ui.components.HairlineRow
import com.rafay99.curfew.ui.components.Hint
import com.rafay99.curfew.ui.components.Lede
import com.rafay99.curfew.ui.components.Page
import com.rafay99.curfew.ui.components.RenameButton
import com.rafay99.curfew.ui.components.RenameSheet
import com.rafay99.curfew.ui.components.SerifTitle
import com.rafay99.curfew.ui.components.SlabButton
import com.rafay99.curfew.ui.components.SwitchRow
import com.rafay99.curfew.ui.components.TextAction
import com.rafay99.curfew.ui.components.TimerRuler
import com.rafay99.curfew.ui.components.TopRow
import com.rafay99.curfew.ui.components.hairline
import com.rafay99.curfew.ui.components.say
import com.rafay99.curfew.ui.components.secondsLeft
import com.rafay99.curfew.ui.theme.Space
import com.rafay99.curfew.ui.theme.Type
import kotlinx.coroutines.launch
import org.json.JSONObject

private enum class Ask { POWEROFF, WAKE_OFF, REBOOT, REMOVE, RENAME }

@Composable
fun ComputerScreen(repo: Repo, snack: SnackbarHostState, id: String, onBack: () -> Unit, onGone: () -> Unit, onUser: (String) -> Unit) {
    val store by repo.store.collectAsStateWithLifecycle()
    val liveMap by repo.live.collectAsStateWithLifecycle()
    val c = store.computers.find { it.id == id }
    if (c == null) {
        LaunchedEffect(Unit) { onGone() }
        return
    }
    val live = liveMap[id] ?: Live()
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf<String?>(null) }
    var ask by remember { mutableStateOf<Ask?>(null) }
    var warn by rememberSaveable { mutableStateOf(false) }
    var picked by rememberSaveable { mutableStateOf<Int?>(null) }
    val remaining = secondsLeft(live.timerEndsAt.takeIf { live.link == Link.ON })
    Every(4000, id) { repo.refresh(id) }

    fun run(op: String, done: String, args: JSONObject = JSONObject()) {
        if (busy != null) return
        busy = op
        scope.launch {
            val error = repo.command(id, op, args)
            busy = null
            say(snack, error ?: done)
        }
    }

    fun wake(thenShutDown: Boolean) {
        if (busy != null) return
        busy = if (thenShutDown) "wake_off" else "wake"
        scope.launch {
            val said = repo.wake(id, thenShutDown)
            busy = null
            say(snack, said)
        }
    }

    fun setTimer(seconds: Int) {
        picked = seconds
        run("timer_set", "Shuts down in ${formatLength(seconds)}", lengthArgs(seconds, warn))
    }

    Page(snack) {
        item {
            TopRow("Computers", onBack) {
                Text(c.os, style = Type.Small, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(end = 12.dp))
            }
        }
        item { SerifTitle(c.title) { RenameButton { ask = Ask.RENAME } } }
        item { Lede(computerLede(live.link, live.status, c.os, remaining, c::userTitle)) }
        if (live.link == Link.OFF && isMac(c.os) && c.wake.isNotEmpty()) {
            item {
                SlabButton(
                    if (busy == "wake_off") "Waking…" else "Wake and shut down", Icons.Rounded.PowerSettingsNew,
                    { ask = Ask.WAKE_OFF }, Modifier.fillMaxWidth().padding(horizontal = Space.Gutter), enabled = busy == null,
                )
            }
            item {
                GhostButton(
                    if (busy == "wake") "Waking…" else "Wake", Icons.Rounded.LightMode,
                    { wake(false) }, Modifier.fillMaxWidth().padding(start = Space.Gutter, end = Space.Gutter, top = 10.dp), enabled = busy == null,
                )
            }
        }
        if (live.link == Link.ON) {
            item {
                SlabButton(
                    if (busy == "poweroff" || busy == "wake_off") "Shutting down…" else "Shut down now", Icons.Rounded.PowerSettingsNew,
                    { ask = Ask.POWEROFF }, Modifier.fillMaxWidth().padding(horizontal = Space.Gutter), enabled = busy == null,
                )
            }
            item {
                GhostButton(
                    if (busy == "reboot") "Restarting…" else "Restart", Icons.Rounded.RestartAlt,
                    { ask = Ask.REBOOT }, Modifier.fillMaxWidth().padding(start = Space.Gutter, end = Space.Gutter, top = 10.dp), enabled = busy == null,
                )
            }
            if (remaining != null) item { CountdownRow("Shuts down in", remaining, busy == null) { run("timer_cancel", "Timer cancelled") } }
            item { TimerRuler(picked.takeIf { remaining != null }, busy == null, "Shut down in", ::setTimer) }
            item { Hint("Shut down later, in minutes.", Modifier.padding(top = 4.dp)) }
            item { SwitchRow("Warn on screen first", warn, true, { warn = it }, line = false) }
            item { Spacer(Modifier.size(14.dp)) }
            val users = live.status?.users.orEmpty()
            if (users.isEmpty()) item { Hint("No user accounts found.") }
            items(users, key = { it.name }) { u ->
                HairlineRow({ onUser(u.name) }) {
                    Text(c.userTitle(u), style = Type.SubName, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Spacer(Modifier.size(4.dp))
                    Text(userLine(u), style = Type.Status)
                }
            }
        }
        item {
            Box(Modifier.hairline().fillMaxWidth().padding(start = Space.Gutter, top = 12.dp)) {
                TextAction("Remove this computer", { ask = Ask.REMOVE }, dim = true)
            }
        }
    }

    when (ask) {
        Ask.POWEROFF -> ConfirmSheet(
            "Shut down ${c.title}?", "It shuts down straight away. Anything not saved is lost.", "Shut down",
            onConfirm = { ask = null; run("poweroff", "Shutting down ${c.title}") }, onDismiss = { ask = null },
        )
        Ask.WAKE_OFF -> ConfirmSheet(
            "Shut down ${c.title}?", "It wakes up, then shuts down straight away. Anything not saved is lost.", "Wake and shut down",
            onConfirm = { ask = null; wake(true) }, onDismiss = { ask = null },
        )
        Ask.REBOOT -> ConfirmSheet(
            "Restart ${c.title}?", "It restarts straight away. Anything not saved is lost.", "Restart",
            onConfirm = { ask = null; run("reboot", "Restarting ${c.title}") }, onDismiss = { ask = null },
        )
        Ask.REMOVE -> ConfirmSheet(
            "Remove ${c.title}?", "This phone stops seeing it. To add it back, pair it again from the computer.", "Remove",
            onConfirm = { ask = null; repo.remove(id); repo.notices.tryEmit("${c.title} was removed") }, onDismiss = { ask = null },
        )
        Ask.RENAME -> RenameSheet(
            "Name this computer", c.alias,
            "Only the name in this app changes. The computer calls itself ${c.name}. Leave it empty to use that.",
            onSave = { ask = null; repo.rename(id, it) }, onDismiss = { ask = null },
        )
        null -> {}
    }
}
