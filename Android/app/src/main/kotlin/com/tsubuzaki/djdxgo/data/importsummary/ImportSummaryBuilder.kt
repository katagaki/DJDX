package com.tsubuzaki.djdxgo.data.importsummary

import com.tsubuzaki.djdxgo.data.Game
import com.tsubuzaki.djdxgo.data.compact
import com.tsubuzaki.djdxgo.data.ddr.DDRClearLamp
import com.tsubuzaki.djdxgo.data.ddr.DDRDifficulty
import com.tsubuzaki.djdxgo.data.ddr.DDRFlareSkill
import com.tsubuzaki.djdxgo.data.ddr.DDRPlayStyle
import com.tsubuzaki.djdxgo.data.ddr.DDRRank
import com.tsubuzaki.djdxgo.data.ddr.DDRRepository
import com.tsubuzaki.djdxgo.data.ddr.DDRSongRecord
import com.tsubuzaki.djdxgo.data.ddrCompact
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.iidx.IIDXDJLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXPlayType
import com.tsubuzaki.djdxgo.data.iidx.IIDXRepository
import com.tsubuzaki.djdxgo.data.iidx.IIDXSongRecord
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordClearType
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordDifficulty
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordGrade
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordRepository
import com.tsubuzaki.djdxgo.data.polarischord.PolarisChordSongRecord
import com.tsubuzaki.djdxgo.data.popn.PopnClearType
import com.tsubuzaki.djdxgo.data.popn.PopnDifficulty
import com.tsubuzaki.djdxgo.data.popn.PopnRank
import com.tsubuzaki.djdxgo.data.popn.PopnRepository
import com.tsubuzaki.djdxgo.data.popn.PopnSongRecord
import com.tsubuzaki.djdxgo.data.sdvx.SDVXClearType
import com.tsubuzaki.djdxgo.data.sdvx.SDVXDifficulty
import com.tsubuzaki.djdxgo.data.sdvx.SDVXGrade
import com.tsubuzaki.djdxgo.data.sdvx.SDVXRepository
import com.tsubuzaki.djdxgo.data.sdvx.SDVXSongRecord
import com.tsubuzaki.djdxgo.data.sdvx.SDVXVolforce

