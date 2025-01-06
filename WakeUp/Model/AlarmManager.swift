import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

class AlarmManager: ObservableObject {
    static let shared = AlarmManager()
    
    @Published var alarms: [Alarm] = []
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()
    
    private init() {
        loadAlarms()
    }
    
    func addAlarm(_ alarm: Alarm, images: [UIImage]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw AuthError.userNotFound
        }
        
        // 1. Upload images first
        var imageUrls: [String] = []
        for (index, image) in images.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 0.7) else { continue }
            let imagePath = "alarms/\(userId)/\(alarm.id)/image\(index).jpg"
            let imageRef = storage.child(imagePath)
            
            _ = try await imageRef.putData(imageData)
            let downloadURL = try await imageRef.downloadURL()
            imageUrls.append(downloadURL.absoluteString)
        }
        
        // 2. Create alarm document
        let alarmData: [String: Any] = [
            "id": alarm.id.uuidString,
            "time": alarm.time,
            "label": alarm.label,
            "selectedDays": Array(alarm.selectedDays).map { $0.rawValue },
            "isEnabled": alarm.isEnabled,
            "imageUrls": imageUrls,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        // 3. Save to Firestore
        try await db.collection("users").document(userId).collection("alarms").document(alarm.id.uuidString).setData(alarmData)
        
        // 4. Update local state
        DispatchQueue.main.async {
            self.alarms.append(alarm)
        }
    }
    
    func removeAlarm(_ alarm: Alarm) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw AuthError.userNotFound
        }
        
        // 1. Delete images from Storage
        let imagesRef = storage.child("alarms/\(userId)/\(alarm.id)")
        try await imagesRef.delete()
        
        // 2. Delete alarm document from Firestore
        try await db.collection("users").document(userId).collection("alarms").document(alarm.id.uuidString).delete()
        
        // 3. Update local state
        DispatchQueue.main.async {
            self.alarms.removeAll { $0.id == alarm.id }
        }
    }
    
    func toggleAlarm(_ alarm: Alarm, isEnabled: Bool) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw AuthError.userNotFound
        }
        
        // 1. Update in Firestore
        try await db.collection("users").document(userId)
            .collection("alarms").document(alarm.id.uuidString)
            .updateData(["isEnabled": isEnabled])
        
        // 2. Update local state
        DispatchQueue.main.async {
            if let index = self.alarms.firstIndex(where: { $0.id == alarm.id }) {
                var updatedAlarm = alarm
                updatedAlarm.isEnabled = isEnabled
                self.alarms[index] = updatedAlarm
            }
        }
    }
    
    private func loadAlarms() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId).collection("alarms")
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching alarms: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let alarms = documents.compactMap { document -> Alarm? in
                    let data = document.data()
                    guard let id = UUID(uuidString: data["id"] as? String ?? ""),
                          let time = data["time"] as? String,
                          let label = data["label"] as? String,
                          let selectedDayValues = data["selectedDays"] as? [Int],
                          let isEnabled = data["isEnabled"] as? Bool else {
                        return nil
                    }
                    
                    let selectedDays = Set(selectedDayValues.compactMap { Weekday(rawValue: $0) })
                    return Alarm(id: id, time: time, label: label, selectedDays: selectedDays, isEnabled: isEnabled)
                }
                
                DispatchQueue.main.async {
                    self?.alarms = alarms
                }
            }
    }
}

// Error handling
enum AuthError: Error {
    case userNotFound
}
