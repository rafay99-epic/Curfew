package com.rafay99.curfew.core

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException
import java.net.ConnectException

class CurfewTest {
    private val ep = Endpoint("192.168.1.20", 787)
    private fun op(name: String) = JSONObject().put("op", name)

    private fun paired(agent: FakeAgent): Computer {
        agent.code = "ABCDEFGHJKLMNPQR"
        return (Client(agent).pair(PairLink(ep, agent.id, "ABCDEFGHJKLMNPQR"), "Phone", 1L) as PairResult.Paired).computer
    }

    private fun call(agent: FakeAgent, c: Computer, name: String = "status") =
        Client(agent).call(ep, c.id, c.phoneId, Proto.unhex(c.key), op(name))

    @Test fun macMatchesPython() {
        val key = ByteArray(32) { it.toByte() }
        assertEquals("cc80803783d8894816d100f1f0599677af989831ae39bf2dd9865611b4431087",
            Proto.mac(key, "req", "0011223344556677", "aaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbb", "{\"op\":\"status\"}"))
    }

    @Test fun keyDerivationMatchesPython() {
        assertEquals("acf2b5f449fe43d0cfe77984beafc4150825b23e335cab519d316ab772b30a0e",
            Proto.hex(Proto.deriveKey("ABCDEFGHJKLMNPQR", "aaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbb", "0011223344556677")))
    }

    @Test fun hexRoundTrip() = assertEquals("00ff10", Proto.hex(Proto.unhex("00ff10")))

    @Test fun pairLinkParses() {
        val l = Proto.parsePairLink("curfew://pair?a=192.168.1.18:8787&i=0b825f00961665a4&c=ABCDEFGHJKLMNPQR")!!
        assertEquals(Endpoint("192.168.1.18", 8787), l.endpoint)
        assertEquals("0b825f00961665a4", l.id)
        assertEquals("ABCDEFGHJKLMNPQR", l.code)
    }

    @Test fun otherQrCodesAreRejected() {
        assertNull(Proto.parsePairLink("https://example.com/?a=1.2.3.4&c=ABCDEFGHJKLMNPQR"))
        assertNull(Proto.parsePairLink("curfew://pair?a=192.168.1.18&c=SHORT"))
        assertNull(Proto.parsePairLink("curfew://pair?c=ABCDEFGHJKLMNPQR"))
    }

    @Test fun addressParses() {
        assertEquals(Endpoint("192.168.1.20", 787), Proto.parseAddress(" 192.168.1.20 "))
        assertEquals(Endpoint("192.168.1.20", 8787), Proto.parseAddress("192.168.1.20:8787"))
        assertEquals(Endpoint("laptop.local", 787), Proto.parseAddress("laptop.local"))
        assertNull(Proto.parseAddress("192.168.1"))
        assertNull(Proto.parseAddress("192.168.1.999"))
        assertNull(Proto.parseAddress("192.168.1.20:99999"))
        assertNull(Proto.parseAddress(""))
    }

    @Test fun typedCodeIsCleaned() = assertEquals("ABCDEFGHJKLMNPQR", Proto.cleanCode(" abcd-efgh jklm-npqr "))

    @Test fun pairingGivesAWorkingKey() {
        val agent = FakeAgent()
        val c = paired(agent)
        assertEquals(agent.id, c.id)
        assertTrue(call(agent, c) is Reply.Ok)
    }

    @Test fun wrongOrUsedCodeIsRefused() {
        val agent = FakeAgent().apply { code = "ABCDEFGHJKLMNPQR" }
        assertEquals(PairResult.BadCode, Client(agent).pair(PairLink(ep, null, "ZZZZZZZZZZZZZZZZ"), "Phone", 1L))
        paired(agent)
        assertEquals(PairResult.BadCode, Client(agent).pair(PairLink(ep, null, "ABCDEFGHJKLMNPQR"), "Phone", 1L))
    }

