//
//  ViewController.swift
//  VHS Camera
//
//  Created by Jae Kyung Lee on 03/09/2017.
//  Copyright © 2017 Jae Kyung Lee. All rights reserved.
//

import UIKit
import GPUImage
import AVFoundation
import Photos

var isPurchased : Bool = false {
    willSet{
        print("isPurchased will set \(isPurchased)")
//        UserDefaults.standard.set(isPurchased, forKey: "isPurchased")
    }
    didSet {
        print("it did set \(isPurchased)")
        UserDefaults.standard.set(isPurchased, forKey: "isPurchased")
        NotificationCenter.default.post(name: Notification.Name("isPurchasedActive"), object: nil)
    }
}



class RecorderViewController: UIViewController {
    
    static let sharedInstance = RecorderViewController()
    enum CameraLense {
        case Color
        case BlackAndWhite
    }

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var topStackView: UIStackView!
    @IBOutlet weak var renderView: RenderView!
    @IBOutlet weak var timeTextView: UITextField!
    
    
    var camera:Camera!
    var movieOutput:MovieOutput? = nil
    var fileOutput: URL!
    var isRecording = false
    var currentCameraLense = CameraLense.Color
    var previewOrientation:Int!
    
    var filter: UnsharpMask!
    var vhs:Luminance!
    var luminance:ColorInversion!
    let maskImage = PictureInput(imageName:"tape_2.png")
    let blendFilter = OverlayBlend()
    let blendImageName = "ad_view_1992"
    var blendImage:PictureInput?
    var timer: Timer!
    var recordingTimer: Timer!
    var count: Double = 0
    
    
    @IBOutlet weak var recordingBtn: UIButton!
    @IBOutlet weak var switchBtn: UISwitch!
    @IBOutlet weak var zoomInBtn: UIButton!
    @IBOutlet weak var settingsBtn: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(RecorderViewController.configureFilteredView), name: Notification.Name("isPurchasedActive"), object: nil)
        ShopViewController().verifyPurchase()
        
        initialize()
        
        NotificationCenter.default.addObserver(self, selector: #selector(RecorderViewController.setPreviewOrientation), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        
        checkPhotoLibraryAuthorization()
    }
    
    func initialize(){
        do {
            camera = try Camera(sessionPreset:AVCaptureSessionPreset640x480, location: .backFacing)
            camera.runBenchmark = true
            print("initialize camera :\(camera)")
            self.clearTempFolder()
            self.initFilters()
            self.configureFilteredView()
            //            Hide settings btn
            self.settingsBtn.isEnabled = false
            previewOrientation = 0
        }catch {
            fatalError("Could not initialize rendering pipeline: \(error)")
        }
    }

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
    }


    @IBAction func capture(_ sender: Any) {
        if (!isRecording) {
            do {
                self.isRecording = true

                let outputURL = URL(fileURLWithPath:self.videoFileLocation())
                
                do {
                    try FileManager.default.removeItem(at:outputURL)
                } catch {
                }
                
                movieOutput = try MovieOutput(URL:outputURL, size:Size(width:480, height:640), liveVideo:true)
                camera.audioEncodingTarget = movieOutput
                self.capturePipelineConfigure()
                movieOutput!.startRecording()
                
                print("is Recording")

                self.count = 0
                self.startRecordingTimeCheck()
                

            } catch {
                fatalError("Couldn't initialize movie, error: \(error)")
            }
        } else {
            movieOutput?.finishRecording{
                
                self.fileOutput = URL(fileURLWithPath:self.videoFileLocation())
                print("Finished recording: \(self.fileOutput)")
                print("Recording done")
                
                self.isRecording = false
                self.camera.audioEncodingTarget = nil
                self.movieOutput = nil
                self.recordingTimeCheckDone()
                
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "videoPreview", sender: nil)
                }
                
            }
        }
    }
    
    
    @IBAction func freshBtnPressed(_ sender: Any) {
        self.camera.switchFlashMode()
    }
    
    
    @IBAction func rotateCameraPressed(_ sender: Any) {
        
        self.camera.switchCameraInput()
    }
    
    
    @IBAction func switchPressed(_ sender: Any) {
        

            if self.currentCameraLense == .Color {
                self.currentCameraLense = .BlackAndWhite
            } else {
                self.currentCameraLense = .Color
            }
        
        
        self.configureFilteredView()
    }
    
    @IBAction func zoomInBtnPressed(_ sender: Any) {
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(RecorderViewController.zoomIn), userInfo: nil, repeats: true)
        
    }

    @IBAction func zoomInBtnTouchUpOutside(_ sender: Any) {
        timer.invalidate()
    }
    

    @IBAction func zoomOutBtnPressed(_ sender: Any) {
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(RecorderViewController.zoomOut), userInfo: nil, repeats: true)
    }
    
    @IBAction func zoomOutBtnTouchUpOutside(_ sender: Any) {
        timer.invalidate()
    }
    
    @IBAction func shopBtnPressed(_ sender: Any) {
        
        self.performSegue(withIdentifier: "showShop", sender: nil)
    }
    
    @IBAction func settingsBtnPressed(_ sender: Any) {
        
        self.performSegue(withIdentifier: "showSettings", sender: nil)
    }
    
    func recordingTimeCheckDone(){
        
        count = 0
        DispatchQueue.main.async {
            self.timeTextView.text = ""
        }
        recordingTimer.invalidate()
    }
    
    func transformTimeTextField() {
        
        var affineTransform: CGAffineTransform
        switch previewOrientation {
        case 0:
            affineTransform = CGAffineTransform(rotationAngle: degreeToRadian(0)).translatedBy(x: 0, y: 0)
            self.timeTextView.layer.setAffineTransform(affineTransform)
            break
        case 1: //landscapeLeft
            affineTransform = CGAffineTransform(rotationAngle: degreeToRadian(90)).translatedBy(x: 90, y: -60)
//            it's not working on ios 11
//            affineTransform = CGAffineTransform(rotationAngle: degreeToRadian(90)).translatedBy(x: 30, y: -30)
            self.timeTextView.layer.setAffineTransform(affineTransform)
            break
        case 2: //landscapeRight
            affineTransform = CGAffineTransform(rotationAngle: degreeToRadian(-90)).translatedBy(x: -350, y: -260)
            //            it's not working on ios 11
//            affineTransform = CGAffineTransform(rotationAngle: degreeToRadian(90)).translatedBy(x: -30, y: 30)
            self.timeTextView.layer.setAffineTransform(affineTransform)
            break
        default:
            affineTransform = CGAffineTransform(rotationAngle: degreeToRadian(0)).translatedBy(x: 10, y: -60)
            self.timeTextView.layer.setAffineTransform(affineTransform)
            return
        }
    }
    
    func countRecordingTime() {
        count += 1
        
        let minutes = Int(count) / 60 % 60
        let seconds = Int(count) % 60

        let time: String

        time = String(format: "REC %02i:%02i", minutes, seconds)
        transformTimeTextField()
        DispatchQueue.main.async {
            self.timeTextView.text = time
        }
    }
    
    func startRecordingTimeCheck() {
        
        recordingTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(RecorderViewController.countRecordingTime), userInfo: nil, repeats: true)
        
    }
    
    func zoomIn() {
        self.camera.zoomIn(isZoomIn: true)
    }

    func zoomOut() {
        self.camera.zoomIn(isZoomIn: false)
    }
    
    func setPreviewOrientation() {
        self.previewOrientation = self.detectVideoOrientation()
    }
    
    func initFilters(){
        
        self.filter = UnsharpMask()
        self.filter.intensity = 5
        self.vhs = Luminance()
        self.vhs.mask = maskImage
        self.maskImage.processImage()
        self.luminance = ColorInversion()
        
        self.blendImage = PictureInput(imageName:blendImageName)
        self.blendImage?.addTarget(blendFilter)
        self.blendImage?.processImage()
        
    }

    
    func configureFilteredView() {
        print("\n configureFilteredView")
        print("camera 111 : \(camera)")
        
        print("\n isPurchase :  \(isPurchased)")
        if isPurchased {
            switch currentCameraLense {
            case .Color:
                camera.removeAllTargets()
                filter.removeAllTargets()
                vhs.removeAllTargets()
                luminance.removeAllTargets()
                blendFilter.removeAllTargets()
                
                camera --> filter --> vhs --> renderView
                
                camera.startCapture()
                
            case .BlackAndWhite:
                camera.removeAllTargets()
                filter.removeAllTargets()
                vhs.removeAllTargets()
                luminance.removeAllTargets()
                blendFilter.removeAllTargets()
                
                camera --> filter --> vhs --> luminance --> renderView
                
                camera.startCapture()
                
            }
        }else {
            
            switch currentCameraLense {
                
            case .Color:
                print("camera 1 : \(camera)")
                camera.removeAllTargets()
                print("camera 2 : \(camera)")
                filter.removeAllTargets()
                vhs.removeAllTargets()
                luminance.removeAllTargets()
                blendFilter.removeAllTargets()
                
                camera --> filter --> vhs --> blendFilter --> renderView
                
                camera.startCapture()
                
            case .BlackAndWhite:
                camera.removeAllTargets()
                filter.removeAllTargets()
                vhs.removeAllTargets()
                luminance.removeAllTargets()
                blendFilter.removeAllTargets()
                
                camera --> filter --> vhs --> luminance --> blendFilter --> renderView
                
                camera.startCapture()
                
            }
        }
        
    }
    
    
    func capturePipelineConfigure(){
        
        if isPurchased {
            switch currentCameraLense {
            case .Color:
                filter --> vhs --> movieOutput!
            case .BlackAndWhite:
                filter --> vhs --> luminance --> movieOutput!
            }
        }else {
            switch currentCameraLense{
            case .Color:
                filter --> vhs --> blendFilter --> movieOutput!
            case .BlackAndWhite:
                filter --> vhs --> luminance --> blendFilter --> movieOutput!
            }
        }
    }
    
    func checkPhotoLibraryAuthorization(){
        let status = PHPhotoLibrary.authorizationStatus()
        print("authorization check \(status)")
        
        if (status == PHAuthorizationStatus.notDetermined){
            PHPhotoLibrary.requestAuthorization({ (newStatus) in
                if (newStatus == PHAuthorizationStatus.authorized){
                    self.showAlert(title: "Photo Library", message:"Photo Library Access Allowed" , dismiss: false)
                }else{
                    self.showAlert(title: "Photo Library", message:"Photo Library Access Not Allowed" , dismiss: false)
                }
            })
        }
    }
    
    
    // MARK: Helpers
    func degreeToRadian(_ x:CGFloat) -> CGFloat {
        return .pi * x / 180.0
    }
    
    func detectVideoOrientation() -> Int {
        
        var videoOrientation: Int
        let orientation:UIDeviceOrientation = UIDevice.current.orientation
        print("current device orientation = \(orientation)")
        switch orientation {
        case .portrait:
            print("\n .portrait")
            videoOrientation = 0
        case .landscapeLeft:
            print("\n .landscapeLeft")
            videoOrientation = 1
        case .landscapeRight:
            print("\n .landscapeRight")
            videoOrientation = 2
        case .portraitUpsideDown:
            print("\n .upsideDown")
            videoOrientation = 3
        default:
            videoOrientation = 0
        }
        
        return videoOrientation
        
    }
    
    func videoFileLocation() -> String {
        return NSTemporaryDirectory().appending("videoFile.mov")
    }

    
    func clearTempFolder() {
        let fileManager = FileManager.default
        let tempFolderPath = NSTemporaryDirectory()
        do {
            let filePaths = try fileManager.contentsOfDirectory(atPath: tempFolderPath)
            for filePath in filePaths {
                try fileManager.removeItem(atPath: tempFolderPath + filePath)
            }
        } catch {
            print("could not clear tmp folders")
        }
        print("clear success")
    }
    
    
    func showAlert(title:String, message:String, dismiss:Bool) {
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        if dismiss {
            controller.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in self.dismiss(animated: true, completion: nil)}))
        } else {
            controller.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        }
        self.present(controller, animated: true, completion: nil)
    }
    
    // MARK: Segue
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "videoPreview"{
            let preview = segue.destination as! PreviewViewController
            preview.fileLocation = self.fileOutput
            preview.videoOrientation = self.previewOrientation
        }
     }
    
 
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
} // end of class


extension Notification.Name {
    static let isPurchasedChanged = Notification.Name("isPurchasedChanged")
}









