package com.rafay99.curfew.data

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import com.rafay99.curfew.core.Endpoint
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import java.net.Inet4Address

class Discovery(context: Context) {
    private val nsd = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val _found = MutableStateFlow<Map<String, Endpoint>>(emptyMap())
    val found: StateFlow<Map<String, Endpoint>> = _found
    private var listener: NsdManager.DiscoveryListener? = null
    private val queue = ArrayDeque<NsdServiceInfo>()
    private var resolving = false

    @Synchronized
    fun start() {
        if (listener != null) return
        val l = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(type: String) {}
            override fun onDiscoveryStopped(type: String) {}
            override fun onStartDiscoveryFailed(type: String, code: Int) {}
            override fun onStopDiscoveryFailed(type: String, code: Int) {}
            override fun onServiceLost(info: NsdServiceInfo) {}
            override fun onServiceFound(info: NsdServiceInfo) {
                synchronized(this@Discovery) { queue.addLast(info) }
                next()
            }
        }
        try {
            nsd.discoverServices("_curfew._tcp", NsdManager.PROTOCOL_DNS_SD, l)
            listener = l
        } catch (e: Exception) {
            listener = null
        }
    }

    @Synchronized
    fun stop() {
        listener?.let { runCatching { nsd.stopServiceDiscovery(it) } }
        listener = null
        queue.clear()
        resolving = false
    }

    private fun done() {
        synchronized(this) { resolving = false }
        next()
    }

    @Suppress("DEPRECATION")
    private fun next() {
        val info = synchronized(this) {
            if (resolving) return
            val i = queue.removeFirstOrNull() ?: return
            resolving = true
            i
        }
        try {
            nsd.resolveService(info, object : NsdManager.ResolveListener {
                override fun onResolveFailed(info: NsdServiceInfo, code: Int) = done()
                override fun onServiceResolved(info: NsdServiceInfo) {
                    val id = info.attributes["id"]?.let { String(it) }
                    val host = (info.host as? Inet4Address)?.hostAddress
                    if (id != null && host != null) _found.update { it + (id to Endpoint(host, info.port)) }
                    done()
                }
            })
        } catch (e: Exception) {
            done()
        }
    }
}
