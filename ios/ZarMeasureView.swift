import Foundation
import UIKit
import SceneKit
import ARKit


@available(iOS 13, *)
@objc public class ZarMeasureView: UIView, ARSCNViewDelegate, UIGestureRecognizerDelegate, ARSessionDelegate, ARCoachingOverlayViewDelegate {
    

    // MARK: Public properties
    @objc public var units: String = "m"
    @objc public var minDistanceCamera: CGFloat = 0.05
    @objc public var maxDistanceCamera: CGFloat = 5
    @objc public var useFeatureDetection: Bool = true
    @objc public var onARStatusChange: RCTDirectEventBlock? = nil
    @objc public var onMeasuringStatusChange: RCTDirectEventBlock? = nil
    @objc public var onMountError: RCTDirectEventBlock? = nil
    
    
    // MARK: Public methods
    
    // Removes all nodes and lines
    // Must be called on UI thread
    func clear() -> Void
    {
        // no need for locks since everything runs on the UI thread
        spheres.removeAll()
        lineNode?.removeFromParentNode()
        targetNode?.removeFromParentNode()
        textNode?.removeFromParentNode()
        while let n = self.sceneView.scene.rootNode.childNodes.first { n.removeFromParentNode()
        }
        lineNode = nil
        targetNode = nil
        textNode = nil
        measurementLabel.text = ""
    }
    
    
    // Adds a new point (or calculates distance if there was one already)
    // returns (err, distance, cameraDistance)
    // if there are already 2 points, they all cleared and status is restarted
    // Must be called on UI thread
    func addPoint() -> (String?, CGFloat?, CGFloat?)
    {
        // if we already have 2 nodes, clear them
        if(spheres.count > 1){
            self.clear()
            return("Cleared", nil, nil)
        }
        
        let (er, currentPosition, result) = self.doHitTestOnExistingPlanes(self.sceneView.center)
            
        if(currentPosition == nil || result == nil){
            return (er, nil, nil)
        }
        else{
            // Makes a new sphere with the created method
            let sphere = SphereNode(at: currentPosition!, color: self.nodeColor)
            
            // Checks if there is at least one sphere in the array
            if let last = spheres.last {

                let distance = sphere.distance(to: last)

                //self.showMeasure(distance)
                measurementLabel.text = ""
                
                let measureLine = LineNode(from: last.position, to: sphere.position, lineColor: self.textColor)

                // remove any previous target and lines, if any.
                lineNode?.removeFromParentNode()
                lineNode = nil
                targetNode?.removeFromParentNode()
                targetNode = nil

                // Adds a second sphere to the array
                spheres.append(sphere)
                self.sceneView.scene.rootNode.addChildNode(sphere)
                
                // add line
                lineNode = measureLine
                self.sceneView.scene.rootNode.addChildNode(measureLine)
                
                // add text node last
                let textNode = TextNode(between: last.position, and: sphere.position, textLabel: self.getMeasureString(distance), textColor: self.nodeColor, sceneView: self.sceneView)
                self.textNode = textNode
                
                self.sceneView.scene.rootNode.addChildNode(textNode)
                
                return (nil, distance, result!.distance)

            // If there are no spheres...
            } else {
                // Add the sphere
                spheres.append(sphere)
                self.sceneView.scene.rootNode.addChildNode(sphere)
                
                return (nil, nil, result!.distance)
            }
        }
    }
    
    // Takes a PNG picture of the scene.
    // Calls completion handler with a string if there was an error
    // or nil otherwise.
    // Must be called on UI thread
    func takePicture(_ path : String, completion: @escaping (String?) -> Void)
    {
        if(!arReady){
            completion("Not ready")
        }
        
        let image = sceneView.snapshot()
        
        DispatchQueue.global(qos: .background).async {
            if let data = image.pngData() {
                let fileUrl = URL(fileURLWithPath: path)
                
                do{
                    try data.write(to: fileUrl)
                    completion(nil)
                }
                catch let error  {
                    completion("Failed to write image to path: " + error.localizedDescription)
                }
            }
            else{
                completion("Failed to save image.")
            }
        }
    }

