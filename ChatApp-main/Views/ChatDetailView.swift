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
    @StateObject private var audioManager = AudioManager.shared
    
    @State private var messageText = ""
    @State private var showingImagePicker = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var otherUser: User?
    @State private var isUploadingPhoto = false
    @State private var selectedFullscreenImageUrl: String? = nil
    @State private var typingTimer: Timer?
    @FocusState private var isTextFieldFocused: Bool
    
    // Swipe-to-Reply state
    @State private var replyingToMessage: Message? = nil
    
    // In-chat search state
    @State private var isSearching: Bool = false
    @State private var searchQuery: String = ""
    @State private var searchMatchIds: [String] = []
    @State private var currentMatchIndex: Int = 0
    
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
            // Search Bar Banner (when toggled)
            if isSearching {
                searchBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            messagesArea
            
            if isUploadingPhoto {
                uploadingPhotoBanner
            }
            
            // Reply Preview Banner
            if let replyMsg = replyingToMessage {
                replyPreviewBanner(for: replyMsg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            inputArea
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSearching)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: replyingToMessage)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                chatHeaderTitle
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation {
                        isSearching.toggle()
                        if !isSearching {
                            searchQuery = ""
                            searchMatchIds = []
                        }
                    }
                }) {
                    Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                        .foregroundColor(Color("Peach"))
                }
            }
        }
        .onAppear {
            chatManager.fetchMessages(for: chat.id)
            fetchOtherUserDetails()
        }
        .onDisappear {
            chatManager.stopMessageListeners()
            chatManager.setTyping(isTyping: false, in: chat.id)
            audioManager.stopPlayback()
            if audioManager.isRecording {
                audioManager.cancelRecording()
            }
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
    
    // MARK: - In-Chat Search Banner
    
    private var searchBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
            
            TextField("Search in conversation...", text: $searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 14))
                .onChange(of: searchQuery) { query in
                    performSearch(query: query)
                }
            
            if !searchQuery.isEmpty {
                if !searchMatchIds.isEmpty {
                    Text("\(currentMatchIndex + 1) of \(searchMatchIds.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Button(action: { moveToMatch(step: -1) }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color("Peach"))
                    }
                    
                    Button(action: { moveToMatch(step: 1) }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color("Peach"))
                    }
                } else {
                    Text("No matches")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    searchQuery = ""
                    searchMatchIds = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchMatchIds = []
            currentMatchIndex = 0
            return
        }
        let matches = chatManager.messages.filter {
            $0.text.localizedCaseInsensitiveContains(trimmed)
        }.map { $0.id }
        
        searchMatchIds = matches
        currentMatchIndex = matches.isEmpty ? 0 : matches.count - 1
    }
    
    private func moveToMatch(step: Int) {
        guard !searchMatchIds.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + step + searchMatchIds.count) % searchMatchIds.count
    }
    
    // MARK: - Reply Preview Banner (Above Input)
    
    private func replyPreviewBanner(for message: Message) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color("Peach"))
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption2)
                        .foregroundColor(Color("Peach"))
                    Text(replySenderDisplayName(for: message))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("Peach"))
                }
                
                Text(message.messageType == .audio ? "🎤 Voice note (\(formatAudioDuration(message.audioDuration ?? 0)))" : (message.messageType == .image ? "📷 Photo" : message.text))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    replyingToMessage = nil
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
    
    private func replySenderDisplayName(for message: Message) -> String {
        if message.senderId == authManager.currentUser?.id {
            return "You"
        }
        if chat.isGroupChat {
            return message.replyToSenderName ?? "Friend"
        }
        return otherUser?.username ?? "Friend"
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
                
                if !chat.isGroupChat && otherUser?.isOnline == true {
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
                } else if !chat.isGroupChat && otherUser?.isOnline == true {
                    Text("Online")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else if !chat.isGroupChat, let lastSeen = otherUser?.lastSeen {
                    Text("Last seen \(formatHeaderDate(lastSeen))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if chat.isGroupChat {
                    Text("\(chat.participants.count) members")
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
                                let isMatch = !searchQuery.isEmpty && message.text.localizedCaseInsensitiveContains(searchQuery)
                                let isCurrentMatch = !searchMatchIds.isEmpty && currentMatchIndex < searchMatchIds.count && searchMatchIds[currentMatchIndex] == message.id
                                
                                MessageBubbleView(
                                    message: message,
                                    isFromCurrentUser: message.senderId == authManager.currentUser?.id,
                                    isGroupChat: chat.isGroupChat,
                                    otherUserName: otherUser?.username,
                                    isHighlighted: isMatch,
                                    isCurrentMatch: isCurrentMatch,
                                    onImageTapped: { url in
                                        selectedFullscreenImageUrl = url
                                    },
                                    onReactionSelected: { reaction in
                                        chatManager.addReaction(reaction, to: message.id, in: chat.id)
                                    },
                                    onReply: {
                                        withAnimation {
                                            replyingToMessage = message
                                            isTextFieldFocused = true
                                        }
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
            .onChange(of: currentMatchIndex) { _ in
                if !searchMatchIds.isEmpty && currentMatchIndex < searchMatchIds.count {
                    withAnimation {
                        proxy.scrollTo(searchMatchIds[currentMatchIndex], anchor: .center)
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
            
            if audioManager.isRecording {
                // Live voice recording UI
                recordingInputBar
            } else {
                // Standard text / photo / voice message input
                standardInputBar
            }
        }
        .background(Color(.systemBackground))
    }
    
    // Live Voice Recording Bar
    private var recordingInputBar: some View {
        HStack(spacing: 12) {
            // Blinking red recording indicator
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .opacity(0.8)
            
            // Duration counter
            Text(formatAudioDuration(audioManager.recordingDuration))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.red)
            
            // Live animated waveform
            HStack(spacing: 2.5) {
                ForEach(audioManager.waveformSamples.indices, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color("Peach"))
                        .frame(width: 3, height: max(6, audioManager.waveformSamples[idx] * 32))
                }
            }
            .frame(height: 36)
            
            Spacer()
            
            // Cancel recording button
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                audioManager.cancelRecording()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .padding(8)
            }
            
            // Send voice note button
            Button(action: finishAndSendAudio) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(Color("Peach"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // Standard text & media bar
    private var standardInputBar: some View {
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
            
            // Send or Mic Button
            if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Voice note button
                Button(action: startAudioRecording) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color("Peach"))
                        .clipShape(Circle())
                }
            } else {
                // Send text message button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color("Peach"))
                        .clipShape(Circle())
                }
                .disabled(isUploadingPhoto)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
    
    // MARK: - Audio Recording & Sending
    
    private func startAudioRecording() {
        audioManager.requestMicrophonePermission { granted in
            guard granted else {
                print("Microphone access denied")
                return
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            audioManager.startRecording()
        }
    }
    
    private func finishAndSendAudio() {
        guard let result = audioManager.stopRecording() else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let senderName = authManager.currentUser?.username ?? "User"
        chatManager.sendAudioMessage(
            fileUrl: result.url,
            duration: result.duration,
            to: chat.id,
            replyToMessage: replyingToMessage,
            replySenderName: senderName
        )
        
        withAnimation {
            replyingToMessage = nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let senderName = authManager.currentUser?.username ?? "User"
        chatManager.sendMessage(
            trimmed,
            to: chat.id,
            replyToMessage: replyingToMessage,
            replySenderName: senderName
        )
        
        messageText = ""
        withAnimation {
            replyingToMessage = nil
        }
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
    
    private func formatAudioDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Message Bubble Component (with Swipe-to-Reply & Audio Player)

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    var isGroupChat: Bool = false
    var otherUserName: String? = nil
    var isHighlighted: Bool = false
    var isCurrentMatch: Bool = false
    var onImageTapped: (String) -> Void
    var onReactionSelected: (String) -> Void
    var onReply: () -> Void
    var onDelete: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @StateObject private var audioManager = AudioManager.shared
    
    private let availableReactions = ["❤️", "👍", "🔥", "😂", "😮"]
    
    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 40) }
            
            // Swipe reply trigger indicator
            if dragOffset > 20 {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .foregroundColor(Color("Peach"))
                    .font(.caption)
                    .opacity(Double(dragOffset / 50))
                    .padding(.trailing, 4)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 3) {
                // Group Chat Sender Name Header
                if isGroupChat && !isFromCurrentUser {
                    Text(message.replyToSenderName ?? (otherUserName ?? "Member"))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("Peach"))
                        .padding(.leading, 6)
                }
                
                // Main Bubble Stack
                ZStack(alignment: .bottomTrailing) {
                    VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                        // Quoted Reply Preview inside bubble
                        if let replyText = message.replyToText, !replyText.isEmpty {
                            quotedReplyCard(text: replyText, senderName: message.replyToSenderName)
                        }
                        
                        bubbleBody
                    }
                    .padding(4)
                    .background(isFromCurrentUser ? Color("Peach") : Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isCurrentMatch ? Color.yellow : (isHighlighted ? Color.orange.opacity(0.6) : Color.clear), lineWidth: 2)
                    )
                    
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
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width > 0 && value.translation.width < 80 {
                            dragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        if value.translation.width > 45 {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onReply()
                        }
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
            )
            
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
            
            // Reply action
            Button(action: onReply) {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
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
    
    // Quoted Reply Card inside bubble
    private func quotedReplyCard(text: String, senderName: String?) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isFromCurrentUser ? Color.white.opacity(0.8) : Color("Peach"))
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(senderName ?? "Message")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isFromCurrentUser ? .white : Color("Peach"))
                
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(isFromCurrentUser ? .white.opacity(0.85) : .secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(6)
        .background(isFromCurrentUser ? Color.white.opacity(0.15) : Color(.systemGray6))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var bubbleBody: some View {
        switch message.messageType {
        case .text:
            Text(message.text)
                .font(.system(size: 15))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundColor(isFromCurrentUser ? .white : .primary)
            
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
            
        case .audio:
            AudioMessageBubbleView(
                message: message,
                isFromCurrentUser: isFromCurrentUser
            )
            
        case .video, .file, .location:
            HStack(spacing: 8) {
                Image(systemName: "paperclip")
                Text(message.text)
                    .font(.subheadline)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundColor(isFromCurrentUser ? .white : .primary)
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

// MARK: - Audio Message Bubble View (Waveform + Play / Pause)

struct AudioMessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    @StateObject private var audioManager = AudioManager.shared
    
    var isPlayingThis: Bool {
        audioManager.playingMessageId == message.id && audioManager.isPlaying
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Play / Pause button
            Button(action: togglePlay) {
                Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isFromCurrentUser ? Color("Peach") : .white)
                    .frame(width: 34, height: 34)
                    .background(isFromCurrentUser ? Color.white : Color("Peach"))
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Waveform visualization
                HStack(spacing: 2.5) {
                    ForEach(0..<18, id: \.self) { index in
                        let sampleHeight = [0.3, 0.6, 0.9, 0.4, 0.7, 1.0, 0.5, 0.8, 0.4, 0.9, 0.6, 0.7, 0.3, 0.8, 0.5, 0.7, 0.4, 0.6][index]
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(barColor(for: index))
                            .frame(width: 2.5, height: CGFloat(sampleHeight * 22))
                    }
                }
                .frame(height: 24)
                
                // Audio duration
                Text(formattedDuration)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isFromCurrentUser ? Color.white.opacity(0.85) : .secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minWidth: 170)
    }
    
    private func barColor(for index: Int) -> Color {
        let progress = isPlayingThis ? audioManager.playbackProgress : 0.0
        let barProgress = Double(index) / 18.0
        
        if isFromCurrentUser {
            return barProgress <= progress ? Color.white : Color.white.opacity(0.4)
        } else {
            return barProgress <= progress ? Color("Peach") : Color.gray.opacity(0.4)
        }
    }
    
    private var formattedDuration: String {
        let duration = message.audioDuration ?? 0
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func togglePlay() {
        guard let url = message.mediaUrl, !url.isEmpty else { return }
        audioManager.playAudio(from: url, messageId: message.id)
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
