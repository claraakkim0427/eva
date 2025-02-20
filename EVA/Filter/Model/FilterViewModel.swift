//
//  FilterViewModel.swift
//  EVA
//
//  Created by Kaia Gao on 7/20/24.
//

import Foundation
import SwiftUI

class FilterViewModel: NSObject, ObservableObject, URLSessionTaskDelegate {
    
    private let model: FilterModel
    
    @Published var showFilteredImg: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var uploadProgress: Double = 0.0
    @Published var showRollingProgress: Bool = false
    @Published var filteredImg: UIImage?
    @Published var va: String = "1.94"
    @Published var cs: String = "1.27"
    @Published var filteredImgName = "null"
    
    private var timer: Timer?
    
    init(_ model: FilterModel) {
        self.model = model
    }
    
    // MARK: - URLSession Configuration for Background Upload
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.eva.upload")
        config.isDiscretionary = false  // Ensure upload runs even on low battery
        config.sessionSendsLaunchEvents = true  // Allows app to resume on upload completion
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    // MARK: - Upload Image
    func filterImage(_ originalImgData: Data?, imgName: String, mimeType: String, cs: String, va: String) {
        guard let originalImgData = originalImgData, imgName != "null" else { return }

        let url = URL(string: "http://54.164.8.50/uploadImg")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = createMultipartFormData(imageData: originalImgData, imageName: imgName, mimeType: mimeType, cs: cs, va: va, boundary: boundary)
        request.httpBody = body

        let uploadTask = backgroundSession.uploadTask(with: request, from: body)
        uploadTask.resume()
        
        print("Background upload started for \(imgName)")
    }
    
    // MARK: - Create Multipart Form Data
    private func createMultipartFormData(imageData: Data, imageName: String, mimeType: String, cs: String, va: String, boundary: String) -> Data {
        var body = Data()
        
        let boundaryPrefix = "--\(boundary)\r\n"
        
        // Append image data
        body.append(boundaryPrefix.data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"src_img\"; filename=\"\(imageName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Append cs parameter
        body.append(boundaryPrefix.data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"cs\"\r\n\r\n".data(using: .utf8)!)
        body.append(cs.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Append va parameter
        body.append(boundaryPrefix.data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"va\"\r\n\r\n".data(using: .utf8)!)
        body.append(va.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    // MARK: - Background Upload Completion Handling
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("Upload failed: \(error.localizedDescription)")
        } else {
            print("Upload completed successfully.")
            DispatchQueue.main.async {
                self.startPollingStatus(imageId: "1", userId: "eva1234")
            }
        }
    }
    
    // MARK: - Poll API for Status Every 5 Seconds
    func startPollingStatus(imageId: String, userId: String) {
        timer?.invalidate()  // Stop any existing timer
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
            self.checkImageStatus(imageId: imageId, userId: userId)
        }
    }

    // MARK: - Check Image Processing Status
    func checkImageStatus(imageId: String, userId: String) {
        let url = URL(string: "http://127.0.0.1:8000/api/status/\(imageId)/\(userId)")!
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Error checking status:", error ?? "Unknown error")
                return
            }

            if let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = jsonResponse["status"] as? String {
                
                DispatchQueue.main.async {
                    if status == "Processed", let processedImageUrl = jsonResponse["processed_image_url"] as? String {
                        self.timer?.invalidate()
                        print("Image processed! URL: \(processedImageUrl)")
                        self.loadFilteredImage(from: processedImageUrl)
                    } else {
                        print("Processing... Status: \(status)")
                    }
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Load Processed Image
    func loadFilteredImage(from url: String) {
        guard let imageUrl = URL(string: "http://127.0.0.1:8000\(url)") else { return }

        let task = URLSession.shared.dataTask(with: imageUrl) { data, _, error in
            guard let data = data, error == nil else {
                print("Error loading processed image:", error ?? "Unknown error")
                return
            }
            
            if let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.filteredImg = image
                    self.showFilteredImg = true
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Save Image
    func saveFilteredImage() {
        model.saveFilteredImg()
        self.showFilteredImg = false
    }
}