    // MARK: Private properties
    private var sceneView = ARSCNView()
    private var coachingView : ARCoachingOverlayView? = nil
    private var spheres: [SCNNode] = []
    private var measurementLabel = UILabel()
    
    // colors good enough for white surfaces
    private let nodeColor : UIColor = UIColor(red: 255/255.0, green: 153/255.0, blue: 0, alpha: 1)
    private let nodeColorErr : UIColor = UIColor(red: 240/255.0, green: 0, blue: 0, alpha: 1)
    private let textColor : UIColor = UIColor(red: 255/255.0, green: 153/255.0, blue: 0, alpha: 1)
    private let fontSize : CGFloat = 16
    
    private var lineNode : LineNode? = nil
    private var targetNode: TargetNode? = nil
    private var textNode : TextNode? = nil
    private var arReady : Bool = false
    private var arStatus : String = "off"
    private var measuringStatus : String = "off"

    
    // MARK: Class lifecycle methods

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    deinit {
//        sceneView.session.pause()
//        arReady = false
//        arStatus = "off"
//        measuringStatus = "off"
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        sceneView.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        
        // measurement label, slightly smaller in height
        // so we don't overlap with the center
        measurementLabel.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height - fontSize * 4)
                                        
        sceneView.setNeedsDisplay()
        measurementLabel.setNeedsDisplay()
    }
    
    public override func willMove(toSuperview newSuperview: UIView?){
        super.willMove(toSuperview: newSuperview)
        
        if(newSuperview == nil){
            
            // remove gesture handlers, delegates, and stop session
            coachingView?.removeFromSuperview()
            coachingView = nil
            
            sceneView.gestureRecognizers?.removeAll()
            sceneView.delegate = nil
            sceneView.session.delegate = nil
            sceneView.session.pause()
            arReady = false
            arStatus = "off"
            measuringStatus = "off"
        }
        else{
            
            // Create a session configuration
            let configuration = ARWorldTrackingConfiguration()
            
            configuration.planeDetection = [.vertical, .horizontal]
            
            // this should technically use Lidar sensors and greatly
            // improve accuracy
            if #available(iOS 13.4, *) {
                if(ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)){
                    configuration.sceneReconstruction = .mesh
                }
            } else {
                // Fallback on earlier versions
            }
            
            
            //sceneView.preferredFramesPerSecond = 30
            sceneView.automaticallyUpdatesLighting = true
            //sceneView.debugOptions = [.showFeaturePoints]
            sceneView.showsStatistics = false
            sceneView.antialiasingMode = .multisampling2X
            
            // Set the view's delegate and session delegate
            sceneView.delegate = self
            sceneView.session.delegate = self
            
            // Run the view's session
            arReady = false
            arStatus = "off"
            measuringStatus = "off"
            
            // Add coaching view
            let _coachingView = ARCoachingOverlayView()
            _coachingView.autoresizingMask = [
              .flexibleWidth, .flexibleHeight
            ]
            _coachingView.goal = .anyPlane
            _coachingView.session = sceneView.session
            _coachingView.delegate = self
            _coachingView.activatesAutomatically = true
            coachingView = _coachingView
            
            addSubview(_coachingView)
            
            // start session
            sceneView.session.run(configuration)
            
        }
    }

    private func commonInit() {
        
        // add our main scene view
        addSubview(sceneView)
        
        // Add our main text indixcator
        measurementLabel.backgroundColor = UIColor(white: 1, alpha: 0.0)
        measurementLabel.text = ""
        measurementLabel.textColor = self.textColor
        measurementLabel.font = UIFont.systemFont(ofSize: fontSize, weight: UIFont.Weight.heavy)
        measurementLabel.numberOfLines = 3
        measurementLabel.textAlignment = .center
        addSubview(measurementLabel)
    }
    
    
    // MARK: Coaching delegates
    
    public func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        let status = "loading"
        arReady = false
        if(status != arStatus){
            arStatus = status
            onARStatusChange?(["status": status])
        }
    }
    
    public func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView){
        let status = "ready"
        arReady = true
        if(status != arStatus){
            arStatus = status
            onARStatusChange?(["status": status])
        }
    }
    
    
    // MARK: Session handling ARSessionDelegate
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        arReady = false
        arStatus = "off"
        measuringStatus = "off"
        self.onMountError?(["message": error.localizedDescription])
    }
    
