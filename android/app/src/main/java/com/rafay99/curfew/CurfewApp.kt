package com.rafay99.curfew

import android.app.Application
import com.rafay99.curfew.data.Repo

class CurfewApp : Application() {
    val repo by lazy { Repo(this) }
}
