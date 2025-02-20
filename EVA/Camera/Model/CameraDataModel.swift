//
//  CameraDataModel.swift
//  EVA
//
//  Created by Kaia Gao on 7/15/24.
//

import AVFoundation
import SwiftUI
import os.log

final class CameraDataModel: ObservableObject {
    
    let camera = Camera()// represents one of the physical cameras — or capture devices — available to your device.
    let photoCollection = PhotoCollection(smartAlbum: .smartAlbumUserLibrary)
    @Published var viewfinderImage: Image?
    @Published var thumbnailImage: Image?
    
    private var rawFileURL: URL? = nil
    

    
    var isPhotosLoaded = false
    public var imageName = ""
    
    init() {
  
        // Task: A unit of asynchronous work to handle the stream of preview images from the camera
        Task {
            await handleCameraPreviews()
        }
        
        Task {
            await handleCameraPhotos()
        }
    }
    

    func handleCameraPreviews() async {
        // transform the stream of CIImage instances into a stream of Image instances.
        let imageStream = camera.previewStream
            .map { $0.image }
        
        //  for-await loop waits for each image in your transformed imageStream before doing something with it.
        for await image in imageStream {
            Task { @MainActor in   //use the image from the preview stream to update your data model’s viewfinderImage property.
                                   // SwiftUI makes sure that any views using this property get updated when the viewfinderImage value changes.
                viewfinderImage = image
            }
        }
    }
    
    func handleCameraPhotos() async {
        // Each AVCapturePhoto element in the camera’s photoStream may contain several images at different resolutions, as well as other metadata about the image, such as its size and the date and time the image was captured.
        let unpackedPhotoStream = camera.photoStream
            .compactMap { self.unpackPhoto($0) } // unpack photostream ->  returns a PhotoData instance that contains a low-resolution image thumbnail as an Image, the size of the image thumbnail, a high-resolution image as Data, and the size of the high-resolution image.
        
        for await photoData in unpackedPhotoStream {
            Task { @MainActor in
                thumbnailImage = photoData.thumbnailImage // use the thumbnail image in photoData to update your model’s thumbnailImage property
            }
//            debugPrint("photoData is raw ",photoData.rawFileURL!)
            savePhoto(imageData: photoData.imageData,rawURL: photoData.rawFileURL,israw:photoData.israw) // save the image data from photoData as a new photo in photo library
        }
    }
    
    private func unpackPhoto(_ photo: AVCapturePhoto) -> PhotoData? {
        // Access the file data representation of this photo
        guard let imageData = photo.fileDataRepresentation() else {
            print("No photo data to write.")
            return nil
        }
        
        guard let previewCGImage = photo.previewCGImageRepresentation(),
           let metadataOrientation = photo.metadata[String(kCGImagePropertyOrientation)] as? UInt32,
              let cgImageOrientation = CGImagePropertyOrientation(rawValue: metadataOrientation) else { return nil }
        let imageOrientation = Image.Orientation(cgImageOrientation)
        let thumbnailImage = Image(decorative: previewCGImage, scale: 1, orientation: imageOrientation)
        
        let photoDimensions = photo.resolvedSettings.photoDimensions
        let imageSize = (width: Int(photoDimensions.width), height: Int(photoDimensions.height))
        let previewDimensions = photo.resolvedSettings.previewDimensions
        let thumbnailSize = (width: Int(previewDimensions.width), height: Int(previewDimensions.height))
        
        
        if photo.isRawPhoto {
            // Generate a unique URL to write the RAW file.
            rawFileURL = makeUniqueDNGFileURL()
            debugPrint("israwphoto")
            do {
                // Write the RAW (DNG) file data to a URL.
                try imageData.write(to: rawFileURL!)
            } catch {
                fatalError("Couldn't write DNG file to the URL.")
            }
        } else {
            // Store compressed bitmap data.
            debugPrint("BITMAP")
            return PhotoData(thumbnailImage: thumbnailImage, thumbnailSize: thumbnailSize, 
                             imageData: imageData, imageSize: imageSize,rawFileURL:nil, israw: self.camera.israw)
        }

        
        

        
        return PhotoData(thumbnailImage: thumbnailImage, thumbnailSize: thumbnailSize, imageData: imageData, imageSize: imageSize,rawFileURL:rawFileURL,israw: self.camera.israw)
    }

    private func makeUniqueDNGFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        if (self.imageName == ""){
            let fileName = ProcessInfo.processInfo.globallyUniqueString
            return tempDir.appendingPathComponent(fileName).appendingPathExtension("dng")
        }
        else{
            let fileName = self.imageName
            return tempDir.appendingPathComponent(fileName).appendingPathExtension("dng")
        }
        
        
    }

    // creates a task and passes on the real work of saving the photo data to the photoCollection
    func savePhoto(imageData: Data,rawURL:URL?=nil,israw:Bool) {
        Task {
            do {
                try await photoCollection.addImage(imageData,fileURL: rawURL,israw:israw)
                logger.debug("Added image data to photo collection.")
            } catch let error {
                logger.error("Failed to add image to photo collection: \(error.localizedDescription)")
            }
        }
    }
    
    func loadPhotos() async {
        guard !isPhotosLoaded else { return }
        
        let authorized = await PhotoLibrary.checkAuthorization()
        guard authorized else {
            logger.error("Photo library access was not authorized.")
            return
        }
        
        Task {
            do {
                try await self.photoCollection.load()
                await self.loadThumbnail()
            } catch let error {
                logger.error("Failed to load photo collection: \(error.localizedDescription)")
            }
            self.isPhotosLoaded = true
        }
    }
    
    func loadThumbnail() async {
        guard let asset = photoCollection.photoAssets.first  else { return }
        await photoCollection.cache.requestImage(for: asset, targetSize: CGSize(width: 256, height: 256))  { result in
            if let result = result {
                Task { @MainActor in
                    self.thumbnailImage = result.image
                }
            }
        }
    }
}

fileprivate struct PhotoData {
    var thumbnailImage: Image
    var thumbnailSize: (width: Int, height: Int)
    var imageData: Data
    var imageSize: (width: Int, height: Int)
    var rawFileURL: URL? = nil
    var israw: Bool = false
}

fileprivate extension CIImage {
    var image: Image? {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(self, from: self.extent) else { return nil }
        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}

fileprivate extension Image.Orientation {

    init(_ cgImageOrientation: CGImagePropertyOrientation) {
        switch cgImageOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        }
    }
}

fileprivate let logger = Logger(subsystem: "com.kaiagao.EVA", category: "CameraDataModel")

