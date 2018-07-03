//
//  LCAVideoCameraController.swift
//  LippyCards
//
//  Created by Admin on 08.02.18.
//  Copyright © 2018 itworksinua. All rights reserved.
//

import UIKit
import AVFoundation

protocol LCAVideoCameraControllerDelegate: class {
    func drawLipsByPoints(points:[NSValue])
    func removeLips()
    func processCapturedImage(image: UIImage)
}

class LCAVideoCameraController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate {
    var viewConteiner: UIView!
    var session = AVCaptureSession()
    var layer = AVSampleBufferDisplayLayer()
    let sampleQueue = DispatchQueue(label: "com.itworksinua.LippyCards.sampleQueue", attributes: [])
    let faceQueue = DispatchQueue(label: "com.itworksinua.LippyCards.faceQueue", attributes: [])
    var isFrontCamera:Bool = false
    weak var delegate: LCAVideoCameraControllerDelegate?
    var defaultVideoDevice: AVCaptureDevice!
    var needScreenShot:Bool = false
    var rearCamera: AVCaptureDevice?
    var rearCameraInput: AVCaptureDeviceInput?
    var frontCamera: AVCaptureDevice?
    var frontCameraInput: AVCaptureDeviceInput?
    var currentCameraPosition: CameraPosition?
    private let context = CIContext()
    var previewLayer: AVCaptureVideoPreviewLayer?
    var currentMetadata: [AVMetadataObject]
    
    var isSessionPrepared = false
    var isFaceDetected = false
    var scalling = false
    
    override init() {
        currentMetadata = []
        super.init()
    }
    
