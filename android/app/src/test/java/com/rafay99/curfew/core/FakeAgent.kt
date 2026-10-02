package com.rafay99.curfew.core

import org.json.JSONObject
import java.io.IOException

class FakeAgent(val id: String = "a1b2c3d4e5f60718") : Transport {
    val phones = HashMap<String, ByteArray>()
    val removed = HashMap<String, ByteArray>()
    val nonces = HashSet<String>()
    var code: String? = null
    var down: IOException? = null
    var tamper = false
    val ops = ArrayList<String>()
    val sent = ArrayList<String>()

    override fun send(to: Endpoint, path: String, body: String?): HttpResult {
        down?.let { throw it }
        if (path == "/v1/hello") {
            val n = Proto.nonce().also(nonces::add)
            return HttpResult(200, JSONObject().put("app", "curfew").put("id", id).put("name", "laptop").put("nonce", n).toString())
        }
        sent.add(body!!)
        val req = JSONObject(body)
        val s = req.getString("snonce")
        val c = req.getString("cnonce")
        val payload = req.getString("payload")
        fun err(code: Int, e: String) = HttpResult(code, JSONObject().put("error", e).toString())
        if (path == "/v1/pair") {
            if (!nonces.remove(s)) return err(409, "bad_nonce")
            val pc = code ?: return err(403, "no_pairing")
            if (Proto.mac(pc.toByteArray(), "pair", s, c, payload) != req.getString("mac")) return err(403, "bad_code")
            val pid = Proto.nonce().take(16)
            val key = Proto.deriveKey(pc, s, c, pid)
            phones[pid] = key
            code = null
            val out = JSONObject().put("ok", true).put("id", id).put("name", "laptop").toString()
            return HttpResult(200, JSONObject().put("phone", pid).put("payload", out).put("mac", Proto.mac(key, "res", pid, s, c, out)).toString())
        }
        val pid = req.getString("phone")
        val key = phones[pid] ?: removed[pid] ?: return err(403, "unknown_phone")
        if (Proto.mac(key, "req", pid, s, c, payload) != req.getString("mac")) return err(403, "bad_mac")
        if (!nonces.remove(s)) return err(409, "bad_nonce")
        val op = JSONObject(payload).getString("op")
        val out = when {
            pid !in phones -> JSONObject().put("ok", false).put("error", "unpaired")
            op == "logout" -> JSONObject().put("ok", false).put("error", "not_logged_in")
            else -> JSONObject().put("ok", true).also { ops.add(op); if (op == "forget") phones.remove(pid) }
        }.toString()
        val mac = Proto.mac(key, "res", pid, s, c, out)
        return HttpResult(200, JSONObject().put("payload", if (tamper) out.replace("true", "false") else out).put("mac", mac).toString())
    }
}
