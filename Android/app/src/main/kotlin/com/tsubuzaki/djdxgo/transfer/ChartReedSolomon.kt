package com.tsubuzaki.djdxgo.transfer

internal object ChartGF {
    private val exp = IntArray(512)
    private val log = IntArray(256)

    init {
        var x = 1
        for (i in 0 until 255) {
            exp[i] = x
            log[x] = i
            x = x shl 1
            if (x and 0x100 != 0) x = x xor 0x11d
        }
        for (i in 255 until 512) exp[i] = exp[i - 255]
    }

    fun mul(a: Int, b: Int): Int = if (a == 0 || b == 0) 0 else exp[log[a] + log[b]]

    fun div(a: Int, b: Int): Int = if (a == 0) 0 else exp[(log[a] + 255 - log[b]) % 255]

    fun pow(a: Int, p: Int): Int = exp[((log[a] * p) % 255 + 255) % 255]

    fun inverse(a: Int): Int = exp[255 - log[a]]

    fun scale(p: IntArray, x: Int): IntArray = IntArray(p.size) { mul(p[it], x) }

    fun add(p: IntArray, q: IntArray): IntArray {
        val n = maxOf(p.size, q.size)
        val r = IntArray(n)
        for (i in p.indices) r[i + n - p.size] = p[i]
        for (i in q.indices) r[i + n - q.size] = r[i + n - q.size] xor q[i]
        return r
    }

    fun multiply(p: IntArray, q: IntArray): IntArray {
        val r = IntArray(p.size + q.size - 1)
        for (j in q.indices) for (i in p.indices) r[i + j] = r[i + j] xor mul(p[i], q[j])
        return r
    }

    fun evaluate(p: IntArray, x: Int): Int {
        var y = p[0]
        for (i in 1 until p.size) y = mul(y, x) xor p[i]
        return y
    }
}

internal class ChartReedSolomon(private val nsym: Int) {
    private val generator: IntArray

    init {
        var g = intArrayOf(1)
        for (i in 0 until nsym) g = ChartGF.multiply(g, intArrayOf(1, ChartGF.pow(2, i)))
        generator = g
    }

    fun encode(msg: IntArray): IntArray {
        val out = msg.copyOf(msg.size + nsym)
        for (i in msg.indices) {
            val coef = out[i]
            if (coef != 0) for (j in 1 until generator.size) out[i + j] = out[i + j] xor ChartGF.mul(generator[j], coef)
        }
        for (i in msg.indices) out[i] = msg[i]
        return out
    }

    fun decode(input: IntArray, erasures: List<Int>): IntArray? {
        if (erasures.size > nsym) return null
        var msg = input.copyOf()
        for (e in erasures) msg[e] = 0
        val synd = syndromes(msg)
        if (synd.all { it == 0 }) return msg.copyOf(msg.size - nsym)
        val fsynd = forneySyndromes(synd, erasures, msg.size)
        val errLoc = errorLocator(fsynd, erasures.size) ?: return null
        val errPos = findErrors(errLoc.reversedArray(), msg.size) ?: return null
        msg = correctErrata(msg, synd, erasures + errPos) ?: return null
        if (syndromes(msg).any { it != 0 }) return null
        return msg.copyOf(msg.size - nsym)
    }

    private fun syndromes(msg: IntArray): IntArray =
        intArrayOf(0) + IntArray(nsym) { ChartGF.evaluate(msg, ChartGF.pow(2, it)) }

    private fun errataLocator(positions: List<Int>): IntArray {
        var loc = intArrayOf(1)
        for (i in positions) loc = ChartGF.multiply(loc, ChartGF.add(intArrayOf(1), intArrayOf(ChartGF.pow(2, i), 0)))
        return loc
    }

    private fun correctErrata(msg: IntArray, synd: IntArray, errPos: List<Int>): IntArray? {
        val coefPos = errPos.map { msg.size - 1 - it }
        val errLoc = errataLocator(coefPos)
        val product = ChartGF.multiply(synd.reversedArray(), errLoc)
        val evaluator = product.copyOfRange(product.size - errLoc.size, product.size)
        val xs = coefPos.map { ChartGF.pow(2, -(255 - it)) }
        val e = IntArray(msg.size)
        for ((i, xi) in xs.withIndex()) {
            val xiInv = ChartGF.inverse(xi)
            var prime = 1
            for (j in xs.indices) if (j != i) prime = ChartGF.mul(prime, 1 xor ChartGF.mul(xiInv, xs[j]))
            if (prime == 0) return null
            val y = ChartGF.mul(xi, ChartGF.evaluate(evaluator, xiInv))
            e[errPos[i]] = ChartGF.div(y, prime)
        }
        return ChartGF.add(msg, e)
    }

    private fun errorLocator(synd: IntArray, eraseCount: Int): IntArray? {
        var errLoc = intArrayOf(1)
        var oldLoc = intArrayOf(1)
        val shift = if (synd.size > nsym) synd.size - nsym else 0
        for (i in 0 until nsym - eraseCount) {
            val k = i + shift
            var delta = synd[k]
            for (j in 1 until errLoc.size) delta = delta xor ChartGF.mul(errLoc[errLoc.size - 1 - j], synd[k - j])
            oldLoc += 0
            if (delta != 0) {
                if (oldLoc.size > errLoc.size) {
                    val newLoc = ChartGF.scale(oldLoc, delta)
                    oldLoc = ChartGF.scale(errLoc, ChartGF.inverse(delta))
                    errLoc = newLoc
                }
                errLoc = ChartGF.add(errLoc, ChartGF.scale(oldLoc, delta))
            }
        }
        val first = errLoc.indexOfFirst { it != 0 }
        if (first < 0) return null
        errLoc = errLoc.copyOfRange(first, errLoc.size)
        if ((errLoc.size - 1) * 2 + eraseCount > nsym) return null
        return errLoc
    }

    private fun findErrors(errLocRev: IntArray, n: Int): List<Int>? {
        val positions = (0 until n).filter { ChartGF.evaluate(errLocRev, ChartGF.pow(2, it)) == 0 }.map { n - 1 - it }
        return if (positions.size == errLocRev.size - 1) positions else null
    }

    private fun forneySyndromes(synd: IntArray, positions: List<Int>, n: Int): IntArray {
        val f = synd.copyOfRange(1, synd.size)
        for (p in positions) {
            val x = ChartGF.pow(2, n - 1 - p)
            for (j in 0 until f.size - 1) f[j] = ChartGF.mul(f[j], x) xor f[j + 1]
        }
        return f
    }
}