    public func prepare() {
        if !isSessionPrepared {
            session.sessionPreset = .vga640x480//.hd1280x720
            configureCaptureDevices()
            configureDeviceInputs()
            
            session.beginConfiguration()
            
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: sampleQueue)
            output.alwaysDiscardsLateVideoFrames = true
            
            let metaOutput = AVCaptureMetadataOutput()
            metaOutput.setMetadataObjectsDelegate(self, queue: faceQueue)

            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            if session.canAddOutput(metaOutput) {
                session.addOutput(metaOutput)
            }
            
            session.commitConfiguration()
            
            let settings: [AnyHashable: Any] = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32BGRA)]
            output.videoSettings = settings as! [String : Any]
            
            // availableMetadataObjectTypes change when output is added to session.
            // before it is added, availableMetadataObjectTypes is empty
            if viewConteiner == nil {
                metaOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.face]
            } else {
                metaOutput.metadataObjectTypes = metaOutput.availableMetadataObjectTypes
            }
            
            for con in output.connections {
                fixConnection(con)
            }
        }
        
        session.startRunning()
    }
    
    public func startVideo(view: UIView) {
        if isSessionPrepared {
            return
        }
        if !session.isRunning {
            print(CameraControllerError.captureSessionIsMissing.localizedDescription)
            return
        }
        
//        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
//        self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
//        self.previewLayer?.connection?.videoOrientation = .portrait
//        self.previewLayer?.connection?.preferredVideoStabilizationMode = .off
//        view.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
//        view.layer.insertSublayer(self.previewLayer!, at: 0)
//        self.previewLayer?.frame = view.frame
        
        layer.frame = view.bounds
        view.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        view.layer.addSublayer(layer)
        view.layoutIfNeeded()
        
        viewConteiner = view
        
        layer.frame = CGRect(x: 0, y: 0, width: 480, height: 640)
        viewConteiner.frame = layer.frame
        
        isSessionPrepared = true
    }
    
    func configureCaptureDevices() {
        let sessionCapture = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
        let cameras = sessionCapture.devices.flatMap({ $0 })
        guard !cameras.isEmpty else {
            print(CameraControllerError.noCamerasAvailable.localizedDescription)
            return
        }
        
        for camera in cameras {
            if camera.position == .front {
                self.frontCamera = camera
                    try! camera.lockForConfiguration()
                let format = camera.activeFormat
                let epsilon = 0.00000001
                let desiredFrameRate = 2.00
                for range in format.videoSupportedFrameRateRanges {
                    
                    if range.minFrameRate <= (desiredFrameRate + epsilon) &&
                        range.maxFrameRate >= (desiredFrameRate - epsilon) {
                        
                        camera.activeVideoMaxFrameDuration =
                            CMTime(value: 1, timescale: CMTimeScale(range.minFrameRate), flags: CMTimeFlags.valid, epoch: 0)
                        camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(range.minFrameRate), flags: CMTimeFlags.valid, epoch: 0)
                        break
                    }
                }

                    camera.unlockForConfiguration()
            }
            if camera.position == .back {
                self.rearCamera = camera
                do {
                    try camera.lockForConfiguration()
                } catch {
                    print("Something went wrong with Back camera")
                }
//                camera.whiteBalanceMode = .autoWhiteBalance
                camera.focusMode = .continuousAutoFocus
                camera.unlockForConfiguration()
            }
        }
    }
    
    func configureDeviceInputs() {
        if let frontCamera = self.frontCamera {
            do {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            } catch {
                print("Something went wrong with Front camera")
            }
            if session.canAddInput(self.frontCameraInput!) {
                session.addInput(self.frontCameraInput!)
                self.defaultVideoDevice = frontCamera
            } else {
                print(CameraControllerError.inputsAreInvalid.localizedDescription)
            }
            self.currentCameraPosition = .front
        } else if let rearCamera = self.rearCamera {
            do {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            } catch {
                print("Something went wrong with Back camera")
            }
            if session.canAddInput(self.rearCameraInput!) {
                session.addInput(self.rearCameraInput!)
                self.defaultVideoDevice = rearCamera
            }
            self.currentCameraPosition = .rear
        } else {
            print(CameraControllerError.noCamerasAvailable.localizedDescription)
        }
    }
    
    public func stopVideo() {
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    public func takePhoto() {
        needScreenShot = true
    }
    
    public func makeFocus(singleTap: UITapGestureRecognizer) {
        #if !((arch(i386) || arch(x86_64)) && os(iOS))
            do {
                try defaultVideoDevice.lockForConfiguration()
                let focusPoint = singleTap.location(in: viewConteiner)
                if defaultVideoDevice.isFocusPointOfInterestSupported && defaultVideoDevice.isFocusModeSupported(AVCaptureDevice.FocusMode.autoFocus) {
                    defaultVideoDevice.focusPointOfInterest = focusPoint
                    defaultVideoDevice.focusMode = AVCaptureDevice.FocusMode.autoFocus
                }
                defaultVideoDevice.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        #endif
    }
    
    func switchCameras() {
        DispatchQueue.main.async {
            self.currentMetadata = []
        }
        if !session.isRunning {
            print(CameraControllerError.captureSessionIsMissing.localizedDescription)
            return
        }
        
        session.beginConfiguration()
        
        func switchToFrontCamera() {
            if self.frontCameraInput == nil {
                do {
                    self.frontCameraInput = try AVCaptureDeviceInput(device: self.frontCamera!)
                } catch {
                    print("Something went wrong with Back camera")
                }
            }
            session.removeInput(self.rearCameraInput!)
            if self.frontCameraInput != nil && session.canAddInput(self.frontCameraInput!) {
                session.addInput(self.frontCameraInput!)
                self.currentCameraPosition = .front
                self.defaultVideoDevice = self.frontCamera
            } else {
                print(CameraControllerError.invalidOperation.localizedDescription)
            }
        }
        
        func switchToRearCamera() {
            if self.rearCameraInput == nil {
                do {
                    self.rearCameraInput = try AVCaptureDeviceInput(device: self.rearCamera!)
                } catch {
                    print("Something went wrong with Back camera")
                }
            }
            session.removeInput(self.frontCameraInput!)
            if self.rearCameraInput != nil && session.canAddInput(self.rearCameraInput!) {
                session.addInput(self.rearCameraInput!)
                self.currentCameraPosition = .rear
            } else {
                print(CameraControllerError.invalidOperation.localizedDescription)
            }
        }

        switch currentCameraPosition {
        case .front?:
            switchToRearCamera()
            break
        case .rear?:
            switchToFrontCamera()
            break
        case .none:
            break
        }
        
        for output in session.outputs {
            for con in output.connections {
                fixConnection(con)
            }
        }
        session.commitConfiguration()
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.async {
            if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
//                if self.scalling == false {
                    let imageSize = CVImageBufferGetDisplaySize(imageBuffer)
                    self.layer.frame = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
                    self.viewConteiner.frame = self.layer.frame
                    self.scalling = true
//                }
            }
//        }
        if !self.currentMetadata.isEmpty && self.isFaceDetected {
            let boundsArray = self.currentMetadata
            .flatMap { $0 as? AVMetadataFaceObject }
            .map { (faceObject) -> NSValue in
                let convertedObject = output.transformedMetadataObject(for: faceObject, connection: connection)
                if convertedObject == nil {
                    return NSValue(cgRect: CGRect(x:0, y:0, width:0, height:0))
                }
                return NSValue(cgRect: convertedObject!.bounds)
            }
            let points:[NSValue] = (DlibWrapper.sharedInstance().doWork(on: sampleBuffer, inRects: boundsArray, parentView: nil) as! [NSValue])
            self.delegate?.drawLipsByPoints(points: points)
        } else {
            self.isFaceDetected = false
            self.delegate?.removeLips()
        }
        if self.needScreenShot {
            guard let outputImage = self.getImageFromSampleBuffer(sampleBuffer: sampleBuffer) else {
                return
            }
            self.delegate?.processCapturedImage(image: outputImage)
            self.needScreenShot = false
        }
            self.layer.enqueue(sampleBuffer)
        }
    }
    
    // MARK: AVCaptureMetadataOutputObjectsDelegate
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        isFaceDetected = true
        currentMetadata = metadataObjects
    }
    
    func getImageFromSampleBuffer(sampleBuffer: CMSampleBuffer) ->UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    func fixConnection(_ connection: AVCaptureConnection) {
//        DispatchQueue.main.async {
            //            if let _ = self.previewLayer?.connection {
            //                if connection.videoOrientation != self.previewLayer?.connection?.videoOrientation {
            //                    connection.videoOrientation = (self.previewLayer?.connection?.videoOrientation)!
            //                }
            //            }
        if connection.isVideoMirroringSupported == false || connection.isVideoOrientationSupported == false {
            return
        }
            if connection.preferredVideoStabilizationMode != .auto {
                connection.preferredVideoStabilizationMode = .auto
            }
            if connection.videoOrientation != .portrait {
                if let _ = self.previewLayer?.connection {
                    if connection.videoOrientation != self.previewLayer?.connection?.videoOrientation {
                        connection.videoOrientation = (self.previewLayer?.connection?.videoOrientation)!
                    }
                }
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirrored != (self.currentCameraPosition == .front) {
                connection.isVideoMirrored = self.currentCameraPosition == .front
            }
        }
//    }
}

extension LCAVideoCameraController {
    enum CameraControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    public enum CameraPosition {
        case front
        case rear
    }
}
