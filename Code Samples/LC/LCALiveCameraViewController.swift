//
//  LCALiveCameraViewController.swift
//  LippyCards
//
//  Created by Admin on 12.01.18.
//  Copyright © 2018 itworksinua. All rights reserved.
//

import UIKit
import Photos

enum LCASelectedState: String {
    case empty, lipstick, gloss
}

class LCALiveCameraViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, LCAVideoCameraControllerDelegate {
    var selectedState: LCASelectedState = .empty
    var makeupList:[LCAMakeup] = []
    var selectedIndexPath: IndexPath!
    var opacityLipstick: Float = 0.3
    
    var selectedLipstickIndexPath: IndexPath!
    var selectedGlossIndexPath: IndexPath!
    
    var makeupSelected:[String: LCAMakeup] = [:]
    var sliderOpacity: UISlider!
    public var usedSavedPhoto: Bool = false
    public var mainPhoto: PHAsset!
    var photoDetector = LCAPhotoFaceLandmarkDetector()
    var lipPoints:[NSValue] = []
    let cameraController = LCAVideoCameraController()
    
    @IBOutlet weak var imgMainPhoto: UIImageView!
    @IBOutlet weak var btnGloss: UIButton!
    @IBOutlet weak var btnLipstick: UIButton!
    @IBOutlet weak var btnTakePhoto: UIButton!
    @IBOutlet weak var constraintToolbarHeight: NSLayoutConstraint!
    @IBOutlet weak var viewColorsConteiner: UIView!
    @IBOutlet weak var viewMainPhotoConteiner: UIView!
    @IBOutlet weak var collectionColors: UICollectionView!
    @IBOutlet weak var viewSliderConteiner: UIView!
    @IBOutlet weak var viewSliderThumb: UIView!
    @IBOutlet weak var constraintSliderThumbTop: NSLayoutConstraint!
    @IBOutlet weak var viewMakeupListConteiner: UIView!
    @IBOutlet weak var btnRotateCamera: UIButton!
    @IBOutlet weak var btnPhotos: UIButton!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var btnCamera: UIButton!
    @IBOutlet weak var viewMediaContainer: UIView!
    var viewVideoMarks: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("viewDidLoad")
        self.setupGestures()
        viewSliderConteiner.layer.shadowOpacity = 0.15
        viewSliderConteiner.layer.shadowRadius = 5
        viewSliderConteiner.layer.shadowColor = UIColor.black.cgColor
        cameraController.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.selectedState = .empty
        self.updateToolBar(animate: false)
        self.setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.setupOpacitySlider()
    }
    
    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
        cameraController.previewLayer?.frame = self.view.bounds
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !usedSavedPhoto {
            if let connection =  cameraController.previewLayer?.connection  {
                let currentDevice: UIDevice = UIDevice.current
                let orientation: UIDeviceOrientation = currentDevice.orientation
                let previewLayerConnection : AVCaptureConnection = connection
                if previewLayerConnection.isVideoOrientationSupported {
                    switch (orientation) {
                    case .portrait: updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                        break
                    case .landscapeRight: updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeLeft)
                        break
                    case .landscapeLeft: updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeRight)
                        break
                    case .portraitUpsideDown: updatePreviewLayer(layer: previewLayerConnection, orientation: .portraitUpsideDown)
                        break
                    default: updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                        break
                    }
                }
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cameraController.stopVideo()
        photoDetector.removeNotifications()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func setupUI() {
        if usedSavedPhoto {
            imgMainPhoto.isHidden = !usedSavedPhoto
            imgMainPhoto.image = self.getAssetThumbnail(asset: mainPhoto)
            photoDetector.imgPhoto = imgMainPhoto
            photoDetector.process()
            photoDetector.setupNotification()
        } else {
            #if !((arch(i386) || arch(x86_64)) && os(iOS))
                cameraController.prepare()
                cameraController.startVideo(view: viewMainPhotoConteiner)
            #endif
        }
        btnTakePhoto.isHidden = usedSavedPhoto
        btnPhotos.isHidden = usedSavedPhoto
        btnRotateCamera.isHidden = usedSavedPhoto
        btnNext.isHidden = !usedSavedPhoto
        btnCamera.isHidden = !usedSavedPhoto
        viewMainPhotoConteiner.isHidden = usedSavedPhoto
        LCADataSource.sharedInstance.selectedMakeup = nil
        self.viewSliderConteiner.alpha = 0
    }
    
    func setupGestures() {
        let tapOnCameraView = UITapGestureRecognizer(target: self, action: #selector(self.onMainPhotoTap))
        viewMainPhotoConteiner.addGestureRecognizer(tapOnCameraView)
        
        let swipeDownOnCameraView = UISwipeGestureRecognizer(target: self, action: #selector(self.closeToolbar))
        swipeDownOnCameraView.direction = .down
        viewMainPhotoConteiner.addGestureRecognizer(swipeDownOnCameraView)
        
        let tapOnPhotoView = UITapGestureRecognizer(target: self, action: #selector(self.closeToolbar))
        imgMainPhoto.isUserInteractionEnabled = true
        imgMainPhoto.addGestureRecognizer(tapOnPhotoView)
        
        let swipeDownOnPhotoView = UISwipeGestureRecognizer(target: self, action: #selector(self.closeToolbar))
        swipeDownOnPhotoView.direction = .down
        imgMainPhoto.addGestureRecognizer(swipeDownOnPhotoView)
        
        let swipeDownOnColors = UISwipeGestureRecognizer(target: self, action: #selector(self.closeToolbar))
        swipeDownOnColors.direction = .down
        viewMakeupListConteiner.addGestureRecognizer(swipeDownOnColors)
    }

    // MARK: Actions
    
    @IBAction func onSelectPhoto(_ sender: Any) {
        let photoPickerAccessStatus = PHPhotoLibrary.authorizationStatus()
        if photoPickerAccessStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization({status in
                if status == .authorized {
                    DispatchQueue.main.async {
                        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                        let photoPickerViewController = storyBoard.instantiateViewController(withIdentifier: "LCAPhotoPickerViewController")
                        self.navigationController?.pushViewController(photoPickerViewController, animated: true)
                    }
                }
            })
        } else if photoPickerAccessStatus != .authorized {
            let alert = UIAlertController(title: "Warning", message: "You restricted access to your Photo library. Please, go to the Settings and allow Photo library usage.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        } else {
            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let PhotoPickerViewController = storyBoard.instantiateViewController(withIdentifier: "LCAPhotoPickerViewController")
            self.navigationController?.pushViewController(PhotoPickerViewController, animated: true)
        }
    }
    
    @IBAction func onChangeCamera(_ sender: Any) {
        removeLips()
        cameraController.switchCameras()
    }
    
    @IBAction func onCamera(_ sender: Any) {
        usedSavedPhoto = false
        mainPhoto = nil
        self.setupUI()
    }
    
    @IBAction func onGloss(_ sender: Any) {
        self.selectedState = self.selectedState == .gloss ? .empty : .gloss
        self.updateToolBar(animate: true)
    }
    
    @IBAction func onPomade(_ sender: Any) {
        self.selectedState = self.selectedState == .lipstick ? .empty : .lipstick
        self.updateToolBar(animate: true)
    }
    
    @IBAction func onTakePhoto(_ sender: Any) {
        cameraController.takePhoto()
    }
    
    @IBAction func onNext(_ sender: Any) {
        LCADataSource.sharedInstance.savedPhoto = imgMainPhoto.image
    }
    
    @objc func onMainPhotoTap(singleTap: UITapGestureRecognizer) {
        if self.selectedState != .empty {
            self.selectedState = .empty
            self.updateToolBar(animate: true)
        } else {
            cameraController.makeFocus(singleTap:singleTap)
        }
    }
    
    @objc func closeToolbar() {
        self.selectedState = .empty
        self.updateToolBar(animate: true)
    }
    
    func updateToolBar(animate: Bool) {
        let animationDuration: Double = animate ? 0.3 : 0
        if self.selectedState == .empty {
            self.closeToolbarWitAnimation(animateDuration: animationDuration)
            if LCADataSource.sharedInstance.selectedMakeup != nil && LCADataSource.sharedInstance.selectedMakeup.makeupType == .lipstick {
                let animationDuration: Double = (self.viewSliderConteiner.alpha != 1) ? 0.3 : 0
                UIView.animate(withDuration: animationDuration) {
                    self.viewSliderConteiner.alpha = 1
                }
                sliderOpacity?.isUserInteractionEnabled = true
            } else {
                UIView.animate(withDuration: animationDuration) {
                    self.viewSliderConteiner.alpha = 0
                }
                sliderOpacity?.isUserInteractionEnabled = false
            }
        } else if self.selectedState == .lipstick {
            self.btnLipstick.alpha = 1;
            self.btnGloss.alpha = 0.4;
            self.sliderOpacity.value = opacityLipstick
            self.makeupList = LCADataSource.sharedInstance.lipstickColors
            self.updateSliderWithValue(value: self.opacityLipstick)
            self.openToolbarWitAnimation(animateDuration: animationDuration)
            sliderOpacity?.isUserInteractionEnabled = true
            UIView.animate(withDuration: animationDuration) {
                self.viewSliderConteiner.alpha = 1
            }
            if (LCADataSource.sharedInstance.selectedMakeup != nil &&
                LCADataSource.sharedInstance.selectedMakeup.makeupType == .lipstick &&
                self.selectedIndexPath.row > 4) {
                self.collectionColors.setContentOffset(CGPoint(x:self.selectedIndexPath.row * 76 + 10, y:0), animated: false)
            }
        } else if self.selectedState == .gloss {
            self.btnLipstick.alpha = 0.4;
            self.btnGloss.alpha = 1;
            self.makeupList = LCADataSource.sharedInstance.glossColors
            self.openToolbarWitAnimation(animateDuration: animationDuration)
            sliderOpacity?.isUserInteractionEnabled = false
            UIView.animate(withDuration: animationDuration) {
                self.viewSliderConteiner.alpha = 0
            }
            if (LCADataSource.sharedInstance.selectedMakeup != nil &&
                LCADataSource.sharedInstance.selectedMakeup.makeupType == .gloss &&
                self.selectedIndexPath.row > 4) {
                self.collectionColors.setContentOffset(CGPoint(x:self.selectedIndexPath.row * 76 + 10, y:0), animated: false)
            }
        }
    }
    
    func openToolbarWitAnimation(animateDuration: Double) {
        self.collectionColors.isScrollEnabled = true
        self.btnTakePhoto.isUserInteractionEnabled = false
        self.viewMainPhotoConteiner.isUserInteractionEnabled = true
        self.constraintToolbarHeight.constant = 172
        UIView.animate(withDuration: animateDuration) {
            self.view.layoutIfNeeded()
            self.viewColorsConteiner.alpha = 1
            self.btnTakePhoto.alpha = 0
        }
        self.collectionColors.reloadData()
    }
    
    func closeToolbarWitAnimation(animateDuration: Double) {
        self.btnLipstick.alpha = 1;
        self.btnGloss.alpha = 1;
        self.btnTakePhoto.isUserInteractionEnabled = true
        self.constraintToolbarHeight.constant = 85
        UIView.animate(withDuration: animateDuration) {
            self.view.layoutIfNeeded()
            self.viewColorsConteiner.alpha = 0
            self.btnTakePhoto.alpha = 1
        }
    }
    
    // MARK: Opacity slider
    
    func setupOpacitySlider() {
        let mySlider = UISlider(frame: CGRect(x: 0, y: 0, width: 100, height: 10))
        self.view.addSubview(mySlider)
        mySlider.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi / 2))
        let xPos = viewSliderConteiner.frame.origin.x - viewSliderThumb.frame.size.width / 2
        let yPos = viewSliderConteiner.frame.origin.y
        let width = viewSliderConteiner.frame.size.height
        let height = viewSliderThumb.frame.size.width
        let sliderFrame = CGRect(x: xPos, y: yPos, width: height, height: width)
        mySlider.frame = sliderFrame
        mySlider.thumbTintColor = .clear
        mySlider.tintColor = .clear
        mySlider.maximumTrackTintColor = .clear
        mySlider.minimumTrackTintColor = .clear
        mySlider.addTarget(self, action: #selector(LCALiveCameraViewController.onOpacitySlider(_:)), for: .valueChanged)
        sliderOpacity = mySlider
    }
    
    func updateSliderWithValue(value: Float) {
        self.constraintSliderThumbTop.constant = (self.viewSliderConteiner.frame.size.height) * CGFloat(value) - CGFloat(self.viewSliderThumb.frame.size.height / 2)
    }
    
    @IBAction func onOpacitySlider(_ sender: UISlider) {
        if self.selectedState != .gloss {
            self.opacityLipstick = sender.value
            self.updateSliderWithValue(value: self.opacityLipstick)
        }
        if selectedIndexPath.row == 0 {
            return
        }
        let selectedMakeup = LCADataSource.sharedInstance.selectedMakeup
        let opacity = ((selectedMakeup?.maxOpacity)! - (selectedMakeup?.minOpacity)!) * sender.value + (selectedMakeup?.minOpacity)!
        LCADataSource.sharedInstance.selectedOpacity = opacity
        NotificationCenter.default.post(name: Notification.Name("LCADataSourceMakeupChanged"), object: nil, userInfo: nil)
    }
    
    // MARK: Collection
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.makeupList.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.row == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LCAMakeupClearCollectionCell",
                                                          for: indexPath)
            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LCAMakeupColorCollectionCell",
                                                      for: indexPath) as? LCAMakeupColorCollectionCell
        cell?.makeupObj = self.makeupList[indexPath.row]
        if self.selectedState == .lipstick &&
            LCADataSource.sharedInstance.selectedMakeup != nil &&
            LCADataSource.sharedInstance.selectedMakeup.makeupType == .lipstick {
            cell?.isSelected = (self.selectedIndexPath != nil) && indexPath.row == self.selectedIndexPath.row
        }
        if self.selectedState == .gloss &&
            LCADataSource.sharedInstance.selectedMakeup != nil &&
            LCADataSource.sharedInstance.selectedMakeup.makeupType == .gloss {
            cell?.isSelected = (self.selectedIndexPath != nil) && indexPath.row == self.selectedIndexPath.row
        }
        return cell!
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if self.selectedState == .lipstick {
            if LCADataSource.sharedInstance.selectedMakeup != nil &&
                LCADataSource.sharedInstance.selectedMakeup.makeupType == .lipstick &&
                self.selectedIndexPath != nil &&
                self.selectedIndexPath.row == indexPath.row {
                self.selectedState = .empty
                self.updateToolBar(animate: true)
                return
            }
            if let selectedIndexPath: IndexPath = self.selectedIndexPath {
                let cell = collectionView.cellForItem(at: selectedIndexPath) as? LCAMakeupColorCollectionCell
                cell?.isSelected = false
            }
            self.selectedIndexPath = indexPath
            let cell = collectionView.cellForItem(at: indexPath)
            if indexPath.row == 0 {
                LCADataSource.sharedInstance.selectedMakeup =  nil
                LCADataSource.sharedInstance.selectedOpacity = 0.0
                btnNext.isHidden = true
            } else {
                LCADataSource.sharedInstance.selectedMakeup = makeupList[indexPath.row]
                let selectedMakeup = makeupList[indexPath.row]
                LCADataSource.sharedInstance.selectedOpacity = (selectedMakeup.maxOpacity - selectedMakeup.minOpacity) * self.sliderOpacity.value + selectedMakeup.minOpacity
                btnNext.isHidden = !usedSavedPhoto
            }
            NotificationCenter.default.post(name: Notification.Name("LCADataSourceMakeupChanged"), object: nil, userInfo: nil)
            cell?.isSelected = true
        }
        if self.selectedState == .gloss {
            if LCADataSource.sharedInstance.selectedMakeup != nil &&
                LCADataSource.sharedInstance.selectedMakeup.makeupType == .gloss &&
                self.selectedIndexPath != nil &&
                self.selectedIndexPath.row == indexPath.row {
                self.selectedState = .empty
                self.updateToolBar(animate: true)
                return
            }
            if let selectedIndexPath : IndexPath = self.selectedIndexPath {
                let cell = collectionView.cellForItem(at: selectedIndexPath) as? LCAMakeupColorCollectionCell
                cell?.isSelected = false
            }
            self.selectedIndexPath = indexPath
            let cell = collectionView.cellForItem(at: indexPath)
            if indexPath.row == 0 {
                LCADataSource.sharedInstance.selectedMakeup =  nil
                LCADataSource.sharedInstance.selectedOpacity = 0.0
                btnNext.isHidden = true
            } else {
                LCADataSource.sharedInstance.selectedMakeup = makeupList[indexPath.row]
                LCADataSource.sharedInstance.selectedOpacity = 0.5
                btnNext.isHidden = !usedSavedPhoto
            }
            NotificationCenter.default.post(name: Notification.Name("LCADataSourceMakeupChanged"), object: nil, userInfo: nil)
            cell?.isSelected = true
        }
        let makeup = makeupList[indexPath.row]
        let makeupType = makeup.makeupType.simpleDescription()
        if makeup.makeupId.range(of:"-1") != nil {
            makeupSelected.removeValue(forKey: makeupType)
        } else {
            makeupSelected[makeupType] = makeup
        }
    }
    
    func getAssetThumbnail(asset: PHAsset) -> UIImage {
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        var thumbnail = UIImage()
        option.isSynchronous = true
        manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFill, options: option, resultHandler: {(result, info)->Void in
            thumbnail = result!
        })
        return thumbnail
    }
    
    func drawLipsByPoints(points:[NSValue]) {
        DispatchQueue.main.async {
            var stablePoints:[NSValue] = []
            if self.lipPoints.count != points.count {
                stablePoints = points
            } else {
                var isNeedUpdatePoints = false
                for i in 0...points.count - 1 {
                    let point = points[i].cgPointValue
                    let savedPoint = self.lipPoints[i].cgPointValue
                    if abs(point.x - savedPoint.x) > 3 ||
                       abs(point.y - savedPoint.y) > 3 {
                        isNeedUpdatePoints = true
                        break
                    } else {
                       NSLog("Skip drawing")
                    }
                }
                stablePoints = isNeedUpdatePoints ? points : self.lipPoints
            }
            self.lipPoints = stablePoints
        
            if self.viewVideoMarks == nil {
                self.viewVideoMarks = UIView()
                self.viewVideoMarks.frame(forAlignmentRect: CGRect(x:0, y:0, width:UIScreen.main.bounds.size.width, height:UIScreen.main.bounds.size.height))
                self.viewMediaContainer.addSubview(self.viewVideoMarks)
            }
            self.viewVideoMarks.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            let shape = CAShapeLayer()
            var color: UIColor
            if (LCADataSource.sharedInstance.selectedMakeup == nil) {
                color = UIColor.clear
            } else {
                let colorComponents = LCADataSource.sharedInstance.selectedMakeup.makeupColor.cgColor.components
                color = UIColor(red: colorComponents![0], green: colorComponents![1], blue: colorComponents![2], alpha: CGFloat(LCADataSource.sharedInstance.selectedOpacity))
            }
            let topLipheight = stablePoints[15].cgPointValue.y - stablePoints[4].cgPointValue.y
            let mouthHeight = stablePoints[19].cgPointValue.y - stablePoints[15].cgPointValue.y
            let path = UIBezierPath()
            if mouthHeight / topLipheight > 0.5 {
                let pointsTop = [stablePoints[0], stablePoints[1], stablePoints[2], stablePoints[3], stablePoints[4], stablePoints[5], stablePoints[6], stablePoints[7], stablePoints[17], stablePoints[16], stablePoints[15], stablePoints[14], stablePoints[13], stablePoints[0]]
                let pathTop = UIBezierPath()
                pathTop.move(to: pointsTop[0].cgPointValue)
                for index in 1...pointsTop.count - 1 {
                    pathTop.addLine(to: pointsTop[index].cgPointValue)
                }
                pathTop.close()
                
                let pointsBottom = [stablePoints[0], stablePoints[12], stablePoints[11], stablePoints[10], stablePoints[9], stablePoints[8], stablePoints[7], stablePoints[18], stablePoints[19], stablePoints[20], stablePoints[0]]
                
                let pathBottom = UIBezierPath()
                pathBottom.move(to: pointsBottom[0].cgPointValue)
                for index in 1...pointsBottom.count - 1 {
                    pathBottom.addLine(to: pointsBottom[index].cgPointValue)
                }
                pathBottom.close()
                
                path.append(pathBottom)
                path.append(pathTop)
            } else {
                path.move(to: stablePoints[0].cgPointValue)
                for index in 1...12 {
                    path.addLine(to: stablePoints[index].cgPointValue)
                }
                path.close()
            }
            shape.fillColor = color.cgColor
            shape.path = path.cgPath
            self.viewVideoMarks.layer.addSublayer(shape)
        }
    }
    
    func removeLips() {
        DispatchQueue.main.async {
            guard let sublayersCount = self.viewVideoMarks?.layer.sublayers?.count else { return }
            if sublayersCount != 0 {
                NSLog("remove lips")
                self.viewVideoMarks.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            }
        }
    }
    
    func processCapturedImage(image: UIImage) {
        cameraController.stopVideo()
        DispatchQueue.main.async {
            self.imgMainPhoto.image = image
            self.viewVideoMarks.isHidden = true
            self.imgMainPhoto.isHidden = false
            self.viewVideoMarks.isHidden = false
            self.viewMediaContainer.bringSubview(toFront: self.viewVideoMarks)
            UIGraphicsBeginImageContext(self.view.frame.size)
            self.viewMediaContainer.layer.render(in:UIGraphicsGetCurrentContext()!)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            LCADataSource.sharedInstance.savedPhoto = image
            let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "LCAResultViewController") as UIViewController
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
}
