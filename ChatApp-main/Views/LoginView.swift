//
//  LoginView.swift
//  PeachChat
//
//  Created by Avinash Chavda.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var username = ""
    @State private var showPassword = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color("Peach"), Color.orange.opacity(0.85)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .onTapGesture {
                    dismissKeyboard()
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Branding
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 90, height: 90)
                                
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white)
                            }
                            
                            Text("PeachChat")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(isSignUp ? "Create an account to start chatting" : "Real-Time Cloud Messaging")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.top, 40)
                        
                        // Form Card
                        VStack(spacing: 18) {
                            // Mode Switcher
                            Picker("Mode", selection: $isSignUp) {
                                Text("Sign In").tag(false)
                                Text("Sign Up").tag(true)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.bottom, 6)
                            .onChange(of: isSignUp) { _ in
                                authManager.errorMessage = nil
                            }
                            
                            if isSignUp {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Username")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        Image(systemName: "person")
                                            .foregroundColor(.gray)
                                        TextField("e.g. avinash", text: $username)
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                    }
                                    .padding(12)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(10)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Email Address")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(.gray)
                                    TextField("e.g. name@example.com", text: $email)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Password")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundColor(.gray)
                                    
                                    if showPassword {
                                        TextField("Minimum 6 characters", text: $password)
                                    } else {
                                        SecureField("Minimum 6 characters", text: $password)
                                    }
                                    
                                    Button(action: { showPassword.toggle() }) {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                            }
                            
                            // Error Message Banner
                            if let error = authManager.errorMessage {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            // Primary Submit Button
                            Button(action: handleAuthAction) {
                                HStack {
                                    Spacer()
                                    if authManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text(isSignUp ? "Create Account" : "Sign In")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                }
                                .padding(14)
                                .background(isFormValid ? Color("Peach") : Color.gray.opacity(0.4))
                                .cornerRadius(12)
                            }
                            .disabled(!isFormValid || authManager.isLoading)
                            .padding(.top, 4)
                        }
                        .padding(22)
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 10)
                        .padding(.horizontal, 20)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private var isFormValid: Bool {
        let emailValid = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let passwordValid = password.count >= 6
        if isSignUp {
            return emailValid && passwordValid && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return emailValid && passwordValid
    }
    
    private func handleAuthAction() {
        dismissKeyboard()
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isSignUp {
            authManager.signUp(email: trimmedEmail, password: password, username: trimmedUsername)
        } else {
            authManager.signIn(email: trimmedEmail, password: password)
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
