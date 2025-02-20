//
//  FilterViewModel.swift
//  EVA
//
//  Created by Kaia Gao on 7/20/24.
//


import Foundation
import SwiftUI
import Alamofire

class FilterViewModel: ObservableObject {
    
    private let model: FilterModel
    
    @Published var showFilteredImg : Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var uploadProgress: Double = 0.0
    @Published var showRollingProgress: Bool = false
    
    @Published var filteredImg: UIImage?
    @Published var va: String = "1.94"
    @Published var cs: String = "1.27"
    @Published var filteredImgName = "null"
    let progressQueue = DispatchQueue(label: "com.alamofire.progressQueue", qos: .utility)
    
    init(_ model: FilterModel) {
        self.model = model
    }
    
    
    func filterImage(_ originalImgData: Data?, imgName: String, mimeType: String, cs: String, va: String, downprogress: Double) {
        if (imgName != "null") {
            
            
            AF.upload(multipartFormData: {
                multiPart in
                multiPart.append(originalImgData!, withName: "src_img",fileName: imgName,mimeType: mimeType)
                multiPart.append(cs.data(using: .utf8)!,withName:"cs")
                multiPart.append(va.data(using: .utf8)!,withName:"va")
                
            },
                      to: "http://54.164.8.50/uploadImg", //http://10.203.47.4:5001
                      method: .post, headers: [
                        "Content-type": "multipart/form-data"
                      ])
            .uploadProgress { progress in
                self.uploadProgress = progress.fractionCompleted
                self.showRollingProgress = true
                print("Upload Progress: \(progress.fractionCompleted)")
            }
            .downloadProgress(queue: progressQueue) { progress in
                
                DispatchQueue.main.async {
                    self.showRollingProgress = false
                    print("Download Progress: \(progress.fractionCompleted)")
                    self.downloadProgress = progress.fractionCompleted
                                }
               
            }
  
            .response { response in
                self.filteredImgName = response.response?.headers["Content-Disposition"]?.split(separator: "=").last.map(String.init) ?? "Unknown"
                self.model.filteredImg = self.filteredImg ?? UIImage()
                self.model.filteredImgName = self.filteredImgName

                
                switch response.result {
                case .success(let responseData):
                    guard let data = responseData, let image = UIImage(data: data) else {
                        return
                    }

                    self.filteredImg = image
                    self.showFilteredImg = true
                    
                case .failure(let error):
                    print("Error in uploading image: \(error.localizedDescription)")
                    //                        completion(nil)
                }
                
                
            }
        }
    }
    
    
    func saveFilteredImage() {
        model.saveFilteredImg()
        self.showFilteredImg = false
    }
}
    
    

