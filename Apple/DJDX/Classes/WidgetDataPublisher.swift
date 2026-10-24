import Foundation
import WidgetKit

actor WidgetDataPublisher {
    static let shared = WidgetDataPublisher()

    func publishAll(playType: IIDXPlayType, iidxVersion: IIDXVersion) {
        syncConfig(playType: playType, iidxVersion: iidxVersion)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func publishClearTypeAndDJLevel(playType: IIDXPlayType, iidxVersion: IIDXVersion) {
        syncConfig(playType: playType, iidxVersion: iidxVersion)
        WidgetCenter.shared.reloadTimelines(ofKind: "ClearTypeWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "DJLevelWidget")
    }

    func publishRadar() {
        WidgetCenter.shared.reloadTimelines(ofKind: "NotesRadarWidget")
    }

    func publishQpro() {
        WidgetCenter.shared.reloadTimelines(ofKind: "QproWidget")
    }

    private func syncConfig(playType: IIDXPlayType, iidxVersion: IIDXVersion) {
        SharedContainer.defaults.set(iidxVersion.rawValue, forKey: WidgetConfig.versionKey)
        SharedContainer.defaults.set(playType.rawValue, forKey: WidgetConfig.playTypeKey)
    }
}
