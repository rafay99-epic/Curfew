package com.rafay99.curfew.core

data class Computer(
    val id: String, val name: String, val phoneId: String, val key: String,
    val host: String, val port: Int, val addedAt: Long,
    val alias: String = "", val userAliases: Map<String, String> = emptyMap(), val os: String = "", val wake: String = "",
) {
    val title get() = alias.ifBlank { name }
    fun userTitle(u: UserInfo) = userAliases[u.name] ?: u.display
}

fun cleanAlias(text: String) = text.replace(Regex("\\s+"), " ").trim().take(40)

fun isMac(os: String) = os.startsWith("macOS")

fun shortOs(os: String) = os.substringBefore(' ')

data class Goodbye(val id: String, val phoneId: String, val key: String, val host: String, val port: Int, val since: Long)

const val GOODBYE_GIVE_UP_MS = 30L * 24 * 3600 * 1000
