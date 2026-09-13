//
//  MessageBubble.swift
//  PeachChat
//
//  Created by Avinash Chavda.
//

import SwiftUI

struct MessageBubble: View {
    var message: Message
    @State private var showTime = false
    
    var body: some View {
        VStack(alignment: message.received ? .leading : .trailing) {
            HStack {
                Text(message.text)
                    .padding()
                    .background(message.received ? Color("chatGray") : Color("Peach"))
                    .cornerRadius(30)
            }
            .frame(maxWidth: 300, alignment: message.received ? .leading : .trailing)
            .onTapGesture {
                showTime.toggle()
            }
            
            if showTime {
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(message.received ? .leading : .trailing, 25)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.received ? .leading : .trailing)
        .padding(message.received ? .leading : .trailing)
        .padding(.horizontal, 10)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        
        // Check if the date is today
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateStyle = .none
            return formatter.string(from: date) // Only show time for today
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, " + formatter.string(from: date)
        } else {
            return formatter.string(from: date) // Show date and time for older messages
        }
    }
}

#Preview {
    MessageBubble(message: Message(
        id: "12345", 
        text: "I've been coding SwiftUI application from scratch and it's so much fun!", 
        senderId: "otherUser", 
        chatId: "default", 
        timestamp: Date()
    ))
}
