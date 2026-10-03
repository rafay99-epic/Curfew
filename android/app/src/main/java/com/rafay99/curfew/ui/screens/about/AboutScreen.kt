package com.rafay99.curfew.ui.screens.about

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.rafay99.curfew.BuildConfig
import com.rafay99.curfew.core.Links
import com.rafay99.curfew.core.Part
import com.rafay99.curfew.ui.components.Lede
import com.rafay99.curfew.ui.components.SerifTitle
import com.rafay99.curfew.ui.components.TextSheet
import com.rafay99.curfew.ui.components.TopRow
import com.rafay99.curfew.ui.components.openLink
import com.rafay99.curfew.ui.theme.Ink
import com.rafay99.curfew.ui.theme.Space
import com.rafay99.curfew.ui.theme.Type

@Composable
fun AboutScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    var licences by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().background(Ink.Page).systemBarsPadding().verticalScroll(rememberScrollState())) {
        TopRow("Computers", onBack) {
            Text(BuildConfig.VERSION_NAME, style = Type.Small, modifier = Modifier.padding(end = 12.dp))
        }
        SerifTitle("Curfew")
        Credit("Made by ", "Abdul Rafay") { context.openLink(Links.AUTHOR) }
        Credit("Built on the agent by ", "Sharjeel Mazhar") { context.openLink(Links.AGENT) }
        Lede(listOf(Part("Everything stays on your home network. No account, no cloud.")), Modifier.padding(top = 10.dp))
        Spacer(Modifier.weight(1f).heightIn(min = 48.dp))
        Column(Modifier.padding(horizontal = Space.Gutter).padding(bottom = 16.dp)) {
            val pages = listOfNotNull(
                Links.privacy?.let { "Privacy policy" to it },
                Links.terms?.let { "Terms" to it },
                Links.contact?.let { "Contact" to it },
            )
            if (pages.isNotEmpty()) Row {
                pages.forEachIndexed { i, (label, url) ->
                    if (i > 0) Text(" · ", style = Type.MonoSmall)
                    Fine(label) { context.openLink(url) }
                }
            }
            Text("Version ${BuildConfig.VERSION_NAME} · ${BuildConfig.APPLICATION_ID}", style = Type.MonoSmall)
            Text("MIT licence", style = Type.MonoSmall)
            Text("Fonts: Instrument Serif, Geist, Geist Mono", style = Type.MonoSmall)
            Fine("Font licences (SIL OFL 1.1)") { licences = true }
        }
    }
    if (licences) {
        val text = remember {
            context.assets.list("licenses").orEmpty().sorted().joinToString("\n\n") { file ->
                "${file.removeSuffix(".txt")}\n\n" + context.assets.open("licenses/$file").bufferedReader().use { it.readText() }
            }
        }
        TextSheet("Font licences", text) { licences = false }
    }
}

@Composable
private fun Credit(lead: String, name: String, onClick: () -> Unit) {
    Text(
        buildAnnotatedString {
            append(lead)
            withStyle(SpanStyle(textDecoration = TextDecoration.Underline)) { append(name) }
            append(".")
        },
        style = Type.Credit,
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = Space.Gutter, vertical = 8.dp),
    )
}

@Composable
private fun Fine(label: String, onClick: () -> Unit) {
    Text(
        label, style = Type.MonoSmall.merge(TextStyle(textDecoration = TextDecoration.Underline)),
        modifier = Modifier.heightIn(min = 32.dp).clickable(onClick = onClick).padding(vertical = 6.dp),
    )
}
