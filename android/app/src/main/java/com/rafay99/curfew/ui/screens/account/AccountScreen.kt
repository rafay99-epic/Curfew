package com.rafay99.curfew.ui.screens.account

import android.content.Context
import android.os.SystemClock
import android.text.format.DateFormat
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Key
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rafay99.curfew.core.AppInfo
import com.rafay99.curfew.core.Link
import com.rafay99.curfew.core.Part
import com.rafay99.curfew.core.UserState
import com.rafay99.curfew.core.accountLede
import com.rafay99.curfew.core.formatCountdown
import com.rafay99.curfew.core.formatLength
import com.rafay99.curfew.core.isMac
import com.rafay99.curfew.core.lengthArgs
import com.rafay99.curfew.data.Live
import com.rafay99.curfew.data.Repo
import com.rafay99.curfew.security.LocalConfirmOwner
import com.rafay99.curfew.ui.components.ConfirmSheet
import com.rafay99.curfew.ui.components.CountdownRow
import com.rafay99.curfew.ui.components.Every
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
import com.rafay99.curfew.ui.components.say
import com.rafay99.curfew.ui.components.secondsLeft
import com.rafay99.curfew.ui.theme.Space
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.Date

private enum class Ask { LOGOUT, NET_OFF, RENAME }

private fun clockIn(context: Context, seconds: Int): String =
    DateFormat.getTimeFormat(context).format(Date(System.currentTimeMillis() + seconds * 1000L))

