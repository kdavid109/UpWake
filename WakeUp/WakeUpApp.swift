//
//  WakeUpApp.swift
//  WakeUp
//
//  Created by David Kim on 1/3/25.
//

import SwiftUI

@main
struct WakeUpApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                LoginView()
            }
        }
    }
}