//    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
//        guard let frame = session.currentFrame else { return }
//        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
//    }
//
//    public func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
//        guard let frame = session.currentFrame else { return }
//        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
//    }
//
//    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
//        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
//    }
    
    public func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return false
    }
    
    // renderer callback method
    public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        DispatchQueue.main.async { [weak self] in
            
            guard let self = self else {return}
            
            // update text node if it is rendered
            if(self.textNode != nil){
                self.textNode?.setScale(sceneView: self.sceneView)
            }
            
            // if we have more than 2 nodes, no need to do anything else
            if self.spheres.count > 1 {
                return
            }
            
            // always remoe this since we re-create it every time
            self.lineNode?.removeFromParentNode()
            self.lineNode = nil
            
            if !self.arReady{
                // remove previous target as well
                self.targetNode?.removeFromParentNode()
                self.targetNode = nil
                
                return
            }
            
            
            let mStatus : String
            
            let (err, currentPosition, result) = self.doHitTestOnExistingPlanes(self.sceneView.center)
            
            
            if let position = currentPosition {
            
                // node color if there was an acceptable error
                let color = err != nil ? self.nodeColorErr : self.nodeColor
                
                // if we have 1 node already, draw line
                // also consider if we have errors
                if let start = self.spheres.first {
                    
                    // line node
                    self.lineNode = LineNode(from: start.position, to: position, lineColor: color)
                    self.sceneView.scene.rootNode.addChildNode(self.lineNode!)
                    
                    // target node exists, update it
                    if let target = self.targetNode{
                        target.updatePosition(to: position, color: color)
                    }
                    
                    // otherwise, re-create it
                    else{
                        self.targetNode = TargetNode(at: position, color: color)
                        self.sceneView.scene.rootNode.addChildNode(self.targetNode!)
                    }
                    
                    
                    // only update label if there was no error
                    if(err == nil){
                        self.showMeasure(self.targetNode!.distance(to: start))
                    }
                    
                }
                
                // else, just add a target node
                else{
                    
                    // target node exists, update it
                    if let target = self.targetNode{
                        target.updatePosition(to: position, color: color)
                    }
                    
                    // otherwise, re-create it
                    else{
                        self.targetNode = TargetNode(at: position, color: color)
                        self.sceneView.scene.rootNode.addChildNode(self.targetNode!)
                    }
                }
                
                self.targetNode?.setScaleAndAnchor(sceneView: self.sceneView, hitResult: result!)
                
                mStatus = err == nil ? "ready" : "error"
            }
            else{
                // also remove target if error
                self.targetNode?.removeFromParentNode()
                self.targetNode = nil
                
                mStatus = "error"
            }
            
            if(mStatus != self.measuringStatus){
                self.measuringStatus = mStatus
                self.onMeasuringStatusChange?(["status": mStatus])
            }
            
        }
        
    }
    
    
    
    // MARK: Private functions
    
    private func getMeasureString(_ value: CGFloat) -> String{
        var unitsStr = "m"
        var distance = value
        
        if(self.units == "ft"){
            distance = value * 3.28084
            unitsStr = "ft"
        }

        let formatted = String(format: "%.2f", distance)
        return "\(formatted) \(unitsStr)"
    }
    
    private func showMeasure(_ value: CGFloat) {
        measurementLabel.text = getMeasureString(value)
    }
    
    
    // Returns (error, point, hitTestResult)
    // if there was an error, error will be a non nil string
    // and the rest nil. Otherwise, a vector and hit result are returned
    // if point is not nil, hitResult is guaranteed to be not nil
    private func doHitTestOnExistingPlanes(_ location: CGPoint) -> (String?, SCNVector3?, ARHitTestResult?) {
        
        if(!arReady){
            return ("Not Ready", nil, nil)
        }
        
        // Search with various options
        // using features increases speed but decreases accuracy
        let hitTest = sceneView.hitTest(location, types: self.useFeatureDetection ? [.existingPlaneUsingGeometry, .existingPlaneUsingExtent, .estimatedVerticalPlane, .estimatedHorizontalPlane, .featurePoint] : [.existingPlaneUsingGeometry, .existingPlaneUsingExtent, .estimatedVerticalPlane, .estimatedHorizontalPlane])
        
        let _result : ARHitTestResult?
        
        
        // Try to get the most accurate results first.
        // That is, the result has an anchor, and is further than our min distance
        if let firstAnchor = hitTest.first(where: {($0.anchor as? ARPlaneAnchor) != nil && $0.distance >= self.minDistanceCamera}) {
            _result = firstAnchor
        }
        else{
            // else, fallback to filter the first one further away
            if let firstMatch = hitTest.first(where: {$0.distance >= self.minDistanceCamera}) {
                _result = firstMatch
            }
            else{
                // lastly, just use the first result
                _result = hitTest.first
            }
        }
        
        // Assigns the most accurate result to a constant if it is non-nil
        guard let result = _result else {
            measurementLabel.text = "Please check your lightning and make sure you are not too far from the surface."
            return ("Detection failed", nil, nil)
        }
        
        
        // for distance errors, still return hit point for max error
        // so we allow rendering anyways
        let hitPos = SCNVector3.positionFrom(matrix: result.worldTransform)
        
        if(result.distance < self.minDistanceCamera){
            measurementLabel.text = "Make sure you are not too close to the surface, or improve lightning conditions."
            
            return ("Detection failed: too close to the surface", nil, nil)
        }
        
        if(result.distance > self.maxDistanceCamera){
            measurementLabel.text = "Make sure you are not too far from the surface, or improve lightning conditions."
            
            return ("Detection failed: too far from the surface", hitPos, result)
        }
        
        measurementLabel.text = ""
        
        return (nil, hitPos, result)
    }
    
    
