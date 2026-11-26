package com.tsubuzaki.djdxgo.data.notes

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

@Entity(primaryKeys = ["game", "title", "chart"])
data class ChartNote(
    val game: Int,
    val title: String,
    val chart: String,
    val text: String = "",
    val greenNumber: Int? = null,
    val laneCover: Int? = null,
    val judgmentOffset: Int? = null,
    val updatedAt: Long = 0L
) {
    val isEmpty: Boolean
        get() = text.isBlank() && greenNumber == null && laneCover == null && judgmentOffset == null

    companion object {
        fun iidxChart(playType: IIDXPlayType, level: IIDXLevel): String {
            val prefix = if (level == IIDXLevel.BEGINNER) IIDXPlayType.SINGLE.code else playType.code
            return "$prefix-${level.csvPrefix}"
        }
    }
}

data class ChartNoteTarget(
    val game: Game,
    val title: String,
    val chart: String,
    val chartLabel: String
)

@Dao
interface ChartNoteDao {
    @Query("SELECT * FROM ChartNote WHERE game = :game AND title = :title AND chart = :chart")
    suspend fun note(game: Int, title: String, chart: String): ChartNote?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(note: ChartNote)

    @Query("DELETE FROM ChartNote WHERE game = :game AND title = :title AND chart = :chart")
    suspend fun delete(game: Int, title: String, chart: String)
}

@Database(entities = [ChartNote::class], version = 1, exportSchema = false)
abstract class ChartNotesDatabase : RoomDatabase() {
    abstract fun chartNoteDao(): ChartNoteDao

    companion object {
        @Volatile
        private var instance: ChartNotesDatabase? = null

        fun get(context: Context): ChartNotesDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    ChartNotesDatabase::class.java,
                    "ChartNotes.db"
                ).build().also { instance = it }
            }
    }
}

class ChartNotesRepository(private val dao: ChartNoteDao) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    suspend fun note(game: Game, title: String, chart: String): ChartNote =
        dao.note(game.id, title, chart) ?: ChartNote(game = game.id, title = title, chart = chart)

    fun save(note: ChartNote) {
        scope.launch {
            if (note.isEmpty) {
                dao.delete(note.game, note.title, note.chart)
            } else {
                dao.upsert(note.copy(updatedAt = System.currentTimeMillis() / 1000L))
            }
        }
    }
}
