package com.tsubuzaki.djdxgo.transfer

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.math.BigInteger
import java.security.KeyStore
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

class LampIdentity private constructor(val privateKey: ByteArray) {

    val transferMessage: ByteArray get() = TRANSFER_MAGIC + privateKey

    val publicKey: ByteArray by lazy { P256.publicKey(BigInteger(1, privateKey)) }

    val contributorId: String by lazy { base64Url(ChartCodec.sha256(publicKey).copyOf(16)) }

    val deletionCode: String by lazy {
        crockfordBase32(hkdfSha256(privateKey, "LAMP1".toByteArray(), "deletion-code".toByteArray(), 16)).chunked(4).joinToString("-")
    }

    override fun equals(other: Any?): Boolean = other is LampIdentity && other.privateKey.contentEquals(privateKey)

    override fun hashCode(): Int = privateKey.contentHashCode()

    companion object {
        private val TRANSFER_MAGIC = byteArrayOf(0x4C, 0x01)

        fun generate(): LampIdentity {
            val random = SecureRandom()
            while (true) {
                val bytes = ByteArray(32).also(random::nextBytes)
                fromPrivateKey(bytes)?.let { return it }
            }
        }

        fun fromPrivateKey(bytes: ByteArray): LampIdentity? {
            if (bytes.size != 32) return null
            val d = BigInteger(1, bytes)
            if (d.signum() == 0 || d >= P256.n) return null
            return LampIdentity(bytes.copyOf())
        }

        fun fromTransferMessage(message: ByteArray): LampIdentity? {
            if (message.size != TRANSFER_MAGIC.size + 32 || !message.copyOf(TRANSFER_MAGIC.size).contentEquals(TRANSFER_MAGIC)) return null
            return fromPrivateKey(message.copyOfRange(TRANSFER_MAGIC.size, message.size))
        }

        fun base64Url(bytes: ByteArray): String =
            Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)

        fun crockfordBase32(bytes: ByteArray): String {
            val alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
            val result = StringBuilder()
            var buffer = 0
            var bits = 0
            for (byte in bytes) {
                buffer = (buffer shl 8) or (byte.toInt() and 0xFF)
                bits += 8
                while (bits >= 5) {
                    result.append(alphabet[(buffer shr (bits - 5)) and 31])
                    bits -= 5
                }
                buffer = buffer and ((1 shl bits) - 1)
            }
            if (bits > 0) result.append(alphabet[(buffer shl (5 - bits)) and 31])
            return result.toString()
        }

        fun hkdfSha256(ikm: ByteArray, salt: ByteArray, info: ByteArray, length: Int): ByteArray {
            val extract = Mac.getInstance("HmacSHA256").apply { init(SecretKeySpec(salt, "HmacSHA256")) }.doFinal(ikm)
            val expand = Mac.getInstance("HmacSHA256").apply { init(SecretKeySpec(extract, "HmacSHA256")) }
            val output = ArrayList<Byte>()
            var previous = ByteArray(0)
            var counter = 1
            while (output.size < length) {
                expand.update(previous)
                expand.update(info)
                expand.update(counter.toByte())
                previous = expand.doFinal()
                output += previous.toList()
                counter++
            }
            return output.take(length).toByteArray()
        }
    }
}

internal object P256 {
    private val p = BigInteger("ffffffff00000001000000000000000000000000ffffffffffffffffffffffff", 16)
    private val a = p - BigInteger.valueOf(3)
    val n = BigInteger("ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551", 16)
    private val gx = BigInteger("6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296", 16)
    private val gy = BigInteger("4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5", 16)

    private class Point(val x: BigInteger, val y: BigInteger)

    private fun add(left: Point?, right: Point?): Point? {
        if (left == null) return right
        if (right == null) return left
        val lambda = if (left.x == right.x) {
            if ((left.y + right.y).mod(p).signum() == 0) return null
            (left.x.pow(2).multiply(BigInteger.valueOf(3)) + a).multiply(left.y.shiftLeft(1).modInverse(p)).mod(p)
        } else {
            (right.y - left.y).multiply((right.x - left.x).modInverse(p)).mod(p)
        }
        val x = (lambda.pow(2) - left.x - right.x).mod(p)
        return Point(x, (lambda.multiply(left.x - x) - left.y).mod(p))
    }

    fun publicKey(d: BigInteger): ByteArray {
        var result: Point? = null
        var addend: Point? = Point(gx, gy)
        for (bit in 0 until d.bitLength()) {
            if (d.testBit(bit)) result = add(result, addend)
            addend = add(addend, addend)
        }
        val point = result!!
        return byteArrayOf(0x04) + fixed(point.x) + fixed(point.y)
    }

    private fun fixed(value: BigInteger): ByteArray {
        val bytes = value.toByteArray()
        return when {
            bytes.size == 32 -> bytes
            bytes.size > 32 -> bytes.copyOfRange(bytes.size - 32, bytes.size)
            else -> ByteArray(32 - bytes.size) + bytes
        }
    }
}

object LampKeyStore {
    private const val PREFERENCES = "lamp"
    private const val KEY = "contributor_key"
    private const val WRAP_ALIAS = "lamp_contributor_wrap"

    private fun wrappingKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(WRAP_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(WRAP_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build()
        )
        return generator.generateKey()
    }

    fun load(context: Context): LampIdentity? = runCatching {
        val stored = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).getString(KEY, null) ?: return null
        val data = Base64.getDecoder().decode(stored)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, wrappingKey(), GCMParameterSpec(128, data, 0, 12))
        LampIdentity.fromPrivateKey(cipher.doFinal(data, 12, data.size - 12))
    }.getOrNull()

    fun save(context: Context, identity: LampIdentity): Boolean = runCatching {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, wrappingKey())
        val stored = Base64.getEncoder().encodeToString(cipher.iv + cipher.doFinal(identity.privateKey))
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit().putString(KEY, stored).commit()
    }.getOrDefault(false)
}
