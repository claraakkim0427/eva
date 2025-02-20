//
//  APIModel.swift
//  EVA
//
//  Created by Kaia Gao on 7/15/24.
//

import Foundation
import SwiftUI

struct ImagewFilter: Decodable {
    var _id: String = "0"
    var filterId: String = "0"
    var Date: String = "0"
}

struct ReturnInfo: Decodable {
    var filteredImg: Array<Float>
}

class APIModel: NSObject, ObservableObject, URLSessionTaskDelegate {
    @Published var imageData = ImagewFilter()
    static let functions = APIModel()

    // MARK: Background URLSession Configuration
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.eva.upload")
        config.isDiscretionary = false  // Ensures upload runs even on low battery
        config.sessionSendsLaunchEvents = true  // Allows the app to resume after closure
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // MARK: Upload Image Using Background Task
    func uploadImage(imgType: String, imgData: UIImage, imageName: String, completion: @escaping (String?) -> Void) {
        guard let imageData = imgData.jpegData(compressionQuality: 0.8) else {
            print("Error: Could not convert image to data.")
            completion(nil)
            return
        }

        let url = URL(string: "http://127.0.0.1:8000/api/upload/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = "BOUNDARY_STRING"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = createMultipartFormData(imageData: imageData, imageName: imageName, boundary: boundary)

        let uploadTask = backgroundSession.uploadTask(with: request, from: body)
        uploadTask.resume()

        print("Background upload started for \(imageName)")

        // Completion handler to return the task ID for tracking
        completion("Task Started")
    }

    // MARK: Create Multipart Form Data
    private func createMultipartFormData(imageData: Data, imageName: String, boundary: String) -> Data {
        var body = Data()

        let boundaryPrefix = "--\(boundary)\r\n"
        body.append(boundaryPrefix.data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(imageName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }

    // MARK: Background Upload Completion Handling
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("Upload failed: \(error.localizedDescription)")
        } else {
            print("Upload completed successfully.")
        }
    }

    // MARK: Check Image Processing Status
    func checkImageStatus(imageId: String, userId: String, completion: @escaping (String?, String?) -> Void) {
        let url = URL(string: "http://127.0.0.1:8000/api/status/\(imageId)/\(userId)")!

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Error checking status:", error ?? "Unknown error")
                completion(nil, nil)
                return
            }

            if let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = jsonResponse["status"] as? String {

                let processedImageUrl = jsonResponse["processed_image_url"] as? String
                completion(status, processedImageUrl)
            } else {
                completion(nil, nil)
            }
        }
        task.resume()
    }

    // MARK: Fetch Image Processing Data
    func fetchData() async {
        guard let url = URL(string: "http://127.0.0.1:8000/api/photo") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let fetchedData = try JSONDecoder().decode([ImagewFilter].self, from: data)
            DispatchQueue.main.async {
                self.imageData = fetchedData[1]
            }
        } catch {
            print("Error fetching data: \(error)")
        }
    }
}
