//
//  FlagScreen.swift
//  PeachChat
//
//  Created by Avinash Chavda.
//

import SwiftUI

struct FlagScreen: View {
    @EnvironmentObject var messagesManager: MessagesManager
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header with flag icon
                VStack(spacing: 10) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("New Message")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.top, 30)
                
                // Message details card
                if let flaggedMessage = messagesManager.flaggedMessage {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AI Assistant")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                
                                Text(formatTimestamp(flaggedMessage.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        Text(flaggedMessage.text)
                            .font(.body)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        messagesManager.clearFlag()
                        isPresented = false
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("View Conversation")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("Peach"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        messagesManager.dismissFlaggedMessage()
                        isPresented = false
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Dismiss")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray4))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .navigationTitle("Flagged Message")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        messagesManager.clearFlag()
                        isPresented = false
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Clear the flag when screen appears
            messagesManager.clearFlag()
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
}

#Preview {
    FlagScreen(isPresented: .constant(true))
        .environmentObject(MessagesManager())
}