    @Test fun pairingWithAnImpostorFails() {
        val impostor = Transport { _, path, _ ->
            if (path == "/v1/hello") HttpResult(200, """{"app":"curfew","id":"x","nonce":"${Proto.nonce()}"}""")
            else HttpResult(200, """{"phone":"0011223344556677","payload":"{\"ok\":true,\"id\":\"x\"}","mac":"${"0".repeat(64)}"}""")
        }
        assertEquals(PairResult.Fake, Client(impostor).pair(PairLink(ep, null, "ABCDEFGHJKLMNPQR"), "Phone", 1L))
    }

    @Test fun pairingChecksTheComputerIdFromTheQrCode() {
        val agent = FakeAgent().apply { code = "ABCDEFGHJKLMNPQR" }
        assertEquals(PairResult.WrongComputer, Client(agent).pair(PairLink(ep, "someoneelse", "ABCDEFGHJKLMNPQR"), "Phone", 1L))
    }

    @Test fun pairingUnreachable() {
        val agent = FakeAgent().apply { down = IOException("timeout") }
        assertEquals(PairResult.Unreachable, Client(agent).pair(PairLink(ep, null, "ABCDEFGHJKLMNPQR"), "Phone", 1L))
    }

    @Test fun everyRequestIsDifferentAndCannotBeReplayed() {
        val agent = FakeAgent()
        val c = paired(agent)
        agent.sent.clear()
        call(agent, c); call(agent, c)
        assertNotEquals(agent.sent[0], agent.sent[1])
        assertEquals(409, agent.send(ep, "/v1/call", agent.sent[0]).code)
    }

    @Test fun tamperedAnswerIsDetected() {
        val agent = FakeAgent()
        val c = paired(agent)
        agent.tamper = true
        assertEquals(Reply.Fake, call(agent, c))
    }

    @Test fun unpairedOnTheComputerIsATrustedAnswer() {
        val agent = FakeAgent()
        val c = paired(agent)
        agent.removed[c.phoneId] = agent.phones.remove(c.phoneId)!!
        assertEquals(Reply.Unpaired, call(agent, c))
    }

    @Test fun reinstalledComputerIsNotRecognisedRatherThanOffline() {
        val agent = FakeAgent()
        val c = paired(agent)
        agent.phones.clear()
        assertEquals(Reply.NotRecognised, call(agent, c))
        assertEquals(Reply.WrongComputer("ffff000011112222"), call(FakeAgent("ffff000011112222"), c))
    }

    @Test fun refusedAndTimeoutAreToldApart() {
        val agent = FakeAgent()
        val c = paired(agent)
        agent.down = ConnectException("failed to connect: ECONNREFUSED (Connection refused)")
        assertEquals(Reply.Unreachable(true), call(agent, c))
        agent.down = java.net.SocketTimeoutException("timeout")
        assertEquals(Reply.Unreachable(false), call(agent, c))
    }

    @Test fun deniedActionCarriesTheReason() {
        val agent = FakeAgent()
        val c = paired(agent)
        assertEquals(Reply.Denied("not_logged_in"), call(agent, c, "logout"))
        assertEquals("That account is not logged in", errorText("not_logged_in"))
    }

    @Test fun garbageAnswersCountAsUnreachable() {
        val junk = Transport { _, _, _ -> HttpResult(200, "<html>router login</html>") }
        assertEquals(Reply.Unreachable(false), Client(junk).call(ep, "id", "p", ByteArray(32), op("status")))
    }

    private val pc = Computer("id1", "laptop", "p1", "aa", "192.168.1.20", 787, 5L)

    @Test fun storeSurvivesSaveAndLoad() {
        val s = StoreData(listOf(pc), listOf(Goodbye("id2", "p2", "bb", "192.168.1.21", 787, 9L)))
        assertEquals(s, StoreData.fromJson(s.toJson()))
        assertEquals(StoreData(), StoreData.fromJson(null))
        assertEquals(StoreData(), StoreData.fromJson("not json"))
    }

