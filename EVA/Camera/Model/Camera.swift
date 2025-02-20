//
//  Camera.swift
//  EVA
//
//  Created by Kaia Gao on 7/15/24.
//


import AVFoundation
import CoreImage
import UIKit
import os.log




class Camera: NSObject {
    private let captureSession = AVCaptureSession()
    private var isCaptureSessionConfigured = false
    private var deviceInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var sessionQueue: DispatchQueue!
    var maxWidth = Int32(8064)
    var maxHeight = Int32(6048)
    public var israw:Bool = true
    

    private var capturesInProgress: [Int64:AVCapturePhotoCaptureDelegate] = [:] // Keep a set of in-progress capture delegates.
    
    private var allCaptureDevices: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera, .builtInDualCamera, .builtInDualWideCamera, .builtInWideAngleCamera, .builtInDualWideCamera], mediaType: .video, position: .unspecified).devices
    }
    
    private var frontCaptureDevices: [AVCaptureDevice] {
        allCaptureDevices
            .filter { $0.position == .front }
    }
    
    private var backCaptureDevices: [AVCaptureDevice] {
        allCaptureDevices
            .filter { $0.position == .back }
    }
    
    private var captureDevices: [AVCaptureDevice] {
        var devices = [AVCaptureDevice]()
        #if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst))
        devices += allCaptureDevices
        #else
//        if let backDevice = backCaptureDevices.first {
        if let backDevice = AVCaptureDevice.default(.builtInWideAngleCamera,  //.builtInWideAngleCamera, builtInLiDARDepthCamera
                                                for: .video, position: .back) {
            devices += [backDevice]
        }
        if let frontDevice = frontCaptureDevices.first {
            devices += [frontDevice]
        }
        #endif
        return devices
    }
    
    private var availableCaptureDevices: [AVCaptureDevice] {
        captureDevices
            .filter( { $0.isConnected } )
            .filter( { !$0.isSuspended } )
    }
    
    private var captureDevice: AVCaptureDevice? {
        didSet {
            guard let captureDevice = captureDevice else { return }
            logger.debug("Using capture device: \(captureDevice.localizedName)")
            sessionQueue.async {
                self.updateSessionForCaptureDevice(captureDevice)
            }
        }
    }
    
    var isRunning: Bool {
        captureSession.isRunning
    }
    
    var isUsingFrontCaptureDevice: Bool {
        guard let captureDevice = captureDevice else { return false }
        return frontCaptureDevices.contains(captureDevice)
    }
    
    var isUsingBackCaptureDevice: Bool {
        guard let captureDevice = captureDevice else { return false }
        return backCaptureDevices.contains(captureDevice)
    }

    private var addToPhotoStream: ((AVCapturePhoto) -> Void)?
    
    private var addToPreviewStream: ((CIImage) -> Void)?
    
    var isPreviewPaused = false
    
    // receive these preview images as async stream of CIImage objects
    // CIImage: Raw Image data
    // UIImage: data with specified properties
    lazy var previewStream: AsyncStream<CIImage> = {
        AsyncStream { continuation in
            addToPreviewStream = { ciImage in
                if !self.isPreviewPaused {
                    continuation.yield(ciImage)
                }
            }
        }
    }()
    
    lazy var photoStream: AsyncStream<AVCapturePhoto> = {
        AsyncStream { continuation in
            addToPhotoStream = { photo in
                continuation.yield(photo)
            }
        }
    }()
        
    override init() {
        super.init()
        initialize()
    }
    
    private func initialize() {
        sessionQueue = DispatchQueue(label: "session queue")
        
        captureDevice = AVCaptureDevice.default(for: .video)
        
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(updateForDeviceOrientation), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    private func areDoublesEqual(_ a: Double, _ b: Double, tolerance: Double = 1.0e-9) -> Bool {
        return abs(a - b) < 1.0e-9
    }
    
    private func getMaxCameraDimension(_ device: AVCaptureDevice) {
        for format in device.formats {
            let formatDimensions = format.supportedMaxPhotoDimensions
            for dimension in formatDimensions {
//                print("[Camera]: Max format dimensions WxH: \(dimension.width) x \(dimension.height)")

                if (maxWidth < dimension.width) {
                    if (areDoublesEqual(Double(dimension.width)/Double(dimension.height), 4/3)) {
                        maxWidth = dimension.width
                        maxHeight = dimension.height
                    }
          
                }
 
            }
        }
        
//        if (maxWidth < 8064) {
//            lowResolutionWarning = true
//        }
    }
    
    private func configureCaptureSession(completionHandler: (_ success: Bool) -> Void) {
        
        var success = false
        
        self.captureSession.beginConfiguration()
        
        defer {
            self.captureSession.commitConfiguration()
            completionHandler(success)
        }
        
        guard
            let captureDevice = captureDevice,
            let deviceInput = try? AVCaptureDeviceInput(device: captureDevice)
        else {
            logger.error("Failed to obtain video input.")
            return
        }
        
        // Configure the session for photo capture.
        let photoOutput = AVCapturePhotoOutput()
                        
        captureSession.sessionPreset = .photo
        
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))
  
        if captureSession.canAddInput(deviceInput){
            captureSession.addInput(deviceInput)
        } else {
            logger.error("Unable to add device input to capture session.")
            return
        }
        if captureSession.canAddOutput(photoOutput) {
            // Use the Apple ProRAW format when the environment supports it.
            captureSession.addOutput(photoOutput)
            self.getMaxCameraDimension(captureDevice)
            
            photoOutput.isAppleProRAWEnabled = photoOutput.isAppleProRAWSupported && self.israw
            photoOutput.maxPhotoDimensions = .init(width: maxWidth, height: maxHeight)
            photoOutput.maxPhotoQualityPrioritization = .quality
            
        } else {
            logger.error("Unable to add photo output to capture session.")
            return
        }
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }else {
            logger.error("Unable to add video output to capture session.")
            return
        }
        
    

        self.deviceInput = deviceInput
        self.photoOutput = photoOutput
        self.videoOutput = videoOutput
        
        //photoOutput.isHighResolutionCaptureEnabled = true
        
        
        updateVideoOutputConnection()
        
        isCaptureSessionConfigured = true
        
        success = true
    }
    
    private func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            logger.debug("Camera access authorized.")
            return true
        case .notDetermined:
            logger.debug("Camera access not determined.")
            sessionQueue.suspend()
            let status = await AVCaptureDevice.requestAccess(for: .video)
            sessionQueue.resume()
            return status
        case .denied:
            logger.debug("Camera access denied.")
            return false
        case .restricted:
            logger.debug("Camera library access restricted.")
            return false
        @unknown default:
            return false
        }
    }
    
    private func deviceInputFor(device: AVCaptureDevice?) -> AVCaptureDeviceInput? {
        guard let validDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        } catch let error {
            logger.error("Error getting capture device input: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func updateSessionForCaptureDevice(_ captureDevice: AVCaptureDevice) {
        guard isCaptureSessionConfigured else { return }
        
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        for input in captureSession.inputs {
            if let deviceInput = input as? AVCaptureDeviceInput {
                captureSession.removeInput(deviceInput)
            }
        }
        
        if let deviceInput = deviceInputFor(device: captureDevice) {
            if !captureSession.inputs.contains(deviceInput), captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
            }
        }
        
        updateVideoOutputConnection()
    }
    
    private func updateVideoOutputConnection() {
        if let videoOutput = videoOutput, let videoOutputConnection = videoOutput.connection(with: .video) {
            if videoOutputConnection.isVideoMirroringSupported {
                videoOutputConnection.isVideoMirrored = isUsingFrontCaptureDevice
            }
        }
    }
    
    func start() async {
        let authorized = await checkAuthorization()
        guard authorized else {
            logger.error("Camera access was not authorized.")
            return
        }
        
        if isCaptureSessionConfigured {
            if !captureSession.isRunning {
                sessionQueue.async { [self] in
                    self.captureSession.startRunning()
                }
            }
            return
        }
        
        sessionQueue.async { [self] in
            self.configureCaptureSession { success in
                guard success else { return }
                self.captureSession.startRunning()
            }
        }
    }
    
    func stop() {
        guard isCaptureSessionConfigured else { return }
        
        if captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    func switchCaptureDevice() {
        if let captureDevice = captureDevice, let index = availableCaptureDevices.firstIndex(of: captureDevice) {
            let nextIndex = (index + 1) % availableCaptureDevices.count
            self.captureDevice = availableCaptureDevices[nextIndex]
        } else {
            self.captureDevice = AVCaptureDevice.default(for: .video)
        }

    }
    
    func switchRawMode(){
        self.israw = !self.israw
        if self.photoOutput?.isAppleProRAWSupported != nil {
            self.photoOutput!.isAppleProRAWEnabled = self.photoOutput!.isAppleProRAWSupported && self.israw
        }
        else{
            self.photoOutput!.isAppleProRAWEnabled = false
        }

       
    }

    private var deviceOrientation: UIDeviceOrientation {
        var orientation = UIDevice.current.orientation
        if orientation == UIDeviceOrientation.unknown {
            orientation = UIScreen.main.orientation
        }
        return orientation
    }
    
    @objc
    func updateForDeviceOrientation() {
        //TODO: Figure out if we need this for anything.
    }
    
    private func videoOrientationFor(_ deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch deviceOrientation {
        case .portrait: return AVCaptureVideoOrientation.portrait
        case .portraitUpsideDown: return AVCaptureVideoOrientation.portraitUpsideDown
        case .landscapeLeft: return AVCaptureVideoOrientation.landscapeRight
        case .landscapeRight: return AVCaptureVideoOrientation.landscapeLeft
        default: return nil
        }
    }
    
    func takePhoto() {
  
        guard let photoOutput = self.photoOutput else { return }
        debugPrint("take photo",photoOutput.isAppleProRAWEnabled)
        
        if photoOutput.isAppleProRAWEnabled{
            sessionQueue.async {
                let query = photoOutput.isAppleProRAWEnabled ?
                { AVCapturePhotoOutput.isAppleProRAWPixelFormat($0) } :
                { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) }
                // Retrieve the RAW format, favoring the Apple ProRAW format when it's in an enabled state.
                guard let rawFormat =
                        photoOutput.availableRawPhotoPixelFormatTypes.first(where: query) else {
                    fatalError("No RAW format found.")
                }
                
                
                // Capture a RAW format photo, along with a processed format photo.
                let processedFormat = [AVVideoCodecKey: AVVideoCodecType.hevc]
                let photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat,
                                                           processedFormat: processedFormat)
                photoSettings.photoQualityPrioritization = photoOutput.maxPhotoQualityPrioritization
                
                // Select the first available codec type, which is JPEG.
                guard let thumbnailPhotoCodecType =
                    photoSettings.availableRawEmbeddedThumbnailPhotoCodecTypes.first else {
                    // Handle the failure to find an available thumbnail photo codec type.
                    return
   
                }

                photoSettings.maxPhotoDimensions = .init(width: self.maxWidth, height: self.maxHeight)
                
                // Select the maximum photo dimensions as thumbnail dimensions if a full-size thumbnail is desired.
                // The system clamps these dimensions to the photo dimensions if the capture produces a photo with smaller than maximum dimensions.
                let dimensions = photoSettings.maxPhotoDimensions
                if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
                    photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
                    debugPrint(previewPhotoPixelFormatType)
                }
                
                    

                photoSettings.rawEmbeddedThumbnailPhotoFormat = [
                    AVVideoCodecKey: thumbnailPhotoCodecType,
                    AVVideoWidthKey: dimensions.width,
                    AVVideoHeightKey: dimensions.height
                ]
                
//
                // Tell the output to capture the photo.
                photoOutput.capturePhoto(with: photoSettings, delegate: self)
            }
        }
        else{
            sessionQueue.async {
            
                var photoSettings = AVCapturePhotoSettings()

                if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                    photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                }
                
                let isFlashAvailable = self.deviceInput?.device.isFlashAvailable ?? false
                photoSettings.flashMode = isFlashAvailable ? .auto : .off
                photoSettings.photoQualityPrioritization = .quality   //.isHighResolutionPhotoEnabled = true
                if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
                    photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
                }

                
                if let photoOutputVideoConnection = photoOutput.connection(with: .video) {
                    if photoOutputVideoConnection.isVideoOrientationSupported,
                        let videoOrientation = self.videoOrientationFor(self.deviceOrientation) {
                        photoOutputVideoConnection.videoOrientation = videoOrientation
                    }
                }
                
                photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
        
        
        }
    }
}


// monitoring progress and receiving results from a photo capture output
extension Camera: AVCapturePhotoCaptureDelegate {
    
    // receive a callback when photo capture is completed
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        if let error = error {
            logger.error("Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        addToPhotoStream?(photo) // add it into the camera’s photo stream waiting for using.
    }
}

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        
        if connection.isVideoOrientationSupported,
           let videoOrientation = videoOrientationFor(deviceOrientation) {
            connection.videoOrientation = videoOrientation
        }

        addToPreviewStream?(CIImage(cvPixelBuffer: pixelBuffer))
    }
}

fileprivate extension UIScreen {

    var orientation: UIDeviceOrientation {
        let point = coordinateSpace.convert(CGPoint.zero, to: fixedCoordinateSpace)
        if point == CGPoint.zero {
            return .portrait
        } else if point.x != 0 && point.y != 0 {
            return .portraitUpsideDown
        } else if point.x == 0 && point.y != 0 {
            return .landscapeRight //.landscapeLeft
        } else if point.x != 0 && point.y == 0 {
            return .landscapeLeft //.landscapeRight
        } else {
            return .unknown
        }
    }
}



fileprivate let logger = Logger(subsystem: "com.kaiagao.EVA", category: "Camera")


