//
//  IIDXSong.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/01.
//

import Foundation
import SwiftData

@Model
final class IIDXSong: Equatable {
    var title: String = ""
    var spNoteCount: IIDXNoteCount?
    var dpNoteCount: IIDXNoteCount?
    var time: String = ""
    var movie: String = ""
    var layer: String = ""

    init(_ tableColumnData: [String]) {
        self.title = tableColumnData[0]
        let spBeginnerNoteCount = tableColumnData[1]
        let spNormalNoteCount = tableColumnData[2]
        let spHyperNoteCount = tableColumnData[3]
        let spAnotherNoteCount = tableColumnData[4]
        let spLeggendariaNoteCount = tableColumnData[5]
        let dpNormalNoteCount = tableColumnData[6]
        let dpHyperNoteCount = tableColumnData[7]
        let dpAnotherNoteCount = tableColumnData[8]
        let dpLeggendariaNoteCount = tableColumnData[9]
        if !(spBeginnerNoteCount == "-" &&
            spNormalNoteCount == "-" &&
            spHyperNoteCount == "-" &&
            spAnotherNoteCount == "-" &&
            spLeggendariaNoteCount == "-") {
            self.spNoteCount = IIDXNoteCount(beginnerNoteCount: spBeginnerNoteCount,
                                             normalNoteCount: spNormalNoteCount,
                                             hyperNoteCount: spHyperNoteCount,
                                             anotherNoteCount: spAnotherNoteCount,
                                             leggendariaNoteCount: spLeggendariaNoteCount,
                                             playType: .single)
        }
        if !(dpNormalNoteCount == "-" &&
             dpHyperNoteCount == "-" &&
             dpAnotherNoteCount == "-" &&
             dpLeggendariaNoteCount == "-" ) {
            self.dpNoteCount = IIDXNoteCount(beginnerNoteCount: "-",
                                             normalNoteCount: dpNormalNoteCount,
                                             hyperNoteCount: dpHyperNoteCount,
                                             anotherNoteCount: dpAnotherNoteCount,
                                             leggendariaNoteCount: dpLeggendariaNoteCount,
                                             playType: .double)
        }
        self.time = tableColumnData[10]
        self.movie = tableColumnData[11]
        self.layer = tableColumnData[12]
    }

    func titleCompact() -> String {
        return title.compact
    }

    static func == (lhs: IIDXSong, rhs: IIDXSongRecord) -> Bool {
        return lhs.title == rhs.title
    }
}

struct IIDXNoteCount: Codable, Equatable {
    var beginnerNoteCount: Int?
    var normalNoteCount: Int?
    var hyperNoteCount: Int?
    var anotherNoteCount: Int?
    var leggendariaNoteCount: Int?
    var playType: IIDXPlayType

    init(beginnerNoteCount: String,
         normalNoteCount: String,
         hyperNoteCount: String,
         anotherNoteCount: String,
         leggendariaNoteCount: String,
         playType: IIDXPlayType) {
        self.beginnerNoteCount = Int(beginnerNoteCount)
        self.normalNoteCount = Int(normalNoteCount)
        self.hyperNoteCount = Int(hyperNoteCount)
        self.anotherNoteCount = Int(anotherNoteCount)
        self.leggendariaNoteCount = Int(leggendariaNoteCount)
        self.playType = playType
    }

    func noteCount(for level: IIDXLevel) -> Int? {
        guard let keyPath = level.noteCountKeyPath else { return nil }
        return self[keyPath: keyPath]
    }
}
