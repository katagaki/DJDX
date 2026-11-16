package com.tsubuzaki.djdxgo.widget

import android.content.Context
import androidx.glance.appwidget.updateAll
import com.tsubuzaki.djdxgo.data.SettingsKeys
import com.tsubuzaki.djdxgo.data.analytics.IIDXAnalytics
import com.tsubuzaki.djdxgo.data.analytics.IIDXAnalyticsData
import com.tsubuzaki.djdxgo.data.analytics.IIDXFilterOptions
import com.tsubuzaki.djdxgo.data.analytics.IIDXTrendPoint
import com.tsubuzaki.djdxgo.data.iidx.IIDXDao
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.profile.ProfileRepository
import com.tsubuzaki.djdxgo.data.settingFlow
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch

class WidgetDataPublisher(
    context: Context,
    private val dao: IIDXDao,
    private val profileRepository: ProfileRepository
) {
    private val context = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    @OptIn(FlowPreview::class)
    fun start(dataVersion: StateFlow<Int>) {
        scope.launch {
            combine(
                context.settingFlow(SettingsKeys.iidxPlayType, IIDXPlayType.SINGLE.value).distinctUntilChanged(),
                dataVersion,
                profileRepository.iidx
            ) { playType, _, _ -> playType }
                .debounce(PUBLISH_DEBOUNCE_MILLIS)
                .collect { runCatching { publish(IIDXPlayType.fromValue(it)) } }
        }
    }

    private suspend fun publish(playType: IIDXPlayType) {
        val analytics = IIDXAnalytics.levelCounts(dao, playType, IIDXFilterOptions())
        val snapshot = WidgetSnapshot(
            playType = playType.value,
            radar = profileRepository.cachedIIDXRadar(playType.code),
            clearType = analytics.clearTypeCounts(),
            djLevel = analytics.djLevelCounts(),
            tower = analytics.towerSnapshot(),
            lastUpdated = System.currentTimeMillis() / 1000L
        )
        WidgetSnapshotStore.write(context, snapshot, profileRepository.iidxQproFile)
        updateAllWidgets(context)
    }

    private fun IIDXAnalyticsData.clearTypeCounts() =
        WidgetCountsSnapshot(clearTypePerDifficulty, clearTypeTrends.map { it.toWidget() })

    private fun IIDXAnalyticsData.djLevelCounts() =
        WidgetCountsSnapshot(djLevelPerDifficulty, djLevelTrends.map { it.toWidget() })

    private fun IIDXAnalyticsData.towerSnapshot(): WidgetTowerSnapshot? {
        if (towerEntries.isEmpty()) return null
        return WidgetTowerSnapshot(
            totalKeyCount = towerTotalKeyCount,
            totalScratchCount = towerTotalScratchCount,
            latestEntries = towerEntries.take(3).map { WidgetTowerEntry(it.playDate, it.keyCount, it.scratchCount) }
        )
    }

    private fun IIDXTrendPoint.toWidget() = WidgetTrendPoint(date, counts)

    companion object {
        private const val PUBLISH_DEBOUNCE_MILLIS = 500L

        suspend fun updateAllWidgets(context: Context) {
            QproWidget().updateAll(context)
            NotesRadarWidget().updateAll(context)
            ClearTypeWidget().updateAll(context)
            DJLevelWidget().updateAll(context)
            TowerWidget().updateAll(context)
        }
    }
}
