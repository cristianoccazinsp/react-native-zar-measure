import Foundation
import ARKit
import QuickLook


@objc(ZarMeasureViewManager)
class ZarMeasureViewManager: RCTViewManager, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    
    // MARK: RN Setup and Constants
    private var _supportsAR = false
    private var _supportsMesh = false
    private var _previewUrl : URL? = nil
    private var _previewResolve : RCTPromiseResolveBlock? = nil
    
    
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    
    @objc
    override func constantsToExport() -> [AnyHashable : Any]! {
        if #available(iOS 13, *) {
            _supportsAR = ARConfiguration.isSupported && ARWorldTrackingConfiguration.isSupported
        } else {
            _supportsAR = false
        };
        if #available(iOS 13, *) {
            _supportsMesh = ZarMeasureView.SUPPORTS_MESH
        }
        return [
            "AR_SUPPORTED": _supportsAR,
            "MESH_SUPPORTED": _supportsMesh
        ]
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
    func clear(_ node:NSNumber, clear: String, vibrate: Bool, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve(nil)
                    return;
                }
                
                view.clear(clear, vibrate)
                resolve(nil)
            }
        }
        else{
            resolve(nil)
        }
    }
    
    
    @objc
    func clearCurrent(_ node:NSNumber, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve(nil)
                    return;
                }
                
                view.clearCurrent() 
                resolve(nil)
            }
        }
        else{
            resolve(nil)
        }
    }
    
    
    @objc
    func removeLast(_ node:NSNumber, clear: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve(nil)
                    return;
                }
                
                view.removeLast(clear)
                resolve(nil)
            }
        }
        else{
            resolve(nil)
        }
    }
    
    
    @objc
    func removeMeasurement(_ node:NSNumber, nodeId:String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve(nil)
                    return;
                }
                
                resolve(view.removeMeasurement(nodeId))
            }
        }
        else{
            resolve(nil)
        }
    }
    
    
    @objc
    func removePlane(_ node:NSNumber, planeId:String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve([])
                    return;
                }
                
                resolve(view.removePlane(planeId))
            }
        }
        else{
            resolve([])
        }
    }
    
    
    @objc
    func editMeasurement(_ node:NSNumber, nodeId:String, text:String, clearPlane: Bool, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve(nil)
                    return;
                }
                
                resolve(view.editMeasurement(nodeId, text, clearPlane))
            }
        }
        else{
            resolve(nil)
        }
    }
    
    
    @objc
    func addPoint(_ node:NSNumber, setCurrent: Bool, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve(["error": "Invalid View Tag"])
                    return;
                }
                
                let (err, measurement, cameraDistance) = view.addPoint(setCurrent)
                
                if(err == nil){
                    resolve(["error": nil, "measurement": measurement,
                             "cameraDistance": cameraDistance])
                }
                else{
                    resolve(["error": err!])
                }
            }
        }
        else{
            resolve(["error": "Not supported"])
        }
    }
    
    
    @objc
    func addPlane(_ node:NSNumber, planeId:String, left:Bool, top:Bool, right:Bool, bottom:Bool, setId:Bool, vibrate:Bool, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve(["error": "Invalid View Tag"])
                    return;
                }
                
                let (err, measurements, plane) = view.addPlane(planeId, left, top, right, bottom, setId, vibrate)
                
                if(err == nil){
                    resolve(["error": nil, "measurements": measurements, "plane": plane])
                }
                else{
                    resolve([ "error": err!])
                }
            }
        }
        else{
            resolve(["error": "Not supported"])
        }
    }
    
    
    @objc
    func getMeasurements(_ node:NSNumber, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
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
    func getPlanes(_ node:NSNumber, minDimension: NSNumber, alignment: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve([])
                    return;
                }
                
                resolve(view.getPlanes(Float(truncating: minDimension), alignment))
            }
        }
        else{
            resolve([])
        }
    }
    
    
    @objc
    func takePicture(_ node:NSNumber, imagePath: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve(["error": "Invalid View Tag"])
                    return;
                }
                
                view.takePicture(imagePath){ (err, measurements) in
                    if(err == nil){
                        resolve(["error": nil, "measurements": measurements])
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
    
    
    @objc
    func saveToFile(_ node:NSNumber, filePath: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            DispatchQueue.main.async { [weak self] in
                
                guard let view = self?.bridge.uiManager.view(forReactTag: node) as? ZarMeasureView else {
                    resolve(["error": "Invalid View Tag"])
                    return;
                }
                
                view.saveToFile(filePath){ (err) in
                    if(err == nil){
                        resolve(["error": nil])
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
    
    
    @objc
    func showPreview(_ path: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void
    {
        if #available(iOS 13, *) {
            
            if !FileManager.default.fileExists(atPath: path) {
                reject("file_invalid", "File does not exist.", nil);
                return;
            }
            
            let url = URL(fileURLWithPath: path)
            
            if !QLPreviewController.canPreview(url as QLPreviewItem) {
                reject("file_not_supported", "File not supported", nil);
                return;
            }
            
            _previewUrl = url
            _previewResolve = resolve
            
            DispatchQueue.main.async { [weak self] in
                if let self = self {
                    let previewController = QLPreviewController()
                    previewController.dataSource = self
                    previewController.delegate = self
                    
                    RCTPresentedViewController()?.present(previewController, animated: true, completion: {
                    })
                }
            }
        }
        else{
            reject("not_supported", "Not supported.]", nil);
        }
    }
    
    
    // MARK: QuickLook delegate
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { return 1 }

    // MARK: QuickLook delegate
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        if let url = _previewUrl {
            if #available(iOS 13.0, *) {
                let res = CustomPreviewItem(fileAt: url)
                
                return res
            } else {
                return url as QLPreviewItem
            }
        }
        else {
            fatalError("Failed to open preview: file was nil.")
        }
    }
    
    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        _previewResolve?(nil)
        _previewResolve = nil
    }
}


@available(iOS 13.0, *)
class CustomPreviewItem : ARQuickLookPreviewItem {
    
    override var previewItemTitle: String? {
        return "Preview"
    }
}
