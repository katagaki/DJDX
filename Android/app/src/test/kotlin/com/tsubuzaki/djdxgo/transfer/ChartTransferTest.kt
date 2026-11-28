package com.tsubuzaki.djdxgo.transfer

import java.security.MessageDigest
import kotlin.random.Random
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class ChartTransferTest {

    private fun hex(bytes: ByteArray) = bytes.joinToString("") { "%02x".format(it) }

    private fun bitsHash(bits: BooleanArray) =
        hex(MessageDigest.getInstance("SHA-256").digest(ByteArray(bits.size) { if (bits[it]) 1 else 0 }))

    private val identity = LampIdentity.fromPrivateKey(ChartCodec.sha256("lamp-test-vector".toByteArray()))!!

    @Test
    fun identityMatchesIOS() {
        assertEquals("cb78c0a2476068038a5bd04c5adb016f3e5f26baac47b0d30b5225c992e2925b", hex(identity.privateKey))
        assertEquals(
            "048369b3e2cc2b57f84e17373086b491b33a15e20d34d6effe410eca60ffd3e5f8" +
                "7db4a87cf9cf40947a55b7bf13b360fc09e6660142334af1e66e1df34113f876",
            hex(identity.publicKey)
        )
        assertEquals("tvHxYaElHEno22xrvtzZYw", identity.contributorId)
        assertEquals("MK51-DPYS-69NM-7335-7SYF-Z93P-1G", identity.deletionCode)
    }

    @Test
    fun chartsMatchIOS() {
        assertEquals("e91607ebdc2510caed92046c63a9b771c7cf36b94c800f35f59017eafb309ccc", bitsHash(ChartCodec.chart(identity.transferMessage)!!))
        assertEquals("8636", ChartCodec.pairingNumber(identity.transferMessage))
        val text = "今日も楽しく灼熱Beachside Bunnyでお皿を回しまくれえええ".toByteArray()
        assertEquals("ea62dad42705c6d210d1a0b58a53caaaf5b0fd812d0a7612087543f381096c88", bitsHash(ChartCodec.chart(text)!!))
        assertEquals("2034", ChartCodec.pairingNumber(text))
    }

    @Test
    fun reedSolomonCorrectsErrorsAndErasures() {
        val random = Random(7)
        val rs = ChartReedSolomon(14)
        repeat(2000) {
            val data = IntArray(18) { random.nextInt(256) }
            val codeword = rs.encode(data)
            val erasures = random.nextInt(15)
            val errors = random.nextInt((14 - erasures) / 2 + 1)
            val positions = (0 until 32).shuffled(random).take(erasures + errors)
            positions.forEach { codeword[it] = codeword[it] xor (1 + random.nextInt(255)) }
            assertArrayEquals(data, rs.decode(codeword, positions.take(erasures)))
        }
    }

    @Test
    fun transferRoundTripsThroughDecoder() {
        val message = identity.transferMessage
        val bits = ChartCodec.chart(message)!!
        val decoder = ChartDecoder()
        var received: ByteArray? = null
        for (frame in 0 until 1800) {
            val time = 1.7 + frame / 30.0
            received = decoder.process(render(bits, time), time).message
            if (received != null) break
        }
        assertNotNull(received)
        assertEquals(identity, LampIdentity.fromTransferMessage(received!!))
    }

    private fun render(bits: BooleanArray, time: Double): ChartFrame {
        val p = ChartPlayfield
        val width = 195
        val height = 422
        val scale = 0.5
        val luma = FloatArray(width * height) { 0.04f }
        val green = FloatArray(width * height)
        fun fill(x0: Double, x1: Double, y0: Double, y1: Double, value: Float, isGreen: Boolean = false) {
            for (y in (y0 * scale).toInt() until (y1 * scale).toInt().coerceAtMost(height)) {
                for (x in (x0 * scale).toInt() until (x1 * scale).toInt().coerceAtMost(width)) {
                    if (y < 0 || x < 0) continue
                    luma[y * width + x] = value
                    if (isGreen) green[y * width + x] = 0.65f
                }
            }
        }
        val half = p.FIDUCIAL_SIZE / 2
        for ((x, y) in p.fiducials) fill(x - half, x + half, y - half, y + half, 0.95f, true)
        val rows = bits.size / 8
        val offset = p.SPEED * time
        for (k in Math.floor((offset - p.PITCH) / p.PITCH).toInt()..Math.ceil((p.JUDGE_Y + offset) / p.PITCH).toInt()) {
            val y = p.JUDGE_Y - k * p.PITCH + offset
            val row = Math.floorMod(k, rows)
            fun clipped(y0: Double, y1: Double) = maxOf(y0, p.VISIBLE_TOP) to minOf(y1, p.JUDGE_Y)
            if (row % 8 == 0) {
                val barY = y + p.PITCH / 2
                val markHalf = if (row % ChartCodec.ROWS_PER_BLOCK == 0) 14.0 else 4.0
                val (top, bottom) = clipped(barY - markHalf, barY + markHalf)
                if (top < bottom) {
                    fill(p.frameX + 2, p.frameX + p.GUTTER - 2, top, bottom, 0.85f)
                    fill(p.frameX + p.frameWidth - p.GUTTER + 2, p.frameX + p.frameWidth - 2, top, bottom, 0.85f)
                }
            }
            for (lane in 0 until 8) {
                if (!bits[row * 8 + lane]) continue
                val (top, bottom) = clipped(y - p.NOTE_HEIGHT / 2, y + p.NOTE_HEIGHT / 2)
                if (top < bottom) fill(p.laneX0[lane] + 2, p.laneX1(lane) - 2, top, bottom, 0.95f)
            }
        }
        return ChartFrame(width, height, luma, green)
    }
}
