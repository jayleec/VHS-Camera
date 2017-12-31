//
//  PlayerView.swift
//  VHS Camera
//
//  Created by Jae Kyung Lee on 03/09/2017.
//  Copyright © 2017 Jae Kyung Lee. All rights reserved.
//

import UIKit
import AVFoundation

class PlayerView: UIView {

    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        
        set {
            playerLayer.player = newValue
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    override public class var layerClass:Swift.AnyClass {
        get {
            return AVPlayerLayer.self
        }
    }

}
