package com.rafay99.curfew.data

import android.content.Context
import com.rafay99.curfew.core.broadcastOf
import com.rafay99.curfew.core.magicPacket
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress

internal suspend fun sendWake(context: Context, address: String, host: String) = withContext(Dispatchers.IO) {
    val packet = magicPacket(address)
    val net = currentNet(context)
    val subnets = if (net.wifi) net.nets.mapNotNull { (a, p) -> broadcastOf(a, p) } else emptyList()
    runCatching {
        DatagramSocket().use { socket ->
            socket.broadcast = true
            for (to in (listOf("255.255.255.255") + subnets + host).distinct())
                runCatching { socket.send(DatagramPacket(packet, packet.size, InetAddress.getByName(to), 9)) }
        }
    }
}