    @Test fun removingDisappearsAtOnceAndQueuesAGoodbye() {
        val s = StoreData(listOf(pc)).withRemoved("id1", 100L)
        assertTrue(s.computers.isEmpty())
        assertEquals(listOf(Goodbye("id1", "p1", "aa", "192.168.1.20", 787, 100L)), s.goodbyes)
    }

    @Test fun goodbyeIsDroppedAfterThirtyDays() {
        val s = StoreData(listOf(pc)).withRemoved("id1", 0L)
        assertEquals(1, s.withoutExpiredGoodbyes(GOODBYE_GIVE_UP_MS - 1).goodbyes.size)
        assertTrue(s.withoutExpiredGoodbyes(GOODBYE_GIVE_UP_MS).goodbyes.isEmpty())
    }

    @Test fun pairingTheSameComputerAgainReplacesItAndRetiresTheOldKey() {
        val again = pc.copy(phoneId = "p9", key = "cc")
        val s = StoreData(listOf(pc)).withPaired(again, 50L)
        assertEquals(listOf(again), s.computers)
        assertEquals("p1", s.goodbyes.single().phoneId)
        val t = StoreData(listOf(pc)).withRemoved("id1", 1L).withPaired(again, 2L)
        assertEquals(listOf(again), t.computers)
        assertEquals("p1", t.goodbyes.single().phoneId)
    }

    @Test fun goodbyeIsDeliveredWithTheOldKey() {
        val agent = FakeAgent()
        val c = paired(agent)
        val g = StoreData(listOf(c)).withRemoved(c.id, 1L).goodbyes.single()
        assertTrue(Client(agent).call(ep, g.id, g.phoneId, Proto.unhex(g.key), op("forget")) is Reply.Ok)
        assertTrue(agent.phones.isEmpty())
    }

    private val statusJson = """{"ok":true,"id":"x","name":"kids-laptop","os":"Ubuntu 26.04","dry":false,
        "timer":{"remaining":754,"warn":true},"users":[
        {"name":"dad","full":"Dad","admin":true,"state":"none"},
        {"name":"classes","full":"","admin":false,"state":"locked"},
        {"name":"gaming","full":"Gaming","admin":false,"state":"active"}]}"""

    @Test fun statusParses() {
        val s = parseStatus(JSONObject(statusJson))
        assertEquals("kids-laptop", s.name)
        assertEquals(754, s.timerSeconds)
        assertTrue(s.warn)
        assertEquals(listOf(UserState.NONE, UserState.LOCKED, UserState.ACTIVE), s.users.map { it.state })
        assertEquals("classes", s.users[1].display)
        assertTrue(s.users[0].admin)
        assertNull(parseStatus(JSONObject("""{"ok":true,"timer":null}""")).timerSeconds)
    }

    @Test fun headlineSaysWhoIsUsingIt() {
        val s = parseStatus(JSONObject(statusJson))
        assertEquals("Gaming is using it · classes also logged in", s.headline())
        val locked = s.copy(users = s.users.filter { it.state != UserState.ACTIVE })
        assertEquals("On, classes logged in, screen locked", locked.headline())
        fun u(name: String, state: UserState) = UserInfo(name, "", false, state)
        val three = s.copy(users = listOf(u("dad", UserState.LOGGED_IN), u("quran", UserState.ACTIVE), u("gaming", UserState.LOGGED_IN)))
        assertEquals("quran is using it · dad and gaming also logged in", three.headline())
        assertEquals("On, dad logged in", three.copy(users = three.users.take(1)).headline())
        assertEquals("Quran is using it · Baba and gaming also logged in", three.headline { mapOf("quran" to "Quran", "dad" to "Baba")[it.name] ?: it.display })
        assertEquals("On, nobody logged in", s.copy(users = s.users.take(1)).headline())
        assertEquals("On, nobody logged in", cardLine(Link.ON, s.copy(users = emptyList()), "Ubuntu 24.04"))
        assertEquals("Off", cardLine(Link.OFF, null, "Ubuntu 24.04"))
        assertEquals("Off or asleep", cardLine(Link.OFF, null, "macOS 27.0"))
        assertEquals("Needs pairing again", cardLine(Link.NOT_RECOGNISED, s, ""))
    }

