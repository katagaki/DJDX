package com.tsubuzaki.djdxgo.data

// Port of CSwiftV: CSV keyed rows with quote-parity line joining.
object Csv {

    fun keyedRows(csv: String): List<Map<String, String>> {
        val content = csv.removePrefix("﻿").replace("\r\n", "\n")
        val lines = joinQuotedLines(content.split("\n"))
        if (lines.isEmpty()) return emptyList()
        val headers = parseLine(lines.first())
        return lines.drop(1)
            .filter { it.isNotBlank() }
            .map { line ->
                val cells = parseLine(line)
                buildMap {
                    headers.forEachIndexed { index, header ->
                        val value = cells.getOrNull(index)?.trim() ?: return@forEachIndexed
                        if (value.isNotEmpty()) put(header.trim(), value)
                    }
                }
            }
    }

    private fun joinQuotedLines(rawLines: List<String>): List<String> {
        val lines = mutableListOf<String>()
        var pending = ""
        for (rawLine in rawLines) {
            val candidate = if (pending.isEmpty()) rawLine else "$pending\n$rawLine"
            if (candidate.count { it == '"' } % 2 == 0) {
                lines.add(candidate)
                pending = ""
            } else {
                pending = candidate
            }
        }
        if (pending.isNotEmpty()) lines.add(pending)
        return lines
    }

    private fun parseLine(line: String): List<String> {
        val cells = mutableListOf<String>()
        val current = StringBuilder()
        var inQuotes = false
        var index = 0
        while (index < line.length) {
            val char = line[index]
            when {
                char == '"' && inQuotes && index + 1 < line.length && line[index + 1] == '"' -> {
                    current.append('"')
                    index++
                }
                char == '"' -> inQuotes = !inQuotes
                char == ',' && !inQuotes -> {
                    cells.add(current.toString())
                    current.clear()
                }
                else -> current.append(char)
            }
            index++
        }
        cells.add(current.toString())
        return cells
    }
}
