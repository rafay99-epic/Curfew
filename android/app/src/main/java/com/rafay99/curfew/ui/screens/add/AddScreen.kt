package com.rafay99.curfew.ui.screens.add

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.QrCodeScanner
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import com.rafay99.curfew.core.PairLink
import com.rafay99.curfew.core.PairResult
import com.rafay99.curfew.core.Part
import com.rafay99.curfew.core.Proto
import com.rafay99.curfew.data.Repo
import com.rafay99.curfew.security.AppLock
import com.rafay99.curfew.ui.components.Lede
import com.rafay99.curfew.ui.components.Page
import com.rafay99.curfew.ui.components.SerifTitle
import com.rafay99.curfew.ui.components.SlabButton
import com.rafay99.curfew.ui.components.TextAction
import com.rafay99.curfew.ui.components.TopRow
import com.rafay99.curfew.ui.theme.Space
import com.rafay99.curfew.ui.theme.Type
import kotlinx.coroutines.launch

@Composable
fun AddScreen(repo: Repo, snack: SnackbarHostState, onBack: () -> Unit, onDone: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var error by rememberSaveable { mutableStateOf<String?>(null) }
    var manual by rememberSaveable { mutableStateOf(false) }
    var address by rememberSaveable { mutableStateOf("") }
    var code by rememberSaveable { mutableStateOf("") }

    fun pair(link: PairLink) {
        if (busy) return
        busy = true
        error = null
        scope.launch {
            when (val r = repo.pair(link)) {
                is PairResult.Paired -> {
                    repo.notices.tryEmit("${r.computer.title} was added")
                    onDone()
                }
                PairResult.BadCode -> error = "That code is wrong, used or expired. Run sudo curfew pair again for a new one."
                PairResult.Unreachable -> error = "Could not reach the computer. Check that this phone is on the same Wi-Fi."
                PairResult.WrongComputer -> error = "A different computer answered at that address. Run sudo curfew pair again."
                PairResult.Fake -> error = "The computer at that address could not prove it knows the code, so nothing was paired."
            }
            busy = false
        }
    }

    fun scan() {
        error = null
        val options = GmsBarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_QR_CODE).enableAutoZoom().build()
        val scanner = GmsBarcodeScanning.getClient(context, options)
        AppLock.away = true
        scanner.startScan()
            .addOnCanceledListener { AppLock.away = false }
            .addOnSuccessListener { found ->
                val link = found.rawValue?.let(Proto::parsePairLink)
                if (link != null) pair(link) else error = "That is not a Curfew code. Scan the one shown by sudo curfew pair."
            }
            .addOnFailureListener {
                AppLock.away = false
                runCatching { ModuleInstall.getClient(context).deferredInstall(scanner) }
                manual = true
                error = "The camera scanner is not ready yet. Try again in a minute, or type the address and code."
            }
    }

    Page(
        snack,
        bottom = if (manual) null else {
            { SlabButton(if (busy) "Pairing…" else "Scan the code", Icons.Rounded.QrCodeScanner, ::scan, Modifier.fillMaxWidth(), enabled = !busy) }
        },
    ) {
        item { TopRow("Computers", onBack) }
        item { SerifTitle("Add a computer") }
        item {
            Lede(listOf(
                Part("On an admin account, open a terminal and run "),
                Part("sudo curfew pair", strong = true),
                Part(". Then scan the square code it shows."),
            ))
        }
        error?.let { e -> item { Text(e, style = Type.Body, modifier = Modifier.fillMaxWidth().padding(horizontal = Space.Gutter, vertical = 4.dp)) } }
        item {
            if (manual) ManualPair(address, { address = it }, code, { code = it }, busy, ::pair, onScan = { manual = false; scan() })
            else Box(Modifier.padding(start = Space.Gutter)) { TextAction("Type the address and code instead", { manual = true }) }
        }
    }
}
