//
//  CalendarManager.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/23.
//

import Foundation

class CalendarManager: ObservableObject {

    let defaults = UserDefaults.standard
    let selectedDateKey = "CalendarManager.SelectedDate"

    @Published var selectedDate: Date

    init(selectedDate: Date? = nil) {
        if let selectedDate = defaults.object(forKey: selectedDateKey) as? Date {
            self.selectedDate = selectedDate
        } else {
            self.selectedDate = .now
        }
    }

    func saveToDefaults() {
        defaults.setValue(selectedDate, forKey: selectedDateKey)
        defaults.synchronize()
    }
}