class ImportSummaryBuilder(
    private val iidxRepository: IIDXRepository,
    private val sdvxRepository: SDVXRepository,
    private val polarisChordRepository: PolarisChordRepository,
    private val ddrRepository: DDRRepository,
    private val popnRepository: PopnRepository
) {

    suspend fun importGroupID(game: Game, date: Long): String? = when (game) {
        Game.IIDX_ARCADE -> iidxRepository.importGroupFor(date)?.id
        Game.SOUND_VOLTEX -> sdvxRepository.importGroupFor(date)?.id
        Game.POLARIS_CHORD -> polarisChordRepository.importGroupFor(date)?.id
        Game.DANCE_DANCE_REVOLUTION -> ddrRepository.importGroupFor(date)?.id
        Game.POPN -> popnRepository.importGroupFor(date)?.id
    }

    suspend fun summary(game: Game, groupID: String): ImportSummary? = when (game) {
        Game.IIDX_ARCADE -> iidxSummary(groupID)
        Game.SOUND_VOLTEX -> sdvxSummary(groupID)
        Game.POLARIS_CHORD -> polarisChordSummary(groupID)
        Game.DANCE_DANCE_REVOLUTION -> ddrSummary(groupID)
        Game.POPN -> popnSummary(groupID)
    }

    // MARK: beatmania IIDX

    private suspend fun iidxSummary(groupID: String): ImportSummary? {
        val groups = iidxRepository.importGroups()
        val index = groups.indexOfFirst { it.id == groupID }
        if (index == -1) return null
        val group = groups[index]
        val earlierGroups = groups.drop(index + 1)

        val entries = mutableListOf<ImportSummaryEntry>()
        var previousImportDate: Long? = null
        for (playType in IIDXPlayType.entries) {
            val latest = iidxRepository.songRecords(group.id, playType)
            if (latest.isEmpty()) continue
            for (candidate in earlierGroups) {
                val previous = iidxRepository.songRecords(candidate.id, playType)
                if (previous.isEmpty()) continue
                previousImportDate = maxOf(previousImportDate ?: candidate.importDate, candidate.importDate)
                entries += iidxPersonalBests(latest, previous, playType)
                break
            }
        }
        return ImportSummary(
            game = Game.IIDX_ARCADE,
            importDate = group.importDate,
            previousImportDate = previousImportDate,
            ratings = emptyList(),
            personalBests = entries.sortedWith(entryOrder)
        )
    }

    private fun iidxPersonalBests(
        latestRecords: List<IIDXSongRecord>,
        previousRecords: List<IIDXSongRecord>,
        playType: IIDXPlayType
    ): List<ImportSummaryEntry> {
        fun key(record: IIDXSongRecord) = record.title.compact + "\u0001" + record.artist.compact
        val previousByKey = previousRecords.associateBy(::key)
        val lampOrder = IIDXClearType.ascending.reversed().dropLast(2).map { it.value }
        val djLevelOrder = IIDXDJLevel.sorted.reversed().map { it.value }

        return latestRecords.flatMap { record ->
            val previousRecord = previousByKey[key(record)]
            record.playedLevels().mapNotNull { (level, latest) ->
                val previous = previousRecord?.slot(level)
                val previousScore = previous?.score ?: 0
                val previousClearType = previous?.clearType?.takeIf { it != IIDXClearType.NO_PLAY.value }
                val previousDJLevel = previous?.djLevel?.takeIf { it != IIDXDJLevel.NONE.value }
                val isNewScore = latest.score > previousScore
                val isNewLamp = isRankImprovement(previousClearType, latest.clearType, lampOrder)
                val isNewDJLevel = isRankImprovement(previousDJLevel, latest.djLevel, djLevelOrder)
                if (!isNewScore && !isNewLamp && !isNewDJLevel) return@mapNotNull null
                ImportSummaryEntry(
                    title = record.title,
                    chart = "${playType.code}${level.code} ${latest.difficulty}",
                    difficulty = level.code,
                    levelValue = latest.difficulty.toDouble(),
                    previousScore = previousScore.takeIf { isNewScore && it > 0 },
                    score = latest.score.takeIf { isNewScore },
                    lamp = if (isNewLamp) ImportSummaryChange(previousClearType, latest.clearType) else null,
                    grade = if (isNewDJLevel) ImportSummaryChange(previousDJLevel, latest.djLevel) else null
                )
            }
        }
    }

    // MARK: SOUND VOLTEX

    private suspend fun sdvxSummary(groupID: String): ImportSummary? {
        val groups = sdvxRepository.importGroups()
        val index = groups.indexOfFirst { it.id == groupID }
        if (index == -1) return null
        val group = groups[index]
        val previousGroup = groups.drop(index + 1).firstOrNull { it.version == group.version }

        val latest = sdvxRepository.songRecords(group.id)
        val previous = previousGroup?.let { sdvxRepository.songRecords(it.id) }
        val volforce = ImportSummaryRating(
            name = "VOLFORCE",
            previousValue = previous?.let(SDVXVolforce::total),
            value = SDVXVolforce.total(latest),
            fractionDigits = 3
        )
        return ImportSummary(
            game = Game.SOUND_VOLTEX,
            importDate = group.importDate,
            previousImportDate = previousGroup?.importDate,
            ratings = listOf(volforce),
            personalBests = previous?.let { sdvxPersonalBests(latest, it) }.orEmpty()
        )
    }

    private fun sdvxPersonalBests(
        latestRecords: List<SDVXSongRecord>,
        previousRecords: List<SDVXSongRecord>
    ): List<ImportSummaryEntry> {
        fun key(record: SDVXSongRecord) = record.title.compact + "|" + record.difficulty
        val previousByKey = previousRecords.associateBy(::key)
        val lampOrder = SDVXClearType.sorted.dropLast(2).map { it.value }
        val gradeOrder = SDVXGrade.sorted.dropLast(1).map { it.value }

        return latestRecords.mapNotNull { record ->
            val previous = previousByKey[key(record)]
            val previousScore = previous?.highScore ?: 0
            val previousClearType = previous?.clearType?.takeIf { it != SDVXClearType.NO_PLAY.value }
            val previousGrade = previous?.grade?.takeIf { it != SDVXGrade.NONE.value }
            val isNewScore = record.highScore > previousScore
            val isNewLamp = isRankImprovement(previousClearType, record.clearType, lampOrder)
            val isNewGrade = isRankImprovement(previousGrade, record.grade, gradeOrder)
            if (!isNewScore && !isNewLamp && !isNewGrade) return@mapNotNull null
            val abbreviation = SDVXDifficulty.fromValue(record.difficulty)?.abbreviation ?: record.difficulty
            ImportSummaryEntry(
                title = record.title,
                chart = "$abbreviation ${record.level}",
                difficulty = record.difficulty,
                levelValue = record.level.toDoubleOrNull() ?: 0.0,
                previousScore = previousScore.takeIf { isNewScore && it > 0 },
                score = record.highScore.takeIf { isNewScore },
                lamp = if (isNewLamp) ImportSummaryChange(previousClearType, record.clearType) else null,
                grade = if (isNewGrade) ImportSummaryChange(previousGrade, record.grade) else null
            )
        }.sortedWith(entryOrder)
    }

    // MARK: Polaris Chord

    private suspend fun polarisChordSummary(groupID: String): ImportSummary? {
        val groups = polarisChordRepository.importGroups()
        val index = groups.indexOfFirst { it.id == groupID }
        if (index == -1) return null
        val group = groups[index]
        val previousGroup = groups.drop(index + 1).firstOrNull { it.version == group.version }

        val entries = previousGroup?.let {
            polarisChordPersonalBests(
                polarisChordRepository.songRecords(group.id),
                polarisChordRepository.songRecords(it.id)
            )
        }.orEmpty()
        return ImportSummary(
            game = Game.POLARIS_CHORD,
            importDate = group.importDate,
            previousImportDate = previousGroup?.importDate,
            ratings = emptyList(),
            personalBests = entries
        )
    }

    private fun polarisChordPersonalBests(
        latestRecords: List<PolarisChordSongRecord>,
        previousRecords: List<PolarisChordSongRecord>
    ): List<ImportSummaryEntry> {
        fun key(record: PolarisChordSongRecord) = record.title.compact + "|" + record.difficulty
        val previousByKey = previousRecords.associateBy(::key)
        val lampOrder = PolarisChordClearType.sorted.dropLast(2).map { it.value }
        val gradeOrder = PolarisChordGrade.sorted.dropLast(1).map { it.value }

        return latestRecords.mapNotNull { record ->
            val previous = previousByKey[key(record)]
            val previousScore = previous?.score ?: 0
            val previousClearType = previous?.clearType?.takeIf { it != PolarisChordClearType.NO_PLAY.value }
            val previousGrade = previous?.grade?.takeIf { it != PolarisChordGrade.NONE.value }
            val isNewScore = record.score > previousScore
            val isNewLamp = isRankImprovement(previousClearType, record.clearType, lampOrder)
            val isNewGrade = isRankImprovement(previousGrade, record.grade, gradeOrder)
            if (!isNewScore && !isNewLamp && !isNewGrade) return@mapNotNull null
            val abbreviation = PolarisChordDifficulty.fromValue(record.difficulty)?.abbreviation ?: record.difficulty
            ImportSummaryEntry(
                title = record.title,
                chart = "$abbreviation ${record.level}",
                difficulty = record.difficulty,
                levelValue = record.level.filter { it.isDigit() || it == '.' }.toDoubleOrNull() ?: 0.0,
                previousScore = previousScore.takeIf { isNewScore && it > 0 },
                score = record.score.takeIf { isNewScore },
                lamp = if (isNewLamp) ImportSummaryChange(previousClearType, record.clearType) else null,
                grade = if (isNewGrade) ImportSummaryChange(previousGrade, record.grade) else null
            )
        }.sortedWith(entryOrder)
    }

    // MARK: pop'n music

    private suspend fun popnSummary(groupID: String): ImportSummary? {
        val groups = popnRepository.importGroups()
        val index = groups.indexOfFirst { it.id == groupID }
        if (index == -1) return null
        val group = groups[index]
        val previousGroup = groups.drop(index + 1).firstOrNull { it.version == group.version }

        val entries = previousGroup?.let {
            popnPersonalBests(popnRepository.songRecords(group.id), popnRepository.songRecords(it.id))
        }.orEmpty()
        return ImportSummary(
            game = Game.POPN,
            importDate = group.importDate,
            previousImportDate = previousGroup?.importDate,
            ratings = emptyList(),
            personalBests = entries
        )
    }

    private fun popnPersonalBests(
        latestRecords: List<PopnSongRecord>,
        previousRecords: List<PopnSongRecord>
    ): List<ImportSummaryEntry> {
        fun key(record: PopnSongRecord) = record.title.compact + "|" + record.genre + "|" + record.difficulty
        val previousByKey = previousRecords.associateBy(::key)
        val lampOrder = PopnClearType.sorted.dropLast(2).map { it.value }
        val gradeOrder = PopnRank.sorted.map { it.value }

        return latestRecords.mapNotNull { record ->
            val previous = previousByKey[key(record)]
            val previousScore = previous?.score ?: 0
            val previousClearType = previous?.clearType?.takeIf { it != PopnClearType.NO_PLAY.value }
            val previousGrade = previous?.rank?.takeIf { it != PopnRank.NONE.value }
            val isNewScore = record.score > previousScore
            val isNewLamp = isRankImprovement(previousClearType, record.clearType, lampOrder)
            val isNewGrade = isRankImprovement(previousGrade, record.rank, gradeOrder)
            if (!isNewScore && !isNewLamp && !isNewGrade) return@mapNotNull null
            val abbreviation = PopnDifficulty.fromValue(record.difficulty)?.abbreviation ?: record.difficulty
            ImportSummaryEntry(
                title = record.title,
                chart = "$abbreviation ${record.level}",
                difficulty = record.difficulty,
                levelValue = record.level.toDouble(),
                previousScore = previousScore.takeIf { isNewScore && it > 0 },
                score = record.score.takeIf { isNewScore },
                lamp = if (isNewLamp) ImportSummaryChange(previousClearType, record.clearType) else null,
                grade = if (isNewGrade) ImportSummaryChange(previousGrade, record.rank) else null
            )
        }.sortedWith(entryOrder)
    }

    // MARK: Dance Dance Revolution

    private suspend fun ddrSummary(groupID: String): ImportSummary? {
        val groups = ddrRepository.importGroups()
        val index = groups.indexOfFirst { it.id == groupID }
        if (index == -1) return null
        val group = groups[index]
        val earlierGroups = groups.drop(index + 1).filter { it.version == group.version }
        val versions = ddrRepository.songVersions()
        val version: (DDRSongRecord) -> Int = { versions[it.title.ddrCompact] ?: 0 }

        val ratings = mutableListOf<ImportSummaryRating>()
        val entries = mutableListOf<ImportSummaryEntry>()
        var previousImportDate: Long? = null
        for (style in DDRPlayStyle.entries) {
            val latest = ddrRepository.songRecords(group.id, style)
            if (latest.isEmpty()) continue
            var previous: List<DDRSongRecord>? = null
            for (candidate in earlierGroups) {
                val records = ddrRepository.songRecords(candidate.id, style)
                if (records.isEmpty()) continue
                previous = records
                previousImportDate = maxOf(previousImportDate ?: candidate.importDate, candidate.importDate)
                break
            }
            ratings += ImportSummaryRating(
                name = "FLARE SKILL (${style.displayName})",
                previousValue = previous?.let { DDRFlareSkill.total(it, version).toDouble() },
                value = DDRFlareSkill.total(latest, version).toDouble(),
                fractionDigits = 0
            )
            if (previous != null) entries += ddrPersonalBests(latest, previous, style)
        }
        return ImportSummary(
            game = Game.DANCE_DANCE_REVOLUTION,
            importDate = group.importDate,
            previousImportDate = previousImportDate,
            ratings = ratings,
            personalBests = entries.sortedWith(entryOrder)
        )
    }

    private fun ddrPersonalBests(
        latestRecords: List<DDRSongRecord>,
        previousRecords: List<DDRSongRecord>,
        style: DDRPlayStyle
    ): List<ImportSummaryEntry> {
        fun key(record: DDRSongRecord) =
            record.songIndex.ifEmpty { record.title.ddrCompact } + "|" + record.difficulty
        val previousByKey = previousRecords.associateBy(::key)
        val lampOrder = DDRClearLamp.order.filter { it != "fail" }

        return latestRecords.mapNotNull { record ->
            if (record.score <= 0 && record.clearKind.isEmpty()) return@mapNotNull null
            val previous = previousByKey[key(record)]
            val previousScore = previous?.score ?: 0
            val previousClearKind = previous?.clearKind?.ifEmpty { null }
            val previousRank = previous?.rank?.ifEmpty { null }
            val isNewScore = record.score > previousScore
            val isNewLamp = isRankImprovement(previousClearKind, record.clearKind, lampOrder)
            val isNewRank = isRankImprovement(previousRank, record.rank, DDRRank.order)
            if (!isNewScore && !isNewLamp && !isNewRank) return@mapNotNull null
            ImportSummaryEntry(
                title = record.title,
                chart = "${chartPrefix(DDRDifficulty.fromValue(record.difficulty))}${style.displayName} ${record.level}",
                difficulty = record.difficulty,
                levelValue = record.level.toDouble(),
                previousScore = previousScore.takeIf { isNewScore && it > 0 },
                score = record.score.takeIf { isNewScore },
                lamp = if (isNewLamp) ImportSummaryChange(previousClearKind, record.clearKind) else null,
                grade = if (isNewRank) ImportSummaryChange(previousRank, record.rank) else null
            )
        }
    }

    private fun chartPrefix(difficulty: DDRDifficulty?): String = when (difficulty) {
        DDRDifficulty.BEGINNER -> "b"
        DDRDifficulty.BASIC -> "B"
        DDRDifficulty.DIFFICULT -> "D"
        DDRDifficulty.EXPERT -> "E"
        DDRDifficulty.CHALLENGE -> "C"
        null -> ""
    }
}
