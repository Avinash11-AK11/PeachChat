//
//  ChatDetailView.swift
//  PeachChat
//
//  Created by Avinash Chavda.
//

import SwiftUI
import PhotosUI
import UIKit
import FirebaseFirestore

struct ChatDetailView: View {
    let chat: Chat
    @EnvironmentObject var chatManager: ChatManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var messageText = ""
    @State private var showingImagePicker = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var otherUser: User?
    @State private var isUploadingPhoto = false
    @State private var selectedFullscreenImageUrl: String? = nil
    @State private var typingTimer: Timer?
    @FocusState private var isTextFieldFocused: Bool
    
    var isOtherUserTyping: Bool {
        guard let otherId = otherUserId else { return false }
        return chatManager.typingUserIds.contains(otherId)
    }
    
    var otherUserId: String? {
        guard let currentId = authManager.currentUser?.id else { return nil }
        return chat.participants.first(where: { $0 != currentId })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            messagesArea
            
            if isUploadingPhoto {
                uploadingPhotoBanner
            }
            
            inputArea
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                chatHeaderTitle
            }
        }
        .onAppear {
            chatManager.fetchMessages(for: chat.id)
            fetchOtherUserDetails()
        }
        .onDisappear {
            chatManager.stopMessageListeners()
            chatManager.setTyping(isTyping: false, in: chat.id)
        }
        .photosPicker(isPresented: $showingImagePicker,
                      selection: $selectedItem,
                      matching: .images,
                      photoLibrary: .shared())
        .onChange(of: selectedItem) { newItem in
            handlePhotoSelected(newItem)
        }
        .fullScreenCover(item: Binding<FullscreenImageItem?>(
            get: { selectedFullscreenImageUrl.map { FullscreenImageItem(url: $0) } },
            set: { selectedFullscreenImageUrl = $0?.url }
        )) { item in
            FullscreenImageView(imageUrl: item.url)
        }
    }
    
    // MARK: - Header Title
    
    private var chatHeaderTitle: some View {
        HStack(spacing: 10) {
            ZStack {
                if let imageUrl = otherUser?.profileImageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color("Peach").opacity(0.3))
                    }
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color("Peach"))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Text(String(chatDisplayName.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                
                if otherUser?.isOnline == true {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .offset(x: 12, y: 12)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(chatDisplayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if isOtherUserTyping {
                    Text("typing...")
                        .font(.caption2)
                        .foregroundColor(Color("Peach"))
                        .italic()
                } else if otherUser?.isOnline == true {
                    Text("Online")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else if let lastSeen = otherUser?.lastSeen {
                    Text("Last seen \(formatHeaderDate(lastSeen))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var chatDisplayName: String {
        if chat.isGroupChat {
            return chat.groupName ?? "Group Chat"
        }
        return otherUser?.username ?? "Chat"
    }
    
    // MARK: - Messages Area
    
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(groupedMessageDates, id: \.self) { date in
                        Section(header: dateHeaderPill(for: date)) {
                            ForEach(messagesForDate(date)) { message in
                                MessageBubbleView(
                                    message: message,
                                    isFromCurrentUser: message.senderId == authManager.currentUser?.id,
                                    onImageTapped: { url in
                                        selectedFullscreenImageUrl = url
                                    },
                                    onReactionSelected: { reaction in
                                        chatManager.addReaction(reaction, to: message.id, in: chat.id)
                                    },
                                    onDelete: {
                                        chatManager.deleteMessage(message.id, from: chat.id)
                                    }
                                )
                                .id(message.id)
                            }
                        }
                    }
                    
                    if isOtherUserTyping {
                        HStack {
                            TypingBubble()
                                .padding(.leading, 16)
                            Spacer()
                        }
                        .id("typingIndicator")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .onChange(of: chatManager.messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isOtherUserTyping) { typing in
                if typing {
                    withAnimation {
                        proxy.scrollTo("typingIndicator", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private func dateHeaderPill(for date: Date) -> some View {
        Text(formatDateHeader(date))
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemBackground))
            .foregroundColor(.secondary)
            .clipShape(Capsule())
            .padding(.vertical, 6)
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 10) {
                // Attach photo button
                Button(action: { showingImagePicker = true }) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                        .foregroundColor(Color("Peach"))
                        .padding(8)
                }
                .disabled(isUploadingPhoto)
                
                // Text field
                HStack {
                    TextField("Message...", text: $messageText, axis: .vertical)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .lineLimit(1...5)
                        .onChange(of: messageText) { newValue in
                            handleTypingNotification(text: newValue)
                        }
                    
                    if !messageText.isEmpty {
                        Button(action: { messageText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(22)
                
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : Color("Peach"))
                        .clipShape(Circle())
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUploadingPhoto)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    private var uploadingPhotoBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Uploading image to Cloudinary...")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Helper Methods
    
    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        chatManager.sendMessage(trimmed, to: chat.id)
        messageText = ""
        chatManager.setTyping(isTyping: false, in: chat.id)
    }
    
    private func handleTypingNotification(text: String) {
        if !text.isEmpty {
            chatManager.setTyping(isTyping: true, in: chat.id)
            typingTimer?.invalidate()
            typingTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
                chatManager.setTyping(isTyping: false, in: chat.id)
            }
        } else {
            chatManager.setTyping(isTyping: false, in: chat.id)
        }
    }
    
    private func handlePhotoSelected(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    isUploadingPhoto = true
                    selectedItem = nil
                }
                
                chatManager.sendImageMessage(image, to: chat.id)
                
                await MainActor.run {
                    isUploadingPhoto = false
                }
            }
        }
    }
    
    private func fetchOtherUserDetails() {
        guard let otherId = otherUserId else { return }
        let db = Firestore.firestore()
        db.collection("users").document(otherId).addSnapshotListener { snapshot, _ in
            guard let data = snapshot?.data() else { return }
            do {
                var userData = data
                if let timestamp = data["lastSeen"] as? Timestamp {
                    userData["lastSeen"] = timestamp.dateValue().timeIntervalSince1970
                }
                let json = try JSONSerialization.data(withJSONObject: userData)
                var user = try JSONDecoder().decode(User.self, from: json)
                user.id = otherId
                DispatchQueue.main.async {
                    self.otherUser = user
                }
            } catch {
                print("Error decoding other user: \(error)")
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = chatManager.messages.last {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    // Grouping messages by calendar day
    private var groupedMessageDates: [Date] {
        let calendar = Calendar.current
        let dates = chatManager.messages.map { calendar.startOfDay(for: $0.timestamp) }
        return Array(Set(dates)).sorted()
    }
    
    private func messagesForDate(_ date: Date) -> [Message] {
        let calendar = Calendar.current
        return chatManager.messages.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
    
    private func formatHeaderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Message Bubble Component

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    var onImageTapped: (String) -> Void
    var onReactionSelected: (String) -> Void
    var onDelete: () -> Void
    
    private let availableReactions = ["❤️", "👍", "🔥", "😂", "😮"]
    
    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 40) }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 3) {
                // Main Bubble
                ZStack(alignment: .bottomTrailing) {
                    bubbleBody
                    
                    // Reaction Badge
                    if let reaction = message.reaction, !reaction.isEmpty {
                        Text(reaction)
                            .font(.system(size: 14))
                            .padding(4)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .offset(x: 4, y: 10)
                    }
                }
                
                // Footer (Timestamp & Status)
                HStack(spacing: 4) {
                    Text(formatMessageTime(message.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if isFromCurrentUser {
                        messageStatusIcon
                    }
                }
                .padding(.horizontal, 4)
            }
            
            if !isFromCurrentUser { Spacer(minLength: 40) }
        }
        .contextMenu {
            // Quick Reactions
            Section("React") {
                ForEach(availableReactions, id: \.self) { emoji in
                    Button(action: { onReactionSelected(emoji) }) {
                        Text(emoji)
                    }
                }
            }
            
            // Copy text action
            if message.messageType == .text && !message.text.isEmpty {
                Button(action: {
                    UIPasteboard.general.string = message.text
                }) {
                    Label("Copy Text", systemImage: "doc.on.doc")
                }
            }
            
            // Delete action (for current user's messages)
            if isFromCurrentUser {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Message", systemImage: "trash")
                }
            }
        }
    }
    
    @ViewBuilder
    private var bubbleBody: some View {
        switch message.messageType {
        case .text:
            Text(message.text)
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isFromCurrentUser ? Color("Peach") : Color(.systemGray5))
                .foregroundColor(isFromCurrentUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            
        case .image:
            if let imageUrl = message.mediaUrl, !imageUrl.isEmpty {
                Button(action: { onImageTapped(imageUrl) }) {
                    AsyncImage(url: URL(string: imageUrl)) { img in
                        img.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: 220, maxHeight: 220)
                            .clipped()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.systemGray5))
                            .frame(width: 200, height: 180)
                            .overlay(ProgressView())
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
        case .video, .audio, .file, .location:
            HStack(spacing: 8) {
                Image(systemName: "paperclip")
                Text(message.text)
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isFromCurrentUser ? Color("Peach") : Color(.systemGray5))
            .foregroundColor(isFromCurrentUser ? .white : .primary)
            .cornerRadius(18)
        }
    }
    
    private var messageStatusIcon: some View {
        Group {
            switch message.status {
            case .sent:
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            case .delivered:
                HStack(spacing: -3) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
            case .read:
                HStack(spacing: -3) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color("Peach"))
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
        }
    }
    
    private func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Typing Indicator Bubble

struct TypingBubble: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.secondary)
                .frame(width: 6, height: 6)
                .scaleEffect(phase == 0 ? 1.2 : 0.8)
            Circle()
                .fill(Color.secondary)
                .frame(width: 6, height: 6)
                .scaleEffect(phase == 1 ? 1.2 : 0.8)
            Circle()
                .fill(Color.secondary)
                .frame(width: 6, height: 6)
                .scaleEffect(phase == 2 ? 1.2 : 0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .clipShape(Capsule())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                phase = 2
            }
        }
    }
}

// MARK: - Fullscreen Image Viewer

struct FullscreenImageItem: Identifiable {
    let id = UUID()
    let url: String
}

struct FullscreenImageView: View {
    let imageUrl: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            AsyncImage(url: URL(string: imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
                    }
                    
                    Spacer()
                    
                    if let url = URL(string: imageUrl) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.8))
                                .padding()
                        }
                    }
                }
                Spacer()
            }
        }
    }
}

#Preview {
    NavigationView {
        ChatDetailView(chat: Chat(id: "1", participants: ["user1", "user2"]))
            .environmentObject(ChatManager())
            .environmentObject(AuthManager())
    }
}
