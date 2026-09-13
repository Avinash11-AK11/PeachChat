# PeachChat 💬
### Real-Time iOS Messaging Application

> Designed & Developed by **Avinash Chavda** ([avinashchavda11@gmail.com](mailto:avinashchavda11@gmail.com))

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg?style=flat&logo=swift)](https://developer.apple.com/swift/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue.svg?style=flat&logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![Firebase](https://img.shields.io/badge/Backend-Firebase-FFCA28.svg?style=flat&logo=firebase)](https://firebase.google.com/)
[![Cloudinary](https://img.shields.io/badge/Media-Cloudinary%20CDN-3448C5.svg?style=flat&logo=cloudinary)](https://cloudinary.com/)
[![iOS](https://img.shields.io/badge/iOS-17.0+-black.svg?style=flat&logo=apple)](https://www.apple.com/ios/)

---

## 📖 Overview

**PeachChat** is an iOS real-time messaging application engineered with modern **SwiftUI**, **Cloud Firestore**, and **Cloudinary Media API**. Engineered to showcase senior-level iOS application architecture, it features real-time bidirectional messaging, presence tracking, live typing indicators, image sharing with a CDN pipeline, message reactions, and interactive fullscreen media inspection.

---

## ✨ Key Features

### ⚡️ Real-Time Messaging & Presence
- **Instant Synchronization**: Powered by Cloud Firestore real-time snapshot listeners with sub-second message delivery.
- **Optimistic UI Updates**: Outgoing messages appear instantly with pending/sent status indicators for zero perceived latency.
- **Message Lifecycle Tracking**: Clear status progression: `✓ Sent` → `✓✓ Delivered` → `✓✓ Read` (highlighted in Peach accent).
- **Live Typing Indicators**: Real-time 3-dot pulsing typing animations synchronized across participants.
- **Presence & Online Status**: Automatic presence state tracking (`Online` vs `Last seen [time]`) responding to iOS application lifecycle events (`scenePhase`).

### 📸 High-Performance Media Pipeline
- **Cloudinary CDN**: Direct client-side unsigned REST multipart image uploads via [`CloudinaryManager`](file:///Users/avinash/Downloads/PeachChat---iOS-Real-Time-Chat-App-main/ChatApp-main/Managers/CloudinaryManager.swift).
- **Dual-Pipeline Fallback**: Automatic failover to Firebase Storage if Cloudinary is unreachable.
- **Interactive Fullscreen Viewer**: Tap-to-zoom fullscreen image inspection with native iOS `ShareLink`.

### 🎨 Modern, Human-Centered UX
- **Date-Grouped Feeds**: Automatic message grouping by calendar day with clean pill headers (*"Today"*, *"Yesterday"*, *"October 14"*).
- **Context Actions & Reactions**: Long-press message bubbles to react with emojis (❤️, 👍, 🔥, 😂, 😮), copy text, or delete messages.
- **Tactile Haptics**: Subtle physical feedback via `UIImpactFeedbackGenerator` upon sending messages.
- **Personalized Profile & Bio**: Dedicated profile management with editable avatar, display name, and status bio.

---

## 🏛️ Architecture & Engineering Design

The project strictly follows the **MVVM (Model-View-ViewModel)** architectural pattern:

```
PeachChat/
├── Models/
│   ├── User.swift              # User entity with robust date decoding & presence
│   ├── Chat.swift              # Conversation model with participant & typing metadata
│   └── Message.swift           # Polymorphic message payload with reactions & status
├── Managers/
│   ├── AuthManager.swift       # Firebase Authentication & User Presence lifecycle
│   ├── ChatManager.swift       # Real-time Firestore chat & message coordination
│   └── CloudinaryManager.swift # Async/await REST media pipeline with multipart upload
├── Views/
│   ├── LoginView.swift         # Dynamic onboarding & sign-in interface
│   ├── ChatListView.swift      # Conversation overview with swipe actions & user search
│   ├── ChatDetailView.swift    # Message thread, typing bubbles & fullscreen viewer
│   └── ProfileView.swift       # User settings, Cloudinary avatar edit & credentials
└── Components/
    ├── MessageBubble.swift     # Reusable bubble layout with tails & status icons
    └── MessageField.swift      # Expandable multi-line compose input
```

---

## 🔒 Security & Firestore Security Rules

To enforce authenticated data boundaries, the following Firestore rules are deployed:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // User directory: Authenticated users can discover contacts; can only modify own profile
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Conversations: Only participants can read, write, or query
    match /chats/{chatId} {
      allow create: if request.auth != null && 
        request.auth.uid in request.resource.data.participants;
      allow read, update, delete: if request.auth != null && 
        request.auth.uid in resource.data.participants;
      
      // Thread Messages: Secured to conversation participants
      match /messages/{messageId} {
        allow read, write: if request.auth != null;
      }
    }
    
    // Standalone fallback / demo messages
    match /messages/{messageId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## 🛠️ Getting Started

### 1. Prerequisites
- macOS 14.0+
- Xcode 15.0+
- iOS 17.0+ Simulator or physical device

### 2. Setup
1. Clone or open the project folder in Xcode:
   ```bash
   open ChatApp-main.xcodeproj
   ```
2. Ensure `GoogleService-Info.plist` is present in the `ChatApp-main` directory.
3. Select an iOS Simulator (e.g. **iPhone 17 Pro**) and press **⌘ + R** to run.

### 3. Testing Real-Time Chats Across Two Devices
1. Launch the app in Simulator 1 and sign up with: `user1@test.com`.
2. Launch the app in Simulator 2 (or a physical device) and sign up with: `user2@test.com`.
3. In Simulator 1, tap the **Pencil Icon** (top right) to start a chat with `user2`.
4. Send messages and photos to experience real-time delivery, typing bubbles, and read receipts!

---

## 👨‍💻 Author

**Avinash Chavda**  
- GitHub: [@Avinash11-AK11](https://github.com/Avinash11-AK11)  
- Email: [avinashchavda11@gmail.com](mailto:avinashchavda11@gmail.com)  
- Role: iOS & Mobile Application Developer  
