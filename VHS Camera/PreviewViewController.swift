//
//  PreviewViewController.swift
//  VHS Camera
//
//  Created by Jae Kyung Lee on 03/09/2017.
//  Copyright © 2017 Jae Kyung Lee. All rights reserved.
//

import UIKit
import GPUImage
import AVKit
import AVFoundation

class PreviewViewController: UIViewController {

    var videoOrientation: Int!
    
    static let assetKeysRequiredToPlay = ["playable","hasProtectedContent"]
    let player = AVPlayer()
    var asset: AVURLAsset? {
        didSet{
            guard let newAsset = asset else { return }
            loadURLAsset(newAsset)
        }
    }
    
    var playerLayer:AVPlayerLayer? {
        return playerView.playerLayer
    }
    
    var playerItem:AVPlayerItem? {
        didSet{
            player.replaceCurrentItem(with: self.playerItem)
            player.actionAtItemEnd = .none
        }
    }
    
    var fileLocation: URL! {
        didSet {
            self.asset = AVURLAsset(url: self.fileLocation)
        }
    }

    
    
    
    @IBOutlet weak var playerView: PlayerView!
    @IBOutlet weak var playPauseButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("fileLocation: \(self.fileLocation)")
        
        addObserver(self, forKeyPath: "player.currentItem.status", options: .new, context: nil)
        addObserver(self, forKeyPath: "player.rate", options: [.new, .initial], context: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerReachedEnd(notification:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        
        let degree = getVideoRotationAngle()
        print("\n\ndegree:\(degree)")
        if (degree != 0.0) && (degree != 180.0) {
            let affineTrasform = CGAffineTransform(rotationAngle: degreeToRadian(degree)).scaledBy(x: getViewPortRatio(), y: getViewPortRatio())
            self.playerView.playerLayer.setAffineTransform(affineTrasform)
            self.playPauseButton.layer.setAffineTransform(CGAffineTransform(rotationAngle: degreeToRadian(-degree)))
        }
        if degree == 180.0 {
            let affineTrasform = CGAffineTransform(rotationAngle: degreeToRadian(degree))
            self.playerView.playerLayer.setAffineTransform(affineTrasform)
            self.playPauseButton.layer.setAffineTransform(CGAffineTransform(rotationAngle: degreeToRadian(-degree)))
        }
        
        
        self.playerView.playerLayer.player = self.player
        
        self.player.play()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        removeObserver(self, forKeyPath: "player.currentItem.status", context: nil)
        removeObserver(self, forKeyPath: "player.rate", context: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    
    func loadURLAsset (_ asset: AVURLAsset) {
        print("loadURLAsset started : \(asset)")
        
        asset.loadValuesAsynchronously(forKeys: PreviewViewController.assetKeysRequiredToPlay){
            DispatchQueue.main.async {
                guard asset == self.asset else { return }
                for key in PreviewViewController.assetKeysRequiredToPlay {
                    var error: NSError?
                    
                    if !asset.isPlayable || asset.hasProtectedContent {
                        let message = "Video is not playable"
                        self.showAlert(title: "Error", message: message, dismiss: false)
                        return
                    }
                    
                    if asset.statusOfValue(forKey: key, error: &error) == .failed {
                        let message = "Failed to load"
                        self.showAlert(title: "Error", message: message, dismiss: false)
                        return
                    }
                }
                
                self.playerItem = AVPlayerItem(asset: asset)
            }
            
        }// end of asset.loadValues
        
    }//end of func loadURLAsset
    
    @IBAction func makeLikeBtnPressed(_ sender: Any) {
        let url = URL(string: "https://itunes.apple.com/...")
        UIApplication.shared.open(url!, options: [:], completionHandler: nil)
    }
    @IBAction func closeButton(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func pressPlayButton(_ sender: Any) {
        self.updatePlayPauseButtonTitle()
    }
    

    
    @IBAction func saveVideo(_ sender: Any) {
        PhotoManager().saveVideoToUserLibrary(fileUrl: self.fileLocation!) { (success, error) in
            if success {
                self.showAlert(title: "Success", message: "Video saved.", dismiss: true)
            } else {
                self.showAlert(title: "Error", message: (error?.localizedDescription)!, dismiss: false)
            }
        }
    }
    
    
    @IBAction func shareBtnPressed(_ sender: Any) {
        let videoURL = NSURL(fileURLWithPath: self.fileLocation.path)
        let activityItems = [videoURL, "iOS App: VHS Video"] as [Any]
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = self.view
        self.present(activityVC, animated: true, completion: nil)
    }
    
    func getVideoRotationAngle() -> CGFloat {
        print("current degree\(videoOrientation)")
        var degree = 0
        
        switch videoOrientation {
        case 0:
            degree = 0
        case 1:
            degree = -90
        case 2:
            degree = 90
        case 3:
            degree = 180
        default:
            degree = 0
        }
        
        return CGFloat(degree)
    }
    
    
    // MARK: Callbacks
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "player.currentItem.status" {
            
        }
    }
    
    func updatePlayPauseButtonTitle() {
        if player.rate > 0 {
            player.pause()
            playPauseButton.setImage(#imageLiteral(resourceName: "play"), for: .normal)
            
        } else {
            player.play()
            playPauseButton.setImage(#imageLiteral(resourceName: "stop"), for: .normal)
        }
    }
    
    func playerReachedEnd(notification: NSNotification){
        // to restart video
        print("playerReachedEnd")
        self.asset = AVURLAsset(url: self.fileLocation)
        playPauseButton.setImage(#imageLiteral(resourceName: "play"), for: .normal)
        self.updatePlayPauseButtonTitle()
        
    }
    
    
    // MARK: Helpers
    func getViewPortRatio() -> CGFloat{
        let screenSize = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let playerHeight = screenSize.height - 137
        
        print("\n playerHeight : \(playerHeight)")
        let ratio = screenWidth / playerHeight
//      defalt size   width: 375 ,  height: 543 about 0.69
    
        print("\n return ratio : \(ratio)")
        return ratio
    }
    
    func degreeToRadian(_ x:CGFloat) -> CGFloat {
        return .pi * x / 180.0
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
    
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
}











