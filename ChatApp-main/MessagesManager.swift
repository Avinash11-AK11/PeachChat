//
//  MessagesManager.swift
//  PeachChat
//
//  Created by Avinash Chavda.
//

import Foundation
import FirebaseFirestore
//import FirebaseFirestoreSwift

class MessagesManager: ObservableObject {
	@Published private(set) var messages: [Message] = []
	@Published private(set) var lastMessageId = ""
	@Published var hasNewMessage = false
	@Published var flaggedMessage: Message?
	
	let db = Firestore.firestore()
	private var lastKnownMessageCount = 0

	init() {
		getMessages()
	}

	func getMessages() {
		print("Starting Firestore listener...")
		db.collection("messages")
			.order(by: "timestamp", descending: false)
			.addSnapshotListener { querySnapshot, error in
				if let error = error {
					print("❌ Firestore listener error: \(error.localizedDescription)")
					return
				}
				
				guard let documents = querySnapshot?.documents else {
					print("❌ No documents found in Firestore")
					return
				}

				print(" Received \(documents.count) documents from Firestore")
				
				let mapped: [Message] = documents.compactMap { document in
					let data = document.data()
					print(" Processing document \(document.documentID): \(data)")
					
					let id = (data["id"] as? String) ?? document.documentID
					let text = data["text"] as? String ?? ""
					let senderId = data["senderId"] as? String ?? "unknown"
					let chatId = data["chatId"] as? String ?? "default"
					let received = data["received"] as? Bool ?? false
					
					print(" Parsed: id=\(id), text='\(text)', senderId=\(senderId), chatId=\(chatId), received=\(received)")
					
					// Fix timestamp parsing with better error handling
					let date: Date
					if let timestamp = data["timestamp"] as? Timestamp {
						date = timestamp.dateValue()
						print(" Firestore Timestamp: \(timestamp) -> Date: \(date)")
						print(" Timestamp seconds: \(timestamp.seconds)")
						print(" Timestamp nanoseconds: \(timestamp.nanoseconds)")
					} else if let timeInterval = data["timestamp"] as? Double {
						date = Date(timeIntervalSince1970: timeInterval)
						print(" TimeInterval: \(timeInterval) -> Date: \(date)")
					} else if let timeInterval = data["timestamp"] as? TimeInterval {
						date = Date(timeIntervalSince1970: timeInterval)
						print(" TimeInterval: \(timeInterval) -> Date: \(date)")
					} else {
						date = Date()
						print(" Using current date as fallback: \(date)")
					}
					
					let message = Message(id: id, text: text, senderId: senderId, chatId: chatId, timestamp: date)
					print(" Created message: \(message)")
					return message
				}

				DispatchQueue.main.async {
					// Check for new messages (received messages only)
					let newReceivedMessages = mapped.filter { $0.received && $0.timestamp > Date().addingTimeInterval(-60) } // Messages from last minute
					
					if !newReceivedMessages.isEmpty && mapped.count > self.lastKnownMessageCount {
						self.flaggedMessage = newReceivedMessages.last
						self.hasNewMessage = true
						print(" New message flagged: \(self.flaggedMessage?.text ?? "")")
					}
					
					self.messages = mapped
					self.lastKnownMessageCount = mapped.count
					
					if let id = self.messages.last?.id {
						self.lastMessageId = id
					}
					print(" Updated UI with \(mapped.count) messages: \(mapped.map { "'\($0.text)'" }.joined(separator: ", "))")
				}
			}
	}
	
	// Clear the flag when user views or dismisses
	func clearFlag() {
		hasNewMessage = false
		flaggedMessage = nil
		print(" Flag cleared")
	}
	
	// Dismiss the flagged message
	func dismissFlaggedMessage() {
		clearFlag()
		print(" Flagged message dismissed")
	}
	
	// Test function to simulate receiving a new message
	func simulateNewMessage() {
		let testMessage = Message(
			id: "test-\(UUID())",
			text: "This is a test message to check the flag functionality!",
			senderId: "test-sender",
			chatId: "test-chat",
			timestamp: Date()
		)
		
		DispatchQueue.main.async {
			self.flaggedMessage = testMessage
			self.hasNewMessage = true
			print(" Test message flagged: \(testMessage.text)")
		}
	}
	
	
	// Add a message in Firestore
	func sendMessage(text: String) {
		let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { 
			print("❌ Empty message, not sending")
			return 
		}
		
		print(" Sending message: '\(trimmed)'")
		
		// Use current date and time
		let currentDate = Date()
		let newMessage = Message(
			id: "\(UUID())", 
			text: trimmed, 
			senderId: "currentUser", 
			chatId: "default", 
			timestamp: currentDate
		)
		
		print(" Creating message with current timestamp: \(currentDate)")
		print(" Current timestamp seconds: \(Int(currentDate.timeIntervalSince1970))")
		
		// Immediate optimistic UI update on main thread
		DispatchQueue.main.async {
			self.messages.append(newMessage)
			self.lastMessageId = newMessage.id
			print(" Added message to UI optimistically: '\(trimmed)'")
			print(" Total messages in UI: \(self.messages.count)")
		}
		
		// Create Firestore timestamp from current date
		let firestoreTimestamp = Timestamp(date: currentDate)
		print(" Firestore timestamp being sent: \(firestoreTimestamp)")
		
		let data: [String: Any] = [
			"id": newMessage.id,
			"text": newMessage.text,
			"senderId": newMessage.senderId,
			"chatId": newMessage.chatId,
			"received": false,
			"timestamp": firestoreTimestamp
		]
		
		print(" Writing to Firestore with data: \(data)")
		
		db.collection("messages").addDocument(data: data) { error in
			if let error = error {
				print("❌ Firestore write error: \(error.localizedDescription)")
				print("❌ Error code: \(error._code)")
				print("❌ Error domain: \(error._domain)")
				
				// Remove the optimistic message if Firestore write failed
				DispatchQueue.main.async {
					if let index = self.messages.firstIndex(where: { $0.id == newMessage.id }) {
						self.messages.remove(at: index)
						print("❌ Removed failed message from UI")
					}
				}
			} else {
				print("✅ Message successfully written to Firestore")
			}
		}
	}
	
}





