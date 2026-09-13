//
//  User.swift
//  PeachChat
//
//  Created by Avinash Chavda.
//

import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable, Equatable {
    var id: String
    var email: String
    var username: String
    var profileImageUrl: String?
    var bio: String?
    var isOnline: Bool
    var lastSeen: Date
    
    init(id: String, email: String, username: String, profileImageUrl: String? = nil, bio: String? = "Hey there! I am using PeachChat.", isOnline: Bool = true, lastSeen: Date = Date()) {
        self.id = id
        self.email = email
        self.username = username
        self.profileImageUrl = profileImageUrl
        self.bio = bio
        self.isOnline = isOnline
        self.lastSeen = lastSeen
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case profileImageUrl
        case bio
        case isOnline
        case lastSeen
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? "User"
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? "Hey there! I am using PeachChat."
        isOnline = try container.decodeIfPresent(Bool.self, forKey: .isOnline) ?? false
        
        // Handle various date formats (Timestamp, Double, String)
        if let timestamp = try? container.decode(Double.self, forKey: .lastSeen) {
            lastSeen = Date(timeIntervalSince1970: timestamp)
        } else if let dateStr = try? container.decode(String.self, forKey: .lastSeen) {
            let formatter = ISO8601DateFormatter()
            lastSeen = formatter.date(from: dateStr) ?? Date()
        } else {
            lastSeen = Date()
        }
    }
}
