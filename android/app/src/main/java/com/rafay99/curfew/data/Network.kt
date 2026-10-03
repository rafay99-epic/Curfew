package com.rafay99.curfew.data

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.rafay99.curfew.core.NetInfo
import java.net.Inet4Address

internal fun currentNet(context: Context): NetInfo {
    val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    val n = cm.activeNetwork
    val caps = n?.let(cm::getNetworkCapabilities)
    val wifi = caps != null && (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) || caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET))
    val nets = n?.let(cm::getLinkProperties)?.linkAddresses.orEmpty()
        .filter { it.address is Inet4Address }.mapNotNull { a -> a.address.hostAddress?.let { it to a.prefixLength } }
    return NetInfo(wifi, nets)
}
