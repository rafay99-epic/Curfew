package com.rafay99.curfew.data

import com.rafay99.curfew.core.Endpoint
import com.rafay99.curfew.core.HttpResult
import com.rafay99.curfew.core.Transport
import java.net.HttpURLConnection
import java.net.URL

object HttpTransport : Transport {
    override fun send(to: Endpoint, path: String, body: String?): HttpResult {
        val con = URL("http://${to.host}:${to.port}$path").openConnection() as HttpURLConnection
        try {
            con.connectTimeout = 2500
            con.readTimeout = 6000
            con.useCaches = false
            if (body != null) {
                con.requestMethod = "POST"
                con.doOutput = true
                con.setRequestProperty("Content-Type", "application/json")
                con.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
            val code = con.responseCode
            val stream = if (code in 200..299) con.inputStream else con.errorStream
            return HttpResult(code, stream?.use { it.readBytes().toString(Charsets.UTF_8) } ?: "")
        } finally {
            con.disconnect()
        }
    }
}
