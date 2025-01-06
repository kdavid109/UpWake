//
//  ObjectsView.swift
//  WakeUp
//
//  Created by David Kim on 1/3/25.
//

#if os(iOS)
import UIKit
#endif
import SwiftUI
import AVFoundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

struct ObjectsView: View {
    @StateObject private var objectsManager = ObjectsManager()
    @State private var showCamera = false
    @State private var gridLayout = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    @Environment(\.colorScheme) var colorScheme
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            // Collection Grid
            ScrollView {
                if isLoading {
                    ProgressView("Loading objects...")
                        .padding(.top, 100)
                } else if objectsManager.objects.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "cube.box.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.teal)
                        Text("No Items Scanned")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Tap the scan button below to add items")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    LazyVGrid(columns: gridLayout, spacing: 16) {
                        ForEach(objectsManager.objects) { object in
                            ObjectCard(object: object, objectsManager: objectsManager)
                        }
                    }
                    .padding()
                }
            }
            
            // Scan Button
            VStack {
                Button(action: {
                    checkCameraPermission()
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                        Text("Scan")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.teal)
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(.background)
            .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.1), radius: 10, y: -5)
        }
        .navigationTitle("Collection Of Items")
        .background(.background)
        .sheet(isPresented: $showCamera) {
            #if os(iOS)
            CameraView(isPresented: $showCamera)
            #else
            Text("Camera not available on this platform")
                .foregroundColor(.primary)
            #endif
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isLoading = false
            }
        }
    }
    
    private func checkCameraPermission() {
        #if os(iOS)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        showCamera = true
                    }
                }
            }
        case .denied:
            print("Camera access denied")
        default:
            break
        }
        #endif
    }
}

// Object Card View
struct ObjectCard: View {
    let object: ScannedObject
    let objectsManager: ObjectsManager
    @Environment(\.colorScheme) var colorScheme
    @State private var image: UIImage?
    @State private var isLoadingImage = true
    @State private var imageLoadError = false
    @State private var isInEditMode = false
    @State private var showDeleteConfirmation = false
    @State private var shakeOffset: CGFloat = 0
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            // Object Image
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(colorScheme == .dark ? 0.3 : 0.1))
                
                if isLoadingImage {
                    ProgressView()
                } else if imageLoadError {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 30))
                            .foregroundColor(.orange)
                        Text("Image Unavailable")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let image = image {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipped()
                            .allowsHitTesting(false) // Disable interaction with the image
                        
                        if isInEditMode {
                            Button(action: {
                                showDeleteConfirmation = true
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .padding(8)
                            .transition(.scale.combined(with: .opacity))
                            .zIndex(1) // Ensure delete button is above everything
                        }
                    }
                } else {
                    Image(systemName: "cube.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.teal)
                }
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .offset(x: shakeOffset)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: shakeOffset)
            .onLongPressGesture {
                enterEditMode()
            }
            .allowsHitTesting(!isInEditMode) // Only allow long press when not in edit mode
            
            // Object Details
            VStack(alignment: .leading, spacing: 4) {
                Text(object.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(object.dateScanned.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .allowsHitTesting(false) // Disable interaction with text
        }
        .background(Color(colorScheme == .dark ? .black : .white).opacity(colorScheme == .dark ? 0.3 : 1))
        .cornerRadius(12)
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: colorScheme == .dark ? 0.3 : 0.1), radius: 5)
        .overlay {
            if isInEditMode {
                Color.black.opacity(0.001) // Nearly invisible overlay
                    .onTapGesture {
                        withAnimation {
                            isInEditMode = false
                            shakeOffset = 0
                        }
                    }
            }
        }
        .confirmationDialog(
            "Delete \(object.name)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        print("DEBUG: Delete button pressed for object: \(object.name)")
                        try await objectsManager.deleteObject(object)
                        print("DEBUG: Delete operation completed successfully")
                        withAnimation {
                            isInEditMode = false
                            shakeOffset = 0
                        }
                    } catch {
                        print("DEBUG: Delete operation failed: \(error)")
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadImage()
        }
    }
    
    private func enterEditMode() {
        withAnimation {
            isInEditMode = true
            // Trigger shake animation
            shakeOffset = 5
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    shakeOffset = -5
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        shakeOffset = 3
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            shakeOffset = -2
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                shakeOffset = 0
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func loadImage() async {
        guard let url = URL(string: object.imageUrl) else {
            DispatchQueue.main.async {
                self.imageLoadError = true
                self.isLoadingImage = false
            }
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Check if we got a successful response
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    self.imageLoadError = true
                    self.isLoadingImage = false
                }
                return
            }
            
            if let downloadedImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = downloadedImage
                    self.imageLoadError = false
                    self.isLoadingImage = false
                }
            } else {
                DispatchQueue.main.async {
                    self.imageLoadError = true
                    self.isLoadingImage = false
                }
            }
        } catch {
            print("Error loading image for \(object.name): \(error)")
            DispatchQueue.main.async {
                self.imageLoadError = true
                self.isLoadingImage = false
            }
        }
    }
}

// Scanned Object Model
struct ScannedObject: Identifiable {
    let id: String
    let name: String
    let imageUrl: String
    let dateScanned: Date
    let storagePath: String
    let processed: Bool
    let status: String
}

// Objects Manager
class ObjectsManager: ObservableObject {
    @Published var objects: [ScannedObject] = []
    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()
    
    init() {
        loadObjects()
    }
    
