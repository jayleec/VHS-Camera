//
//  PhotoManager.swift
//  VHS Camera
//
//  Created by Jae Kyung Lee on 06/09/2017.
//  Copyright © 2017 Jae Kyung Lee. All rights reserved.
//

import UIKit
import Photos

class PhotoManager: NSObject {
    
    public func saveVideoToUserLibrary(fileUrl:URL, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: fileUrl)
        }) { (success, error) in
            
            if success {
                completion(true, nil)
                
            } else {
                completion(false, error)
                print(error)
            }
        }
        
    }
    
    public func fetchAssetsFromLibrary(completion: @escaping (Bool, [PHAsset]?) -> Void) {
        
        var content = [PHAsset]()
        let collections = PHAssetCollection.fetchAssetCollections(with: .moment, subtype: .any, options: nil)
        
        collections.enumerateObjects({ (collection, start, stop) in
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            assets.enumerateObjects({ (object, count, stop) in
                content.append(object)
            })
            
        })
        
        completion(true, content)
        
    }
    
    
    public func getAssetThumbnail(asset:PHAsset) -> UIImage {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        var thumbnail = UIImage()
        options.isSynchronous = true
        manager.requestImage(for: asset, targetSize: CGSize(width: 240.0, height: 135.0), contentMode: .aspectFill, options: options) { (result, info) in
            
            thumbnail = result!
        }
        
        return thumbnail
    }
    
    public func fetchAVAssetForPHAsset(videoAsset:PHAsset, completion: @escaping (Bool,URL) ->Void) {
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        PHImageManager.default().requestAVAsset(forVideo: videoAsset, options: options) { (asset, audioMix, dict) in
            
            let url = (asset as! AVURLAsset).url
            completion(true, url)
            
        }
    }
    
}
