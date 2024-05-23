//
//  CalendarManager.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/23.
//

import Foundation

class CalendarManager: ObservableObject {
    @Published var selectedDate: Date

    init(selectedDate: Date = .now) {
        self.selectedDate = selectedDate
    }
}