//    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
//        // Update the UI to provide feedback on the state of the AR experience.
//        let message: String
//        let status: String
//
//        switch trackingState {
//            case .normal where frame.anchors.isEmpty:
//                // No planes detected; provide instructions for this app's AR interactions.
//                message = "To begin, move the device around the area to improve subsequent measurement accuracy."
//                status = "no_anchors"
//                arReady = false
//
//            case .notAvailable:
//                message = "Tracking unavailable."
//                status = "not_available"
//                arReady = false
//
//            case .limited(.excessiveMotion):
//                message = "Move the device more slowly."
//                status = "excessive_motion"
//                arReady = false
//
//            case .limited(.insufficientFeatures):
//                message = "Point the device at a visible surface, or improve lightning conditions."
//                status = "insufficient_features"
//                arReady = false
//
//            case .limited(.initializing):
//                message = "To begin, move the device around the area to improve subsequent measurement accuracy."
//                status = "initializing"
//                arReady = false
//
//            case .limited(.relocalizing):
//                message = "To begin, move the device around the area to improve subsequent measurement accuracy."
//                status = "initializing"
//                arReady = false
//
//            default:
//                // No feedback needed when tracking is normal and planes are visible.
//
//                // if ready not set yet, clear messages
//                if(!arReady){
//                    message = ""
//                    arReady = true
//                }
//
//                // otherwise, leave message as is
//                else{
//                    message = measurementLabel.text ?? ""
//                }
//                status = "ready"
//        }
//
//        measurementLabel.text = message
//
//        if(status != arStatus){
//            arStatus = status
//            onARStatusChange?(["status": status])
//        }
//    }
}


