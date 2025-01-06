import Foundation

struct Alarm: Identifiable {
    let id: UUID
    let time: String
    let label: String
    let selectedDays: Set<Weekday>
    var isEnabled: Bool
    
    init(id: UUID = UUID(), time: String, label: String, selectedDays: Set<Weekday>, isEnabled: Bool = true) {
        self.id = id
        self.time = time
        self.label = label
        self.selectedDays = selectedDays
        self.isEnabled = isEnabled
    }
} 