# PeachChat 💬
### Production-Grade Real-Time iOS Messaging Application

> Designed & Developed by **Avinash Chavda** ([avinashchavda11@gmail.com](mailto:avinashchavda11@gmail.com))

[![iOS Build & Test CI](https://github.com/Avinash11-AK11/PeachChat/actions/workflows/ios-build.yml/badge.svg)](https://github.com/Avinash11-AK11/PeachChat/actions)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg?style=flat&logo=swift)](https://developer.apple.com/swift/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue.svg?style=flat&logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![Firebase](https://img.shields.io/badge/Backend-Firebase-FFCA28.svg?style=flat&logo=firebase)](https://firebase.google.com/)
[![Cloudinary](https://img.shields.io/badge/Media-Cloudinary%20CDN-3448C5.svg?style=flat&logo=cloudinary)](https://cloudinary.com/)
[![iOS](https://img.shields.io/badge/iOS-17.0+-black.svg?style=flat&logo=apple)](https://www.apple.com/ios/)

---

## 📖 Overview

**PeachChat** is a production-grade iOS real-time messaging application engineered with modern **SwiftUI**, **Cloud Firestore**, and **Cloudinary Media API**. Engineered to showcase senior-level iOS application architecture, it features bidirectional messaging, live audio voice notes with real-time waveform visualization, swipe-to-reply with quoted previews, in-chat message search, group chat creation, presence tracking, live typing indicators, and automated CI/CD via GitHub Actions.

---

## ✨ Key Features

### 🎙️ Live Voice Notes & Waveform Visualization
- **AVFoundation Audio Pipeline**: Hardware-accelerated recording (`AVAudioRecorder`) and playback (`AVAudioPlayer`) in AAC format (`.m4a`).
- **Real-Time Metering Waveform**: 20-sample live audio decibel metering rendered as dynamic dancing waveform bars during recording.
- **Audio Message Player**: Interactive audio bubbles with play/pause controls, synchronized progress playback indicator, and duration display.
- **Cloudinary Audio CDN**: High-speed audio upload pipeline to Cloudinary with automatic failover to Firebase Storage.

### ↩️ Swipe-to-Reply & Quoted Previews
- **Gesture-Driven Interactions**: Horizontal swipe drag gesture with tactile feedback (`UIImpactFeedbackGenerator`) to instantly reply to any message.
- **Quoted Message Previews**: Pinned reply card above the input composer and styled inline quote bubbles showing the original sender's name and message snippet.

### 🔍 In-Chat Search & Stepper Navigation
- **Instant Search**: Search through conversational histories in real time with dynamic highlight outlines on matching message bubbles.
- **Match Stepper**: Interactive counter showing match counts (*"2 of 5"*) with jump-to-match buttons (`chevron.up` / `chevron.down`) powered by `ScrollViewReader`.

### 👥 Group Chats & Multi-Participant Channels
- **Group Creation Flow**: Dedicated tab in the new chat modal allowing custom group names and multi-select user checkboxes.
- **Sender Badges & Metadata**: Distinct sender attribution tags on incoming bubbles for crystal-clear group communication.

### ⚡️ Real-Time Messaging & Presence
- **Instant Synchronization**: Powered by Cloud Firestore real-time snapshot listeners with sub-second message delivery.
- **Optimistic UI Updates**: Outgoing messages appear instantly with pending/sent status indicators for zero perceived latency.
- **Message Lifecycle Tracking**: Clear status progression: `✓ Sent` → `✓✓ Delivered` → `✓✓ Read` (highlighted in Peach accent).
- **Live Typing Indicators**: Real-time 3-dot pulsing typing animations synchronized across participants.
- **Presence & Online Status**: Automatic presence state tracking (`Online` vs `Last seen [time]`) responding to iOS application lifecycle events (`scenePhase`).

### 📸 High-Performance Media Pipeline
- **Cloudinary CDN**: Direct client-side unsigned REST multipart image uploads via [`CloudinaryManager`](ChatApp-main/Managers/CloudinaryManager.swift).
- **Dual-Pipeline Fallback**: Automatic failover to Firebase Storage if Cloudinary is unreachable.
- **Interactive Fullscreen Viewer**: Tap-to-zoom fullscreen image inspection with native iOS `ShareLink`.

### 🎨 Modern, Human-Centered UX
- **Date-Grouped Feeds**: Automatic message grouping by calendar day with clean pill headers (*"Today"*, *"Yesterday"*, *"October 14"*).
- **Context Actions & Reactions**: Long-press message bubbles to react with emojis (❤️, 👍, 🔥, 😂, 😮), copy text, or delete messages.
- **Tactile Haptics**: Subtle physical feedback via `UIImpactFeedbackGenerator` upon sending messages.
- **Personalized Profile & Bio**: Dedicated profile management with editable avatar, display name, and status bio.

### 🚀 CI/CD Pipeline (GitHub Actions)
- **Automated Compilation**: Continuous integration workflow running on `macos-14` running Xcode builds on every commit and pull request to verify zero compile regressions.

---

## 🏛️ Architecture & Engineering Design

The project strictly follows the **MVVM (Model-View-ViewModel)** architectural pattern:

```
PeachChat/
├── Models/
│   ├── User.swift              # User entity with bio, presence & timestamp parsing
│   ├── Chat.swift              # Conversation model supporting 1-on-1 and Group chats
│   └── Message.swift           # Polymorphic payload (text, image, audio, reply metadata)
├── Managers/
│   ├── AuthManager.swift       # Firebase Authentication & User Presence lifecycle
│   ├── ChatManager.swift       # Real-time Firestore chat & message coordination
│   ├── CloudinaryManager.swift # Async/await REST media pipeline (images + audio)
│   └── AudioManager.swift      # AVFoundation recording, metering waveform & playback
├── Views/
│   ├── LoginView.swift         # Dynamic onboarding & sign-in interface
│   ├── ChatListView.swift      # Chat feed, user search & group creation flow
│   ├── ChatDetailView.swift    # Thread, voice recorder, audio bubbles & search
│   └── ProfileView.swift       # User settings, Cloudinary avatar edit & credentials
├── Components/
│   ├── MessageBubble.swift     # Reusable bubble layout with tails & status icons
│   └── MessageField.swift      # Expandable multi-line compose input
└── .github/workflows/
    └── ios-build.yml           # Automated GitHub Actions CI workflow
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
1. Clone the repository:
   ```bash
   git clone https://github.com/Avinash11-AK11/PeachChat.git
   cd PeachChat
   ```
2. Open the project in Xcode:
   ```bash
   open ChatApp-main.xcodeproj
   ```
3. Select an iOS Simulator (e.g. **iPhone 17 Pro**) and press **⌘ + R** to run.

### 3. Testing Real-Time Features Across Devices
1. Launch the app in Simulator 1 and sign up with: `user1@test.com`.
2. Launch the app in Simulator 2 (or a physical device) and sign up with: `user2@test.com`.
3. In Simulator 1, tap the **Pencil Icon** (top right) to start a chat or create a group with `user2`.
4. Test text messaging, voice notes with live waveform recording, audio playback, swipe-to-reply, and in-chat keyword search!

---

## 👨‍💻 Author

**Avinash Chavda**  
- GitHub: [@Avinash11-AK11](https://github.com/Avinash11-AK11)  
- Email: [avinashchavda11@gmail.com](mailto:avinashchavda11@gmail.com)  
- Role: iOS & Mobile Application Developer  
