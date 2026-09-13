//
//  AudioManager.swift
//  PeachChat
//
//  Created by Avinash Chavda.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

class AudioManager: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    static let shared = AudioManager()
    
    // Recording State
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var waveformSamples: [CGFloat] = Array(repeating: 0.2, count: 20)
    
    // Playback State
    @Published var playingMessageId: String? = nil
    @Published var isPlaying: Bool = false
    @Published var playbackProgress: Double = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var playbackTimer: Timer?
    private var currentRecordingUrl: URL?
    
    override init() {
        super.init()
    }
    
    // MARK: - Permission
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }
    
    // MARK: - Recording
    
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileUrl = tempDir.appendingPathComponent("peach_voice_\(UUID().uuidString).m4a")
        currentRecordingUrl = fileUrl
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileUrl, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            recordingDuration = 0
            waveformSamples = Array(repeating: 0.15, count: 20)
            
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0)
                // Normalize power from (-60dB ... 0dB) to (0.1 ... 1.0)
                let normalized = max(0.1, CGFloat((power + 60) / 60))
                
                self.recordingDuration += 0.1
                self.waveformSamples.removeFirst()
                self.waveformSamples.append(normalized)
            }
        } catch {
            print("Failed to start audio recorder: \(error)")
        }
    }
    
    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        guard isRecording, let recorder = audioRecorder else { return nil }
        let duration = recordingDuration
        recorder.stop()
        isRecording = false
        
        guard let url = currentRecordingUrl else { return nil }
        return (url, duration)
    }
    
    func cancelRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        isRecording = false
        
        if let url = currentRecordingUrl {
            try? FileManager.default.removeItem(at: url)
        }
        currentRecordingUrl = nil
    }
    
    // MARK: - Playback
    
    func playAudio(from urlString: String, messageId: String) {
        if playingMessageId == messageId && isPlaying {
            pausePlayback()
            return
        }
        
        stopPlayback()
        
        guard let url = URL(string: urlString) else { return }
        
        // If it's a remote URL, download data or stream
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try Data(contentsOf: url)
                DispatchQueue.main.async {
                    do {
                        let session = AVAudioSession.sharedInstance()
                        try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
                        try session.setActive(true)
                        
                        self.audioPlayer = try AVAudioPlayer(data: data)
                        self.audioPlayer?.delegate = self
                        self.audioPlayer?.play()
                        
                        self.playingMessageId = messageId
                        self.isPlaying = true
                        
                        self.playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                            guard let self = self, let player = self.audioPlayer else { return }
                            if player.duration > 0 {
                                self.playbackProgress = player.currentTime / player.duration
                            }
                        }
                    } catch {
                        print("Audio playback init error: \(error)")
                    }
                }
            } catch {
                print("Failed to load audio data from URL: \(error)")
            }
        }
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playingMessageId = nil
        playbackProgress = 0.0
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopPlayback()
    }
}