@Composable
fun AccountScreen(repo: Repo, snack: SnackbarHostState, id: String, userName: String, onBack: () -> Unit, onGone: () -> Unit) {
    val store by repo.store.collectAsStateWithLifecycle()
    val liveMap by repo.live.collectAsStateWithLifecycle()
    val c = store.computers.find { it.id == id }
    if (c == null) {
        LaunchedEffect(Unit) { onGone() }
        return
    }
    val context = LocalContext.current
    val live = liveMap[id] ?: Live()
    val user = live.status?.users?.find { it.name == userName }
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf<String?>(null) }
    var ask by remember { mutableStateOf<Ask?>(null) }
    var apps by remember { mutableStateOf<List<AppInfo>?>(null) }
    var failed by remember { mutableStateOf(false) }
    Every(5000, id + userName) {
        repo.refresh(id)
        val got = repo.apps(id, userName)
        if (got != null) apps = got
        failed = got == null
    }
    val on = live.link == Link.ON
    val loggedIn = on && user != null && user.state != UserState.NONE
    val name = user?.let(c::userTitle) ?: c.userAliases[userName] ?: userName
    val caps = live.status?.caps.orEmpty()
    val confirmOwner = LocalConfirmOwner.current
    var netWarn by rememberSaveable { mutableStateOf(false) }
    var netPicked by rememberSaveable { mutableStateOf<Int?>(null) }
    var approvedUntil by remember { mutableStateOf<Long?>(null) }
    val mac = isMac(c.os)
    val waiting = user != null && if (mac) user.state != UserState.ACTIVE else user.state == UserState.NONE
    val approvedLeft = secondsLeft(approvedUntil.takeIf { on && waiting })
    val netLeft = secondsLeft(live.netEndsAt[userName].takeIf { on })
    LaunchedEffect(netLeft == 0) {
        if (netLeft == 0) {
            delay(1500)
            repo.refresh(id)
        }
    }

    fun run(op: String, done: String, args: JSONObject = JSONObject()) {
        if (busy != null) return
        busy = op
        scope.launch {
            val error = repo.command(id, op, args.put("user", userName))
            busy = null
            say(snack, error ?: done)
        }
    }

    fun netOffAfter(seconds: Int) {
        netPicked = seconds.takeIf { it > 0 }
        run(
            "net_set", if (seconds == 0) "Internet is off for $name" else "Internet turns off for $name in ${formatLength(seconds)}",
            lengthArgs(seconds, netWarn),
        )
    }

    fun login() {
        if (busy != null) return
        confirmOwner("Log in $name", "On ${c.title}, without typing the password") { yes ->
            if (!yes || busy != null) return@confirmOwner
            busy = "login"
            scope.launch {
                var unlocked = false
                var seconds = 0
                val error = repo.command(id, "login", JSONObject().put("user", userName)) {
                    unlocked = it.optString("how") == "unlocked"
                    seconds = it.optInt("seconds")
                }
                busy = null
                if (error == null && !unlocked) approvedUntil = SystemClock.elapsedRealtime() + seconds * 1000L
                else say(snack, error ?: "Unlocked $name")
            }
        }
    }

    val gutter = Modifier.fillMaxWidth().padding(horizontal = Space.Gutter)
    Page(snack) {
        item { TopRow(c.title, onBack) }
        item { SerifTitle(name) { RenameButton { ask = Ask.RENAME } } }
        item { Lede(accountLede(on, user, "net" in caps, netLeft?.let { clockIn(context, it) })) }
        if (approvedLeft != null && approvedLeft > 0) item {
            val left = Part(formatCountdown(approvedLeft), strong = true)
            Lede(when {
                !mac -> listOf(
                    Part("Now pick $name on the login screen. It opens without the password, once, for "), left,
                    Part(". If it already asks for the password, press Enter there."),
                )
                user?.state == UserState.NONE -> listOf(
                    Part("Now choose $name on the login screen of ${c.title} and press Enter with the password empty. Works once, for "), left, Part("."),
                )
                else -> listOf(Part("Now press Enter on the lock screen of ${c.title} with the password empty. Works once, for "), left, Part("."))
            })
        }
        if (on && user != null && "login" in caps && user.state != UserState.ACTIVE) item {
            SlabButton(
                when {
                    busy == "login" -> "Asking…"
                    user.state == UserState.NONE -> "Log in without password"
                    else -> "Unlock without password"
                },
                Icons.Rounded.Key, ::login, gutter, enabled = busy == null,
            )
        }
        item {
            Row(gutter.padding(top = 4.dp)) {
                TextAction("Lock screen", { run("lock", "Locked $name") }, enabled = loggedIn && busy == null)
                TextAction("Log out", { ask = Ask.LOGOUT }, enabled = loggedIn && busy == null)
            }
        }
        if (on && user != null && "net" in caps) {
            item {
                SwitchRow("Internet", !user.netOff, !user.admin && busy == null, { wanted ->
                    if (wanted) run("net_clear", "Internet is back on for $name") else ask = Ask.NET_OFF
                })
            }
            if (user.admin) item { Hint("Always on for an admin account.") }
            else {
                if (netLeft != null) item { CountdownRow("Internet off in", netLeft, busy == null) { run("net_clear", "Timer cancelled") } }
                item { TimerRuler(netPicked.takeIf { netLeft != null }, busy == null, if (user.netOff) "Back on for" else "Internet off in", ::netOffAfter) }
                item { Hint(if (user.netOff) "Back on for a while, in minutes." else "Internet off later, in minutes.", Modifier.padding(top = 4.dp)) }
                item { SwitchRow("Warn on screen first", netWarn, true, { netWarn = it }, line = false) }
            }
        }
        openApps(on, loggedIn, apps, failed)
    }

    when (ask) {
        Ask.LOGOUT -> ConfirmSheet(
            "Log out $name?", "Everything open in this account is closed. Anything not saved is lost.", "Log out",
            onConfirm = { ask = null; run("logout", "Logged out $name") }, onDismiss = { ask = null },
        )
        Ask.NET_OFF -> ConfirmSheet(
            "Turn off the internet?", "Only for $name, straight away. The computer stays on and nothing is closed.", "Turn off",
            onConfirm = { ask = null; netOffAfter(0) }, onDismiss = { ask = null },
        )
        Ask.RENAME -> RenameSheet(
            "Name this account", c.userAliases[userName].orEmpty(),
            "Only the name in this app changes. On the computer it is ${user?.display ?: userName}. Leave it empty to use that.",
            onSave = { ask = null; repo.renameUser(id, userName, it) }, onDismiss = { ask = null },
        )
        null -> {}
    }
}
