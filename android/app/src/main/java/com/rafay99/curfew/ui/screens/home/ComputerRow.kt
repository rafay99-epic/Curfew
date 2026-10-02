package com.rafay99.curfew.ui.screens.home

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.rafay99.curfew.core.Computer
import com.rafay99.curfew.core.Link
import com.rafay99.curfew.core.cardLine
import com.rafay99.curfew.core.formatCountdown
import com.rafay99.curfew.core.shortOs
import com.rafay99.curfew.data.Live
import com.rafay99.curfew.ui.components.HairlineRow
import com.rafay99.curfew.ui.components.secondsLeft
import com.rafay99.curfew.ui.theme.Ink
import com.rafay99.curfew.ui.theme.Mono
import com.rafay99.curfew.ui.theme.Type

@Composable
internal fun ComputerRow(c: Computer, live: Live, tag: String?, onClick: () -> Unit) {
    val remaining = secondsLeft(live.timerEndsAt.takeIf { live.link == Link.ON })
    val os = shortOs(c.os)
    val line = cardLine(live.link, live.status, c.os, c::userTitle)
    val status = buildAnnotatedString {
        append(line)
        when {
            remaining != null -> {
                append(" · ")
                withStyle(SpanStyle(fontFamily = Mono, color = Ink.Text, fontWeight = FontWeight.Medium)) {
                    append(if (remaining > 0) formatCountdown(remaining) else "now")
                }
            }
            os.isNotEmpty() && live.link in setOf(Link.ON, Link.OFF) -> append(" · $os")
        }
    }
    HairlineRow(onClick) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(c.title, style = Type.Name, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
            if (tag != null) Text("  #$tag", style = Type.MonoSmall, maxLines = 1, modifier = Modifier.padding(bottom = 4.dp))
        }
        Spacer(Modifier.size(5.dp))
        Text(status, style = Type.Status, maxLines = 3, overflow = TextOverflow.Ellipsis)
    }
}