extension SCNNode {
    
    // Gets distance between two SCNNodes in meters
    func distance(to destination: SCNNode) -> CGFloat {
        return position.distance(to: destination.position)
    }
}

extension SCNVector3 {
    func distance(to destination: SCNVector3) -> CGFloat {
        let dx = destination.x - x
        let dy = destination.y - y
        let dz = destination.z - z
        return CGFloat(sqrt(dx*dx + dy*dy + dz*dz))
    }
    
    static func positionFrom(matrix: matrix_float4x4) -> SCNVector3 {
        let column = matrix.columns.3
        return SCNVector3(column.x, column.y, column.z)
    }
}

class LineNode: SCNNode {
    
    init(from vectorA: SCNVector3, to vectorB: SCNVector3, lineColor color: UIColor) {
        super.init()
        
        //let height = self.distance(from: vectorA, to: vectorB)
        let height = vectorA.distance(to: vectorB)
        
        self.position = vectorA
        let nodeVector2 = SCNNode()
        nodeVector2.position = vectorB
        
        let nodeZAlign = SCNNode()
        nodeZAlign.eulerAngles.x = Float.pi/2
        
        let box = SCNBox(width: 0.003, height: height, length: 0.003, chamferRadius: 0)
        let material = SCNMaterial()
        material.diffuse.contents = color
        box.materials = [material]
        
        
        let nodeLine = SCNNode(geometry: box)
        nodeLine.position.y = Float(-height/2) + 0.003
        nodeZAlign.addChildNode(nodeLine)
        
        self.addChildNode(nodeZAlign)
        
        self.constraints = [SCNLookAtConstraint(target: nodeVector2)]
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
}

class SphereNode: SCNNode {
    
    init(at position: SCNVector3, color nodeColor: UIColor) {
        super.init()
        
        // material
        let material = SCNMaterial()
        material.diffuse.contents = nodeColor
        material.lightingModel = .constant
        
        // Creates an SCNSphere with a radius
        let sphere = SCNSphere(radius: 0.01)
        sphere.firstMaterial = material
        
        // Positions the node based on the passed in position
        self.geometry = sphere
        self.position = position
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}


@available(iOS 13, *)
class TargetNode: SCNNode {
        
    init(at position: SCNVector3, color nodeColor: UIColor) {
        super.init()
        
        // add circle/donut
        let donutMaterial = SCNMaterial()
        donutMaterial.diffuse.contents = nodeColor.withAlphaComponent(0.9)
        donutMaterial.lightingModel = .constant
        
        let donut = SCNTube(innerRadius: 0.08 - 0.005, outerRadius: 0.08, height: 0.001)
        donut.firstMaterial = donutMaterial
        
        let donutNode = SCNNode(geometry: donut)
        donutNode.name = "donut"
        self.addChildNode(donutNode)
        
        // Add sphere
        let sphereMaterial = SCNMaterial()
        sphereMaterial.diffuse.contents = nodeColor
        sphereMaterial.lightingModel = .constant
        
        let sphere = SCNSphere(radius: 0.01)
        sphere.firstMaterial = sphereMaterial
        
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.name = "sphere"
        self.addChildNode(sphereNode)
        
        // Positions the node based on the passed in position
        self.position = position
    }
    
    // update the node position so we don't need to re-create it every time
    // and optionally its color
    func updatePosition(to position: SCNVector3, color nodeColor: UIColor?){
        self.position = position
        
        if let color = nodeColor {
            self.childNode(withName: "donut", recursively: false)?.geometry?.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.9)
            
            self.childNode(withName: "sphere", recursively: false)?.geometry?.firstMaterial?.diffuse.contents = color
        }
    }
    
