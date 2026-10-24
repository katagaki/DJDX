import Foundation

// Ports classify()/rec_to_box() from training/scripts/auto_label.py: snap each
// OCR region to a schema class via positional + content heuristics. Loose on
// purpose — the human refines in the editor.
enum AutoLabel {
    private static let clearWords: Set<String> = [
        "FAILED", "NO PLAY", "CLEAR", "H-CLEAR", "EX-HARD",
        "ASSIST", "EASY", "FULLCOMBO", "A-CLEAR",
    ]

    private static func isDigits(_ s: String) -> Bool {
        !s.isEmpty && s.count <= 5 && s.allSatisfy(\.isNumber)
    }

    private static func isDelta(_ s: String) -> Bool {
        guard let first = s.first, first == "+" || first == "-" else { return false }
        let rest = s.dropFirst()
        return !rest.isEmpty && rest.allSatisfy(\.isNumber)
    }

    static func classify(_ r: OCRRegion) -> String {
        let txt = r.text.trimmingCharacters(in: .whitespaces).uppercased()
        let x = r.x, y = r.y
        let inLeftCol = x > 0.05 && x < 0.55

        if !inLeftCol {
            if txt.contains("NOTES") { return "notes_count" }
            if ["HYPER", "ANOTHER", "LEGGENDARIA", "NORMAL", "BEGINNER"].contains(where: txt.contains) {
                return "difficulty_label"
            }
            if txt.contains("STAGE RESULT") { return "stage_label" }
            if y > 0.80 && y < 0.95 { return "song_title" }
            if y > 0.85 && y < 0.99 { return "song_artist" }
            return Schema.unlabeledText
        }

        if txt.contains("PACEMAKER") { return "pacemaker_aa" }
        if txt.contains("CLEAR TYPE") || clearWords.contains(txt) || txt.contains("CLEAR") || txt.contains("FAILED") {
            return "clear_type_now"
        }
        if txt.contains("DJ LEVEL") || txt == "SCORE" || txt.contains("MISS COUNT") {
            return Schema.unlabeledText
        }
        if isDelta(txt) { return "score_delta" }
        if isDigits(txt) {
            if y >= 0.43 && y <= 0.55 { return "score_now" }
            if y >= 0.55 && y <= 0.66 { return "miss_count_now" }
            if y >= 0.65 && y <= 0.74 { return "pacemaker_aa" }
            if y >= 0.72 && y <= 0.95 { return "judge_great" }
        }
        return Schema.unlabeledText
    }

    static func boxes(from regions: [OCRRegion]) -> [Box] {
        regions.map {
            Box(cls: classify($0), x: $0.x, y: $0.y, w: $0.w, h: $0.h)
        }
    }
}
