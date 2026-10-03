package com.rafay99.curfew.ui.screens.account

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rafay99.curfew.core.AppInfo
import com.rafay99.curfew.core.formatDuration
import com.rafay99.curfew.ui.components.hairline
import com.rafay99.curfew.ui.theme.Space
import com.rafay99.curfew.ui.theme.Type

internal fun LazyListScope.openApps(on: Boolean, loggedIn: Boolean, apps: List<AppInfo>?, failed: Boolean) {
    item {
        Column(Modifier.fillMaxWidth().padding(top = 14.dp).hairline().padding(start = Space.Gutter, end = Space.Gutter, top = 15.dp)) {
            Text("Open now", style = Type.Body)
            Spacer(Modifier.size(4.dp))
            val empty = when {
                !on -> "Nothing to show while the computer cannot be reached."
                !loggedIn -> "Not logged in, so nothing is open."
                apps == null && failed -> "Could not get the list. Trying again."
                apps == null -> "Looking…"
                apps.isEmpty() -> "Nothing is open."
                else -> null
            }
            if (empty != null) Text(empty, style = Type.Status)
        }
    }
    if (on && loggedIn && !apps.isNullOrEmpty()) items(apps) { a ->
        val note = if (a.terminal) "terminal, ${formatDuration(a.ageSeconds)}" else formatDuration(a.ageSeconds)
        Text(
            buildAnnotatedString {
                append(a.name)
                append("  ")
                withStyle(Type.MonoSmall.toSpanStyle()) { append(note) }
            },
            style = Type.Body.copy(fontSize = 15.sp, lineHeight = 27.sp), maxLines = 2, overflow = TextOverflow.Ellipsis,
            modifier = Modifier.fillMaxWidth().padding(horizontal = Space.Gutter),
        )
    }
}
