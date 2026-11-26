import Foundation

enum ChartGF {
    static let tables: (exp: [UInt8], log: [Int]) = {
        var exp = [UInt8](repeating: 0, count: 512)
        var log = [Int](repeating: 0, count: 256)
        var x = 1
        for i in 0..<255 {
            exp[i] = UInt8(x)
            log[x] = i
            x <<= 1
            if x & 0x100 != 0 { x ^= 0x11d }
        }
        for i in 255..<512 { exp[i] = exp[i - 255] }
        return (exp, log)
    }()

    @inline(__always) static func mul(_ a: UInt8, _ b: UInt8) -> UInt8 {
        if a == 0 || b == 0 { return 0 }
        return tables.exp[tables.log[Int(a)] + tables.log[Int(b)]]
    }

    static func div(_ a: UInt8, _ b: UInt8) -> UInt8 {
        if a == 0 { return 0 }
        return tables.exp[(tables.log[Int(a)] + 255 - tables.log[Int(b)]) % 255]
    }

    static func pow(_ a: UInt8, _ p: Int) -> UInt8 {
        tables.exp[((tables.log[Int(a)] * p) % 255 + 255) % 255]
    }

    static func inverse(_ a: UInt8) -> UInt8 { tables.exp[255 - tables.log[Int(a)]] }

    static func scale(_ p: [UInt8], _ x: UInt8) -> [UInt8] { p.map { mul($0, x) } }

    static func add(_ p: [UInt8], _ q: [UInt8]) -> [UInt8] {
        let n = max(p.count, q.count)
        var r = [UInt8](repeating: 0, count: n)
        for i in 0..<p.count { r[i + n - p.count] = p[i] }
        for i in 0..<q.count { r[i + n - q.count] ^= q[i] }
        return r
    }

    static func multiply(_ p: [UInt8], _ q: [UInt8]) -> [UInt8] {
        var r = [UInt8](repeating: 0, count: p.count + q.count - 1)
        for j in 0..<q.count {
            for i in 0..<p.count { r[i + j] ^= mul(p[i], q[j]) }
        }
        return r
    }

    static func evaluate(_ p: [UInt8], _ x: UInt8) -> UInt8 {
        var y = p[0]
        for i in 1..<p.count { y = mul(y, x) ^ p[i] }
        return y
    }
}

struct ChartReedSolomon: Sendable {
    struct Failure: Error {}

    let nsym: Int
    let generator: [UInt8]

    init(nsym: Int) {
        var g: [UInt8] = [1]
        for i in 0..<nsym { g = ChartGF.multiply(g, [1, ChartGF.pow(2, i)]) }
        self.nsym = nsym
        generator = g
    }

    func encode(_ msg: [UInt8]) -> [UInt8] {
        var out = msg + [UInt8](repeating: 0, count: nsym)
        for i in 0..<msg.count {
            let coef = out[i]
            if coef != 0 {
                for j in 1..<generator.count { out[i + j] ^= ChartGF.mul(generator[j], coef) }
            }
        }
        for i in 0..<msg.count { out[i] = msg[i] }
        return out
    }

    func decode(_ input: [UInt8], erasures: [Int]) throws -> [UInt8] {
        if erasures.count > nsym { throw Failure() }
        var msg = input
        for e in erasures { msg[e] = 0 }
        let synd = syndromes(msg)
        if synd.allSatisfy({ $0 == 0 }) { return Array(msg[..<(msg.count - nsym)]) }
        let fsynd = forneySyndromes(synd, erasures, msg.count)
        let errLoc = try errorLocator(fsynd, eraseCount: erasures.count)
        let errPos = try findErrors(Array(errLoc.reversed()), msg.count)
        msg = try correctErrata(msg, synd, erasures + errPos)
        if syndromes(msg).contains(where: { $0 != 0 }) { throw Failure() }
        return Array(msg[..<(msg.count - nsym)])
    }

    private func syndromes(_ msg: [UInt8]) -> [UInt8] {
        [0] + (0..<nsym).map { ChartGF.evaluate(msg, ChartGF.pow(2, $0)) }
    }

    private func errataLocator(_ positions: [Int]) -> [UInt8] {
        var loc: [UInt8] = [1]
        for i in positions { loc = ChartGF.multiply(loc, ChartGF.add([1], [ChartGF.pow(2, i), 0])) }
        return loc
    }

    private func correctErrata(_ msg: [UInt8], _ synd: [UInt8], _ errPos: [Int]) throws -> [UInt8] {
        let coefPos = errPos.map { msg.count - 1 - $0 }
        let errLoc = errataLocator(coefPos)
        let product = ChartGF.multiply(Array(synd.reversed()), errLoc)
        let evaluator = Array(product[(product.count - errLoc.count)...])
        let xs = coefPos.map { ChartGF.pow(2, -(255 - $0)) }
        var e = [UInt8](repeating: 0, count: msg.count)
        for (i, xi) in xs.enumerated() {
            let xiInv = ChartGF.inverse(xi)
            var prime: UInt8 = 1
            for j in 0..<xs.count where j != i { prime = ChartGF.mul(prime, 1 ^ ChartGF.mul(xiInv, xs[j])) }
            if prime == 0 { throw Failure() }
            let y = ChartGF.mul(xi, ChartGF.evaluate(evaluator, xiInv))
            e[errPos[i]] = ChartGF.div(y, prime)
        }
        return ChartGF.add(msg, e)
    }

    private func errorLocator(_ synd: [UInt8], eraseCount: Int) throws -> [UInt8] {
        var errLoc: [UInt8] = [1]
        var oldLoc: [UInt8] = [1]
        let shift = synd.count > nsym ? synd.count - nsym : 0
        for i in 0..<(nsym - eraseCount) {
            let k = i + shift
            var delta = synd[k]
            for j in 1..<errLoc.count { delta ^= ChartGF.mul(errLoc[errLoc.count - 1 - j], synd[k - j]) }
            oldLoc.append(0)
            if delta != 0 {
                if oldLoc.count > errLoc.count {
                    let newLoc = ChartGF.scale(oldLoc, delta)
                    oldLoc = ChartGF.scale(errLoc, ChartGF.inverse(delta))
                    errLoc = newLoc
                }
                errLoc = ChartGF.add(errLoc, ChartGF.scale(oldLoc, delta))
            }
        }
        while let first = errLoc.first, first == 0 { errLoc.removeFirst() }
        if errLoc.isEmpty || (errLoc.count - 1) * 2 + eraseCount > nsym { throw Failure() }
        return errLoc
    }

    private func findErrors(_ errLocRev: [UInt8], _ n: Int) throws -> [Int] {
        var positions: [Int] = []
        for i in 0..<n where ChartGF.evaluate(errLocRev, ChartGF.pow(2, i)) == 0 { positions.append(n - 1 - i) }
        if positions.count != errLocRev.count - 1 { throw Failure() }
        return positions
    }

    private func forneySyndromes(_ synd: [UInt8], _ positions: [Int], _ n: Int) -> [UInt8] {
        var f = Array(synd[1...])
        for p in positions {
            let x = ChartGF.pow(2, n - 1 - p)
            for j in 0..<(f.count - 1) { f[j] = ChartGF.mul(f[j], x) ^ f[j + 1] }
        }
        return f
    }
}
