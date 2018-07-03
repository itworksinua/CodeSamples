//
//  LCAPhotoFaceLandmarkDetector.swift
//  LippyCards
//
//  Created by Admin on 28.01.18.
//  Copyright © 2018 itworksinua. All rights reserved.
//

import UIKit
import Vision

class LCAPhotoFaceLandmarkDetector: NSObject {
    public var image: UIImage!
    var face: VNFaceObservation!
    var _imgPhoto: UIImageView!
    public var imgPhoto: UIImageView! {
        get {
            return _imgPhoto
        }
        set(newValue) {
            image = newValue.image
            _imgPhoto = newValue
        }
    }
    
    public func setupNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.addFaceLandmarksToImage), name: NSNotification.Name(rawValue: "LCADataSourceMakeupChanged"), object: nil)
    }
    
    public func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
    
    public func process() {
        var orientation:Int32 = 0
        
        // detect image orientation, we need it to be accurate for the face detection to work
        switch image.imageOrientation {
        case .up:
            orientation = 1
        case .right:
            orientation = 6
        case .down:
            orientation = 3
        case .left:
            orientation = 8
        default:
            orientation = 1
        }
        
        // vision
        let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: self.handleFaceFeatures)
        let requestHandler = VNImageRequestHandler(cgImage: image.cgImage!, orientation: CGImagePropertyOrientation(rawValue: UInt32(orientation))! ,options: [:])
        do {
            try requestHandler.perform([faceLandmarksRequest])
        } catch {
            print(error)
        }
    }
    
    func handleFaceFeatures(request: VNRequest, errror: Error?) {
        guard let observations = request.results as? [VNFaceObservation] else {
            fatalError("unexpected result type!")
        }
        
        for face in observations {
            self.face = face
            addFaceLandmarksToImage()
        }
    }
    
    @objc func addFaceLandmarksToImage() {
        if (face == nil) {
            return
        }
        UIGraphicsBeginImageContextWithOptions(image.size, true, 0.0)
        let context = UIGraphicsGetCurrentContext()
        
        // draw the image
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        
        context?.translateBy(x: 0, y: image.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        // draw the face rect
        let w = face.boundingBox.size.width * image.size.width
        let h = face.boundingBox.size.height * image.size.height
        let x = face.boundingBox.origin.x * image.size.width
        let y = face.boundingBox.origin.y * image.size.height
        
        let bezierPath = UIBezierPath()
        
        // outer lips
        var pointsOuter:[NSValue] = []
        context?.saveGState()
        if let landmark = face.landmarks?.outerLips {
            for i in 0...landmark.pointCount - 1 { // last point is 0,0
                let point = landmark.normalizedPoints[i]
                pointsOuter.append(NSValue(cgPoint: point))
            }
        }
        
        var pointsInner:[NSValue] = []
        context?.saveGState()
        if let landmark = face.landmarks?.innerLips {
            for i in 0...landmark.pointCount - 1 { // last point is 0,0
                let point = landmark.normalizedPoints[i]
                pointsInner.append(NSValue(cgPoint: point))
            }
        }
        
        let topLipheight = pointsInner[4].cgPointValue.y - pointsInner[1].cgPointValue.y
        let mouthHeight = pointsInner[1].cgPointValue.y - pointsOuter[2].cgPointValue.y
        if mouthHeight / topLipheight > 2 {
            let topOuterMarks = [pointsOuter[9], pointsOuter[0], pointsOuter[1], pointsOuter[2], pointsOuter[3], pointsOuter[4], pointsOuter[5]]
            let splineTopOuter = SAMCubicSpline(points: topOuterMarks)
            
            var topOuterHeavyMarks:[NSValue] = []
            for i in 0...topOuterMarks.count - 2 {
                let pointStart: CGPoint = topOuterMarks[i] as! CGPoint
                let pointEnd: CGPoint = topOuterMarks[i+1] as! CGPoint
                let del = (pointEnd.x - pointStart.x) / 5
                topOuterHeavyMarks.append(NSValue(cgPoint:pointStart))
                for j in 1...4 {
                    let x = pointStart.x + del * CGFloat(j)
                    let y = splineTopOuter?.interpolate(x)
                    topOuterHeavyMarks.append(NSValue(cgPoint: CGPoint(x: x, y: y!)))
                }
            }
            topOuterHeavyMarks.append(topOuterMarks.last!)
            
            
            let bottomOuterMarks = [pointsOuter[9], pointsOuter[8], pointsOuter[7], pointsOuter[6], pointsOuter[5]]
            let splineBottomOuter = SAMCubicSpline(points: bottomOuterMarks)
            
            var bottomOuterHeavyMarks:[NSValue] = []
            for i in 0...bottomOuterMarks.count - 2 {
                let pointStart: CGPoint = bottomOuterMarks[i] as! CGPoint
                let pointEnd: CGPoint = bottomOuterMarks[i+1] as! CGPoint
                let del = (pointEnd.x - pointStart.x) / 5
                bottomOuterHeavyMarks.append(NSValue(cgPoint:pointStart))
                for j in 1...4 {
                    let x = pointStart.x + del * CGFloat(j)
                    let y = splineBottomOuter?.interpolate(x)
                    bottomOuterHeavyMarks.append(NSValue(cgPoint: CGPoint(x: x, y: y!)))
                }
            }
            bottomOuterHeavyMarks.append(bottomOuterMarks.last!)
            
            
            var lip = bottomOuterHeavyMarks
            for i in stride(from: topOuterHeavyMarks.count - 1, to: 0, by: -1) {
                lip.append(topOuterHeavyMarks[i])
            }
            lip.append(bottomOuterHeavyMarks.first!)
            
            for i in 0...lip.count - 1 {
                let point: CGPoint = lip[i] as! CGPoint
                if i == 0 {
                    context?.move(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                } else {
                    context?.addLine(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                }
            }
        } else {
            let topOuterMarks = [pointsOuter[9], pointsOuter[0], pointsOuter[1], pointsOuter[2], pointsOuter[3], pointsOuter[4], pointsOuter[5]]
            let splineTopOuter = SAMCubicSpline(points: topOuterMarks)
            
            var topOuterHeavyMarks:[NSValue] = []
            for i in 0...topOuterMarks.count - 2 {
                let pointStart: CGPoint = topOuterMarks[i] as! CGPoint
                let pointEnd: CGPoint = topOuterMarks[i+1] as! CGPoint
                let del = (pointEnd.x - pointStart.x) / 5
                topOuterHeavyMarks.append(NSValue(cgPoint:pointStart))
                for j in 1...4 {
                    let x = pointStart.x + del * CGFloat(j)
                    let y = splineTopOuter?.interpolate(x)
                    topOuterHeavyMarks.append(NSValue(cgPoint: CGPoint(x: x, y: y!)))
                }
            }
            topOuterHeavyMarks.append(topOuterMarks.last!)
            
            let topInerMarks = [pointsOuter[9], pointsInner[0], pointsInner[1], pointsInner[2], pointsOuter[5], pointsOuter[9]]
            let splineTopIner = SAMCubicSpline(points: topInerMarks)
            
            var topInerHeavyMarks:[NSValue] = []
            for i in 0...topInerMarks.count - 2 {
                let pointStart: CGPoint = topInerMarks[i] as! CGPoint
                let pointEnd: CGPoint = topInerMarks[i+1] as! CGPoint
                let del = (pointEnd.x - pointStart.x) / 5
                topInerHeavyMarks.append(NSValue(cgPoint:pointStart))
                for j in 1...4 {
                    let x = pointStart.x + del * CGFloat(j)
                    let y = splineTopIner?.interpolate(x)
                    topInerHeavyMarks.append(NSValue(cgPoint: CGPoint(x: x, y: y!)))
                }
            }
            topInerHeavyMarks.append(topInerMarks.last!)

            
            let bottomOuterMarks = [pointsOuter[9], pointsOuter[8], pointsOuter[7], pointsOuter[6], pointsOuter[5]]
            let splineBottomOuter = SAMCubicSpline(points: bottomOuterMarks)
            
            var bottomOuterHeavyMarks:[NSValue] = []
            for i in 0...bottomOuterMarks.count - 2 {
                let pointStart: CGPoint = bottomOuterMarks[i] as! CGPoint
                let pointEnd: CGPoint = bottomOuterMarks[i+1] as! CGPoint
                let del = (pointEnd.x - pointStart.x) / 5
                bottomOuterHeavyMarks.append(NSValue(cgPoint:pointStart))
                for j in 1...4 {
                    let x = pointStart.x + del * CGFloat(j)
                    let y = splineBottomOuter?.interpolate(x)
                    bottomOuterHeavyMarks.append(NSValue(cgPoint: CGPoint(x: x, y: y!)))
                }
            }
            bottomOuterHeavyMarks.append(bottomOuterMarks.last!)
            
            let bottomInerMarks = [pointsOuter[9], pointsInner[5], pointsInner[4], pointsInner[3], pointsOuter[5]]
            let splineBottomIner = SAMCubicSpline(points: bottomInerMarks)
            
            var bottomInerHeavyMarks:[NSValue] = []
            for i in 0...bottomInerMarks.count - 2 {
                let pointStart: CGPoint = bottomInerMarks[i] as! CGPoint
                let pointEnd: CGPoint = bottomInerMarks[i+1] as! CGPoint
                let del = (pointEnd.x - pointStart.x) / 5
                bottomInerHeavyMarks.append(NSValue(cgPoint:pointStart))
                for j in 1...4 {
                    let x = pointStart.x + del * CGFloat(j)
                    let y = splineBottomIner?.interpolate(x)
                    bottomInerHeavyMarks.append(NSValue(cgPoint: CGPoint(x: x, y: y!)))
                }
            }
            bottomInerHeavyMarks.append(bottomInerMarks.last!)
            
            
            var lip = topOuterHeavyMarks
            for i in stride(from: topInerMarks.count - 1, to: 0, by: -1) {
                lip.append(topInerMarks[i])
            }
            lip.append(topOuterHeavyMarks.first!)
            for i in 0...bottomOuterHeavyMarks.count - 1 {
                lip.append(bottomOuterHeavyMarks[i])
            }
            for i in stride(from: bottomInerHeavyMarks.count - 1, to: 0, by: -1) {
                lip.append(bottomInerHeavyMarks[i])
            }
            lip.append(bottomOuterHeavyMarks.first!)
            
            for i in 0...lip.count - 1 {
                let point: CGPoint = lip[i] as! CGPoint
                if i == 0 {
                    context?.move(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                } else {
                    context?.addLine(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                }
            }
        }
        
        bezierPath.close()
        var color: UIColor
        if (LCADataSource.sharedInstance.selectedMakeup == nil) {
            color = UIColor.clear
        } else {
            let colorComponents = LCADataSource.sharedInstance.selectedMakeup.makeupColor.cgColor.components
            color = UIColor(red: colorComponents![0], green: colorComponents![1], blue: colorComponents![2], alpha: CGFloat(LCADataSource.sharedInstance.selectedOpacity))
            print("%f.4", LCADataSource.sharedInstance.selectedOpacity)
        }
        context!.setFillColor(color.cgColor)
        context?.drawPath(using: .fill)
        context?.closePath()
        context?.saveGState()
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        imgPhoto.image = finalImage
    }
}
