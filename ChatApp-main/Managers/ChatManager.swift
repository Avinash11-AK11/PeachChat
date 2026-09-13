//
//  ChatManager.swift
//  PeachChat
//
//  Created by Avinash Chavda.
//

import Foundation
import UIKit
import FirebaseFirestore
import FirebaseStorage

class ChatManager: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var currentChat: Chat?
    @Published var messages: [Message] = []
    @Published var typingUserIds: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var _currentUserId: String?
    private var chatsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    private var chatDocListener: ListenerRegistration?
    
    var currentUserId: String? {
        return _currentUserId
    }
    
    func setCurrentUser(_ userId: String) {
        _currentUserId = userId
        fetchUserChats()
    }
    
    // MARK: - Chat Management
    
    func fetchUserChats() {
        guard let currentUserId = _currentUserId else { return }
        
        isLoading = true
        chatsListener?.remove()
        
        chatsListener = db.collection("chats")
            .whereField("participants", arrayContains: currentUserId)
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else {
                        self?.chats = []
                        return
                    }
                    
                    self?.chats = documents.compactMap { document in
                        do {
                            let data = document.data()
                            var chatData = data
                            if let timestamp = data["lastMessageTime"] as? Timestamp {
                                chatData["lastMessageTime"] = timestamp.dateValue().timeIntervalSince1970
                            }
                            
                            let jsonData = try JSONSerialization.data(withJSONObject: chatData)
                            var chat = try JSONDecoder().decode(Chat.self, from: jsonData)
                            chat.id = document.documentID
                            return chat
                        } catch {
                            print("Error decoding chat: \(error)")
                            return nil
                        }
                    }
                }
            }
    }
    
    func createChat(with userId: String, isGroupChat: Bool = false, groupName: String? = nil) {
        guard let currentUserId = _currentUserId else { return }
        
        let chatId = UUID().uuidString
        let participants = isGroupChat ? [currentUserId, userId] : [currentUserId, userId]
        
        let chat = Chat(
            id: chatId,
            participants: participants,
            isGroupChat: isGroupChat,
            groupName: groupName
        )
        
        do {
            let data = try JSONEncoder().encode(chat)
            var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            dict["lastMessageTime"] = Timestamp(date: Date())
            
            db.collection("chats").document(chatId).setData(dict) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        self?.chats.insert(chat, at: 0)
                        self?.currentChat = chat
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Message Management
    
    func fetchMessages(for chatId: String) {
        isLoading = true
        messagesListener?.remove()
        chatDocListener?.remove()
        
        // Listen to chat document for live typing indicators
        chatDocListener = db.collection("chats").document(chatId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let data = snapshot?.data() else { return }
                if let typing = data["typingUsers"] as? [String] {
                    DispatchQueue.main.async {
                        self?.typingUserIds = typing.filter { $0 != self?._currentUserId }
                    }
                }
            }
        
        // Listen for real-time messages in this chat
        messagesListener = db.collection("chats").document(chatId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] querySnapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else {
                        self?.messages = []
                        return
                    }
                    
                    self?.messages = documents.compactMap { document in
                        do {
                            let data = document.data()
                            var messageData = data
                            if let timestamp = data["timestamp"] as? Timestamp {
                                messageData["timestamp"] = timestamp.dateValue().timeIntervalSince1970
                            }
                            
                            let jsonData = try JSONSerialization.data(withJSONObject: messageData)
                            var message = try JSONDecoder().decode(Message.self, from: jsonData)
                            message.id = document.documentID
                            return message
                        } catch {
                            print("Error decoding message: \(error)")
                            return nil
                        }
                    }
                    
                    // Mark messages as read if current user is not the sender
                    if let currentUserId = self?._currentUserId {
                        for message in self?.messages ?? [] {
                            if message.senderId != currentUserId && message.status != .read {
                                self?.markMessageAsRead(message.id, in: chatId)
                            }
                        }
                    }
                }
            }
    }
    
    func stopMessageListeners() {
        messagesListener?.remove()
        messagesListener = nil
        chatDocListener?.remove()
        chatDocListener = nil
        typingUserIds = []
    }
    
    func setTyping(isTyping: Bool, in chatId: String) {
        guard let currentUserId = _currentUserId else { return }
        let chatRef = db.collection("chats").document(chatId)
        if isTyping {
            chatRef.updateData(["typingUsers": FieldValue.arrayUnion([currentUserId])]) { _ in }
        } else {
            chatRef.updateData(["typingUsers": FieldValue.arrayRemove([currentUserId])]) { _ in }
        }
    }
    
    func addReaction(_ reaction: String, to messageId: String, in chatId: String) {
        db.collection("chats").document(chatId)
            .collection("messages").document(messageId)
            .updateData(["reaction": reaction]) { error in
                if let error = error {
                    print("Error updating reaction: \(error)")
                }
            }
    }
    
    func deleteChat(_ chatId: String) {
        db.collection("chats").document(chatId).delete { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.chats.removeAll { $0.id == chatId }
                }
            }
        }
    }
    
    func sendMessage(_ text: String, to chatId: String, messageType: Message.MessageType = .text) {
        guard let currentUserId = _currentUserId else { return }
        
        let messageId = UUID().uuidString
        let timestamp = Date()
        let message = Message(
            id: messageId,
            text: text,
            senderId: currentUserId,
            chatId: chatId,
            timestamp: timestamp,
            messageType: messageType
        )
        
        // Optimistic update
        DispatchQueue.main.async {
            self.messages.append(message)
        }
        
        do {
            // Create Firestore document with proper timestamp
            var messageData: [String: Any] = [
                "id": messageId,
                "text": text,
                "senderId": currentUserId,
                "chatId": chatId,
                "timestamp": Timestamp(date: timestamp),
                "messageType": messageType.rawValue,
                "status": "sent"
            ]
            
            db.collection("chats").document(chatId)
                .collection("messages").document(messageId)
                .setData(messageData) { [weak self] error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.errorMessage = error.localizedDescription
                            // Remove optimistic message on error
                            if let index = self?.messages.firstIndex(where: { $0.id == messageId }) {
                                self?.messages.remove(at: index)
                            }
                        } else {
                            // Update chat's last message
                            self?.updateChatLastMessage(chatId: chatId, message: message)
                            // Mark as delivered
                            self?.updateMessageStatus(messageId: messageId, in: chatId, status: .delivered)
                        }
                    }
                }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func sendImageMessage(_ image: UIImage, to chatId: String) {
        guard let currentUserId = _currentUserId else { return }
        
        uploadImage(image) { [weak self] imageUrl in
            guard let imageUrl = imageUrl else {
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to upload image"
                }
                return
            }
            
            let messageId = UUID().uuidString
            let message = Message(
                id: messageId,
                text: "Image",
                senderId: currentUserId,
                chatId: chatId,
                messageType: .image
            )
            
            // Add media URL to message
            var messageData: [String: Any] = [
                "id": messageId,
                "text": "Image",
                "senderId": currentUserId,
                "chatId": chatId,
                "timestamp": Timestamp(date: Date()),
                "messageType": "image",
                "status": "sent",
                "mediaUrl": imageUrl,
                "mediaType": "image"
            ]
            
            // Optimistic update
            DispatchQueue.main.async {
                var optimisticMessage = message
                optimisticMessage.mediaUrl = imageUrl
                self?.messages.append(optimisticMessage)
            }
            
            self?.db.collection("chats").document(chatId)
                .collection("messages").document(messageId)
                .setData(messageData) { [weak self] error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.errorMessage = error.localizedDescription
                            // Remove optimistic message on error
                            if let index = self?.messages.firstIndex(where: { $0.id == messageId }) {
                                self?.messages.remove(at: index)
                            }
                        } else {
                            // Update chat's last message
                            self?.updateChatLastMessage(chatId: chatId, message: message)
                        }
                    }
                }
        }
    }
    
    private func uploadImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        CloudinaryManager.shared.uploadImage(image, folder: "chat_images") { [weak self] result in
            switch result {
            case .success(let imageUrl):
                print("✅ Image uploaded to Cloudinary successfully: \(imageUrl)")
                completion(imageUrl)
            case .failure(let error):
                print("⚠️ Cloudinary upload error: \(error.localizedDescription). Falling back to Firebase Storage...")
                self?.uploadImageToFirebaseStorage(image, completion: completion)
            }
        }
    }
    
    private func uploadImageToFirebaseStorage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(nil)
            return
        }
        
        let imageName = "\(UUID().uuidString)_\(Date().timeIntervalSince1970).jpg"
        let imageRef = storage.reference().child("chat_images/\(imageName)")
        
        imageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Error uploading image to Firebase Storage: \(error)")
                completion(nil)
                return
            }
            
            imageRef.downloadURL { url, error in
                if let error = error {
                    print("Error getting download URL: \(error)")
                    completion(nil)
                    return
                }
                
                completion(url?.absoluteString)
            }
        }
    }
    
    private func updateChatLastMessage(chatId: String, message: Message) {
        let updates: [String: Any] = [
            "lastMessage": message.text,
            "lastMessageTime": Timestamp(date: message.timestamp),
            "lastMessageSenderId": message.senderId
        ]
        
        db.collection("chats").document(chatId).updateData(updates) { error in
            if let error = error {
                print("Error updating chat: \(error)")
            }
        }
    }
    
    private func updateMessageStatus(messageId: String, in chatId: String, status: Message.MessageStatus) {
        let statusString = status.rawValue
        db.collection("chats").document(chatId)
            .collection("messages").document(messageId)
            .updateData(["status": statusString]) { error in
                if let error = error {
                    print("Error updating message status: \(error)")
                }
            }
    }
    
    func markMessageAsRead(_ messageId: String, in chatId: String) {
        db.collection("chats").document(chatId)
            .collection("messages").document(messageId)
            .updateData(["status": "read"]) { [weak self] error in
                if let error = error {
                    print("Error marking message as read: \(error)")
                } else {
                    // Update local message status
                    if let index = self?.messages.firstIndex(where: { $0.id == messageId }) {
                        self?.messages[index].status = .read
                    }
                }
            }
    }
    
    func deleteMessage(_ messageId: String, from chatId: String) {
        db.collection("chats").document(chatId)
            .collection("messages").document(messageId)
            .delete { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        // Remove from local messages
                        self?.messages.removeAll { $0.id == messageId }
                    }
                }
            }
    }
}
