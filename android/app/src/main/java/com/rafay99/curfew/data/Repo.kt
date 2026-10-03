package com.rafay99.curfew.data

import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import com.rafay99.curfew.core.AppInfo
import com.rafay99.curfew.core.Client
import com.rafay99.curfew.core.Computer
import com.rafay99.curfew.core.Endpoint
import com.rafay99.curfew.core.Link
import com.rafay99.curfew.core.PairLink
import com.rafay99.curfew.core.PairResult
import com.rafay99.curfew.core.Proto
import com.rafay99.curfew.core.Reply
import com.rafay99.curfew.core.StoreData
import com.rafay99.curfew.core.diagnose
import com.rafay99.curfew.core.errorText
import com.rafay99.curfew.core.parseApps
import com.rafay99.curfew.core.parseStatus
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.abs

class Repo(private val app: Context) {
    private val file = SecureFile(app, "store")
    private val client = Client(HttpTransport)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val discovery = Discovery(app)
    private val _store = MutableStateFlow(StoreData.fromJson(file.read()))
    private val _live = MutableStateFlow<Map<String, Live>>(emptyMap())
    private var foreground = false
    private val locks = ConcurrentHashMap<String, Mutex>()

    private suspend fun <T> serial(id: String, block: suspend () -> T): T = locks.getOrPut(id) { Mutex() }.withLock { block() }

    val store: StateFlow<StoreData> = _store
    val live: StateFlow<Map<String, Live>> = _live
    val notices = MutableSharedFlow<String>(extraBufferCapacity = 4)

    @Synchronized
    private fun save(change: (StoreData) -> StoreData) {
        val next = change(_store.value)
        if (next != _store.value) {
            _store.value = next
            file.write(next.toJson())
        }
    }

    fun onForeground() {
        foreground = true
        discovery.start()
        scope.launch { deliverGoodbyes() }
    }

    fun onBackground() {
        foreground = false
        discovery.stop()
    }

    private val phoneName: String
        get() = (runCatching { Settings.Global.getString(app.contentResolver, "device_name") }.getOrNull()
            ?: Build.MODEL ?: "Phone").take(40)

    private fun endpoints(id: String, host: String, port: Int) =
        (listOfNotNull(discovery.found.value[id]) + Endpoint(host, port)).distinct()

    private fun reach(c: Computer, payload: JSONObject): Pair<Reply, Endpoint> {
        var worst: Pair<Reply, Endpoint>? = null
        fun rank(r: Reply) = when (r) {
            is Reply.WrongComputer -> 3
            is Reply.Unreachable -> if (r.refused) 2 else 1
            else -> 0
        }
        for (ep in endpoints(c.id, c.host, c.port)) {
            val r = client.call(ep, c.id, c.phoneId, Proto.unhex(c.key), payload)
            if (r !is Reply.Unreachable && r !is Reply.WrongComputer && r !is Reply.Fake) return r to ep
            if (worst == null || rank(r) > rank(worst.first)) worst = r to ep
        }
        return worst!!
    }

    private fun setLive(id: String, change: (Live) -> Live) = _live.update { it + (id to change(it[id] ?: Live())) }

    private fun absorb(c: Computer, reply: Reply, ep: Endpoint): JSONObject? {
        when (reply) {
            is Reply.Ok -> {
                if (ep.host != c.host || ep.port != c.port)
                    save { s -> s.copy(computers = s.computers.map { if (it.id == c.id) it.copy(host = ep.host, port = ep.port) else it }) }
                return reply.json
            }
            is Reply.Denied -> return null
            Reply.Unpaired -> {
                save { s -> s.copy(computers = s.computers.filter { it.id != c.id }) }
                _live.update { it - c.id }
                notices.tryEmit("“${c.title}” removed this phone, so it was taken off the list.")
            }
            Reply.NotRecognised -> setLive(c.id) { it.copy(link = Link.NOT_RECOGNISED, timerEndsAt = null) }
            is Reply.WrongComputer -> {
                val ours = _store.value.computers.any { it.id == reply.id }
                setLive(c.id) { it.copy(link = if (ours) Link.OFF else Link.NOT_RECOGNISED, timerEndsAt = null) }
            }
            Reply.Fake, is Reply.Unreachable -> setLive(c.id) { old ->
                val refused = reply is Reply.Unreachable && reply.refused
                if (old.link == Link.ON && old.fails < 1 && !refused) old.copy(fails = old.fails + 1)
                else old.copy(link = diagnose(currentNet(app), c.host, refused), timerEndsAt = null, fails = old.fails + 1)
            }
        }
        return null
    }

