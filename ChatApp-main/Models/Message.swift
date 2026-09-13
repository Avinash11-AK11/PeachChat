//
//  Message.swift
//  PeachChat
//
//  Created by Avinash Chavda.
//

import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable, Hashable {
    var id: String
    var text: String
    var senderId: String
    var chatId: String
    var timestamp: Date
    var messageType: MessageType
    var status: MessageStatus
    var replyToMessageId: String?
    var replyToText: String?
    var replyToSenderName: String?
    var mediaUrl: String?
    var mediaType: MediaType?
    var reaction: String?
    var isDeleted: Bool?
    var audioDuration: Double?
    
    enum MessageType: String, Codable, CaseIterable {
        case text = "text"
        case image = "image"
        case video = "video"
        case audio = "audio"
        case file = "file"
        case location = "location"
    }
    
    enum MessageStatus: String, Codable, CaseIterable {
        case sent = "sent"
        case delivered = "delivered"
        case read = "read"
        case failed = "failed"
    }
    
    enum MediaType: String, Codable, CaseIterable {
        case image = "image"
        case video = "video"
        case audio = "audio"
        case file = "file"
    }
    
    init(id: String, text: String, senderId: String, chatId: String, timestamp: Date = Date(), messageType: MessageType = .text, status: MessageStatus = .sent, reaction: String? = nil, isDeleted: Bool? = false, replyToMessageId: String? = nil, replyToText: String? = nil, replyToSenderName: String? = nil, mediaUrl: String? = nil, audioDuration: Double? = nil) {
        self.id = id
        self.text = text
        self.senderId = senderId
        self.chatId = chatId
        self.timestamp = timestamp
        self.messageType = messageType
        self.status = status
        self.reaction = reaction
        self.isDeleted = isDeleted
        self.replyToMessageId = replyToMessageId
        self.replyToText = replyToText
        self.replyToSenderName = replyToSenderName
        self.mediaUrl = mediaUrl
        self.mediaType = messageType == .image ? .image : (messageType == .audio ? .audio : nil)
        self.audioDuration = audioDuration
    }
    
    // Computed property for backward compatibility
    var received: Bool {
        return senderId != "currentUser"
    }
    
    // Custom decoder to handle Firestore timestamps, doubles, and ISO8601 date strings
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        senderId = try container.decodeIfPresent(String.self, forKey: .senderId) ?? ""
        chatId = try container.decodeIfPresent(String.self, forKey: .chatId) ?? ""
        messageType = try container.decodeIfPresent(MessageType.self, forKey: .messageType) ?? .text
        status = try container.decodeIfPresent(MessageStatus.self, forKey: .status) ?? .sent
        replyToMessageId = try container.decodeIfPresent(String.self, forKey: .replyToMessageId)
        replyToText = try container.decodeIfPresent(String.self, forKey: .replyToText)
        replyToSenderName = try container.decodeIfPresent(String.self, forKey: .replyToSenderName)
        mediaUrl = try container.decodeIfPresent(String.self, forKey: .mediaUrl)
        mediaType = try container.decodeIfPresent(MediaType.self, forKey: .mediaType)
        reaction = try container.decodeIfPresent(String.self, forKey: .reaction)
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        audioDuration = try container.decodeIfPresent(Double.self, forKey: .audioDuration)
        
        // Handle timestamp decoding flexibly
        if let timestampVal = try? container.decode(Double.self, forKey: .timestamp) {
            timestamp = Date(timeIntervalSince1970: timestampVal)
        } else if let timestampString = try? container.decode(String.self, forKey: .timestamp) {
            let formatter = ISO8601DateFormatter()
            timestamp = formatter.date(from: timestampString) ?? Date()
        } else {
            timestamp = Date()
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, text, senderId, chatId, timestamp, messageType, status
        case replyToMessageId, replyToText, replyToSenderName, mediaUrl, mediaType, reaction, isDeleted, audioDuration
    }
}
