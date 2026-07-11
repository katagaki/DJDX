package com.tsubuzaki.djdxgo.data

import java.text.Normalizer

private val replacements = mapOf(
    "Ø" to "O",
    "！" to "!",
    "？" to "?",
    "（" to "(",
    "）" to ")",
    "：" to ":",
    "／" to "/",
    "，" to ",",
    "〜" to "~",
    "ー" to "-",
    "　" to "",
    " " to "",
    "・" to "•",
    "‘" to "'",
    "’" to "'",
    "“" to "\"",
    "”" to "\"",
    "¡" to "!",
    "■" to "",
    "□" to "",
    "★" to "",
    "☆" to "",
    "♥" to "",
    "♡" to "",
    "Ʞ" to "K",
    "И" to "N"
)

val String.compact: String
    get() {
        var result = Normalizer.normalize(this, Normalizer.Form.NFKC)
        replacements.forEach { (from, to) -> result = result.replace(from, to) }
        result = Normalizer.normalize(result, Normalizer.Form.NFD)
            .replace(Regex("\\p{Mn}+"), "")
        return result.lowercase()
    }

val String.ddrCompact: String
    get() = replace(Regex("【[^】]*】"), "")
        .replace(Regex("\\*\\d+$"), "")
        .compact

fun editDistance(a: String, b: String): Int {
    if (a == b) return 0
    if (a.isEmpty()) return b.length
    if (b.isEmpty()) return a.length
    var previous = IntArray(b.length + 1) { it }
    val current = IntArray(b.length + 1)
    for (i in 1..a.length) {
        current[0] = i
        for (j in 1..b.length) {
            val cost = if (a[i - 1] == b[j - 1]) 0 else 1
            current[j] = minOf(current[j - 1] + 1, previous[j] + 1, previous[j - 1] + cost)
        }
        previous = current.copyOf()
    }
    return previous[b.length]
}

fun editRatio(a: String, b: String): Double {
    val maxLength = maxOf(a.length, b.length)
    if (maxLength == 0) return 0.0
    return editDistance(a, b).toDouble() / maxLength
}
