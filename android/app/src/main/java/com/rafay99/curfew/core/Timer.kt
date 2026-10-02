package com.rafay99.curfew.core

import org.json.JSONObject

const val TIMER_MIN_SECONDS = 60
const val TIMER_MAX_SECONDS = 6 * 3600

val TIMER_PRESETS = listOf(15, 30, 45, 60).map { it * 60 }

fun timerSteps(min: Int = TIMER_MIN_SECONDS, max: Int = TIMER_MAX_SECONDS): List<Int> =
    ((1..5).map { it * 60 } + (2..12).map { it * 300 } + (5..24).map { it * 900 }).filter { it in min..max }

fun lengthArgs(seconds: Int, warn: Boolean): JSONObject = JSONObject().put("seconds", seconds).put("warn", warn).apply {
    if (seconds > 0 && seconds % 60 == 0) put("minutes", seconds / 60)
}
