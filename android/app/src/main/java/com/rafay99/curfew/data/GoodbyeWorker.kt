package com.rafay99.curfew.data

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.rafay99.curfew.CurfewApp
import java.util.concurrent.TimeUnit

class GoodbyeWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        (applicationContext as CurfewApp).repo.deliverGoodbyes(fromWorker = true)
        return Result.success()
    }

    companion object {
        private const val NAME = "curfew-goodbyes"

        fun sync(context: Context, pending: Boolean) {
            val wm = WorkManager.getInstance(context)
            if (!pending) {
                wm.cancelUniqueWork(NAME)
                return
            }
            val request = PeriodicWorkRequestBuilder<GoodbyeWorker>(30, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.UNMETERED).build())
                .build()
            wm.enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }
    }
}
