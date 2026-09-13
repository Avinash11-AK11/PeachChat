//
//  CloudinaryManager.swift
//  ChatApp-main
//
//  Created for PeachChat Cloudinary Media Integration.
//

import UIKit

class CloudinaryManager {
    static let shared = CloudinaryManager()
    
    // Cloudinary Credentials & Config
    var cloudName: String = "dqp6ow5n3" 
    var apiKey: String = "819873292399778"
    // An unsigned upload preset created in Cloudinary Console > Settings > Upload > Upload Presets
    var uploadPreset: String = "peach_chat_preset"
    
    private init() {}
    
    /// Uploads a UIImage to Cloudinary using direct unsigned REST API
    func uploadImage(_ image: UIImage, folder: String = "chat_images", completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "CloudinaryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to compress image to JPEG."])))
            return
        }
        
        guard !cloudName.isEmpty else {
            completion(.failure(NSError(domain: "CloudinaryManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cloudinary cloudName is not configured."])))
            return
        }
        
        let urlString = "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "CloudinaryManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid Cloudinary endpoint URL."])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add upload_preset
        if !uploadPreset.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(uploadPreset)\r\n".data(using: .utf8)!)
        }
        
        // Add api_key
        if !apiKey.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"api_key\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(apiKey)\r\n".data(using: .utf8)!)
        }
        
        // Add folder
        if !folder.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"folder\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(folder)\r\n".data(using: .utf8)!)
        }
        
        // Add file
        let filename = "\(UUID().uuidString).jpg"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "CloudinaryManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "Empty response from Cloudinary."])))
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let secureUrl = json["secure_url"] as? String {
                        DispatchQueue.main.async {
                            completion(.success(secureUrl))
                        }
                    } else if let errorDict = json["error"] as? [String: Any],
                              let msg = errorDict["message"] as? String {
                        DispatchQueue.main.async {
                            completion(.failure(NSError(domain: "CloudinaryManager", code: -5, userInfo: [NSLocalizedDescriptionKey: "Cloudinary: \(msg)"])))
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(NSError(domain: "CloudinaryManager", code: -6, userInfo: [NSLocalizedDescriptionKey: "Unexpected Cloudinary response format."])))
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// Modern async/await image upload to Cloudinary
    func uploadImageAsync(_ image: UIImage, folder: String = "chat_images") async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            uploadImage(image, folder: folder) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
