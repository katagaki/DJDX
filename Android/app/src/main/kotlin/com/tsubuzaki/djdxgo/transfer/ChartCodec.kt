package com.tsubuzaki.djdxgo.transfer

import java.security.MessageDigest

object ChartCodec {
    const val ROWS_PER_BLOCK = 32
    const val LANES = 8
    private const val PAYLOAD_BYTES = 16
    private const val CHUNK_BYTES = 15
    private const val PARITY_BYTES = 14
    const val MAX_BLOCKS = 15
    const val MAX_MESSAGE_BYTES = MAX_BLOCKS * CHUNK_BYTES - 1
    private const val ERASURE_THRESHOLD = 0.3f
    private const val DECODE_MARGIN = 2

    private val whitening = sha256("DJDX-CHART1-WHITEN".toByteArray()).map { it.toInt() and 0xFF }
    private val reedSolomon = ChartReedSolomon(PARITY_BYTES)

    fun sha256(vararg parts: ByteArray): ByteArray {
        val digest = MessageDigest.getInstance("SHA-256")
        parts.forEach { digest.update(it) }
        return digest.digest()
    }

    private fun checksum(payload: IntArray): IntArray {
        val hash = sha256("DJDX-CHART1".toByteArray(), ByteArray(payload.size) { payload[it].toByte() })
        return intArrayOf(hash[0].toInt() and 0xFF, hash[1].toInt() and 0xFF)
    }

    fun pairingNumber(message: ByteArray): String {
        val h = sha256("DJDX-PAIR1".toByteArray(), message)
        val n = ((h[0].toLong() and 0xFF) shl 24 or ((h[1].toLong() and 0xFF) shl 16) or
            ((h[2].toLong() and 0xFF) shl 8) or (h[3].toLong() and 0xFF)) % 10000
        return n.toString().padStart(4, '0')
    }

    private fun symbolCells(i: Int): IntArray {
        val measure = i / 8
        val lane = i % 8
        return IntArray(8) { (measure * 8 + it) * LANES + lane }
    }

    fun chart(message: ByteArray): BooleanArray? {
        if (message.size > MAX_MESSAGE_BYTES) return null
        val bytes = intArrayOf(message.size) + message.map { it.toInt() and 0xFF }
        val count = (bytes.size + CHUNK_BYTES - 1) / CHUNK_BYTES
        val bits = ArrayList<Boolean>()
        for (index in 0 until count) {
            val part = bytes.copyOfRange(index * CHUNK_BYTES, minOf(bytes.size, (index + 1) * CHUNK_BYTES))
            val payload = intArrayOf(index shl 4 or count) + part + IntArray(CHUNK_BYTES - part.size)
            bits += encodeBlock(payload).toList()
        }
        return bits.toBooleanArray()
    }

    fun encodeBlock(payload: IntArray): BooleanArray {
        val codeword = reedSolomon.encode(payload + checksum(payload))
        val bits = BooleanArray(ROWS_PER_BLOCK * LANES)
        for (i in 0 until 32) {
            val byte = codeword[i] xor whitening[i]
            symbolCells(i).forEachIndexed { bit, cell -> bits[cell] = byte and (0x80 shr bit) != 0 }
        }
        return bits
    }

    fun decodeBlock(bits: BooleanArray, confidence: FloatArray): IntArray? {
        val raw = IntArray(32)
        val conf = FloatArray(32) { 1f }
        for (i in 0 until 32) {
            var byte = 0
            symbolCells(i).forEachIndexed { bit, cell ->
                if (bits[cell]) byte = byte or (0x80 shr bit)
                conf[i] = minOf(conf[i], confidence[cell])
            }
            raw[i] = byte xor whitening[i]
        }
        val order = (0 until 32).sortedBy { conf[it] }
        val base = order.count { conf[it] < ERASURE_THRESHOLD }
        val limit = PARITY_BYTES - DECODE_MARGIN
        if (base > limit) return null
        for (erased in base..limit) {
            val erasures = order.take(erased)
            val data = reedSolomon.decode(raw, erasures) ?: continue
            val payload = data.copyOfRange(0, PAYLOAD_BYTES)
            if (!data.copyOfRange(PAYLOAD_BYTES, data.size).contentEquals(checksum(payload))) continue
            val codeword = reedSolomon.encode(data)
            val erasedSet = erasures.toSet()
            val corrected = (0 until 32).count { it !in erasedSet && codeword[it] != raw[it] }
            if (erased + 2 * corrected <= limit) return payload
        }
        return null
    }

    fun blockIndex(payload: IntArray): Int = payload[0] shr 4
    fun blockCount(payload: IntArray): Int = payload[0] and 0x0F

    fun assemble(blocks: Map<Int, IntArray>, count: Int): ByteArray? {
        if (blocks.size != count) return null
        val bytes = ArrayList<Int>()
        for (i in 0 until count) bytes += (blocks[i] ?: return null).drop(1)
        val length = bytes[0]
        if (length >= bytes.size) return null
        return ByteArray(length) { bytes[it + 1].toByte() }
    }
}
