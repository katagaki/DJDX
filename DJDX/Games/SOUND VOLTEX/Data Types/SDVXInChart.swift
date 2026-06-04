import Foundation

// One chart entry from the sdvx.in (SDVX譜面保管所∇) archive.
//
// sdvx.in identifies charts by a 5-digit code (a version/batch prefix followed by
// a song index, e.g. "07076") plus a difficulty slot letter. Every song exposes
// exactly four slots: n (NOVICE), a (ADVANCED), e (EXHAUST) and m (the top slot).
// The m slot holds whichever top difficulty the song has — INFINITE, GRAVITY,
// HEAVENLY, VIVID, EXCEED, MAXIMUM or NABLA — so the concrete type is resolved
// from the player's own record at lookup time rather than stored here.
struct SDVXInChart: Sendable, Hashable {
    var code: String          // e.g. "07076"
    var slot: String          // "n" | "a" | "e" | "m"
    var title: String
    var level: Int            // in-game level (1–20), taken from the source sort page

    // Folder prefix on sdvx.in (the first two digits of the code).
    var folder: String { String(code.prefix(2)) }

    // The viewable chart page, e.g. https://sdvx.in/07/07076m.htm
    var pageURL: URL? {
        URL(string: "https://sdvx.in/\(folder)/\(code)\(slot).htm")
    }
}
