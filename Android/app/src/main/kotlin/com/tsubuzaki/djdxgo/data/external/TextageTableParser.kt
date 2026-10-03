package com.tsubuzaki.djdxgo.data.external

import com.tsubuzaki.djdxgo.data.compact
import org.jsoup.parser.Parser

object TextageTableParser {

    private data class TitleEntry(val version: Int, val title: String)

    fun charts(titleTableText: String, accessTableText: String): List<TextageChart> {
        val titles = parseTitleTable(titleTableText)
        val access = parseAccessTable(accessTableText)
        return access.mapNotNull { (tag, values) ->
            val meta = titles[tag] ?: return@mapNotNull null
            val chart = TextageChart(
                tag = tag,
                version = meta.version,
                title = meta.title,
                titleCompact = meta.title.compact,
                spNormal = values[5],
                spHyper = values[7],
                spAnother = values[9],
                spLeggendaria = values[11],
                dpNormal = values[15],
                dpHyper = values[17],
                dpAnother = values[19],
                dpLeggendaria = values[21]
            )
            val hasAnyChart = listOf(
                chart.spNormal, chart.spHyper, chart.spAnother, chart.spLeggendaria,
                chart.dpNormal, chart.dpHyper, chart.dpAnother, chart.dpLeggendaria
            ).any { it > 0 }
            if (hasAnyChart && chart.title.isNotEmpty()) chart else null
        }
    }

    private fun parseTitleTable(text: String): Map<String, TitleEntry> {
        val result = mutableMapOf<String, TitleEntry>()
        for (rawLine in text.lines()) {
            val line = stripBlockComments(rawLine)
            if (line.trim().startsWith("//")) continue
            val tag = extractTag(line) ?: continue
            val bracket = extractBracketContent(line) ?: continue
            val version = parseVersion(bracket) ?: continue
            val strings = quotedStrings(bracket)
            if (strings.size < 3) continue
            val title = cleanTitle(strings[2])
            if (title.isEmpty()) continue
            result[tag] = TitleEntry(version, title)
        }
        return result
    }

    private fun parseAccessTable(text: String): Map<String, List<Int>> {
        val result = mutableMapOf<String, List<Int>>()
        for (rawLine in text.lines()) {
            val line = stripBlockComments(rawLine)
            if (line.trim().startsWith("//")) continue
            val tag = extractTag(line) ?: continue
            val bracket = extractBracketContent(line) ?: continue
            val values = bracket.split(",").take(ACCESS_VALUE_COUNT).map(::parseLevelToken)
            if (values.size >= ACCESS_VALUE_COUNT) result[tag] = values
        }
        return result
    }

    private fun parseVersion(bracket: String): Int? {
        val first = bracket.substringBefore(",").trim()
        if (first == "SS") return SUBSTREAM_VERSION
        return first.toIntOrNull()
    }

    private fun parseLevelToken(token: String): Int {
        val value = token.trim()
        value.toIntOrNull()?.let { return it }
        if (value.length == 1) value.toIntOrNull(16)?.let { return it }
        return 0
    }

    private fun extractTag(line: String): String? {
        val firstQuote = line.indexOf('\'')
        if (firstQuote < 0) return null
        val secondQuote = line.indexOf('\'', firstQuote + 1)
        if (secondQuote < 0) return null
        val tag = line.substring(firstQuote + 1, secondQuote)
        if (tag.isEmpty() || !tag.all { it.isLetterOrDigit() || it == '_' }) return null
        return tag
    }

    private fun extractBracketContent(line: String): String? {
        val open = line.indexOf('[')
        val close = line.lastIndexOf(']')
        if (open < 0 || close <= open) return null
        return line.substring(open + 1, close)
    }

    private fun stripBlockComments(line: String): String =
        line.replace(Regex("/\\*.*?\\*/"), "")

    private fun cleanTitle(raw: String): String =
        Parser.unescapeEntities(raw.replace(Regex("<[^>]+>"), ""), false).trim()

    private fun quotedStrings(string: String): List<String> {
        val result = mutableListOf<String>()
        val current = StringBuilder()
        var inQuote = false
        var escaped = false
        for (character in string) {
            if (inQuote) {
                when {
                    escaped -> {
                        current.append(character)
                        escaped = false
                    }
                    character == '\\' -> escaped = true
                    character == '"' -> {
                        result.add(current.toString())
                        current.clear()
                        inQuote = false
                    }
                    else -> current.append(character)
                }
            } else if (character == '"') {
                inQuote = true
                current.clear()
            }
        }
        return result
    }

    private const val ACCESS_VALUE_COUNT = 23
    private const val SUBSTREAM_VERSION = 35
}
