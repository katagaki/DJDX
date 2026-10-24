package com.tsubuzaki.djdxgo.ui.iidx

import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.datastore.preferences.core.Preferences
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.compact
import com.tsubuzaki.djdxgo.data.external.IIDXSong
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.iidx.IIDXDJLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevelScore
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.iidx.IIDXSongRecord
import com.tsubuzaki.djdxgo.data.settingFlow

enum class IIDXSortMode(val value: String, @StringRes val labelRes: Int) {
    TITLE("title", R.string.scores_sort_title),
    CLEAR_TYPE("clearType", R.string.scores_sort_clear_type),
    DJ_LEVEL("djLevel", R.string.scores_sort_dj_level),
    SCORE_RATE("scoreRate", R.string.scores_sort_score_rate),
    SCORE("score", R.string.scores_sort_score),
    MISS_COUNT("missCount", R.string.scores_sort_miss_count),
    DIFFICULTY("difficulty", R.string.scores_sort_difficulty),
    LAST_PLAY_DATE("lastPlayDate", R.string.scores_sort_last_play_date);

    companion object {
        fun fromValue(value: String): IIDXSortMode =
            entries.firstOrNull { it.value == value } ?: LAST_PLAY_DATE
    }
}

data class IIDXScoreEntry(
    val record: IIDXSongRecord,
    val level: IIDXLevel,
    val score: IIDXLevelScore
)

@Composable
fun <T> rememberSetting(key: Preferences.Key<T>, default: T): State<T> {
    val context = LocalContext.current
    val flow = remember(key) { context.settingFlow(key, default) }
    return flow.collectAsState(initial = default)
}

fun IIDXSong.noteCount(playType: IIDXPlayType, level: IIDXLevel): Int? =
    when (playType) {
        IIDXPlayType.SINGLE -> when (level) {
            IIDXLevel.BEGINNER -> spBeginnerNoteCount
            IIDXLevel.NORMAL -> spNormalNoteCount
            IIDXLevel.HYPER -> spHyperNoteCount
            IIDXLevel.ANOTHER -> spAnotherNoteCount
            IIDXLevel.LEGGENDARIA -> spLeggendariaNoteCount
        }
        IIDXPlayType.DOUBLE -> when (level) {
            IIDXLevel.BEGINNER -> dpBeginnerNoteCount
            IIDXLevel.NORMAL -> dpNormalNoteCount
            IIDXLevel.HYPER -> dpHyperNoteCount
            IIDXLevel.ANOTHER -> dpAnotherNoteCount
            IIDXLevel.LEGGENDARIA -> dpLeggendariaNoteCount
        }
    }

fun scoreRate(score: Int, noteCount: Int?): Float? =
    if (noteCount != null && noteCount > 0) score.toFloat() / (noteCount * 2).toFloat() else null

fun filterAndSortEntries(
    records: List<IIDXSongRecord>,
    songs: Map<String, IIDXSong>,
    playType: IIDXPlayType,
    searchTerm: String,
    levelFilters: Set<String>,
    difficultyFilters: Set<String>,
    clearTypeFilters: Set<String>,
    djLevelFilters: Set<String>,
    versionFilters: Set<String>,
    scoreAvailableOnly: Boolean,
    beginnerHidden: Boolean,
    sortMode: IIDXSortMode,
    sortDescending: Boolean
): List<IIDXScoreEntry> {
    val searchCompact = searchTerm.trim().compact
    val versioned = if (versionFilters.isEmpty()) records else records.filter { it.version in versionFilters }
    val searched = if (searchCompact.isEmpty()) {
        versioned
    } else {
        versioned.filter {
            it.title.compact.contains(searchCompact) || it.artist.compact.contains(searchCompact)
        }
    }

    val entries = searched.flatMap { record ->
        record.playedLevels().mapNotNull { (level, score) ->
            if (level == IIDXLevel.BEGINNER && beginnerHidden) return@mapNotNull null
            if (scoreAvailableOnly && score.score == 0) return@mapNotNull null
            if (levelFilters.isNotEmpty() && level.code !in levelFilters) return@mapNotNull null
            if (difficultyFilters.isNotEmpty() &&
                score.difficulty.toString() !in difficultyFilters
            ) return@mapNotNull null
            if (clearTypeFilters.isNotEmpty() && score.clearType !in clearTypeFilters) return@mapNotNull null
            if (djLevelFilters.isNotEmpty() && score.djLevel !in djLevelFilters) return@mapNotNull null
            IIDXScoreEntry(record, level, score)
        }
    }

    fun rate(entry: IIDXScoreEntry): Float =
        scoreRate(
            entry.score.score,
            songs[entry.record.title.compact]?.noteCount(playType, entry.level)
        ) ?: 0f

    val titleComparator = compareBy<IIDXScoreEntry> { it.record.title.compact }
    val comparator = when (sortMode) {
        IIDXSortMode.TITLE -> {
            val base = compareBy<IIDXScoreEntry> { it.record.title.compact }
            if (sortDescending) base.reversed() else base
        }
        IIDXSortMode.CLEAR_TYPE -> directional(
            compareBy { IIDXClearType.sortIndex(it.score.clearType) },
            sortDescending,
            titleComparator
        )
        IIDXSortMode.DJ_LEVEL -> directional(
            compareBy { IIDXDJLevel.sortIndex(it.score.djLevel) },
            sortDescending,
            titleComparator
        )
        IIDXSortMode.SCORE_RATE -> directional(compareBy { rate(it) }, sortDescending, titleComparator)
        IIDXSortMode.SCORE -> directional(compareBy { it.score.score }, sortDescending, titleComparator)
        IIDXSortMode.MISS_COUNT -> directional(
            compareBy { it.score.missCount },
            sortDescending,
            titleComparator
        )
        IIDXSortMode.DIFFICULTY -> directional(
            compareBy { it.score.difficulty },
            sortDescending,
            titleComparator
        )
        IIDXSortMode.LAST_PLAY_DATE -> directional(
            compareBy { it.record.lastPlayDate },
            sortDescending,
            titleComparator
        )
    }
    return entries.sortedWith(comparator)
}

private fun directional(
    primary: Comparator<IIDXScoreEntry>,
    descending: Boolean,
    tieBreaker: Comparator<IIDXScoreEntry>
): Comparator<IIDXScoreEntry> =
    (if (descending) primary.reversed() else primary).thenComparing(tieBreaker)
