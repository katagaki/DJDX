package com.tsubuzaki.djdxgo.data.analytics

import com.tsubuzaki.djdxgo.data.DJDXDatabase
import com.tsubuzaki.djdxgo.data.ddr.DDRPlayStyle
import com.tsubuzaki.djdxgo.data.ddr.DDRRepository
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext

class AnalyticsStore(
    private val database: DJDXDatabase,
    private val ddrRepository: DDRRepository
) {
    private val iidxState = MutableStateFlow<IIDXAnalyticsData?>(null)
    private val sdvxState = MutableStateFlow<ChartAnalyticsData?>(null)
    private val polarisChordState = MutableStateFlow<ChartAnalyticsData?>(null)
    private val ddrState = MutableStateFlow<ChartAnalyticsData?>(null)

    val iidx: StateFlow<IIDXAnalyticsData?> = iidxState.asStateFlow()
    val sdvx: StateFlow<ChartAnalyticsData?> = sdvxState.asStateFlow()
    val polarisChord: StateFlow<ChartAnalyticsData?> = polarisChordState.asStateFlow()
    val ddr: StateFlow<ChartAnalyticsData?> = ddrState.asStateFlow()

    suspend fun reloadIIDX(playType: IIDXPlayType, filters: IIDXFilterOptions) {
        iidxState.value = withContext(Dispatchers.IO) {
            IIDXAnalytics.compute(database.iidxDao(), playType, filters)
        }
    }

    suspend fun reloadSDVX(filters: SDVXFilterOptions) {
        sdvxState.value = withContext(Dispatchers.IO) {
            val dao = database.sdvxDao()
            val groups = dao.importGroups()
            val latest = groups.getOrNull(0)?.let { dao.songRecords(it.id) }.orEmpty()
            val previous = groups.getOrNull(1)?.let { dao.songRecords(it.id) }
            ChartAnalytics.sdvx(latest, previous, filters)
        }
    }

    suspend fun reloadPolarisChord(filters: PolarisChordFilterOptions) {
        polarisChordState.value = withContext(Dispatchers.IO) {
            val dao = database.polarisChordDao()
            val groups = dao.importGroups()
            val latest = groups.getOrNull(0)?.let { dao.songRecords(it.id) }.orEmpty()
            val previous = groups.getOrNull(1)?.let { dao.songRecords(it.id) }
            ChartAnalytics.polarisChord(latest, previous, filters)
        }
    }

    suspend fun reloadDDR(style: DDRPlayStyle, filters: DDRFilterOptions) {
        ddrState.value = withContext(Dispatchers.IO) {
            ChartAnalytics.ddr(
                ddrRepository.songRecords(System.currentTimeMillis() / 1000L, style),
                filters
            )
        }
    }
}
