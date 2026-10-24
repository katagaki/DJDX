import UIKit

final class StagedResultsOverlayView: UIView {
    private let label = UILabel()

    private static let fields: [(title: String, label: String)] = [
        ("TITLE", "song_title"),
        ("CHART", "difficulty_label"),
        ("CLEAR", "clear_type_now"),
        ("DJ", "dj_level_now"),
        ("SCORE", "score_now"),
        ("MISS", "miss_count_now")
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = UIColor.black.withAlphaComponent(0.55)
        layer.cornerRadius = 12.0
        layer.masksToBounds = true
        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 13.0, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 10.0),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10.0),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12.0),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12.0)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with regions: [DetectedRegion]) {
        var byLabel: [String: String] = [:]
        for region in regions {
            let text = region.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { byLabel[region.label] = text }
        }
        let lines = Self.fields.compactMap { field -> String? in
            guard let value = byLabel[field.label] else { return nil }
            return "\(field.title)  \(value.replacingOccurrences(of: "\n", with: " "))"
        }
        label.text = lines.joined(separator: "\n")
        isHidden = lines.isEmpty
    }
}
