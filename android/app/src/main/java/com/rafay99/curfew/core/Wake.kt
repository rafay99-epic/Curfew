package com.rafay99.curfew.core

private val hardwareAddress = Regex("[0-9a-f]{2}([:-])[0-9a-f]{2}(\\1[0-9a-f]{2}){4}", RegexOption.IGNORE_CASE)

fun parseHardwareAddress(text: String): String? =
    text.trim().takeIf(hardwareAddress::matches)?.lowercase()?.replace('-', ':')

fun magicPacket(address: String): ByteArray {
    val hw = Proto.unhex(address.filter { it != ':' })
    return ByteArray(6) { -1 } + ByteArray(16 * 6) { hw[it % 6] }
}

fun broadcastOf(addr: String, prefix: Int): String? {
    val p = addr.split('.').map { it.toIntOrNull()?.takeIf { b -> b in 0..255 } ?: return null }
    if (p.size != 4 || prefix !in 1..30) return null
    val bits = p.fold(0L) { acc, b -> (acc shl 8) or b.toLong() }
    val all = bits or ((1L shl (32 - prefix)) - 1)
    return (3 downTo 0).joinToString(".") { (all shr (it * 8) and 0xFF).toString() }
}
