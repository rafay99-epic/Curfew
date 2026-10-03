package com.rafay99.curfew.core

import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

const val DEFAULT_PORT = 787

data class Endpoint(val host: String, val port: Int)
data class PairLink(val endpoint: Endpoint, val id: String?, val code: String)
class HttpResult(val code: Int, val body: String)

fun interface Transport {
    fun send(to: Endpoint, path: String, body: String?): HttpResult
}

object Proto {
    private val random = SecureRandom()

    fun hex(b: ByteArray) = b.joinToString("") { "%02x".format(it) }
    fun unhex(s: String) = ByteArray(s.length / 2) { s.substring(it * 2, it * 2 + 2).toInt(16).toByte() }
    fun nonce(): String = hex(ByteArray(16).also(random::nextBytes))

    private fun hmac(key: ByteArray, msg: String): ByteArray =
        Mac.getInstance("HmacSHA256").run {
            init(SecretKeySpec(key, "HmacSHA256"))
            doFinal(msg.toByteArray(Charsets.UTF_8))
        }

    fun mac(key: ByteArray, vararg parts: String) = hex(hmac(key, parts.joinToString("\n")))

    fun deriveKey(code: String, snonce: String, cnonce: String, phoneId: String) =
        hmac(code.toByteArray(Charsets.UTF_8), listOf("key", snonce, cnonce, phoneId).joinToString("\n"))

    fun same(a: String, b: String) = MessageDigest.isEqual(a.toByteArray(), b.toByteArray())

    fun cleanCode(s: String) = s.uppercase().filter { it in 'A'..'Z' || it in '0'..'9' }

    fun parseAddress(text: String): Endpoint? {
        val t = text.trim().removePrefix("http://").trimEnd('/')
        val host = t.substringBefore(':')
        val port = if (':' in t) t.substringAfter(':').toIntOrNull() ?: return null else DEFAULT_PORT
        if (port !in 1..65535 || !Regex("[A-Za-z0-9.-]{1,253}").matches(host)) return null
        if (host.all { it.isDigit() || it == '.' }) {
            val parts = host.split('.')
            if (parts.size != 4 || parts.any { it.isEmpty() || it.length > 3 || it.toInt() > 255 }) return null
        }
        return Endpoint(host, port)
    }

    fun parsePairLink(text: String): PairLink? {
        val t = text.trim()
        if (!t.startsWith("curfew://pair?")) return null
        val q = t.substringAfter('?').split('&').mapNotNull {
            val i = it.indexOf('=')
            if (i < 1) null else it.substring(0, i) to it.substring(i + 1)
        }.toMap()
        val ep = parseAddress(q["a"] ?: return null) ?: return null
        val code = cleanCode(q["c"] ?: return null)
        if (code.length != 16) return null
        return PairLink(ep, q["i"]?.takeIf { it.isNotEmpty() }, code)
    }
}
