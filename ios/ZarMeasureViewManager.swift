import Foundation
import ARKit


@objc(ZarMeasureViewManager)
class ZarMeasureViewManager: RCTViewManager {
    
    // MARK: RN Setup and Constants
    private var _supportsAR = false;
    
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    @objc
    override func constantsToExport() -> [AnyHashable : Any]! {
        if #available(iOS 11.0, *) {
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
        if #available(iOS 11.0, *) {
            return ZarMeasureView()
        } else {
            return nil;
        }
    }
  
    
}
