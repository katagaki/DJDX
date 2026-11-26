import Foundation

struct RatingPool {
    let limit: Int
    let total: Int
    private let count: Int
    private let cutoff: Int

    init(values: [Int], limit: Int) {
        let sorted = values.sorted(by: >)
        self.limit = limit
        self.count = sorted.count
        self.total = sorted.prefix(limit).reduce(0, +)
        self.cutoff = sorted.count >= limit ? sorted[limit - 1] : 0
    }

    func gain(replacing oldValue: Int, with newValue: Int) -> Int {
        guard newValue > oldValue else { return 0 }
        if count < limit || oldValue >= cutoff {
            return newValue - oldValue
        }
        return max(0, newValue - cutoff)
    }
}
