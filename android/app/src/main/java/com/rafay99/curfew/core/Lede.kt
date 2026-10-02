package com.rafay99.curfew.core

data class Part(val text: String, val strong: Boolean = false)

fun List<Part>.text() = joinToString("") { it.text }

data class Glance(val title: String, val link: Link, val secondsLeft: Int?)

private val counts = listOf("None", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten")

private fun countOn(on: Int, total: Int): String = when {
    total == 1 -> "It is on."
    on == total && total == 2 -> "Both are on."
    on == total -> "All $total are on."
    else -> "${counts.getOrElse(on) { "$on" }} ${if (on == 1) "is" else "are"} still on."
}

fun homeLede(all: List<Glance>): List<Part> {
    if (all.isEmpty()) return listOf(Part("Nothing paired yet."))
    val on = all.filter { it.link == Link.ON }
    if (on.isEmpty()) return listOf(Part(if (all.any { it.link == Link.CHECKING }) "Checking…" else "All quiet."))
    val count = countOn(on.size, all.size)
    val soon = on.mapNotNull { g -> g.secondsLeft?.let { g to it } }.minByOrNull { it.second }
        ?: return listOf(Part(count))
    val (g, seconds) = soon
    val tail = if (seconds > 0) " shuts down in ${inWords(seconds)}." else " is shutting down."
    return listOf(Part("$count "), Part(g.title, strong = true), Part(tail))
}

fun computerLede(link: Link, status: Status?, os: String, secondsLeft: Int?, nameOf: (UserInfo) -> String = { it.display }): List<Part> =
    when (link) {
        Link.CHECKING -> listOf(Part("Checking…"))
        Link.ON -> {
            val who = (status?.headline(nameOf) ?: "On").replace(" · ", ". ") + "."
            when {
                secondsLeft == null -> listOf(Part(who))
                secondsLeft > 0 -> listOf(Part("$who "), Part("Shuts down in ${formatCountdown(secondsLeft)}.", strong = true))
                else -> listOf(Part("$who "), Part("Shutting down now.", strong = true))
            }
        }
        Link.OFF -> listOf(Part(
            if (isMac(os)) "Off or asleep. This page updates when it wakes."
            else "Off, asleep or not on the Wi-Fi. This page updates when it is back."
        ))
        Link.NOT_RUNNING -> listOf(Part("On, but the agent is not answering. Restarting the computer usually fixes it."))
        Link.NO_WIFI -> listOf(Part("This phone is not on Wi-Fi. Turn Wi-Fi on to reach it."))
        Link.OTHER_WIFI -> listOf(Part("This phone is on another network. Join the home Wi-Fi to reach it."))
        Link.NOT_RECOGNISED -> listOf(Part("It no longer knows this phone, probably after a reinstall. Remove it below, run sudo curfew pair on it and add it again."))
    }

fun accountLede(reachable: Boolean, user: UserInfo?, net: Boolean, netUntil: String?): List<Part> {
    if (!reachable) return listOf(Part("The computer cannot be reached."))
    if (user == null) return listOf(Part("This account no longer exists."))
    val state = when (user.state) {
        UserState.ACTIVE -> "In use right now."
        UserState.LOCKED -> "Locked."
        UserState.LOGGED_IN -> "Logged in, in the background."
        UserState.NONE -> "Not logged in."
    }
    return when {
        !net || user.admin -> listOf(Part(state))
        user.netOff -> listOf(Part("$state Internet is off."))
        netUntil != null -> listOf(Part("$state Internet is on until "), Part(netUntil, strong = true), Part("."))
        else -> listOf(Part(state))
    }
}

fun userLine(u: UserInfo): String {
    val state = when (u.state) {
        UserState.ACTIVE -> "In use"
        UserState.LOCKED -> "Locked"
        UserState.LOGGED_IN -> "Logged in"
        UserState.NONE -> "Not logged in"
    }
    val net = when {
        u.admin -> null
        u.netOff -> "internet off"
        u.netSeconds != null -> "internet off in ${inWords(u.netSeconds)}"
        else -> null
    }
    return listOfNotNull("Admin".takeIf { u.admin }, state, net)
        .mapIndexed { i, p -> if (i == 0) p else p.replaceFirstChar(Char::lowercase) }
        .joinToString(", ")
}
