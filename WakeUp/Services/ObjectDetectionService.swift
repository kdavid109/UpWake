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
        let safeObjectName = objectName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "", options: .regularExpression)
        
        // First, remove the background
        print("Removing background from image...")
        let processedImageData = try await removeBackground(from: imageData)
        print("Background removal successful")
        
        let imageName = "\(objectId)_\(safeObjectName).png" // Using PNG for better quality
        let storagePath = "users/\(userId)/objects/\(imageName)"
        print("Generated storage path: \(storagePath)")
        
        let imageRef = storage.child(storagePath)
        print("Created storage reference")
        
        // Upload the processed image with metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/png"
        metadata.customMetadata = [
            "uploadStartTime": "\(Date().timeIntervalSince1970)",
            "userId": userId,
            "objectName": objectName,
            "objectId": objectId,
            "bucket": "upwake-fdfad.firebasestorage.app",
            "backgroundRemoved": "true"
        ]
        
        print("Starting file upload...")
        
        // Function to retry upload with exponential backoff
        func uploadWithRetry(attempts: Int = 3) async throws -> StorageMetadata {
            var lastError: Error?
            
            for attempt in 1...attempts {
                do {
                    print("Upload attempt \(attempt)/\(attempts)")
                    let uploadTask = imageRef.putData(processedImageData, metadata: metadata)
                    
                    _ = uploadTask.observe(.progress) { snapshot in
                        let percentComplete = Double(snapshot.progress?.completedUnitCount ?? 0) / Double(snapshot.progress?.totalUnitCount ?? 1)
                        print("Upload progress: \(Int(percentComplete * 100))%")
                    }
                    
                    _ = try await uploadTask
                    let uploadedMetadata = try await imageRef.getMetadata()
                    print("Upload successful on attempt \(attempt)")
                    
                    let exists = try await checkFileExists(ref: imageRef)
                    if !exists {
                        throw UploadError.uploadFailed
                    }
                    
                    return uploadedMetadata
                } catch {
                    lastError = error
                    print("Upload attempt \(attempt) failed: \(error.localizedDescription)")
                    if attempt < attempts {
                        let delay = TimeInterval(pow(2.0, Double(attempt)))
                        print("Waiting \(delay) seconds before retry...")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                }
            }
            throw lastError ?? UploadError.uploadFailed
        }
        
        // Helper function to check if file exists
        func checkFileExists(ref: StorageReference) async throws -> Bool {
            do {
                let metadata = try await ref.getMetadata()
                return metadata.size > 0
            } catch {
                return false
            }
        }
        
        // Perform upload with retries
        do {
            let uploadedMetadata = try await uploadWithRetry()
            print("Final upload successful. Size: \(uploadedMetadata.size), contentType: \(uploadedMetadata.contentType ?? "unknown")")
            
            // Wait a moment to ensure the upload is fully processed
            try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            
            // Get the download URL
            print("Getting download URL...")
            let downloadURL = try await imageRef.downloadURL()
            print("Got download URL: \(downloadURL.absoluteString)")
            
            // Create Firestore document
            print("Creating Firestore document with ID: \(objectId)")
            let objectDoc = db.collection("users").document(userId)
                .collection("objects").document(objectId)
            
            let data: [String: Any] = [
                "id": objectId,
                "name": objectName,
                "imageUrl": downloadURL.absoluteString,
                "storagePath": storagePath,
                "timestamp": FieldValue.serverTimestamp(),
                "processed": true,
                "uploadComplete": true,
                "status": "completed",
                "dateScanned": Date(),
                "bucket": "upwake-fdfad.firebasestorage.app",
                "backgroundRemoved": true
            ]
            
            print("Document data to be saved:")
            data.forEach { key, value in
                print("\(key): \(value)")
            }
            
            print("Updating Firestore document...")
            try await objectDoc.setData(data)
            print("Firestore document created successfully")
            
            print("--- Image upload process completed successfully ---\n")
        } catch {
            print("Error during upload process: \(error.localizedDescription)")
            try? await imageRef.delete()
            throw error
        }
    }
    
    private func removeBackground(from imageData: Data) async throws -> Data {
        let apiKey = "YOUR_REMOVE_BG_API_KEY"  // Replace with your actual API key
        let url = URL(string: "https://api.remove.bg/v1.0/removebg")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let base64Image = imageData.base64EncodedString()
        let requestBody: [String: Any] = [
            "image_file_b64": base64Image,
            "size": "auto",
            "format": "png",
            "type": "auto",
            "bg_color": "white"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.uploadFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            print("Remove.bg API error: \(httpResponse.statusCode)")
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Error details: \(errorJson)")
            }
            throw UploadError.uploadFailed
        }
        
        return data
    }
}

enum UploadError: Error {
    case invalidImage
    case uploadFailed
} 
