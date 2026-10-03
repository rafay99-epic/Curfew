package com.rafay99.curfew.core

import org.json.JSONObject
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WakeTest {
    private val mac = Computer("id1", "studio", "p1", "aa", "192.168.1.30", 787, 5L, os = "macOS 27.0", wake = "aa:bb:cc:dd:ee:ff")

    @Test fun magicPacketIsSixFfThenTheAddressSixteenTimes() {
        val p = magicPacket("aa:bb:cc:dd:ee:ff")
        assertEquals(102, p.size)
        assertArrayEquals(ByteArray(6) { -1 }, p.copyOfRange(0, 6))
        val hw = byteArrayOf(0xaa.toByte(), 0xbb.toByte(), 0xcc.toByte(), 0xdd.toByte(), 0xee.toByte(), 0xff.toByte())
        for (i in 0 until 16) assertArrayEquals(hw, p.copyOfRange(6 + i * 6, 12 + i * 6))
    }

    @Test fun hardwareAddressParses() {
        assertEquals("aa:bb:cc:dd:ee:ff", parseHardwareAddress("aa:bb:cc:dd:ee:ff"))
        assertEquals("aa:bb:cc:dd:ee:0f", parseHardwareAddress(" AA:BB:CC:DD:EE:0F "))
        assertEquals("aa:bb:cc:dd:ee:ff", parseHardwareAddress("aa-bb-cc-dd-ee-ff"))
        listOf("", "aa:bb:cc:dd:ee", "aa:bb:cc:dd:ee:ff:00", "aa:bb-cc:dd:ee:ff", "aabbccddeeff", "gg:bb:cc:dd:ee:ff", "a:bb:cc:dd:ee:ff")
            .forEach { assertNull(it, parseHardwareAddress(it)) }
    }

    @Test fun broadcastAddressOfTheSubnet() {
        assertEquals("192.168.1.255", broadcastOf("192.168.1.42", 24))
        assertEquals("10.0.15.255", broadcastOf("10.0.8.3", 20))
        assertNull(broadcastOf("192.168.1.42", 32))
        assertNull(broadcastOf("fe80::1", 64))
    }

    @Test fun statusCarriesTheWakeAddressOnlyFromAMac() {
        val s = parseStatus(JSONObject("""{"ok":true,"name":"studio","os":"macOS 27.0","caps":["seconds","net"],"timer":null,"users":[],"wake":"AA:BB:CC:DD:EE:FF"}"""))
        assertEquals("aa:bb:cc:dd:ee:ff", s.wake)
        assertNull(parseStatus(JSONObject("""{"ok":true,"name":"pc","os":"Ubuntu 26.04","timer":null,"users":[]}""")).wake)
        assertNull(parseStatus(JSONObject("""{"ok":true,"name":"pc","timer":null,"users":[],"wake":"nope"}""")).wake)
    }

    @Test fun storeKeepsTheWakeAddress() {
        val s = StoreData(listOf(mac))
        assertEquals(s, StoreData.fromJson(s.toJson()))
        assertEquals("aa:bb:cc:dd:ee:ff", s.withPaired(mac.copy(phoneId = "p9", key = "cc", wake = ""), 9L).computers.single().wake)
    }

    @Test fun macWithoutAStoredPasswordSaysWhatToDo() =
        assertEquals("Type the password at this Mac's login screen once first. After that the phone can log it in.", errorText("no_password"))
}
