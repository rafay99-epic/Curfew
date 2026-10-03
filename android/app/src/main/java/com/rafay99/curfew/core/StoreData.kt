package com.rafay99.curfew.core

import org.json.JSONArray
import org.json.JSONObject

data class StoreData(val computers: List<Computer> = emptyList(), val goodbyes: List<Goodbye> = emptyList()) {

    fun toJson(): String = JSONObject()
        .put("computers", JSONArray(computers.map {
            JSONObject().put("id", it.id).put("name", it.name).put("phone", it.phoneId).put("key", it.key)
                .put("host", it.host).put("port", it.port).put("added", it.addedAt)
                .put("alias", it.alias).put("users", JSONObject(it.userAliases)).put("os", it.os).put("wake", it.wake)
        }))
        .put("goodbyes", JSONArray(goodbyes.map {
            JSONObject().put("id", it.id).put("phone", it.phoneId).put("key", it.key)
                .put("host", it.host).put("port", it.port).put("since", it.since)
        }))
        .toString()

    fun withPaired(c: Computer, now: Long): StoreData {
        val old = computers.find { it.id == c.id }
        val named = if (old == null) c else c.copy(alias = old.alias, userAliases = old.userAliases, os = old.os, wake = old.wake)
        return copy(
            computers = computers.filter { it.id != c.id } + named,
            goodbyes = goodbyes + listOfNotNull(old?.let { Goodbye(it.id, it.phoneId, it.key, it.host, it.port, now) }),
        )
    }

    fun withRemoved(id: String, now: Long): StoreData {
        val c = computers.find { it.id == id } ?: return this
        return copy(computers = computers - c, goodbyes = goodbyes + Goodbye(c.id, c.phoneId, c.key, c.host, c.port, now))
    }

    fun withAlias(id: String, alias: String) =
        copy(computers = computers.map { if (it.id == id) it.copy(alias = cleanAlias(alias)) else it })

    fun withUserAlias(id: String, user: String, alias: String) = copy(computers = computers.map {
        val a = cleanAlias(alias)
        if (it.id != id) it else it.copy(userAliases = if (a.isEmpty()) it.userAliases - user else it.userAliases + (user to a))
    })

    fun withoutExpiredGoodbyes(now: Long) = copy(goodbyes = goodbyes.filter { now - it.since < GOODBYE_GIVE_UP_MS })

    companion object {
        fun fromJson(text: String?): StoreData = try {
            val j = JSONObject(text ?: "{}")
            val cs = j.optJSONArray("computers") ?: JSONArray()
            val gs = j.optJSONArray("goodbyes") ?: JSONArray()
            StoreData(
                (0 until cs.length()).map { cs.getJSONObject(it) }.map {
                    val users = it.optJSONObject("users") ?: JSONObject()
                    Computer(it.getString("id"), it.getString("name"), it.getString("phone"), it.getString("key"),
                        it.getString("host"), it.getInt("port"), it.optLong("added"), it.optString("alias"),
                        users.keys().asSequence().associateWith { k -> users.optString(k) }, it.optString("os"),
                        parseHardwareAddress(it.optString("wake")).orEmpty())
                },
                (0 until gs.length()).map { gs.getJSONObject(it) }.map {
                    Goodbye(it.getString("id"), it.getString("phone"), it.getString("key"),
                        it.getString("host"), it.getInt("port"), it.optLong("since"))
                },
            )
        } catch (e: Exception) {
            StoreData()
        }
    }
}
