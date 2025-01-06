//
//  Registerview.swift
//  WakeUp
//
//  Created by David Kim on 1/3/25.
//

import SwiftUI
import FirebaseAuth

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 25) {
            // Stylized App Title
            Text("Up Wake")
                .font(.custom("Arial Rounded MT Bold", size: 45))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.teal, .teal.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.vertical, 20)
                .shadow(color: .teal.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Registration Form
            VStack(spacing: 16) {
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // Register Button
                Button(action: {
                    validateAndRegister()
                }) {
                    Text("Create Account")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 30)
            
            // Back to Login Link
            HStack {
                Text("Already have an account?")
                    .foregroundColor(.gray)
                Button(action: {
                    dismiss()
                }) {
                    Text("Login")
                        .fontWeight(.semibold)
                        .foregroundColor(.teal)
                }
            }
            .font(.subheadline)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func validateAndRegister() {
        // Validate inputs
        guard !username.isEmpty else {
            alertMessage = "Please enter a username"
            showAlert = true
            return
        }
        
        guard !email.isEmpty else {
            alertMessage = "Please enter an email"
            showAlert = true
            return
        }
        
        guard !password.isEmpty else {
            alertMessage = "Please enter a password"
            showAlert = true
            return
        }
        
        guard password == confirmPassword else {
            alertMessage = "Passwords do not match"
            showAlert = true
            return
        }
        
        guard password.count >= 6 else {
            alertMessage = "Password must be at least 6 characters"
            showAlert = true
            return
        }
        
        // Create account using Firebase
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                alertMessage = error.localizedDescription
                showAlert = true
            } else {
                // Update user profile with username
                let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
                changeRequest?.displayName = username
                changeRequest?.commitChanges { error in
                    if let error = error {
                        print("Error updating profile: \(error.localizedDescription)")
                    }
                }
                
                // Dismiss registration view
                dismiss()
            }
        }
    }
}

#Preview {
    RegisterView()
}
