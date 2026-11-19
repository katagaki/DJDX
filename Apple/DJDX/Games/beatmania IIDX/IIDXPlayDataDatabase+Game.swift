import Foundation

extension IIDXPlayDataDatabase {
    static var current: IIDXPlayDataDatabase {
        database(for: Game(rawValue: UserDefaults.standard.integer(forKey: "Global.SelectedGame")) ?? .iidxArcade)
    }

    static func database(for game: Game) -> IIDXPlayDataDatabase {
        game == .iidxInfinitas ? .infinitas : .shared
    }

    var isVersionless: Bool {
        self === Self.infinitas
    }
}
