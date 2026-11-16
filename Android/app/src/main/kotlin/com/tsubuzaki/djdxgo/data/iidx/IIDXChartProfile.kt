package com.tsubuzaki.djdxgo.data.iidx

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt
import kotlinx.serialization.Serializable

@Serializable
enum class IIDXChartTrait {
    BACKLOADED,
    BUILD_UP,
    BURST,
    STAMINA,
    CHAOTIC,
    STAIRS,
    CONSECUTIVE_CHORDS,
    ADJACENT_PAIRS,
    JACKS,
    SCRATCH_COMBO,
    LEGACY_NOTES,
    CHARGE_COMBO,
    CHARGE_CHORDS,
    GRADUAL_SOFLAN,
    SUDDEN_SOFLAN
}

@Serializable
data class IIDXChartNote(
    val lane: Int,
    val time: Double,
    val type: String,
    val endTime: Double? = null
)

@Serializable
data class IIDXChartBPMChange(
    val time: Double,
    val bpm: Double
)

@Serializable
data class IIDXChartData(
    val notes: List<IIDXChartNote>,
    val bpmChanges: List<IIDXChartBPMChange>
)

@Serializable
data class IIDXChartProfile(
    val version: Int = CURRENT_VERSION,
    val traits: List<IIDXChartTrait>
) {
    val isCurrent: Boolean get() = version == CURRENT_VERSION

    companion object {
        const val CURRENT_VERSION = 10

        private val staminaBaselines = mapOf(
            1 to 2.0, 2 to 2.6, 3 to 3.3, 4 to 4.2, 5 to 4.9, 6 to 5.5,
            7 to 6.5, 8 to 7.3, 9 to 8.3, 10 to 10.0, 11 to 11.6, 12 to 15.3
        )

        fun analyze(chart: IIDXChartData, playType: IIDXPlayType, level: Int): IIDXChartProfile {
            val notes = chart.notes
            val bpmChanges = chart.bpmChanges
            val times = notes.map { it.time / 1000.0 }.sorted()
            if (times.size < 50 || times.last() - times.first() < 20.0) {
                return IIDXChartProfile(traits = emptyList())
            }
            val scratchLanes = if (playType == IIDXPlayType.DOUBLE) setOf(0, 8) else setOf(0)
            val traits = mutableListOf<IIDXChartTrait>()
            traits += densityTraits(times, playType, level)
            if (isBuildUp(times)) traits += IIDXChartTrait.BUILD_UP
            val onsets = onsets(notes, scratchLanes)
            if (isChaotic(onsets)) traits += IIDXChartTrait.CHAOTIC
            traits += keyPatternTraits(onsets)
            if (hasJacks(notes, bpmChanges, scratchLanes)) traits += IIDXChartTrait.JACKS
            traits += scratchComboTraits(notes, playType)
            if (hasLegacyNotes(notes, playType)) traits += IIDXChartTrait.LEGACY_NOTES
            if (isChargeCombo(notes, scratchLanes)) traits += IIDXChartTrait.CHARGE_COMBO
            if (hasChargeChords(notes, bpmChanges, scratchLanes)) traits += IIDXChartTrait.CHARGE_CHORDS
            traits += soflanTraits(bpmChanges, notes.map { it.time }.sorted())
            return IIDXChartProfile(traits = traits)
        }

        // MARK: Density

        private data class Window(val start: Double, val value: Double)

        private fun densityTraits(times: List<Double>, playType: IIDXPlayType, level: Int): List<IIDXChartTrait> {
            val first = times.first()
            val duration = times.last() - first
            val density2 = densities(times, 2.0).map { it.value }
            val density5 = densities(times, 5.0)
            val density10 = densities(times, 10.0)
            val values10 = density10.map { it.value }
            val traits = mutableListOf<IIDXChartTrait>()

            val peakPosition = density10.maxByOrNull { it.value }
                ?.let { (it.start + 5.0 - first) / duration } ?: 0.0
            val tailStart = first + duration * 0.85 - 5.0
            val tailPeak = density5.filter { it.start >= tailStart }.maxOfOrNull { it.value } ?: 0.0
            val headMedian = median(density5.filter { it.start < tailStart }.map { it.value })
            if (headMedian > 0.0 && tailPeak / headMedian >= 1.6 && peakPosition >= 0.8) {
                traits += IIDXChartTrait.BACKLOADED
            }

            val maxDensity10 = values10.maxOrNull() ?: 0.0
            val median2 = median(density2)
            if (maxDensity10 > 0.0 && median2 > 0.0 &&
                median(values10) / maxDensity10 <= 0.68 &&
                (density2.maxOrNull() ?: 0.0) / median2 >= 1.7 &&
                peakPosition < 0.8
            ) {
                traits += IIDXChartTrait.BURST
            }

            val baseline = staminaBaselines[level]
            if (playType == IIDXPlayType.SINGLE && duration >= 60.0 && baseline != null &&
                times.size / duration >= baseline * 1.13
            ) {
                traits += IIDXChartTrait.STAMINA
            }
            return traits
        }

        private fun isBuildUp(times: List<Double>): Boolean {
            val first = times.first()
            val last = times.last()
            if (last <= first) return false
            val segmentCount = 12
            val segmentLength = (last - first) / segmentCount
            val densities = (0 until segmentCount).map { segment ->
                val start = first + segmentLength * segment
                val end = if (segment == segmentCount - 1) last + 1e-9 else start + segmentLength
                (lowerBound(times, end) - lowerBound(times, start)) / segmentLength
            }
            val meanPosition = (0 until segmentCount).sum().toDouble() / segmentCount
            val meanDensity = densities.sum() / segmentCount
            if (meanDensity <= 0.0) return false
            var covariance = 0.0
            var positionVariance = 0.0
            var densityVariance = 0.0
            densities.forEachIndexed { index, density ->
                val position = index.toDouble()
                covariance += (position - meanPosition) * (density - meanDensity)
                positionVariance += (position - meanPosition) * (position - meanPosition)
                densityVariance += (density - meanDensity) * (density - meanDensity)
            }
            if (densityVariance <= 0.0) return false
            val rise = covariance / positionVariance * (segmentCount - 1) / meanDensity
            val correlation = covariance / sqrt(positionVariance * densityVariance)
            return rise >= 0.35 && correlation >= 0.6 && densities.last() >= meanDensity * 1.2
        }

        // MARK: Patterns

        private data class Onset(val time: Int, val lanes: Set<Int>)

        private fun onsets(notes: List<IIDXChartNote>, scratchLanes: Set<Int>): List<Onset> {
            val lanesByTime = sortedMapOf<Int, MutableSet<Int>>()
            notes.filter { it.lane !in scratchLanes }.forEach { note ->
                lanesByTime.getOrPut(Math.round(note.time).toInt()) { mutableSetOf() }.add(note.lane)
            }
            return lanesByTime.map { (time, lanes) -> Onset(time, lanes) }
        }

        private fun isChaotic(onsets: List<Onset>): Boolean {
            val patterns = onsets.map { it.lanes }
            if (patterns.size < 50) return false
            var structured = 0
            for (index in 2 until patterns.size) {
                val previous2 = patterns[index - 2]
                val previous1 = patterns[index - 1]
                val current = patterns[index]
                if (current == previous1 || current == previous2) {
                    structured++
                } else if (current.size == 1 && previous1.size == 1 && previous2.size == 1) {
                    val lane0 = previous2.first()
                    val lane1 = previous1.first()
                    val lane2 = current.first()
                    if (lane2 - lane1 == lane1 - lane0 && abs(lane2 - lane1) == 1) structured++
                }
            }
            return structured.toDouble() / (patterns.size - 2) <= 0.10
        }

        private fun keyPatternTraits(onsets: List<Onset>): List<IIDXChartTrait> {
            if (onsets.size < 50) return emptyList()
            val traits = mutableListOf<IIDXChartTrait>()
            val stairNotes = stairOnsetCount(onsets, 7)
            if (stairNotes >= 40 && stairNotes.toDouble() / onsets.size >= 0.07) {
                traits += IIDXChartTrait.STAIRS
            }
            if ((runLengths(onsets) { it.lanes.size >= 2 }.maxOrNull() ?: 0) >= 45) {
                traits += IIDXChartTrait.CONSECUTIVE_CHORDS
            }
            val pairRuns = runLengths(onsets) { onset ->
                onset.lanes.size == 2 && onset.lanes.max() - onset.lanes.min() == 1
            }
            if (pairRuns.filter { it >= 6 }.sum() >= 12) {
                traits += IIDXChartTrait.ADJACENT_PAIRS
            }
            return traits
        }

        private fun stairOnsetCount(onsets: List<Onset>, chainLength: Int): Int {
            var ascending = mapOf<Int, Int>()
            var descending = mapOf<Int, Int>()
            val marked = mutableSetOf<Int>()
            onsets.forEachIndexed { index, onset ->
                val isConnected = index > 0 && onset.time - onsets[index - 1].time <= 250
                val nextAscending = mutableMapOf<Int, Int>()
                val nextDescending = mutableMapOf<Int, Int>()
                for (lane in onset.lanes) {
                    nextAscending[lane] = if (isConnected) (ascending[lane - 1] ?: 0) + 1 else 1
                    nextDescending[lane] = if (isConnected) (descending[lane + 1] ?: 0) + 1 else 1
                    val length = max(nextAscending.getValue(lane), nextDescending.getValue(lane))
                    if (length >= chainLength) {
                        marked.addAll((index - length + 1)..index)
                    }
                }
                ascending = nextAscending
                descending = nextDescending
            }
            return marked.size
        }

        private fun runLengths(onsets: List<Onset>, predicate: (Onset) -> Boolean): List<Int> {
            val lengths = mutableListOf<Int>()
            var current = 0
            onsets.forEachIndexed { index, onset ->
                if (predicate(onset)) {
                    val isConnected = index > 0 && onset.time - onsets[index - 1].time <= 250
                    current = if (current > 0 && isConnected) current + 1 else 1
                } else {
                    if (current > 0) lengths += current
                    current = 0
                }
            }
            if (current > 0) lengths += current
            return lengths
        }

        private fun scratchComboTraits(notes: List<IIDXChartNote>, playType: IIDXPlayType): List<IIDXChartTrait> {
            val noteCount = notes.size.toDouble()
            fun qualifies(hits: Int) = hits >= 100 && hits / noteCount >= 0.09
            val qualified = when (playType) {
                IIDXPlayType.DOUBLE -> qualifies(
                    scratchComboHits(notes, 0, setOf(1, 2, 3)) + scratchComboHits(notes, 8, setOf(13, 14, 15))
                )
                IIDXPlayType.SINGLE -> qualifies(scratchComboHits(notes, 0, setOf(1, 2, 3))) ||
                    qualifies(scratchComboHits(notes, 0, setOf(5, 6, 7)))
            }
            return if (qualified) listOf(IIDXChartTrait.SCRATCH_COMBO) else emptyList()
        }

        private fun scratchComboHits(notes: List<IIDXChartNote>, scratchLane: Int, keyLanes: Set<Int>): Int {
            val keys = notes.filter { it.lane in keyLanes }.map { it.time }.sorted()
            if (keys.isEmpty()) return 0
            return notes.filter { it.lane == scratchLane }.count { note ->
                val index = lowerBound(keys, note.time - 110.0)
                index < keys.size && keys[index] <= note.time + 110.0
            }
        }

        private data class Hold(val lane: Int, val start: Double, val end: Double)

        private fun isChargeCombo(notes: List<IIDXChartNote>, scratchLanes: Set<Int>): Boolean {
            val holds = notes.mapNotNull { note ->
                val end = note.endTime
                if (note.type == "normal" || end == null) null else Hold(note.lane, note.time + 30.0, end - 30.0)
            }
            if (holds.isEmpty()) return false
            val pressedDuringHold = notes.count { note ->
                note.type == "normal" && note.lane !in scratchLanes && holds.any { hold ->
                    hold.lane != note.lane && hold.start < note.time && note.time < hold.end
                }
            }
            return pressedDuringHold >= 60 && pressedDuringHold.toDouble() / notes.size >= 0.06
        }

        private fun beatLengthLookup(bpmChanges: List<IIDXChartBPMChange>): (Double) -> Double {
            val changes = bpmChanges.sortedBy { it.time }
            val changeTimes = changes.map { it.time }
            return { time ->
                if (changes.isEmpty()) {
                    400.0
                } else {
                    val bpm = changes[max(lowerBound(changeTimes, time + 1.0) - 1, 0)].bpm
                    if (bpm > 0.0) 60000.0 / bpm else 400.0
                }
            }
        }

        private fun hasJacks(
            notes: List<IIDXChartNote>,
            bpmChanges: List<IIDXChartBPMChange>,
            scratchLanes: Set<Int>
        ): Boolean {
            val beatLength = beatLengthLookup(bpmChanges)
            val notesByLane = notes.indices.filter { notes[it].lane !in scratchLanes }.groupBy { notes[it].lane }
            val marked = mutableSetOf<Int>()
            for (indices in notesByLane.values) {
                val sorted = indices.sortedBy { notes[it].time }
                var chain = mutableListOf<Int>()
                for (index in sorted) {
                    val previous = chain.lastOrNull()
                    if (previous == null) {
                        chain = mutableListOf(index)
                        continue
                    }
                    val previousNote = notes[previous]
                    val gap = notes[index].time - (previousNote.endTime ?: previousNote.time)
                    val beat = beatLength(previousNote.time)
                    if (gap <= 5.0) continue
                    if (gap <= min(beat * 0.26 + 1.0, 200.0)) {
                        marked += previous
                        marked += index
                    }
                    if (gap <= min(beat * 0.51 + 1.0, 200.0)) {
                        chain += index
                    } else {
                        if (chain.size >= 3) marked.addAll(chain)
                        chain = mutableListOf(index)
                    }
                }
                if (chain.size >= 3) marked.addAll(chain)
            }
            return marked.size >= 100 && marked.size.toDouble() / notes.size >= 0.10
        }

        private fun hasLegacyNotes(notes: List<IIDXChartNote>, playType: IIDXPlayType): Boolean {
            val noteCount = notes.size.toDouble()
            fun qualifies(hits: Int) = hits >= 50 && hits / noteCount >= 0.04
            return when (playType) {
                IIDXPlayType.DOUBLE -> qualifies(legacyNoteHits(notes, 0, 3) + legacyNoteHits(notes, 8, 13))
                IIDXPlayType.SINGLE -> qualifies(legacyNoteHits(notes, 0, 3)) ||
                    qualifies(legacyNoteHits(notes, 0, 5))
            }
        }

        private fun legacyNoteHits(notes: List<IIDXChartNote>, scratchLane: Int, keyLane: Int): Int {
            val keys = notes.filter { it.lane == keyLane }.map { it.time }.sorted()
            if (keys.isEmpty()) return 0
            return notes.filter { it.lane == scratchLane }.count { note ->
                val index = lowerBound(keys, note.time - 2.0)
                index < keys.size && keys[index] <= note.time + 2.0
            }
        }

        private fun hasChargeChords(
            notes: List<IIDXChartNote>,
            bpmChanges: List<IIDXChartBPMChange>,
            scratchLanes: Set<Int>
        ): Boolean {
            val beatLength = beatLengthLookup(bpmChanges)
            val keyTimes = notes.filter { it.lane !in scratchLanes }.map { it.time }.sorted()
            val chordedCharges = notes.count { note ->
                val end = note.endTime
                if (note.type == "normal" || note.lane in scratchLanes || end == null ||
                    end - note.time > beatLength(note.time) * 1.05
                ) {
                    false
                } else {
                    lowerBound(keyTimes, note.time + 2.0 + 1e-9) - lowerBound(keyTimes, note.time - 2.0) >= 2
                }
            }
            return chordedCharges >= 60 && chordedCharges.toDouble() / notes.size >= 0.05
        }

        // MARK: Soflan

        private data class BPMSegment(val bpm: Double, val duration: Double, val noteCount: Int)

        private fun soflanTraits(bpmChanges: List<IIDXChartBPMChange>, noteTimes: List<Double>): List<IIDXChartTrait> {
            val lastNote = noteTimes.lastOrNull() ?: return emptyList()
            val changes = bpmChanges.sortedBy { it.time }
            val segments = mutableListOf<BPMSegment>()
            changes.forEachIndexed { index, change ->
                val end = if (index + 1 < changes.size) changes[index + 1].time else lastNote
                if (change.bpm > 0.0 && end > change.time) {
                    val noteCount = lowerBound(noteTimes, end) - lowerBound(noteTimes, change.time)
                    segments += BPMSegment(change.bpm, end - change.time, noteCount)
                }
            }
            if (segments.size < 2) return emptyList()
            val traits = mutableListOf<IIDXChartTrait>()
            if (hasGradualSoflan(segments)) traits += IIDXChartTrait.GRADUAL_SOFLAN
            val hasSuddenSoflan = segments.zipWithNext().any { (previous, next) ->
                max(previous.bpm, next.bpm) / min(previous.bpm, next.bpm) >= 1.3 &&
                    previous.noteCount >= 3 && next.noteCount >= 3
            }
            if (hasSuddenSoflan) traits += IIDXChartTrait.SUDDEN_SOFLAN
            return traits
        }

        private fun hasGradualSoflan(segments: List<BPMSegment>): Boolean {
            var start = 0
            while (start < segments.size - 1) {
                var end = start
                var direction = 0.0
                while (end + 1 < segments.size) {
                    val ratio = segments[end + 1].bpm / segments[end].bpm
                    val step = max(ratio, 1.0 / ratio)
                    val stepDirection = if (ratio > 1.0) 1.0 else if (ratio < 1.0) -1.0 else 0.0
                    if (stepDirection == 0.0 || step > 1.3 || (direction != 0.0 && stepDirection != direction) ||
                        (end > start && segments[end].duration > 4000.0)
                    ) {
                        break
                    }
                    direction = stepDirection
                    end++
                }
                if (end - start >= 3) {
                    val total = max(segments[start].bpm, segments[end].bpm) /
                        min(segments[start].bpm, segments[end].bpm)
                    val noteCount = (start + 1..end).sumOf { segments[it].noteCount }
                    if (total >= 1.2 && noteCount >= 8) return true
                }
                start = max(end, start + 1)
            }
            return false
        }

        // MARK: Helpers

        private fun densities(times: List<Double>, window: Double): List<Window> {
            if (times.isEmpty()) return emptyList()
            val last = times.last()
            val results = mutableListOf<Window>()
            var lower = 0
            var upper = 0
            var start = times.first()
            while (start + window <= last + 1e-9) {
                while (lower < times.size && times[lower] < start) lower++
                while (upper < times.size && times[upper] < start + window) upper++
                results += Window(start, (upper - lower) / window)
                start += 0.5
            }
            return results
        }

        private fun lowerBound(values: List<Double>, target: Double): Int {
            var low = 0
            var high = values.size
            while (low < high) {
                val middle = (low + high) / 2
                if (values[middle] < target) low = middle + 1 else high = middle
            }
            return low
        }

        private fun median(values: List<Double>): Double {
            if (values.isEmpty()) return 0.0
            val sorted = values.sorted()
            val middle = sorted.size / 2
            return if (sorted.size % 2 == 0) (sorted[middle - 1] + sorted[middle]) / 2.0 else sorted[middle]
        }
    }
}