    func setScaleAndAnchor(sceneView view : ARSCNView, hitResult hit: ARHitTestResult){
//        if let pov = view.pointOfView {
//            let distance = pov.distance(to: self)
//            let scale = Float((CGFloat(0.5) * distance))
//            self.scale = SCNVector3Make(scale, scale, scale)
//        }
        
        guard let donut = self.childNode(withName: "donut", recursively: false) else {return}
        
        if let _anchor = hit.anchor as? ARPlaneAnchor {
            guard let anchoredNode = view.node(for: _anchor) else { return }
            
            // rotate our donut based on detected anchor
            donut.eulerAngles.x = anchoredNode.eulerAngles.x
            donut.eulerAngles.y = anchoredNode.eulerAngles.y
            donut.eulerAngles.z = anchoredNode.eulerAngles.z
            
            
        }
        else{
            
            // no anchor, check result type
            // if it is estimated vertical, rotate
            if(hit.type == .estimatedVerticalPlane){
                
                // set transform directly so we dont need to do math
                // then restore values. This is needed since worldTransform doesnt provide eulerAngles
                let dummy = SCNNode()
                dummy.transform = SCNMatrix4(hit.worldTransform)
                donut.eulerAngles.x = .pi / 2
                donut.eulerAngles.y = dummy.eulerAngles.y
                donut.eulerAngles.z = 0
            }
            
            // in any other case, assume horizontal
            else{
                donut.eulerAngles.x = 0
                donut.eulerAngles.y = 0
                donut.eulerAngles.z = 0
            }

        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}


@available(iOS 13, *)
class TextNode: SCNNode {
    
    private let extrusionDepth: CGFloat = 0.1
    
    init(between vectorA: SCNVector3, and vectorB: SCNVector3, textLabel label: String, textColor color: UIColor, sceneView view : ARSCNView) {
        super.init()
        
        let constraint = SCNBillboardConstraint()
        
        
        let text = SCNText(string: label, extrusionDepth: extrusionDepth)
        text.font = UIFont.systemFont(ofSize: 5, weight: UIFont.Weight.heavy)
        text.firstMaterial?.diffuse.contents = color
        text.firstMaterial?.isDoubleSided = true
        
        // allows it to stay on top of lines and other stuff
        text.firstMaterial?.readsFromDepthBuffer = false
        text.firstMaterial?.writesToDepthBuffer = false
        
        let x = (vectorA.x + vectorB.x) / 2
        let y = (vectorA.y + vectorB.y) / 2
        let z = (vectorA.z + vectorB.z) / 2
        
        let max = text.boundingBox.max
        let min = text.boundingBox.min
        let tx = (max.x + min.x) / 2.0
        let ty = (max.y + min.y) / 2.0
        let tz = Float(extrusionDepth) / 2.0
        
        // main node positioning
        self.pivot = SCNMatrix4MakeTranslation(tx, ty, tz)
        self.geometry = text
        self.position = SCNVector3(x, y, z)
        self.constraints = [constraint]
        self.renderingOrder = 10
        self.setScale(sceneView: view)
        
        
        // Add background
        let bound = SCNVector3Make(max.x - min.x,
                                   max.y - min.y,
                                   max.z - min.z);

        let plane = SCNPlane(width: CGFloat(bound.x + 3),
                            height: CGFloat(bound.y + 3))
        
        plane.cornerRadius = 5
        plane.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.9)
        plane.firstMaterial?.readsFromDepthBuffer = false
        plane.firstMaterial?.writesToDepthBuffer = false

        let planeNode = SCNNode(geometry: plane)
        planeNode.position = SCNVector3(
            CGFloat(min.x) + CGFloat(bound.x) / 2,
            CGFloat(min.y) + CGFloat(bound.y) / 2,
            CGFloat(min.z) - extrusionDepth
        )
        
        self.addChildNode(planeNode)
    }
    
    func setScale(sceneView view : ARSCNView){
        guard let pov = view.pointOfView else {
            return
        }
        let distance = pov.distance(to: self)
        let scale = Float((CGFloat(0.01) * distance))
        self.scale = SCNVector3Make(scale, scale, scale)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
}