    private fun gotStatus(c: Computer, j: JSONObject) {
        val st = parseStatus(j)
        val wake = st.wake.orEmpty()
        if (st.name != c.name || st.os != c.os || wake != c.wake)
            save { s -> s.copy(computers = s.computers.map { if (it.id == c.id) it.copy(name = st.name, os = st.os, wake = wake) else it }) }
        setLive(c.id) { old ->
            val now = SystemClock.elapsedRealtime()
            fun steady(seconds: Int?, before: Long?): Long? {
                val ends = seconds?.let { now + it * 1000L } ?: return null
                return if (before != null && abs(ends - before) < 2000) before else ends
            }
            val net = st.users.mapNotNull { u -> steady(u.netSeconds, old.netEndsAt[u.name])?.let { u.name to it } }.toMap()
            Live(Link.ON, st, steady(st.timerSeconds, old.timerEndsAt), netEndsAt = net)
        }
    }

    suspend fun refresh(id: String) = withContext(Dispatchers.IO) {
        serial(id) {
            val c = _store.value.computers.find { it.id == id } ?: return@serial
            val (reply, ep) = reach(c, JSONObject().put("op", "status"))
            absorb(c, reply, ep)?.let { gotStatus(c, it) }
        }
    }

    suspend fun refreshAll() = coroutineScope {
        _store.value.computers.map { async { refresh(it.id) } }.awaitAll()
    }

    fun rename(id: String, alias: String) = save { it.withAlias(id, alias) }

    fun renameUser(id: String, user: String, alias: String) = save { it.withUserAlias(id, user, alias) }

    suspend fun command(id: String, op: String, args: JSONObject = JSONObject(), answer: (JSONObject) -> Unit = {}): String? = withContext(Dispatchers.IO) {
        val c = _store.value.computers.find { it.id == id } ?: return@withContext "That computer was removed"
        val payload = args.put("op", op)
        val (reply, ok) = serial(id) {
            val (reply, ep) = reach(c, payload)
            val ok = absorb(c, reply, ep)
            if (ok != null && ok.has("timer")) setLive(id) { old ->
                old.copy(timerEndsAt = ok.optJSONObject("timer")?.let { SystemClock.elapsedRealtime() + it.optInt("remaining") * 1000L })
            }
            reply to ok
        }
        if (ok != null) scope.launch { delay(if (op == "poweroff" || op == "reboot") 2500 else 300); refresh(id) }
        if (ok != null) answer(ok)
        when {
            ok != null -> null
            reply is Reply.Denied -> errorText(reply.error)
            reply is Reply.Unpaired -> "This phone was removed from that computer"
            else -> "Could not reach ${c.title}"
        }
    }

    suspend fun wake(id: String, thenShutDown: Boolean): String {
        val c = _store.value.computers.find { it.id == id } ?: return "That computer was removed"
        if (c.wake.isEmpty()) return errorText("unsupported")
        val until = SystemClock.elapsedRealtime() + 45_000
        while (true) {
            sendWake(app, c.wake, c.host)
            refresh(id)
            if (_live.value[id]?.link == Link.ON) break
            if (SystemClock.elapsedRealtime() >= until)
                return "${c.title} did not wake up. Over Wi-Fi a Mac only wakes with an Apple TV or HomePod at home."
            delay(3000)
        }
        if (!thenShutDown) return "${c.title} is awake"
        return command(id, "poweroff") ?: "Shutting down ${c.title}"
    }

    suspend fun apps(id: String, user: String): List<AppInfo>? = withContext(Dispatchers.IO) {
        val c = _store.value.computers.find { it.id == id } ?: return@withContext null
        serial(id) {
            val (reply, ep) = reach(c, JSONObject().put("op", "apps").put("user", user))
            absorb(c, reply, ep)?.let(::parseApps)
        }
    }

    suspend fun pair(link: PairLink): PairResult = withContext(Dispatchers.IO) {
        val now = System.currentTimeMillis()
        val r = client.pair(link, phoneName, now)
        if (r is PairResult.Paired) {
            save { it.withPaired(r.computer, now) }
            _live.update { it - r.computer.id }
            GoodbyeWorker.sync(app, _store.value.goodbyes.isNotEmpty())
            scope.launch { refresh(r.computer.id) }
        }
        r
    }

    fun remove(id: String) {
        save { it.withRemoved(id, System.currentTimeMillis()) }
        _live.update { it - id }
        GoodbyeWorker.sync(app, true)
        scope.launch { deliverGoodbyes() }
    }

    suspend fun deliverGoodbyes(fromWorker: Boolean = false) = withContext(Dispatchers.IO) {
        save { it.withoutExpiredGoodbyes(System.currentTimeMillis()) }
        if (_store.value.goodbyes.isEmpty()) return@withContext GoodbyeWorker.sync(app, false)
        if (fromWorker && !foreground) {
            discovery.start()
            delay(4000)
        }
        for (g in _store.value.goodbyes) {
            for (ep in endpoints(g.id, g.host, g.port)) {
                val r = client.call(ep, g.id, g.phoneId, Proto.unhex(g.key), JSONObject().put("op", "forget"))
                if (r is Reply.Ok || r is Reply.Unpaired || r is Reply.NotRecognised) {
                    save { s -> s.copy(goodbyes = s.goodbyes - g) }
                    break
                }
            }
        }
        if (fromWorker && !foreground) discovery.stop()
        GoodbyeWorker.sync(app, _store.value.goodbyes.isNotEmpty())
    }
}
