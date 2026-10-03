package com.rafay99.curfew.core

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class ProtocolVectorsTest {
    private val vectors = JSONObject(vectorsFile().readText())

    private fun vectorsFile(): File {
        val start = File("").absoluteFile
        return generateSequence(start) { it.parentFile }
            .map { File(it, "protocol/vectors.json") }
            .firstOrNull { it.isFile }
            ?: error("protocol/vectors.json not found in $start or any parent")
    }

    private fun cases(name: String): List<JSONObject> {
        val a = vectors.getJSONArray(name)
        return (0 until a.length()).map(a::getJSONObject).also { assertTrue("no $name vectors", it.isNotEmpty()) }
    }

    private fun JSONArray.strings() = (0 until length()).map(::getString)

    @Test fun keyDerivationMatchesEveryVector() = cases("derive_key").forEach {
        val key = Proto.deriveKey(it.getString("code"), it.getString("snonce"), it.getString("cnonce"), it.getString("phone"))
        assertEquals(it.toString(), it.getString("key_hex"), Proto.hex(key))
    }

    @Test fun macMatchesEveryVector() = cases("mac").forEach {
        val parts = it.getJSONArray("parts").strings().toTypedArray()
        assertEquals(it.toString(), it.getString("mac"), Proto.mac(Proto.unhex(it.getString("key_hex")), *parts))
    }

    @Test fun codeCleanupMatchesEveryVector() = cases("clean_code").forEach {
        assertEquals(it.toString(), it.getString("out"), Proto.cleanCode(it.getString("in")))
    }
}
