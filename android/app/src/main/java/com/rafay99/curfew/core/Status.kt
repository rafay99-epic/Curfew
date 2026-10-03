package com.rafay99.curfew.core

import org.json.JSONArray
import org.json.JSONObject

enum class UserState {
    NONE, LOGGED_IN, LOCKED, ACTIVE;

    companion object {
        fun of(s: String) = when (s) {
            "active" -> ACTIVE
            "locked" -> LOCKED
            "logged_in" -> LOGGED_IN
            else -> NONE
        }
    }
}

data class UserInfo(
    val name: String, val full: String, val admin: Boolean, val state: UserState,
    val netOff: Boolean = false, val netSeconds: Int? = null,
) {
    val display get() = full.ifBlank { name }
}

data class Status(
    val name: String, val os: String, val users: List<UserInfo>, val timerSeconds: Int?, val warn: Boolean,
    val caps: Set<String> = emptySet(), val wake: String? = null,
) {
    fun headline(nameOf: (UserInfo) -> String = { it.display }): String {
        fun names(vararg s: UserState) = users.filter { it.state in s }.map(nameOf)
        fun List<String>.all() = if (size > 1) dropLast(1).joinToString(", ") + " and " + last() else joinToString()
        val active = names(UserState.ACTIVE)
        val locked = names(UserState.LOCKED)
        val idle = names(UserState.LOGGED_IN)
        val also = { others: List<String> -> if (others.isEmpty()) "" else " · " + others.all() + " also logged in" }
        return when {
            active.isNotEmpty() -> active.all() + (if (active.size > 1) " are" else " is") + " using it" + also(locked + idle)
            locked.isNotEmpty() -> "On, " + locked.all() + " logged in, screen locked" + also(idle)
            idle.isNotEmpty() -> "On, " + idle.all() + " logged in"
            else -> "On, nobody logged in"
        }
    }
}

data class AppInfo(val name: String, val detail: String, val ageSeconds: Long, val terminal: Boolean)

fun parseStatus(j: JSONObject): Status {
    val us = j.optJSONArray("users") ?: JSONArray()
    val t = j.optJSONObject("timer")
    return Status(
        name = j.optString("name").ifBlank { "Computer" },
        os = j.optString("os"),
        users = (0 until us.length()).mapNotNull { us.optJSONObject(it) }.filter { it.optString("name").isNotEmpty() }.map {
            UserInfo(it.optString("name"), it.optString("full"), it.optBoolean("admin"), UserState.of(it.optString("state")),
                it.optString("net") == "off", it.optJSONObject("net_timer")?.optInt("remaining"))
        },
        timerSeconds = t?.optInt("remaining"),
        warn = t?.optBoolean("warn") ?: false,
        caps = (j.optJSONArray("caps") ?: JSONArray()).let { c -> (0 until c.length()).map { c.optString(it) }.toSet() },
        wake = parseHardwareAddress(j.optString("wake")),
    )
}

fun parseApps(j: JSONObject): List<AppInfo> {
    val a = j.optJSONArray("apps") ?: JSONArray()
    return (0 until a.length()).mapNotNull { a.optJSONObject(it) }.filter { it.optString("name").isNotEmpty() }.map {
        AppInfo(it.optString("name"), it.optString("detail"), it.optLong("age"), it.optBoolean("terminal"))
    }
}