    @Test fun statusCarriesInternetAndAbilities() {
        val s = parseStatus(JSONObject("""{"ok":true,"name":"pc","caps":["seconds","net","login"],"timer":null,"users":[
            {"name":"dad","admin":true,"state":"active","net":"on"},
            {"name":"gaming","admin":false,"state":"none","net":"off"},
            {"name":"quran","admin":false,"state":"none","net":"on","net_timer":{"remaining":90,"warn":false}}]}"""))
        assertEquals(setOf("seconds", "net", "login"), s.caps)
        assertEquals(listOf(false, true, false), s.users.map { it.netOff })
        assertEquals(listOf(null, null, 90), s.users.map { it.netSeconds })
        val old = parseStatus(JSONObject(statusJson))
        assertTrue(old.caps.isEmpty() && old.users.none { it.netOff || it.netSeconds != null })
    }

    @Test fun namesGivenInTheAppStayOnThePhone() {
        val s = StoreData(listOf(pc)).withAlias("id1", "  Fatima's   computer ").withUserAlias("id1", "gaming-user", "Gaming")
        val c = s.computers.single()
        assertEquals("Fatima's computer", c.title)
        assertEquals("laptop", c.name)
        assertEquals("Gaming", c.userTitle(UserInfo("gaming-user", "Gaming User", false, UserState.NONE)))
        assertEquals("Quran", c.userTitle(UserInfo("quran", "Quran", false, UserState.NONE)))
        assertEquals(s, StoreData.fromJson(s.toJson()))
        val back = s.withAlias("id1", " ").withUserAlias("id1", "gaming-user", "")
        assertEquals("laptop", back.computers.single().title)
        assertTrue(back.computers.single().userAliases.isEmpty())
        assertEquals("Fatima's computer", s.withPaired(pc.copy(phoneId = "p9", key = "cc"), 9L).computers.single().title)
        val mac = StoreData(listOf(pc.copy(os = "macOS 27.0")))
        assertEquals(mac, StoreData.fromJson(mac.toJson()))
        assertEquals("macOS 27.0", mac.withPaired(pc.copy(phoneId = "p9", key = "cc"), 9L).computers.single().os)
        val v1 = """{"computers":[{"id":"id1","name":"laptop","phone":"p1","key":"aa","host":"192.168.1.20","port":787,"added":5}],"goodbyes":[]}"""
        assertEquals(StoreData(listOf(pc)), StoreData.fromJson(v1))
    }

    @Test fun timerChoices() {
        assertEquals(60, TIMER_MIN_SECONDS)
        assertEquals(listOf(60, 120, 180, 240, 300, 600), timerSteps().take(6))
        assertEquals(6 * 3600, timerSteps().last())
        assertEquals(300, timerSteps(300, 6 * 3600).first())
        assertEquals(listOf(900, 1800, 2700, 3600), TIMER_PRESETS)
        assertEquals(timerSteps(), timerSteps().distinct().sorted())
        assertEquals("15 s", formatLength(15))
        assertEquals("1 min", formatLength(60))
        assertEquals("1 h 30 min", formatLength(5400))
        assertEquals("6 h", formatLength(21600))
    }

    @Test fun appsParse() {
        val a = parseApps(JSONObject("""{"ok":true,"apps":[{"name":"Minecraft","detail":"java -jar TLauncher.jar","age":125,"terminal":true},{"name":""}]}"""))
        assertEquals(listOf(AppInfo("Minecraft", "java -jar TLauncher.jar", 125, true)), a)
    }

