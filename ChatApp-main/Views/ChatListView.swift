//
//  ChatListView.swift
//  PeachChat
//
//  Created by Avinash Chavda.
//

import SwiftUI
import FirebaseFirestore

struct ChatListView: View {
    @StateObject private var chatManager = ChatManager()
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showingNewChat = false
    @State private var showingProfile = false
    @State private var searchText = ""
    
    var filteredChats: [Chat] {
        if searchText.isEmpty {
            return chatManager.chats
        } else {
            return chatManager.chats.filter { chat in
                chat.lastMessage.localizedCaseInsensitiveContains(searchText) ||
                (chat.groupName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search conversations...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if chatManager.isLoading && chatManager.chats.isEmpty {
                    Spacer()
                    ProgressView("Loading conversations...")
                        .progressViewStyle(CircularProgressViewStyle(tint: Color("Peach")))
                    Spacer()
                } else if filteredChats.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: searchText.isEmpty ? "bubble.left.and.bubble.right.fill" : "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(Color("Peach").opacity(0.8))
                        
                        Text(searchText.isEmpty ? "No messages yet" : "No matching conversations")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text(searchText.isEmpty ? "Start a new conversation to connect with friends." : "Check the spelling or try searching for someone else.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        if searchText.isEmpty {
                            Button(action: { showingNewChat = true }) {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("Start New Chat")
                                }
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color("Peach"))
                                .cornerRadius(20)
                            }
                            .padding(.top, 8)
                        }
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredChats) { chat in
                            ChatRowView(chat: chat)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.visible, edges: .bottom)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        chatManager.deleteChat(chat.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("PeachChat")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Profile Avatar Button (Leading)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingProfile = true }) {
                        if let imageUrl = authManager.currentUser?.profileImageUrl, !imageUrl.isEmpty {
                            AsyncImage(url: URL(string: imageUrl)) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle().fill(Color("Peach").opacity(0.4))
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color("Peach"))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(String(authManager.currentUser?.username.prefix(1) ?? "U").uppercased())
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                }
                
                // New Chat Button (Trailing)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewChat = true }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color("Peach"))
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewChat) {
            NewChatView(chatManager: chatManager)
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
                .environmentObject(authManager)
        }
        .onAppear {
            if let currentUser = authManager.currentUser {
                chatManager.setCurrentUser(currentUser.id)
                authManager.updatePresence(isOnline: true)
            }
        }
        .onReceive(authManager.$currentUser) { user in
            if let user = user {
                chatManager.setCurrentUser(user.id)
            }
        }
        .environmentObject(chatManager)
    }
}

struct ChatRowView: View {
    let chat: Chat
    @State private var otherUser: User?
    @EnvironmentObject var authManager: AuthManager
    
    var isOtherUserTyping: Bool {
        guard let otherId = otherUser?.id else { return false }
        return chat.typingUsers.contains(otherId)
    }
    
