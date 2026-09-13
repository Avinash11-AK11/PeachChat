//
//  ChatApp_mainApp.swift
//  PeachChat
//
//  Created by Avinash Chavda.
//

import SwiftUI
import Firebase

@main
struct ChatApp_mainApp: App {
    @State private var isFirebaseReady: Bool = false
    
    init() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            _isFirebaseReady = State(initialValue: true)
        } else {
            print("⚠️ Warning: GoogleService-Info.plist not found in bundle. Please ensure it is added to ChatApp-main.")
            _isFirebaseReady = State(initialValue: false)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if isFirebaseReady {
                MainView()
            } else {
                FirebaseMissingView()
            }
        }
    }
}

struct FirebaseMissingView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.orange)
                        .padding(.top, 40)
                    
                    Text("Firebase Setup Required")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("To enable real-time chat, authentication, and cloud storage, PeachChat requires a valid GoogleService-Info.plist configuration.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Setup Steps:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(alignment: .top) {
                            Text("1.")
                                .fontWeight(.bold)
                            Text("Go to **console.firebase.google.com** and create or select a project.")
                        }
                        
                        HStack(alignment: .top) {
                            Text("2.")
                                .fontWeight(.bold)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Register an iOS app with Bundle ID:")
                                Text(Bundle.main.bundleIdentifier ?? "io.Avinash.PeachChat")
                                    .font(.system(.footnote, design: .monospaced))
                                    .padding(6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        HStack(alignment: .top) {
                            Text("3.")
                                .fontWeight(.bold)
                            Text("Download **GoogleService-Info.plist** and place it inside the **ChatApp-main** folder in your project.")
                        }
                        
                        HStack(alignment: .top) {
                            Text("4.")
                                .fontWeight(.bold)
                            Text("Enable **Email/Password** under Authentication > Sign-in method, and create a **Cloud Firestore** database.")
                        }
                    }
                    .font(.subheadline)
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MainView: View {
    @StateObject private var authManager = AuthManager()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                ChatListView()
                    .environmentObject(authManager)
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
        .onAppear {
            if authManager.currentUser != nil {
                authManager.isAuthenticated = true
                authManager.updatePresence(isOnline: true)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if authManager.isAuthenticated {
                if newPhase == .active {
                    authManager.updatePresence(isOnline: true)
                } else if newPhase == .background || newPhase == .inactive {
                    authManager.updatePresence(isOnline: false)
                }
            }
        }
    }
}