    func deleteObject(_ object: ScannedObject) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("DEBUG: No user ID found for deletion")
            return
        }
        
        print("DEBUG: Starting deletion process for object: \(object.id)")
        
        do {
            // Delete from Storage using the stored path
            print("DEBUG: Attempting to delete from storage: \(object.storagePath)")
            try await storage.child(object.storagePath).delete()
            print("DEBUG: Successfully deleted from storage")
            
            // Delete from Firestore
            let docRef = db.collection("users").document(userId)
                .collection("objects").document(object.id)
            
            print("DEBUG: Attempting to delete from Firestore...")
            try await docRef.delete()
            print("DEBUG: Successfully deleted from Firestore")
            
            // Update local state
            DispatchQueue.main.async {
                self.objects.removeAll { $0.id == object.id }
            }
        } catch {
            print("DEBUG: Error during deletion: \(error)")
            throw error
        }
    }
    
    private func loadObjects() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No user ID found")
            return
        }
        
        print("Starting to load objects for user: \(userId)")
        
        db.collection("users").document(userId)
            .collection("objects")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching objects: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No documents found")
                    return
                }
                
                Task {
                    var validObjects: [ScannedObject] = []
                    
                    for document in documents {
                        let data = document.data()
                        print("Processing document: \(document.documentID)")
                        
                        guard let name = data["name"] as? String,
                              let imageUrl = data["imageUrl"] as? String,
                              let storagePath = data["storagePath"] as? String else {
                            print("Missing required fields for document: \(document.documentID)")
                            continue
                        }
                        
                        let processed = data["processed"] as? Bool ?? false
                        let status = data["status"] as? String ?? "pending"
                        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                        
                        // Verify image exists in Storage
                        let imageRef = self?.storage.child(storagePath)
                        do {
                            _ = try await imageRef?.downloadURL()
                            
                            let object = ScannedObject(
                                id: document.documentID,
                                name: name,
                                imageUrl: imageUrl,
                                dateScanned: timestamp,
                                storagePath: storagePath,
                                processed: processed,
                                status: status
                            )
                            validObjects.append(object)
                            print("Added valid object: \(name)")
                        } catch {
                            print("Failed to verify image for \(name): \(error.localizedDescription)")
                            // Image doesn't exist in storage, delete the document
                            try? await document.reference.delete()
                            print("Deleted document for missing image: \(storagePath)")
                        }
                    }
                    
                    print("Loaded \(validObjects.count) valid objects")
                    
                    DispatchQueue.main.async {
                        self?.objects = validObjects
                    }
                }
            }
    }
    
    func reloadObjects() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection("objects")
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            var validObjects: [ScannedObject] = []
            
            for document in snapshot.documents {
                let data = document.data()
                
                guard let name = data["name"] as? String,
                      let imageUrl = data["imageUrl"] as? String,
                      let storagePath = data["storagePath"] as? String else {
                    continue
                }
                
                let processed = data["processed"] as? Bool ?? false
                let status = data["status"] as? String ?? "pending"
                let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                
                // Verify image exists
                let imageRef = storage.child(storagePath)
                do {
                    _ = try await imageRef.downloadURL()
                    
                    let object = ScannedObject(
                        id: document.documentID,
                        name: name,
                        imageUrl: imageUrl,
                        dateScanned: timestamp,
                        storagePath: storagePath,
                        processed: processed,
                        status: status
                    )
                    validObjects.append(object)
                } catch {
                    // Image doesn't exist, delete document
                    try? await document.reference.delete()
                }
            }
            
            DispatchQueue.main.async {
                self.objects = validObjects
            }
        } catch {
            print("Error reloading objects: \(error)")
        }
    }
}

#if os(iOS)
// Camera View
struct CameraView: View {
    @Binding var isPresented: Bool
    @StateObject private var objectDetectionService = ObjectDetectionService.shared
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    @State private var selectedImage: UIImage?
    @State private var objectName: String = ""
    @State private var showingImagePicker = false
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            Color(.systemBackground).edgesIgnoringSafeArea(.all)
            
            VStack {
                // Header with Exit Button
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
                
                Spacer()
                
                if let image = selectedImage {
                    // Image Preview
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .padding()
                    
                    // Object Name Input
                    TextField("Enter object name", text: $objectName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                        .padding(.top)
                        .disabled(isUploading)
                    
                    // Save Button
                    Button(action: {
                        Task {
                            isUploading = true
                            do {
                                try await objectDetectionService.uploadImageAndDetectObjects(
                                    image: image,
                                    objectName: objectName.isEmpty ? "Untitled Object" : objectName
                                )
                                // Successful upload, dismiss the view
                                DispatchQueue.main.async {
                                    isUploading = false
                                    dismiss()
                                }
                            } catch {
                                print("Error saving image: \(error)")
                                errorMessage = error.localizedDescription
                                showError = true
                                isUploading = false
                            }
                        }
                    }) {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 8)
                                Text("Saving...")
                            } else {
                                Text("Save Object")
                            }
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal)
                        .cornerRadius(12)
                        .opacity(isUploading ? 0.7 : 1)
                    }
                    .disabled(isUploading)
                    .padding()
                    
                    // Retake Photo Button
                    Button(action: {
                        selectedImage = nil
                        showingImagePicker = true
                    }) {
                        Text("Retake Photo")
                            .foregroundColor(.teal)
                    }
                    .disabled(isUploading)
                    .padding(.bottom)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.teal)
                        
                        Text("Take a photo of your object")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding()
                }
                
                Spacer()
            }
            
            // Loading overlay
            if isUploading {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .allowsHitTesting(true)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: sourceType)
        }
        .onAppear {
            showingImagePicker = true
        }
    }
}

// Image Picker Coordinator
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
#endif

#Preview {
    NavigationView {
        ObjectsView()
    }
}
