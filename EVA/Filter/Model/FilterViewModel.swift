//
//  FilterViewModel.swift
//  EVA
//
//  Created by Kaia Gao on 7/20/24.
//

import Foundation
import SwiftUI
import Alamofire

// MARK: - Decodable Struct for API Response
struct ImageStatusResponse: Decodable {
    let status: String
    let processed_image_url: String?
}

class FilterViewModel: ObservableObject {
    
    private let model: FilterModel
    
    @Published var showFilteredImg: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var uploadProgress: Double = 0.0
    @Published var showRollingProgress: Bool = false
    
    @Published var filteredImg: UIImage?
    @Published var va: String = "1.94"
    @Published var cs: String = "1.27"
    @Published var filteredImgName = "null"
    @Published var status: String = "Not started"
    
    private var statusTimer: Timer?
    
    let progressQueue = DispatchQueue(label: "com.alamofire.progressQueue", qos: .utility)
    
    init(_ model: FilterModel) {
        self.model = model
    }
    
    // MARK: - Upload Image & Start Polling for Status
    func filterImage(_ originalImgData: Data?, imgName: String, mimeType: String, cs: String, va: String) {
        guard let imageData = originalImgData else {
            print("Error: No image data found.")
            return
        }
        
        AF.upload(multipartFormData: { multiPart in
            multiPart.append(imageData, withName: "src_img", fileName: imgName, mimeType: mimeType)
            multiPart.append(cs.data(using: .utf8)!, withName: "cs")
            multiPart.append(va.data(using: .utf8)!, withName: "va")
        },
        to: "http://54.164.8.50/uploadImg",
        method: .post,
        headers: ["Content-Type": "multipart/form-data"])
        .uploadProgress { progress in
            DispatchQueue.main.async {
                self.uploadProgress = progress.fractionCompleted
                self.showRollingProgress = true
                print("Upload Progress: \(progress.fractionCompleted)")
            }
        }
        .response { response in
            guard let headers = response.response?.headers,
                  let disposition = headers["Content-Disposition"],
                  let filename = disposition.split(separator: "=").last.map(String.init) else {
                print("Error retrieving filename from response headers.")
                return
            }

            self.filteredImgName = filename
            self.model.filteredImgName = self.filteredImgName
            print("Uploaded image: \(self.filteredImgName)")

            // Start polling for processing status
            self.startPollingStatus(imageId: "1", userId: "eva1234")
        }
    }
    
    // MARK: - Automatic Status Polling
    func startPollingStatus(imageId: String, userId: String) {
        statusTimer?.invalidate() // Stop any existing timer
        
        // Start a new timer that checks status every 5 seconds
        statusTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkImageStatus(imageId: imageId, userId: userId)
        }
    }
    
    // MARK: - Check Image Processing Status
    func checkImageStatus(imageId: String, userId: String) {
        let url = "http://127.0.0.1:8000/api/status/\(imageId)/\(userId)"

        AF.request(url).responseDecodable(of: ImageStatusResponse.self) { response in
            switch response.result {
            case .success(let jsonResponse):
                DispatchQueue.main.async {
                    self.status = jsonResponse.status
                    print("Status: \(jsonResponse.status)")

                    if jsonResponse.status == "Processed", let processedImageUrl = jsonResponse.processed_image_url {
                        self.loadProcessedImage(from: processedImageUrl)
                        self.statusTimer?.invalidate()  // Stop polling once processed
                    }
                }
            case .failure(let error):
                print("Error checking status: \(error)")
            }
        }
    }
    
    // MARK: - Load Processed Image
    func loadProcessedImage(from urlString: String) {
        guard let url = URL(string: "http://127.0.0.1:8000\(urlString)") else {
            print("Invalid processed image URL.")
            return
        }

        AF.download(url).responseData { response in
            guard let data = response.value, let image = UIImage(data: data) else {
                print("Failed to load processed image.")
                return
            }

            DispatchQueue.main.async {
                self.filteredImg = image
                self.showFilteredImg = true
                print("Loaded processed image successfully.")
            }
        }
    }
    
    // MARK: - Save Filtered Image
    func saveFilteredImage() {
        model.saveFilteredImg()
        self.showFilteredImg = false
    }
}
