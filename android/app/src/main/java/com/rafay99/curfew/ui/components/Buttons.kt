package com.rafay99.curfew.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rafay99.curfew.ui.theme.Ink
import com.rafay99.curfew.ui.theme.Space
import com.rafay99.curfew.ui.theme.Type

private val SlabShape = RoundedCornerShape(Space.Slab)

@Composable
private fun SlabContent(text: String, icon: ImageVector?, textColor: Color, ghost: Boolean) {
    Row(
        Modifier.fillMaxWidth().padding(PaddingValues(horizontal = 18.dp, vertical = 17.dp)),
        horizontalArrangement = if (icon == null) Arrangement.Center else Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text, color = textColor, maxLines = 2, overflow = TextOverflow.Ellipsis,
            style = if (ghost) Type.Button.copy(fontSize = 16.sp, fontWeight = FontWeight.Medium) else Type.Button,
            modifier = Modifier.weight(1f, fill = icon != null),
        )
        if (icon != null) Icon(icon, null, Modifier.size(20.dp), tint = textColor)
    }
}

@Composable
fun SlabButton(text: String, icon: ImageVector?, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true) {
    val ink = if (enabled) Ink.Page else Ink.Faint
    Surface(
        onClick = onClick, enabled = enabled, shape = SlabShape, color = if (enabled) Ink.Text else Ink.Line2,
        modifier = modifier.heightIn(min = 56.dp),
    ) { SlabContent(text, icon, ink, ghost = false) }
}

@Composable
fun GhostButton(text: String, icon: ImageVector?, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true) {
    val ink = if (enabled) Ink.Text else Ink.Faint
    Surface(
        onClick = onClick, enabled = enabled, shape = SlabShape, color = Ink.Page, border = BorderStroke(1.dp, ink),
        modifier = modifier.heightIn(min = 56.dp),
    ) { SlabContent(text, icon, ink, ghost = true) }
}

@Composable
fun TextAction(text: String, onClick: () -> Unit, enabled: Boolean = true, dim: Boolean = false) {
    val ink = when {
        !enabled -> Ink.Faint
        dim -> Ink.Dim
        else -> Ink.Text
    }
    Box(
        Modifier.heightIn(min = Space.Touch).semantics { role = Role.Button }
            .clickable(enabled = enabled, onClick = onClick).padding(end = 20.dp),
        contentAlignment = Alignment.CenterStart,
    ) {
        Text(
            text, style = Type.Body, color = ink,
            modifier = Modifier.drawBehind {
                val y = size.height + 3.dp.toPx()
                drawLine(if (enabled) Ink.Faint else Ink.Line2, Offset(0f, y), Offset(size.width, y), 1.dp.toPx())
            },
        )
    }
}

@Composable
fun RenameButton(onClick: () -> Unit) {
    IconButton(onClick = onClick) { Icon(Icons.Outlined.Edit, contentDescription = "Rename", tint = Ink.Dim, modifier = Modifier.size(20.dp)) }
}
