package com.rafay99.curfew.core

enum class Link { CHECKING, ON, OFF, NOT_RUNNING, NO_WIFI, OTHER_WIFI, NOT_RECOGNISED }

data class NetInfo(val wifi: Boolean, val nets: List<Pair<String, Int>>)

fun cardLine(link: Link, status: Status?, os: String, nameOf: (UserInfo) -> String = { it.display }): String = when (link) {
    Link.CHECKING -> "Checking…"
    Link.ON -> status?.headline(nameOf) ?: "On"
    Link.OFF -> if (isMac(os)) "Off or asleep" else "Off"
    Link.NOT_RUNNING -> "On, but the agent is not answering"
    Link.NO_WIFI -> "This phone is not on Wi-Fi"
    Link.OTHER_WIFI -> "This phone is on another network"
    Link.NOT_RECOGNISED -> "Needs pairing again"
}

fun inSubnet(host: String, addr: String, prefix: Int): Boolean {
    fun bits(s: String): Long? {
        val p = s.split('.')
        if (p.size != 4) return null
        return p.fold(0L) { acc, x -> (acc shl 8) or (x.toIntOrNull()?.takeIf { it in 0..255 } ?: return null).toLong() }
    }
    val a = bits(host) ?: return false
    val b = bits(addr) ?: return false
    if (prefix !in 1..32) return false
    val mask = (0xFFFFFFFFL shl (32 - prefix)) and 0xFFFFFFFFL
    return (a and mask) == (b and mask)
}

fun diagnose(net: NetInfo, host: String, refused: Boolean): Link = when {
    refused -> Link.NOT_RUNNING
    !net.wifi -> Link.NO_WIFI
    host.all { it.isDigit() || it == '.' } && net.nets.isNotEmpty() && net.nets.none { inSubnet(host, it.first, it.second) } -> Link.OTHER_WIFI
    else -> Link.OFF
}