    var body: some View {
        NavigationLink(destination: ChatDetailView(chat: chat)) {
            HStack(spacing: 12) {
                // Profile Avatar
                ZStack {
                    if let imageUrl = chat.groupImageUrl ?? otherUser?.profileImageUrl, !imageUrl.isEmpty {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: chat.isGroupChat ? "person.3.fill" : "person.fill")
                                .foregroundColor(.white)
                        }
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(LinearGradient(colors: [Color("Peach"), Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 52, height: 52)
                            .overlay(
                                Text(String(displayName.prefix(1)).uppercased())
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    // Online Badge
                    if otherUser?.isOnline == true {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 13, height: 13)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                            .offset(x: 18, y: 18)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(formatTimestamp(chat.lastMessageTime))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        if isOtherUserTyping {
                            Text("typing...")
                                .font(.system(size: 14))
                                .foregroundColor(Color("Peach"))
                                .italic()
                        } else {
                            Text(chat.lastMessage.isEmpty ? "No messages yet" : chat.lastMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        if chat.unreadCount > 0 {
                            Text("\(chat.unreadCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color("Peach"))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .onAppear(perform: fetchOtherUser)
    }
    
    private var displayName: String {
        if chat.isGroupChat {
            return chat.groupName ?? "Group Chat"
        }
        return otherUser?.username ?? "Chat"
    }
    
    private func fetchOtherUser() {
        guard !chat.isGroupChat, let currentUserId = authManager.currentUser?.id else { return }
        guard let otherUserId = chat.participants.first(where: { $0 != currentUserId }) else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(otherUserId).getDocument { snapshot, _ in
            guard let data = snapshot?.data() else { return }
            do {
                var userData = data
                if let timestamp = data["lastSeen"] as? Timestamp {
                    userData["lastSeen"] = timestamp.dateValue().timeIntervalSince1970
                }
                let json = try JSONSerialization.data(withJSONObject: userData)
                var user = try JSONDecoder().decode(User.self, from: json)
                user.id = otherUserId
                DispatchQueue.main.async {
                    self.otherUser = user
                }
            } catch {
                print("Failed to decode other user: \(error)")
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}

// MARK: - New Chat & Group View

struct NewChatView: View {
    @ObservedObject var chatManager: ChatManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0 // 0: Direct Chat, 1: New Group
    @State private var searchText = ""
    @State private var groupName = ""
    @State private var selectedUserIds: Set<String> = []
    @State private var users: [User] = []
    @State private var isLoading = false
    
    var filteredUsers: [User] {
        if searchText.isEmpty {
            return users
        } else {
            return users.filter {
                $0.username.localizedCaseInsensitiveContains(searchText) ||
                $0.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Segmented Picker (Direct vs Group)
                Picker("Chat Type", selection: $selectedTab) {
                    Text("Direct Chat").tag(0)
                    Text("New Group").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
                
                // Group Name Input (only for New Group tab)
                if selectedTab == 1 {
                    HStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(Color("Peach"))
                            .font(.system(size: 16))
                        
                        TextField("Group Name (e.g. iOS Engineers)...", text: $groupName)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search users...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.vertical, 6)
                
                if isLoading {
                    Spacer()
                    ProgressView("Finding users...")
                        .progressViewStyle(CircularProgressViewStyle(tint: Color("Peach")))
                    Spacer()
                } else if filteredUsers.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No other users found")
                            .font(.headline)
                        Text("Create another account on a second device or simulator to test live chatting!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredUsers) { user in
                            if selectedTab == 0 {
                                // 1-on-1 Direct Chat row
                                Button(action: {
                                    chatManager.createChat(with: user.id)
                                    dismiss()
                                }) {
                                    userRowContent(for: user, isSelected: false, isMultiSelect: false)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                // Multi-select Group Chat row
                                Button(action: {
                                    if selectedUserIds.contains(user.id) {
                                        selectedUserIds.remove(user.id)
                                    } else {
                                        selectedUserIds.insert(user.id)
                                    }
                                }) {
                                    userRowContent(for: user, isSelected: selectedUserIds.contains(user.id), isMultiSelect: true)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                
                // Bottom Action for Group Creation
                if selectedTab == 1 {
                    VStack(spacing: 8) {
                        Divider()
                        HStack {
                            Text("\(selectedUserIds.count) member\(selectedUserIds.count == 1 ? "" : "s") selected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: createGroup) {
                                Text("Create Group")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedUserIds.isEmpty ? Color.gray.opacity(0.5) : Color("Peach"))
                                    .clipShape(Capsule())
                            }
                            .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedUserIds.isEmpty)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                    .background(Color(.secondarySystemBackground))
                }
            }
            .navigationTitle(selectedTab == 0 ? "New Direct Chat" : "Create Group Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadUsers()
        }
    }
    
    private func userRowContent(for user: User, isSelected: Bool, isMultiSelect: Bool) -> some View {
        HStack(spacing: 12) {
            if isMultiSelect {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Color("Peach") : .secondary)
                    .font(.system(size: 20))
            }
            
            // User avatar
            ZStack {
                if let imageUrl = user.profileImageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color("Peach").opacity(0.3))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color("Peach"))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(String(user.username.prefix(1)).uppercased())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                
                if user.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                        .offset(x: 15, y: 15)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(user.username)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if !isMultiSelect {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func createGroup() {
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !selectedUserIds.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        chatManager.createGroupChat(name: trimmedName, participantIds: Array(selectedUserIds))
        dismiss()
    }
    
    private func loadUsers() {
        isLoading = true
        let db = Firestore.firestore()
        db.collection("users").getDocuments { snapshot, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("Error fetching users: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.users = documents.compactMap { document in
                    do {
                        var data = document.data()
                        if let timestamp = data["lastSeen"] as? Timestamp {
                            data["lastSeen"] = timestamp.dateValue().timeIntervalSince1970
                        }
                        let jsonData = try JSONSerialization.data(withJSONObject: data)
                        var user = try JSONDecoder().decode(User.self, from: jsonData)
                        user.id = document.documentID
                        
                        // Exclude current logged in user from list
                        if user.id == self.chatManager.currentUserId {
                            return nil
                        }
                        return user
                    } catch {
                        print("Error decoding user: \(error)")
                        return nil
                    }
                }
            }
        }
    }
}

#Preview {
    ChatListView()
        .environmentObject(AuthManager())
}
