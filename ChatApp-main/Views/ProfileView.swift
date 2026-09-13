//
//  ProfileView.swift
//  ChatApp-main
//
//  Created for PeachChat Production Experience.
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploadingImage: Bool = false
    @State private var isSavingProfile: Bool = false
    @State private var showSignOutAlert: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Avatar Section
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ZStack {
                                if let imageUrl = authManager.currentUser?.profileImageUrl, !imageUrl.isEmpty {
                                    AsyncImage(url: URL(string: imageUrl)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(LinearGradient(colors: [Color("Peach"), Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Text(String(authManager.currentUser?.username.prefix(1) ?? "U").uppercased())
                                                .font(.system(size: 40, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                }
                                
                                if isUploadingImage {
                                    Circle()
                                        .fill(Color.black.opacity(0.5))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        )
                                }
                                
                                // Photos picker overlay badge
                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    Image(systemName: "camera.fill")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color("Peach"))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                }
                                .offset(x: 35, y: 35)
                                .disabled(isUploadingImage)
                            }
                            
                            Text("Tap camera to change photo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                
                // MARK: - User Info
                Section(header: Text("Profile Information")) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(Color("Peach"))
                            .frame(width: 24)
                        TextField("Username", text: $username)
                    }
                    
                    HStack {
                        Image(systemName: "quote.bubble.fill")
                            .foregroundColor(Color("Peach"))
                            .frame(width: 24)
                        TextField("About / Status", text: $bio)
                    }
                    
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        Text(authManager.currentUser?.email ?? "Not logged in")
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                // MARK: - Save Changes
                Section {
                    Button(action: saveChanges) {
                        HStack {
                            Spacer()
                            if isSavingProfile {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Save Changes")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color("Peach"))
                    .disabled(isSavingProfile || isUploadingImage)
                }
                
                // MARK: - App & Portfolio Info
                Section(header: Text("About PeachChat")) {
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("Avinash Chavda")
                            .fontWeight(.semibold)
                            .foregroundColor(Color("Peach"))
                    }
                    HStack {
                        Text("Architecture")
                        Spacer()
                        Text("MVVM + SwiftUI")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Real-Time Engine")
                        Spacer()
                        Text("Firebase Firestore")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Media CDN")
                        Spacer()
                        Text("Cloudinary Media API")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.0 (Production)")
                            .foregroundColor(.secondary)
                    }
                }
                
                // MARK: - Account Actions
                Section {
                    Button(role: .destructive, action: {
                        showSignOutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                }
            }
            .navigationTitle("Profile & Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let user = authManager.currentUser {
                    username = user.username
                    bio = user.bio ?? "Hey there! I am using PeachChat."
                }
            }
            .onChange(of: selectedItem) { newItem in
                guard let newItem = newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            isUploadingImage = true
                        }
                        authManager.updateUserProfile(profileImage: image) { success in
                            isUploadingImage = false
                            if success {
                                alertMessage = "Profile picture updated successfully!"
                                showSuccessAlert = true
                            }
                        }
                    }
                }
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.updatePresence(isOnline: false)
                    authManager.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out of PeachChat?")
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func saveChanges() {
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSavingProfile = true
        
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        
        authManager.updateUserProfile(username: trimmedUsername, bio: trimmedBio) { success in
            isSavingProfile = false
            if success {
                alertMessage = "Profile updated successfully!"
                showSuccessAlert = true
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
}