    @Test fun diagnosis() {
        val home = NetInfo(true, listOf("192.168.1.7" to 24))
        assertEquals(Link.OFF, diagnose(home, "192.168.1.20", false))
        assertEquals(Link.NOT_RUNNING, diagnose(home, "192.168.1.20", true))
        assertEquals(Link.OTHER_WIFI, diagnose(NetInfo(true, listOf("10.0.0.5" to 24)), "192.168.1.20", false))
        assertEquals(Link.NO_WIFI, diagnose(NetInfo(false, emptyList()), "192.168.1.20", false))
        assertTrue(inSubnet("192.168.1.20", "192.168.0.7", 16))
        assertFalse(inSubnet("192.168.2.20", "192.168.1.7", 24))
        assertFalse(inSubnet("laptop.local", "192.168.1.7", 24))
    }

    @Test fun formatting() {
        assertEquals("0:05", formatCountdown(5))
        assertEquals("12:34", formatCountdown(754))
        assertEquals("1:00:00", formatCountdown(3600))
        assertEquals("0:00", formatCountdown(-3))
        assertEquals("45 min", formatMinutes(45))
        assertEquals("2 h", formatMinutes(120))
        assertEquals("1 h 30 min", formatMinutes(90))
        assertEquals("just now", formatDuration(20))
        assertEquals("5m", formatDuration(300))
        assertEquals("1h 30m", formatDuration(5400))
        assertEquals("5h", formatDuration(5 * 3600 + 5))
        assertEquals("3d", formatDuration(3 * 86400))
        assertEquals("less than a minute", inWords(40))
        assertEquals("1 minute", inWords(60))
        assertEquals("24 minutes", inWords(23 * 60 + 10))
    }

    @Test fun homeLedeSummarisesTheHouse() {
        assertEquals("Nothing paired yet.", homeLede(emptyList()).text())
        assertEquals("All quiet.", homeLede(listOf(Glance("iMac", Link.OFF, null))).text())
        assertEquals("Checking…", homeLede(listOf(Glance("iMac", Link.CHECKING, null))).text())
        val house = listOf(Glance("MacBook Pro", Link.ON, 1450), Glance("ThinkPad", Link.OFF, null), Glance("Studio iMac", Link.OFF, null))
        val lede = homeLede(house)
        assertEquals("One is still on. MacBook Pro shuts down in 25 minutes.", lede.text())
        assertEquals(listOf("MacBook Pro"), lede.filter { it.strong }.map { it.text })
        assertEquals("Both are on.", homeLede(listOf(Glance("a", Link.ON, null), Glance("b", Link.ON, null))).text())
        assertEquals("It is on. a is shutting down.", homeLede(listOf(Glance("a", Link.ON, 0))).text())
    }

    @Test fun computerLedeReadsAsSentences() {
        val s = parseStatus(JSONObject(statusJson))
        assertEquals("Gaming is using it. classes also logged in. Shuts down in 12:34.", computerLede(Link.ON, s, "Ubuntu", 754).text())
        assertEquals("Off or asleep. This page updates when it wakes.", computerLede(Link.OFF, null, "macOS 27.0", null).text())
        assertTrue(computerLede(Link.OFF, null, "Ubuntu 24.04", null).text().startsWith("Off, asleep or not on the Wi-Fi."))
    }

    @Test fun accountLedeAndUserLines() {
        val work = UserInfo("work", "Work", false, UserState.LOCKED, netSeconds = 2400)
        assertEquals("Locked. Internet is on until 22:27.", accountLede(true, work, true, "22:27").text())
        assertEquals("Locked.", accountLede(true, work, false, "22:27").text())
        assertEquals("Not logged in. Internet is off.", accountLede(true, work.copy(state = UserState.NONE, netOff = true), true, null).text())
        assertEquals("The computer cannot be reached.", accountLede(false, work, true, null).text())
        assertEquals("Locked, internet off in 40 minutes", userLine(work))
        assertEquals("Admin, in use", userLine(UserInfo("rafay", "", true, UserState.ACTIVE)))
        assertEquals("Not logged in", userLine(UserInfo("guest", "", false, UserState.NONE)))
    }
}
