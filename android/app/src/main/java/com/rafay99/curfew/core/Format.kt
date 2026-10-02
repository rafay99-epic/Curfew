package com.rafay99.curfew.core

fun formatCountdown(seconds: Int): String {
    val s = seconds.coerceAtLeast(0)
    return if (s >= 3600) "%d:%02d:%02d".format(s / 3600, s % 3600 / 60, s % 60) else "%d:%02d".format(s / 60, s % 60)
}

fun formatMinutes(m: Int): String = when {
    m < 60 -> "$m min"
    m % 60 == 0 -> "${m / 60} h"
    else -> "${m / 60} h ${m % 60} min"
}

fun formatLength(seconds: Int): String = if (seconds < 60) "$seconds s" else formatMinutes(seconds / 60)

fun formatDuration(seconds: Long): String {
    val m = seconds / 60
    return when {
        m < 1 -> "just now"
        m < 60 -> "${m}m"
        m < 48 * 60 -> if (m % 60 == 0L) "${m / 60}h" else "${m / 60}h ${m % 60}m"
        else -> "${m / 1440}d"
    }
}

fun inWords(seconds: Int): String {
    val m = (seconds + 59) / 60
    return when {
        seconds < 60 -> "less than a minute"
        m == 1 -> "1 minute"
        m < 60 -> "$m minutes"
        else -> formatMinutes(m)
    }
}

fun errorText(error: String): String = when (error) {
    "not_logged_in" -> "That account is not logged in"
    "bad_user" -> "That account no longer exists"
    "is_admin" -> "Internet stays on for admin accounts"
    "unsupported" -> "That computer cannot do this"
    "bad_op", "bad_args" -> "The agent on that computer is too old for this. Update it there."
    else -> "The computer could not do that"
}
