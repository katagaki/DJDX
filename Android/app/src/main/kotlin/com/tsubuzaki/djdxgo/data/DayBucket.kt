package com.tsubuzaki.djdxgo.data

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

data class DayBucket(val startOfDay: Long, val startOfNextDay: Long)

fun dayBucket(epochSeconds: Long): DayBucket {
    val zone = ZoneId.systemDefault()
    val day = Instant.ofEpochSecond(epochSeconds).atZone(zone).toLocalDate()
    return DayBucket(
        startOfDay = day.atStartOfDay(zone).toEpochSecond(),
        startOfNextDay = day.plusDays(1).atStartOfDay(zone).toEpochSecond()
    )
}

fun startOfDay(date: LocalDate): Long =
    date.atStartOfDay(ZoneId.systemDefault()).toEpochSecond()

fun endOfDayExclusive(date: LocalDate): Long =
    date.plusDays(1).atStartOfDay(ZoneId.systemDefault()).toEpochSecond()
