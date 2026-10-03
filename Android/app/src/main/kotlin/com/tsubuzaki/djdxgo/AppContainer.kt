package com.tsubuzaki.djdxgo

import android.content.Context
import android.net.Uri
import com.tsubuzaki.djdxgo.data.DJDXDatabase
import com.tsubuzaki.djdxgo.data.analytics.AnalyticsStore
import com.tsubuzaki.djdxgo.data.ddr.DDRRepository
import com.tsubuzaki.djdxgo.data.external.ExternalDataReloader
import com.tsubuzaki.djdxgo.data.iidx.IIDXRepository
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordRepository
import com.tsubuzaki.djdxgo.data.profile.ProfileRepository
import com.tsubuzaki.djdxgo.data.sdvx.SDVXRepository
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class AppContainer(context: Context) {
    val database = DJDXDatabase.get(context)
    val iidxRepository = IIDXRepository(database.iidxDao())
    val sdvxRepository = SDVXRepository(database.sdvxDao())
    val polarisChordRepository = PolarisChordRepository(database.polarisChordDao())
    val externalDataDao = database.externalDataDao()
    val ddrRepository = DDRRepository(database.ddrDao(), externalDataDao)
    val externalDataReloader = ExternalDataReloader(externalDataDao)
    val analyticsStore = AnalyticsStore(database, ddrRepository)
    val profileRepository = ProfileRepository(context.applicationContext)

    private val dataVersionState = MutableStateFlow(0)
    val dataVersion: StateFlow<Int> = dataVersionState.asStateFlow()

    private val importCompletedEvents = MutableSharedFlow<Unit>(
        extraBufferCapacity = 1,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val importCompleted: SharedFlow<Unit> = importCompletedEvents.asSharedFlow()

    private val deepLinkEvents = MutableSharedFlow<Uri>(
        replay = 1,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val deepLinks: SharedFlow<Uri> = deepLinkEvents.asSharedFlow()

    fun notifyDataChanged() {
        dataVersionState.update { it + 1 }
    }

    fun notifyImportCompleted() {
        notifyDataChanged()
        importCompletedEvents.tryEmit(Unit)
    }

    fun handleDeepLink(uri: Uri) {
        deepLinkEvents.tryEmit(uri)
    }

    @OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
    fun consumeDeepLink() {
        deepLinkEvents.resetReplayCache()
    }
}
