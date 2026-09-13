//
//  ContentView.swift
//  PeachChat
//
//  Created by Avinash Chavda.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject var messagesManager = MessagesManager()
    @State private var showingFlagScreen = false

    var body: some View {
        NavigationView {
            VStack {
                VStack {
                    // Title row with flag badge
                    HStack {
                        TitleRow()
                        
                        Spacer()
                        
                        // Test button (for development only)
                        Button(action: {
                            messagesManager.simulateNewMessage()
                        }) {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.blue)
                        }
                        .padding(.trailing, 8)
                        
                        // Flag badge
                        if messagesManager.hasNewMessage {
                            Button(action: {
                                showingFlagScreen = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 24, height: 24)
                                    
                                    Image(systemName: "flag.fill")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal)
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            ForEach(messagesManager.messages, id: \.id) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.top, 10)
                        .background(.white)
                        .cornerRadius(30, corners: [.topLeft, .topRight])
                        .onChange(of: messagesManager.lastMessageId) { newValue in
                            withAnimation {
                                proxy.scrollTo(newValue, anchor: .bottom)
                            }
                        }
                    }

                }
                .background(Color("Peach"))
                
                MessageField()
                    .environmentObject(messagesManager)
            }
        }
        .sheet(isPresented: $showingFlagScreen) {
            FlagScreen(isPresented: $showingFlagScreen)
                .environmentObject(messagesManager)
        }
        .onReceive(messagesManager.$hasNewMessage) { hasNewMessage in
            if hasNewMessage {
                // Optional: Add haptic feedback when new message arrives
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
        }
    }
}


//struct ContentView: View {
//    @StateObject var messagesManager = MessagesManager()
//    
//    var body: some View {
//        VStack {
//            VStack {
//                TitleRow()
//                
//                ScrollViewReader { proxy in
//                    ScrollView {
//                        ForEach(messagesManager.messages, id: \.id) { message in
//                            MessageBubble(message: message)
//                        }
//                    }
//                    .padding(.top, 10)
//                    .background(.white)
//                    .cornerRadius(30, corners: [.topLeft, .topRight]) // Custom cornerRadius modifier added in Extensions file
//                    .onChange(of: messagesManager.lastMessageId) { id in
//                        // When the lastMessageId changes, scroll to the bottom of the conversation
//                        withAnimation {
//                            proxy.scrollTo(id, anchor: .bottom)
//                        }
//                    }
//                }
//            }
//            .background(Color("Peach"))
//            
//            MessageField()
//                .environmentObject(messagesManager)
//        }
//    }
//}
//
//
//#Preview {
//    ContentView()
//}
