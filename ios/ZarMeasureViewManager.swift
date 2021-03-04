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
        if #available(iOS 13, *) {
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
        if #available(iOS 13, *) {
            return ZarMeasureView()
        } else {
            return nil;
        }
    }
  
    @objc
    func clear(_ node:NSNumber, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve(nil)
                    return;
                }
                
                view.clear()
                resolve(nil)
            }
        }
        else{
            resolve(nil)
        }
    }
    
    @objc
    func removeLast(_ node:NSNumber, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve(nil)
                    return;
                }
                
                view.removeLast()
                resolve(nil)
            }
        }
        else{
            resolve(nil)
        }
    }
    
    @objc
    func removeMeasurement(_ node:NSNumber, nodeId nid:String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve(nil)
                    return;
                }
                
                resolve(view.removeMeasurement(nid))
            }
        }
        else{
            resolve(nil)
        }
    }
    
    @objc
    func addPoint(_ node:NSNumber, setCurrent current : Bool, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve(["added": false, "error": "Invalid View Tag"])
                    return;
                }
                
                let (err, measurement, cameraDistance) = view.addPoint(current)
                
                if(err == nil){
                    resolve(["added": true, "error": nil, "measurement": measurement,
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
    func getMeasurements(_ node:NSNumber,resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve([])
                    return;
                }
                
                resolve(view.getMeasurements())
            }
        }
        else{
            resolve([])
        }
    }
    
    
    @objc
    func takePicture(_ node:NSNumber, imagePath path: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve(["error": "Invalid View Tag"])
                    return;
                }
                
                view.takePicture(path){ (err, measurements) in
                    if(err == nil){
                        resolve(["error": nil, "measurements": measurements])
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    else{
                        resolve(["error": err])
                    }
                    
                }
            }
        }
        else{
            resolve(["error": "Not supported"])
        }
    }
    
}
