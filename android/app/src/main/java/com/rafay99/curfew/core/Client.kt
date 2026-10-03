package com.rafay99.curfew.core

import org.json.JSONObject
import java.io.IOException
import java.net.ConnectException

sealed interface Reply {
    data class Ok(val json: JSONObject) : Reply
    data class Denied(val error: String) : Reply
    data object Unpaired : Reply
    data object NotRecognised : Reply
    data class WrongComputer(val id: String) : Reply
    data object Fake : Reply
    data class Unreachable(val refused: Boolean) : Reply
}

sealed interface PairResult {
    data class Paired(val computer: Computer) : PairResult
    data object BadCode : PairResult
    data object Unreachable : PairResult
    data object WrongComputer : PairResult
    data object Fake : PairResult
}

class Client(private val transport: Transport) {

    private class Hello(val id: String, val nonce: String)

    private fun hello(to: Endpoint): Hello {
        val res = transport.send(to, "/v1/hello", null)
        val j = try { JSONObject(res.body) } catch (e: Exception) { throw IOException("not a Curfew agent") }
        if (res.code != 200 || j.optString("app") != "curfew") throw IOException("not a Curfew agent")
        return Hello(j.optString("id"), j.optString("nonce"))
    }

    private fun refused(e: IOException) =
        e is ConnectException && (e.message ?: "").contains("refused", ignoreCase = true)

    fun call(to: Endpoint, agentId: String, phoneId: String, key: ByteArray, payload: JSONObject): Reply {
        repeat(2) {
            try {
                val hello = hello(to)
                if (hello.id != agentId) return Reply.WrongComputer(hello.id)
                val cnonce = Proto.nonce()
                val text = payload.toString()
                val env = JSONObject().put("phone", phoneId).put("snonce", hello.nonce).put("cnonce", cnonce)
                    .put("payload", text).put("mac", Proto.mac(key, "req", phoneId, hello.nonce, cnonce, text))
                val res = transport.send(to, "/v1/call", env.toString())
                val body = JSONObject(res.body)
                if (res.code == 200) {
                    val answer = body.optString("payload")
                    val expect = Proto.mac(key, "res", phoneId, hello.nonce, cnonce, answer)
                    if (!Proto.same(expect, body.optString("mac"))) return Reply.Fake
                    val j = JSONObject(answer)
                    return when {
                        j.optBoolean("ok") -> Reply.Ok(j)
                        j.optString("error") == "unpaired" -> Reply.Unpaired
                        else -> Reply.Denied(j.optString("error"))
                    }
                }
                when (body.optString("error")) {
                    "bad_nonce" -> Unit
                    "unknown_phone", "bad_mac" -> return Reply.NotRecognised
                    else -> return Reply.Unreachable(false)
                }
            } catch (e: IOException) {
                return Reply.Unreachable(refused(e))
            } catch (e: Exception) {
                return Reply.Unreachable(false)
            }
        }
        return Reply.Unreachable(false)
    }

    fun pair(link: PairLink, phoneName: String, now: Long): PairResult {
        try {
            val to = link.endpoint
            val hello = hello(to)
            if (link.id != null && link.id != hello.id) return PairResult.WrongComputer
            val cnonce = Proto.nonce()
            val text = JSONObject().put("name", phoneName).toString()
            val env = JSONObject().put("snonce", hello.nonce).put("cnonce", cnonce).put("payload", text)
                .put("mac", Proto.mac(link.code.toByteArray(), "pair", hello.nonce, cnonce, text))
            val res = transport.send(to, "/v1/pair", env.toString())
            val body = JSONObject(res.body)
            if (res.code != 200) {
                return if (body.optString("error") in setOf("bad_code", "no_pairing")) PairResult.BadCode
                else PairResult.Unreachable
            }
            val phoneId = body.getString("phone")
            val answer = body.getString("payload")
            val key = Proto.deriveKey(link.code, hello.nonce, cnonce, phoneId)
            if (!Proto.same(Proto.mac(key, "res", phoneId, hello.nonce, cnonce, answer), body.optString("mac")))
                return PairResult.Fake
            val j = JSONObject(answer)
            return PairResult.Paired(
                Computer(id = j.getString("id"), name = j.optString("name").ifBlank { "Computer" },
                    phoneId = phoneId, key = Proto.hex(key), host = to.host, port = to.port, addedAt = now)
            )
        } catch (e: Exception) {
            return PairResult.Unreachable
        }
    }
}
