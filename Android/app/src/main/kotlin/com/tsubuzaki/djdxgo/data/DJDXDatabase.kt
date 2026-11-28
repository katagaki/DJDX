package com.tsubuzaki.djdxgo.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.tsubuzaki.djdxgo.data.ddr.DDRDao
import com.tsubuzaki.djdxgo.data.ddr.DDRImportGroup
import com.tsubuzaki.djdxgo.data.ddr.DDRSongRecord
import com.tsubuzaki.djdxgo.data.external.DDRSongMeta
import com.tsubuzaki.djdxgo.data.external.ExternalDataDao
import com.tsubuzaki.djdxgo.data.external.IIDXSong
import com.tsubuzaki.djdxgo.data.external.NotesRadarEntry
import com.tsubuzaki.djdxgo.data.external.SDVXInChart
import com.tsubuzaki.djdxgo.data.external.TextageChart
import com.tsubuzaki.djdxgo.data.external.TextageChartViewerChart
import com.tsubuzaki.djdxgo.data.iidx.IIDXDao
import com.tsubuzaki.djdxgo.data.iidx.IIDXImportGroup
import com.tsubuzaki.djdxgo.data.iidx.IIDXSongRecord
import com.tsubuzaki.djdxgo.data.iidx.IIDXTowerEntry
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordDao
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordImportGroup
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordSongRecord
import com.tsubuzaki.djdxgo.data.popn.PopnDao
import com.tsubuzaki.djdxgo.data.popn.PopnImportGroup
import com.tsubuzaki.djdxgo.data.popn.PopnSongRecord
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
        PopnImportGroup::class,
        PopnSongRecord::class,
        IIDXSong::class,
        TextageChartViewerChart::class,
        SDVXInChart::class,
        NotesRadarEntry::class,
        DDRSongMeta::class,
        TextageChart::class
    ],
    version = 3,
    exportSchema = false
)
abstract class DJDXDatabase : RoomDatabase() {
    abstract fun iidxDao(): IIDXDao
    abstract fun sdvxDao(): SDVXDao
    abstract fun polarisChordDao(): PolarisChordDao
    abstract fun ddrDao(): DDRDao
    abstract fun popnDao(): PopnDao
    abstract fun externalDataDao(): ExternalDataDao

    companion object {
        private val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS `TextageChart` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, " +
                        "`tag` TEXT NOT NULL, `version` INTEGER NOT NULL, `title` TEXT NOT NULL, " +
                        "`titleCompact` TEXT NOT NULL, `spNormal` INTEGER NOT NULL, `spHyper` INTEGER NOT NULL, " +
                        "`spAnother` INTEGER NOT NULL, `spLeggendaria` INTEGER NOT NULL, `dpNormal` INTEGER NOT NULL, " +
                        "`dpHyper` INTEGER NOT NULL, `dpAnother` INTEGER NOT NULL, `dpLeggendaria` INTEGER NOT NULL)"
                )
                db.execSQL(
                    "CREATE UNIQUE INDEX IF NOT EXISTS `index_TextageChart_titleCompact` ON `TextageChart` (`titleCompact`)"
                )
            }
        }

        private val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS `PopnImportGroup` (`id` TEXT NOT NULL, " +
                        "`importDate` INTEGER NOT NULL, `version` INTEGER, PRIMARY KEY(`id`))"
                )
                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS `PopnSongRecord` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, " +
                        "`importGroupID` TEXT NOT NULL, `title` TEXT NOT NULL, `genre` TEXT NOT NULL, " +
                        "`artist` TEXT NOT NULL, `difficulty` TEXT NOT NULL, `level` INTEGER NOT NULL, " +
                        "`score` INTEGER NOT NULL, `medal` TEXT NOT NULL, `rank` TEXT NOT NULL)"
                )
                db.execSQL(
                    "CREATE INDEX IF NOT EXISTS `index_PopnSongRecord_importGroupID` ON `PopnSongRecord` (`importGroupID`)"
                )
            }
        }

        @Volatile
        private var instance: DJDXDatabase? = null

        fun get(context: Context): DJDXDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    DJDXDatabase::class.java,
                    "PlayData.db"
                ).addMigrations(MIGRATION_1_2, MIGRATION_2_3).build().also { instance = it }
            }
    }
}
