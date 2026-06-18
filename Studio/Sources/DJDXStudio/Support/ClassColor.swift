import SwiftUI

// Mirrors CLASS_COLORS in training/scripts/labeler.py so boxes look the same
// in both tools.
enum ClassColor {
    static let palette: [String: String] = [
        "dj_level_now": "#ff595e",
        "dj_level_prev": "#ff924c",
        "clear_type_now": "#ffca3a",
        "clear_type_prev": "#c5ca30",
        "score_now": "#8ac926",
        "score_prev": "#52a675",
        "score_delta": "#1982c4",
        "miss_count_now": "#4267ac",
        "miss_count_prev": "#565aa0",
        "miss_count_delta": "#6a4c93",
        "pacemaker_aa": "#b5179e",
        "judge_pgreat": "#7209b7",
        "judge_great": "#560bad",
        "judge_good": "#480ca8",
        "judge_bad": "#3a0ca3",
        "judge_poor": "#3f37c9",
        "song_title": "#4361ee",
        "song_artist": "#4895ef",
        "difficulty_label": "#4cc9f0",
        "notes_count": "#80ed99",
        "stage_label": "#fee440",
        "combo_break": "#ff70a6",
        "unlabeled_text": "#999999",
    ]

    static func hex(for cls: String) -> String { palette[cls] ?? "#cccccc" }

    static func color(for cls: String) -> Color { Color(hex: hex(for: cls)) }
}

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b: Double
        if s.count == 6 {
            r = Double((v >> 16) & 0xff) / 255
            g = Double((v >> 8) & 0xff) / 255
            b = Double(v & 0xff) / 255
        } else {
            r = 0.8; g = 0.8; b = 0.8
        }
        self = Color(red: r, green: g, blue: b)
    }
}
