//
//  ShopViewController.swift
//  VHS Camera
//
//  Created by Jae Kyung Lee on 23/09/2017.
//  Copyright © 2017 Jae Kyung Lee. All rights reserved.
//

import UIKit
import StoreKit
import SwiftyStoreKit


enum RegisteredPurchase: String {
    case RemoveAd
}

class NetworkActivityIndicatorManager : NSObject {
    private static var loadingCount = 0
    
    class func NetworkOperationStarted() {
        if loadingCount == 0 {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
        }
        loadingCount += 1
    }
    class func networkOperationFinished() {
        if loadingCount > 0 {
            loadingCount -= 1
        }
        
        if loadingCount == 0{
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
    }
    
}

class ShopViewController: UIViewController {
    
    /* In-App Purchases */
    var SHARED_SECRET = "YOUR SHARED_SECRET"
    let APP_BUNDLE_ID = "com.ninjajaekyung.VHS"
    var REMOVE_AD_PRODUCT_ID = "com.ninjajaekyung.VHS.RemoveAd"
    
    @IBOutlet weak var priceTextField: UITextField!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        getInfo(RegisteredPurchase.RemoveAd)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func closeBtnPressed(_ sender: Any) {
        
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func purchase(_ sender: Any) {
        purchase(RegisteredPurchase.RemoveAd)
    }
    
    @IBAction func restore(_ sender: Any) {
        restorePurchases()
    }
    
    // MARK: Helpers
    func getInfo(_ purchase: RegisteredPurchase){
        NetworkActivityIndicatorManager.NetworkOperationStarted()
        SwiftyStoreKit.retrieveProductsInfo( [APP_BUNDLE_ID + "." + purchase.rawValue]) { result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            if let product = result.retrievedProducts.first {
                let priceString = product.localizedPrice!
                print("product price:\(priceString)")
                if (self.priceTextField != nil) {
                    self.priceTextField.text = priceString
                }
            }
//            self.showAlert(self.alertForProductRetrievalInfo(result))
        }
    }
    
    func purchase(_ purchase: RegisteredPurchase){
        NetworkActivityIndicatorManager.NetworkOperationStarted()
        SwiftyStoreKit.purchaseProduct(APP_BUNDLE_ID + "." + purchase.rawValue, atomically: true){
            result in
            if case .success(let purchase) = result {
                isPurchased = true                
                if purchase.needsFinishTransaction{
                    SwiftyStoreKit.finishTransaction(purchase.transaction)
                }
            }
            if let alert = self.alertForPurchaseResult(result){
                self.showAlert(alert)
            }
        }
        
    }
    
    func restorePurchases(){
        NetworkActivityIndicatorManager.NetworkOperationStarted()
        SwiftyStoreKit.restorePurchases(atomically: true) { results in
            NetworkActivityIndicatorManager.networkOperationFinished()
            
            print("restore purchse  \(results.restoredPurchases)")
            for purchase in results.restoredPurchases where purchase.needsFinishTransaction {
                SwiftyStoreKit.finishTransaction(purchase.transaction)
            }
            
            self.showAlert(self.alertForRestorePurchases(results))
        }
    }
    
    func verifyReceipt(completion: @escaping (VerifyReceiptResult) -> Void){
        NetworkActivityIndicatorManager.NetworkOperationStarted()
        
        let appleValidator = AppleReceiptValidator(service: .production, sharedSecret: SHARED_SECRET)
        SwiftyStoreKit.verifyReceipt(using: appleValidator, completion: completion)
    }
    
    func verifyPurchase(){
        NetworkActivityIndicatorManager.NetworkOperationStarted()
        verifyReceipt(completion: {result in
            NetworkActivityIndicatorManager.networkOperationFinished()
            print("verify result \(result)")

            switch result {
            case .success(let receipt):
                
                let purchaseResult = SwiftyStoreKit.verifyPurchase(productId: self.REMOVE_AD_PRODUCT_ID, inReceipt: receipt)
                if self.alertForVerifyPurchase(purchaseResult) {
                    isPurchased = true
                    
                }
                
            case .error:
                self.showAlert(self.alertForVerifyReceipt(result))
            }
        })
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
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}



// MARK: User facing alerts
extension ShopViewController {
    
    func alertWithTitle(_ title: String, message: String) -> UIAlertController {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        return alert
    }
    
    func showAlert(_ alert: UIAlertController) {
        guard self.presentedViewController != nil else {
            self.present(alert, animated: true, completion: nil)
            return
        }
    }
    
    func alertForProductRetrievalInfo(_ result: RetrieveResults) -> UIAlertController {
        
        if let product = result.retrievedProducts.first {
            let priceString = product.localizedPrice!
            return alertWithTitle(product.localizedTitle, message: "\(product.localizedDescription) - \(priceString)")
        } else if let invalidProductId = result.invalidProductIDs.first {
            return alertWithTitle("Could not retrieve product info", message: "Invalid product identifier: \(invalidProductId)")
        } else {
            let errorString = result.error?.localizedDescription ?? "Unknown error. Please contact support"
            return alertWithTitle("Could not retrieve product info", message: errorString)
        }
    }
    
    // swiftlint:disable cyclomatic_complexity
    func alertForPurchaseResult(_ result: PurchaseResult) -> UIAlertController? {
        switch result {
        case .success(let purchase):
            print("Purchase Success: \(purchase.productId)")
            return alertWithTitle("Thank You", message: "Purchase completed")
        case .error(let error):
            print("Purchase Failed: \(error)")
            switch error.code {
            case .unknown: return alertWithTitle("Purchase failed", message: error.localizedDescription)
            case .clientInvalid: // client is not allowed to issue the request, etc.
                return alertWithTitle("Purchase failed", message: "Not allowed to make the payment")
            case .paymentCancelled: // user cancelled the request, etc.
                return nil
            case .paymentInvalid: // purchase identifier was invalid, etc.
                return alertWithTitle("Purchase failed", message: "The purchase identifier was invalid")
            case .paymentNotAllowed: // this device is not allowed to make the payment
                return alertWithTitle("Purchase failed", message: "The device is not allowed to make the payment")
            case .storeProductNotAvailable: // Product is not available in the current storefront
                return alertWithTitle("Purchase failed", message: "The product is not available in the current storefront")
            case .cloudServicePermissionDenied: // user has not allowed access to cloud service information
                return alertWithTitle("Purchase failed", message: "Access to cloud service information is not allowed")
            case .cloudServiceNetworkConnectionFailed: // the device could not connect to the nework
                return alertWithTitle("Purchase failed", message: "Could not connect to the network")
            case .cloudServiceRevoked: // user has revoked permission to use this cloud service
                return alertWithTitle("Purchase failed", message: "Cloud service was revoked")
            }
        }
    }
    
    func alertForRestorePurchases(_ results: RestoreResults) -> UIAlertController {
        
        if results.restoreFailedPurchases.count > 0 {
            print("Restore Failed: \(results.restoreFailedPurchases)")
            return alertWithTitle("Restore failed", message: "Unknown error. Please contact support")
        } else if results.restoredPurchases.count > 0 {
            isPurchased = true
            print("Restore Success: \(results.restoredPurchases)")
            return alertWithTitle("Purchases Restored", message: "All purchases have been restored")
        } else {
            print("Nothing to Restore")
            return alertWithTitle("Nothing to restore", message: "No previous purchases were found")
        }
    }
    
    func alertForVerifyReceipt(_ result: VerifyReceiptResult) -> UIAlertController {
        
        switch result {
        case .success(let receipt):
            print("Verify receipt Success: \(receipt)")
            return alertWithTitle("Receipt verified", message: "Receipt verified remotely")
        case .error(let error):
            print("Verify receipt Failed: \(error)")
            switch error {
            case .noReceiptData:
                return alertWithTitle("Receipt verification", message: "No receipt data. Try again.")
            case .networkError(let error):
                return alertWithTitle("Receipt verification", message: "Network error while verifying receipt: \(error)")
            default:
                return alertWithTitle("Receipt verification", message: "Receipt verification failed: \(error)")
            }
        }
    }
    
    func alertForVerifySubscription(_ result: VerifySubscriptionResult) -> UIAlertController {
        
        switch result {
        case .purchased(let expiryDate):
            print("Product is valid until \(expiryDate)")
            return alertWithTitle("Product is purchased", message: "Product is valid until \(expiryDate)")
        case .expired(let expiryDate):
            print("Product is expired since \(expiryDate)")
            return alertWithTitle("Product expired", message: "Product is expired since \(expiryDate)")
        case .notPurchased:
            print("This product has never been purchased")
            return alertWithTitle("Not purchased", message: "This product has never been purchased")
        }
    }
    
    func alertForVerifyPurchase(_ result: VerifyPurchaseResult) -> Bool {
        
        switch result {
        case .purchased:
            print("Product is purchased")
            return true
//            return alertWithTitle("Product is purchased", message: "Product will not expire")
        case .notPurchased:
            print("This product has never been purchased")
            return false
//            return alertWithTitle("Not purchased", message: "This product has never been purchased")
        }
    }
}



