//
//  Chat.swift
//  PeachChat
//
//  Created by Avinash Chavda.
//

import Foundation
import FirebaseFirestore

struct Chat: Identifiable, Codable, Equatable {
    var id: String
    var participants: [String] // User IDs
    var lastMessage: String
    var lastMessageTime: Date
    var lastMessageSenderId: String
    var unreadCount: Int
    var isGroupChat: Bool
    var groupName: String?
    var groupImageUrl: String?
    var typingUsers: [String]
    
    init(id: String, participants: [String], isGroupChat: Bool = false, groupName: String? = nil) {
        self.id = id
        self.participants = participants
        self.lastMessage = ""
        self.lastMessageTime = Date()
        self.lastMessageSenderId = ""
        self.unreadCount = 0
        self.isGroupChat = isGroupChat
        self.groupName = groupName
        self.groupImageUrl = nil
        self.typingUsers = []
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case participants
        case lastMessage
        case lastMessageTime
        case lastMessageSenderId
        case unreadCount
        case isGroupChat
        case groupName
        case groupImageUrl
        case typingUsers
    }
    
    // Custom decoder to handle Firestore timestamps, doubles, and ISO8601 strings
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        participants = try container.decodeIfPresent([String].self, forKey: .participants) ?? []
        lastMessage = try container.decodeIfPresent(String.self, forKey: .lastMessage) ?? ""
        lastMessageSenderId = try container.decodeIfPresent(String.self, forKey: .lastMessageSenderId) ?? ""
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
        isGroupChat = try container.decodeIfPresent(Bool.self, forKey: .isGroupChat) ?? false
        groupName = try container.decodeIfPresent(String.self, forKey: .groupName)
        groupImageUrl = try container.decodeIfPresent(String.self, forKey: .groupImageUrl)
        typingUsers = try container.decodeIfPresent([String].self, forKey: .typingUsers) ?? []
        
        // Handle timestamp decoding flexibly
        if let timestamp = try? container.decode(Double.self, forKey: .lastMessageTime) {
            lastMessageTime = Date(timeIntervalSince1970: timestamp)
        } else if let timestampString = try? container.decode(String.self, forKey: .lastMessageTime) {
            let formatter = ISO8601DateFormatter()
            lastMessageTime = formatter.date(from: timestampString) ?? Date()
        } else {
            lastMessageTime = Date()
        }
    }
}
