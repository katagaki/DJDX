package com.tsubuzaki.djdxgo.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.tsubuzaki.djdxgo.data.ddr.DDRDao
import com.tsubuzaki.djdxgo.data.ddr.DDRImportGroup
import com.tsubuzaki.djdxgo.data.ddr.DDRSongRecord
import com.tsubuzaki.djdxgo.data.external.DDRSongMeta
import com.tsubuzaki.djdxgo.data.external.ExternalDataDao
import com.tsubuzaki.djdxgo.data.external.IIDXSong
import com.tsubuzaki.djdxgo.data.external.NotesRadarEntry
import com.tsubuzaki.djdxgo.data.external.SDVXInChart
import com.tsubuzaki.djdxgo.data.external.TextageChartViewerChart
import com.tsubuzaki.djdxgo.data.iidx.IIDXDao
import com.tsubuzaki.djdxgo.data.iidx.IIDXImportGroup
import com.tsubuzaki.djdxgo.data.iidx.IIDXSongRecord
import com.tsubuzaki.djdxgo.data.iidx.IIDXTowerEntry
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordDao
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordImportGroup
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordSongRecord
import com.tsubuzaki.djdxgo.data.sdvx.SDVXDao
import com.tsubuzaki.djdxgo.data.sdvx.SDVXImportGroup
import com.tsubuzaki.djdxgo.data.sdvx.SDVXSongRecord

@Database(
    entities = [
        IIDXImportGroup::class,
        IIDXSongRecord::class,
        IIDXTowerEntry::class,
        SDVXImportGroup::class,
        SDVXSongRecord::class,
        PolarisChordImportGroup::class,
        PolarisChordSongRecord::class,
        DDRImportGroup::class,
        DDRSongRecord::class,
        IIDXSong::class,
        TextageChartViewerChart::class,
        SDVXInChart::class,
        NotesRadarEntry::class,
        DDRSongMeta::class
    ],
    version = 1,
    exportSchema = false
)
abstract class DJDXDatabase : RoomDatabase() {
    abstract fun iidxDao(): IIDXDao
    abstract fun sdvxDao(): SDVXDao
    abstract fun polarisChordDao(): PolarisChordDao
    abstract fun ddrDao(): DDRDao
    abstract fun externalDataDao(): ExternalDataDao

    companion object {
        @Volatile
        private var instance: DJDXDatabase? = null

        fun get(context: Context): DJDXDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    DJDXDatabase::class.java,
                    "PlayData.db"
                ).build().also { instance = it }
            }
    }
}
