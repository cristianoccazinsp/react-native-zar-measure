import Foundation
import ARKit


@objc(ZarMeasureViewManager)
class ZarMeasureViewManager: RCTViewManager {
    
    // MARK: RN Setup and Constants
    private var _supportsAR = false
    
    
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    @objc
    override func constantsToExport() -> [AnyHashable : Any]! {
        if #available(iOS 11.3, *) {
            _supportsAR = ARConfiguration.isSupported
        } else {
            _supportsAR = false
        };
        return ["AR_SUPPORTED": _supportsAR]
    }
    
    
    // MARK: RN Methods
    
    @objc
    func checkVideoAuthorizationStatus(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if AVCaptureDevice.authorizationStatus(for: .video) ==  .authorized {
            resolve(true)
        }
        else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                resolve(granted)
            });
        }
    }
    
    override func view() -> UIView! {
        if #available(iOS 11.3, *) {
            return ZarMeasureView()
        } else {
            return nil;
        }
    }
  
    @objc
    func clear(_ node:NSNumber, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 11.3, *) {
            DispatchQueue.main.async {
                let view = self.bridge.uiManager.view(forReactTag: node) as! ZarMeasureView
                view.clear()
                resolve(nil)
            }
        }
        else{
            resolve(nil)
        }
    }
    
    @objc
    func addPoint(_ node:NSNumber, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 11.3, *) {
            DispatchQueue.main.async {
                let view = self.bridge.uiManager.view(forReactTag: node) as! ZarMeasureView
                
                let (err, distance, cameraDistance) = view.addPoint()
                
                if(err == nil){
                    resolve(["added": true, "error": nil, "distance": distance,
                             "cameraDistance": cameraDistance])
                }
                else{
                    resolve(["added": false, "error": err!])
                }
            }
        }
        else{
            resolve(["added": false, "error": "Not supported"])
        }
    }
    
    @objc
    func takePicture(_ node:NSNumber, imagePath path: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 11.3, *) {
            DispatchQueue.main.async {
                let view = self.bridge.uiManager.view(forReactTag: node) as! ZarMeasureView
                
                view.takePicture(path){ err in
                    resolve(["error": err])
                }
            }
        }
        else{
            resolve(["error": "Not supported"])
        }
    }
    
}
