//
//  FilterModel.swift
//  EVA
//
//  Created by Kaia Gao on 7/20/24.
//


import Foundation
import UIKit
import Photos
import Accelerate
import Foundation

class FilterModel: ObservableObject {
    
    var filteredImg: UIImage = UIImage()
    var va: Float = 0
    var cs: Float = 0
    var imgData: Data?
    var filteredImgName: String = "null"
    
    
    func saveFilteredImg() {
        
            print("Saving Filtered Image...")
        
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(self.filteredImgName) //.appendingPathExtension("png")
            print(fileURL)
            
            do {
                //            try imgData?.write(to: fileURL)
                try self.filteredImg.heicData()?.write(to: fileURL,options: .atomic)
            } catch {
                fatalError("Couldn't write filtered file to the URL.")
            }
            
        // Check photo library access
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                
                // Don't continue unless the user granted access.
                guard status == .authorized else {
                    print("Need authorization to access the photo library")
                    return
                }
                
                PHPhotoLibrary.shared().performChanges {
                    
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    
                    // Save the RAW (DNG) file as the main resource for the Photos asset.
                    let options = PHAssetResourceCreationOptions()
                    options.shouldMoveFile = true
                    creationRequest.addResource(with: .photo,
                                                fileURL: fileURL,
                                                options: options)
                } completionHandler: { success, error in
                    // Process the Photos library error.
                }
                // Save the image to the photo library
//                UIImageWriteToSavedPhotosAlbum(filteredImg, self, #selector(filteredImg(_:didFinishSavingWithError:contextInfo:)), nil)
            }
            print("Saving Filtered Image DONE")
        }
        
        
        
    }

