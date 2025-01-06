//
//  LoginView.swift
//  WakeUp
//
//  Created by David Kim on 1/3/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

    
struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @State private var showRegisterSheet = false
    
    var body: some View {
        Group {
            if isLoggedIn {
                // Your main app view here
                AlarmView()
            } else {
                // Your existing login view content
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
                    
                    // Login Form
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        // Login Button
                        Button(action: handleLogin) {
                            Text("Login")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.teal)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // Sign Up Link
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(.gray)
                        Button(action: {
                            showRegisterSheet = true
                        }) {
                            Text("Register")
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
                .sheet(isPresented: $showRegisterSheet) {
                    RegisterView()
                }
            }
        }
    }
    
    private func handleLogin() {
        guard !email.isEmpty else {
            alertMessage = "Please enter your email"
            showAlert = true
            return
        }
        
        guard !password.isEmpty else {
            alertMessage = "Please enter your password"
            showAlert = true
            return
        }
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                alertMessage = error.localizedDescription
                showAlert = true
            } else {
                if let user = result?.user {
                    // Set logged in state
                    isLoggedIn = true
                    
                    // Clear sensitive data
                    email = ""
                    password = ""
                }
            }
        }
    }
}

#Preview {
    LoginView()
}

