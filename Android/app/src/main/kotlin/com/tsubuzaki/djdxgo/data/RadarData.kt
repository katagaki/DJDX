package com.tsubuzaki.djdxgo.data

import com.tsubuzaki.djdxgo.data.external.NotesRadarEntry

data class RadarData(
    val notes: Double = 0.0,
    val chord: Double = 0.0,
    val peak: Double = 0.0,
    val charge: Double = 0.0,
    val scratch: Double = 0.0,
    val soflan: Double = 0.0
) {
    fun sum(): Double = notes + chord + peak + charge + scratch + soflan

    fun value(axis: RadarAxis): Double = when (axis) {
        RadarAxis.NOTES -> notes
        RadarAxis.CHORD -> chord
        RadarAxis.PEAK -> peak
        RadarAxis.CHARGE -> charge
        RadarAxis.SCRATCH -> scratch
        RadarAxis.SOFLAN -> soflan
    }

    fun highestAxis(): RadarAxis = RadarAxis.displayOrder.maxBy { value(it) }
}

enum class RadarAxis(val label: String) {
    NOTES("NOTES"),
    CHORD("CHORD"),
    PEAK("PEAK"),
    CHARGE("CHARGE"),
    SCRATCH("SCRATCH"),
    SOFLAN("SOF-LAN");

    companion object {
        val displayOrder: List<RadarAxis> = listOf(NOTES, CHORD, PEAK, CHARGE, SCRATCH, SOFLAN)
        val chartOrder: List<RadarAxis> = listOf(NOTES, CHORD, CHARGE, SOFLAN, SCRATCH, PEAK)
    }
}

fun NotesRadarEntry.toRadarData(): RadarData =
    RadarData(notes = notes, chord = chord, peak = peak, charge = charge, scratch = scratch, soflan = soflan)
