package com.rafay99.curfew.data

import com.rafay99.curfew.core.Link
import com.rafay99.curfew.core.Status

data class Live(
    val link: Link = Link.CHECKING, val status: Status? = null, val timerEndsAt: Long? = null, val fails: Int = 0,
    val netEndsAt: Map<String, Long> = emptyMap(),
)
