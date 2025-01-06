import Firebase
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

class ObjectDetectionService: ObservableObject {
    static let shared = ObjectDetectionService()
    
    private let storage = Storage.storage().reference()
    private let db = Firestore.firestore()
    
    private func verifyUpload(ref: StorageReference, maxAttempts: Int = 3) async throws -> URL {
        print("Starting upload verification process...")
        for attempt in 1...maxAttempts {
            do {
                print("Verification attempt \(attempt)/\(maxAttempts)")
                
                // Try to get download URL
                print("Attempting to get download URL...")
                let url = try await ref.downloadURL()
                print("Successfully got download URL: \(url.absoluteString)")
                
                // Verify the file exists by checking metadata
                print("Verifying metadata...")
                let metadata = try await ref.getMetadata()
                print("Successfully got metadata: size=\(metadata.size), contentType=\(metadata.contentType ?? "unknown")")
                
                return url
            } catch {
                print("Verification attempt \(attempt) failed with error: \(error.localizedDescription)")
                if attempt == maxAttempts {
                    print("All verification attempts failed")
                    throw error
                }
                let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                print("Waiting \(delay/1_000_000_000) seconds before next attempt...")
                try await Task.sleep(nanoseconds: delay)
            }
        }
        throw UploadError.uploadFailed
    }
    
    func uploadImageAndDetectObjects(image: UIImage, objectName: String) async throws {
        print("\n--- Starting image upload process ---")
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Error: No user ID available")
            throw UploadError.invalidImage
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            print("Error: Failed to convert image to JPEG data")
            throw UploadError.invalidImage
        }
        
        print("Image converted to data: \(imageData.count) bytes")
        
        // Generate a unique ID for both Storage and Firestore
        let objectId = UUID().uuidString
        print("Generated object ID: \(objectId)")
        
        // Create storage path using both object name and ID
        let safeObjectName = objectName.replacingOccurrences(of: "/", with: "-")
        let imageName = "\(objectId)_\(safeObjectName).jpg"
        let storagePath = "users/\(userId)/objects/\(imageName)"
        print("Generated storage path: \(storagePath)")
        
        let imageRef = storage.child(storagePath)
        print("Created storage reference")
        
        // Upload the image with metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "uploadStartTime": "\(Date().timeIntervalSince1970)",
            "userId": userId,
            "objectName": objectName,
            "objectId": objectId
        ]
        
        print("Starting file upload...")
        do {
            _ = try await imageRef.putData(imageData, metadata: metadata)
            print("Initial upload completed successfully")
            
            // Get metadata after upload
            let uploadedMetadata = try await imageRef.getMetadata()
            print("Upload metadata - size: \(uploadedMetadata.size), contentType: \(uploadedMetadata.contentType ?? "unknown")")
        } catch {
            print("Error during initial upload: \(error.localizedDescription)")
            throw error
        }
        
        print("Starting upload verification...")
        let downloadURL = try await verifyUpload(ref: imageRef)
        print("Upload verified successfully")
        
        print("Waiting 2 seconds before Firestore update...")
        try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
        
        // Use the same objectId for Firestore document
        print("Creating Firestore document with ID: \(objectId)")
        
        let objectDoc = db.collection("users").document(userId)
            .collection("objects").document(objectId)
        
        let data: [String: Any] = [
            "id": objectId,
            "name": objectName,
            "imageUrl": downloadURL.absoluteString,
            "storagePath": storagePath,
            "timestamp": FieldValue.serverTimestamp(),
            "processed": false,
            "uploadComplete": true,
            "originalFileName": imageName,
            "status": "pending"  // Add status field
        ]
        
        print("Updating Firestore document...")
        do {
            try await objectDoc.setData(data)
            print("Firestore document created successfully")
        } catch {
            print("Error creating Firestore document: \(error.localizedDescription)")
            throw error
        }
        
        print("--- Image upload process completed successfully ---\n")
    }
}

enum UploadError: Error {
    case invalidImage
    case uploadFailed
} 
