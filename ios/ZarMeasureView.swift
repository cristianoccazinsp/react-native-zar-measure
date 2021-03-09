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
    @objc public var intersectDistance: CGFloat = 0.1
    @objc public var debugMode = false
    @objc public var onARStatusChange: RCTDirectEventBlock? = nil
    @objc public var onMeasuringStatusChange: RCTDirectEventBlock? = nil
    @objc public var onMountError: RCTDirectEventBlock? = nil
    @objc public var onTextTap: RCTDirectEventBlock? = nil
    
    // MARK: Public methods
    
    
    @objc public var torchOn = false {
        didSet {
            toggleTorch(torchOn)
        }
    }
    
    // Removes all nodes and lines
    // Must be called on UI thread
    func clear()
    {
        // no need for locks since everything runs on the UI thread
        measurements.removeAll()
        lineNode?.removeFromParentNode()
        targetNode?.removeFromParentNode()
        currentNode?.removeFromParentNode()
     
        while let n = rootNode.childNodes.first { n.removeFromParentNode()
        }
        
        lineNode = nil
        targetNode = nil
        currentNode = nil
        measurementLabel.text = ""
        lastHitResult = (nil, nil)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // removes the current measurement step, if any
    func clearCurrent()
    {
        if let current = currentNode {
            current.removeFromParentNode()
            lineNode?.removeFromParentNode()
            currentNode = nil
            lineNode = nil
            lastHitResult = (nil, nil)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    // removes the last added measurement
    func removeLast()
    {
        if let current = currentNode {
            current.removeFromParentNode()
            lineNode?.removeFromParentNode()
            currentNode = nil
            lineNode = nil
            lastHitResult = (nil, nil)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        else if let last = measurements.last{
            last.line.removeFromParentNode()
            last.node1.removeFromParentNode()
            last.node2.removeFromParentNode()
            last.text.removeFromParentNode()
            measurements.removeLast()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    func removeMeasurement(_ id:String) -> MeasurementLine?
    {
        guard let idx = measurements.firstIndex(where: {$0.id == id}) else { return nil}
        
        let node = measurements[idx]
        measurements.remove(at: idx)
        
        node.line.removeFromParentNode()
        node.node1.removeFromParentNode()
        node.node2.removeFromParentNode()
        node.text.removeFromParentNode()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        return node.toDict()
    }
    
    func editMeasurement(_ id:String, _ text:String) -> MeasurementLine?
    {
        guard let idx = measurements.firstIndex(where: {$0.id == id}) else { return nil}
        
        let node = measurements[idx]
        
        // remove node, and create a new one with the text
        node.text.removeFromParentNode()
        
        node.text = TextNode(between: node.node1.position, and: node.node2.position, textLabel: text, textColor: self.nodeColor)
        node.text.id = node.id
        node.text.setScale(sceneView: self.sceneView)
        
        self.rootNode.addChildNode(node.text)
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        return node.toDict()
    }
    
    func getMeasurements() -> [MeasurementLine]{
        return measurements.enumerated().map { (index, element) in
            return element.toDict()
        }
    }
    
    // Adds a new point (or calculates distance if there was one already)
    // returns (err, measurement, cameraDistance)
    // if setCurrent is true, sets the newly added point as the current one
    func addPoint(_ setCurrent : Bool) -> (String?, MeasurementLine?, CGFloat?)
    {
        
        let (er, resultx) = self.lastHitResult
        
        defer {
            // clear hit results on adding point so we refresh existing nodes
            // due to some shapes needing to change
            self.lastHitResult = (nil, nil)
        }
        
        guard let result = resultx else {
            return (er, nil, nil)
        }
        
        
        // Makes a new sphere with the created method
        let sphere = SphereNode(at: result.position, color: self.nodeColor)
        sphere.setScale(sceneView: self.sceneView)
        
        // If we have a current node
        if let current = currentNode {

            let distance = sphere.distance(to: current)

            //self.showMeasure(distance)
            measurementLabel.text = ""

            // remove any previous target and lines, if any.
            lineNode?.removeFromParentNode()
            lineNode = nil
            targetNode?.removeFromParentNode()
            targetNode = nil

            // Adds a new measurement and clear current node
            
            let newText = TextNode(between: current.position, and: sphere.position, textLabel: self.getMeasureString(distance), textColor: self.nodeColor)
            newText.setScale(sceneView: self.sceneView)
            
            let newLine = LineNode(from: current.position, to: sphere.position, lineColor: self.textColor)
            newLine.setScale(sceneView: self.sceneView, in: newText)
           
            let newMeasure = MeasurementGroup(getNextId(), current, sphere, newLine, newText, distance)
            measurements.append(newMeasure)
            
            // add all objects to the scene
            self.rootNode.addChildNode(sphere)
            self.rootNode.addChildNode(newLine)
            self.rootNode.addChildNode(newText)
            
            // clear current node to allow new measurement
            if setCurrent{
                // clone it
                currentNode = SphereNode(at: sphere.position, color: self.nodeColor)
                currentNode?.setScale(sceneView: self.sceneView)
                self.rootNode.addChildNode(currentNode!)
            }
            else {
                currentNode = nil
            }
            
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            return (nil, newMeasure.toDict(), result.distance)

        } else {
            // Add the sphere as the current node
            currentNode = sphere
            self.rootNode.addChildNode(sphere)
            
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return (nil, nil, result.distance)
        }
        
    }
    
    // Takes a PNG picture of the scene.
    // Calls completion handler with a string if there was an error
    // or nil otherwise.
    // Must be called on UI thread
    func takePicture(_ path : String, completion: @escaping (String?, [MeasurementLine2D]) -> Void)
    {
        if(!arReady){
            completion("Not ready", [])
        }
        
        takingPicture = true
        // temporary remove target nodes from view
        targetNode?.isHidden = true
        lineNode?.isHidden = true
        
        let image = sceneView.snapshot()
        var points : [MeasurementLine2D] = []
        var idx = 0
        
        for m in measurements {
            if let d = m.toDict2D(sceneView){
                points.append(d)
            }
            idx += 1
        }
        
        // re add it back
        targetNode?.isHidden = false
        lineNode?.isHidden = false
        
        takingPicture = false
        
        DispatchQueue.global(qos: .background).async {
            if let data = image.pngData() {
                let fileUrl = URL(fileURLWithPath: path)
                
                do{
                    try data.write(to: fileUrl)
                    completion(nil, points)
                }
                catch let error  {
                    completion("Failed to write image to path: " + error.localizedDescription, [])
                }
            }
            else{
                completion("Failed to save image.", [])
            }
        }
    }

    // MARK: Private properties
    private var sceneView = ARSCNView()
    private var sceneCenter = CGPoint(x: 0, y: 0)
    private var rootNode = SCNNode()
    private var coachingView : ARCoachingOverlayView = ARCoachingOverlayView()
    private var lastHitResult: (String?, HitResult?) = (nil, nil)
    private var takingPicture = false
    
    // throttle some operations
    private var donutScaleTimeout = 0.4
    private var nodesScaleTimeout = 0.1
    private var closeNodeTimeout = 0.8
    private var donutLastScaled = TimeInterval(0)
    private var nodesLastScaled = TimeInterval(0)
    private var closeNodeLastTime = TimeInterval(0)
    
    // colors good enough for white surfaces
    private let nodeColor : UIColor = UIColor(red: 255/255.0, green: 153/255.0, blue: 0, alpha: 1)
    private let nodeColorErr : UIColor = UIColor(red: 240/255.0, green: 0, blue: 0, alpha: 1)
    private let nodeColorClose : UIColor = UIColor(red: 0, green: 153/255.0, blue: 51/255.0, alpha: 1)
    private let textColor : UIColor = UIColor(red: 255/255.0, green: 153/255.0, blue: 0, alpha: 1)
    private let fontSize : CGFloat = 16
    
    private var measurementLabel = UILabel() // general purpose message
    
    private var nodeId = 1
    private var measurements: [MeasurementGroup] = []
    private var currentNode : SphereNode? = nil // to start a measurement
    private var lineNode : LineNode? = nil
    private var targetNode: TargetNode? = nil
    
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
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        sceneView.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        sceneCenter = sceneView.center
        
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
            
            coachingView.delegate = nil
            coachingView.session = nil
            
            sceneView.gestureRecognizers?.removeAll()
            sceneView.delegate = nil
            sceneView.session.delegate = nil
            sceneView.session.pause()
            toggleTorch(false)
            
            arReady = false
            arStatus = "off"
            measuringStatus = "off"
        }
        else{
            
            // Create a session configuration
            let configuration = ARWorldTrackingConfiguration()
            
            configuration.planeDetection = [.vertical, .horizontal]
            configuration.worldAlignment = .gravity
            configuration.isLightEstimationEnabled = false
            
            // this should technically use Lidar sensors and greatly
            // improve accuracy
            if #available(iOS 13.4, *) {
                if(ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)){
                    configuration.sceneReconstruction = .mesh
                }
            } else {
                // Fallback on earlier versions
            }
        
            
            sceneView.preferredFramesPerSecond = 30
            sceneView.automaticallyUpdatesLighting = false
            sceneView.rendersCameraGrain = false
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
            coachingView.delegate = self
            coachingView.session = sceneView.session
            
            // start session
            sceneView.session.run(configuration)
            
            // run this afterwards, for some reason the session takes time to start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else {return}
                
                if self.sceneView.delegate != nil && !self.coachingView.isActive && !self.arReady {
                    self.coachingView.setActive(true, animated: true)
                }
            }
            
            // add tap gestures as well
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            tapGestureRecognizer.cancelsTouchesInView = false
            self.sceneView.addGestureRecognizer(tapGestureRecognizer)
            
            toggleTorch(self.torchOn)
        }
    }

    
    // MARK: Coaching delegates
    
    public func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        let status = "loading"
        arReady = false
        measurementLabel.text = ""
        
        if(status != arStatus){
            arStatus = status
            onARStatusChange?(["status": status])
        }
    }
    
    public func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView){
        let status = "ready"
        arReady = true
        measurementLabel.text = ""
        
        if(status != arStatus){
            arStatus = status
            onARStatusChange?(["status": status])
        }
    }
    
    
    // MARK: Session handling delegates
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        arReady = false
        arStatus = "off"
        measuringStatus = "off"
        self.onMountError?(["message": error.localizedDescription])
    }
    
    public func sessionInterruptionEnded(_ session: ARSession) {
        // if interruption ended and we had flash, try to turn it on again
        if torchOn {
            toggleTorch(true)
        }
    }
    
    public func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return false
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if(!debugMode) { return }
        
        // Place content only for anchors found by plane detection.
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        // Create a node to visualize the plane's bounding rectangle.
        // Create a custom object to visualize the plane geometry and extent.
        let color = planeAnchor.alignment == .vertical ? self.nodeColor : self.nodeColorClose
        let plane = DebugPlane(anchor: planeAnchor, in: sceneView, withColor: color)
        
        // Add the visualization to the ARKit-managed node so that it tracks
        // changes in the plane anchor as plane estimation continues.
        node.addChildNode(plane)
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if(!debugMode) { return }
        
        // Update only anchors and nodes set up by `renderer(_:didAdd:for:)`.
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let plane = node.childNodes.first as? DebugPlane
            else { return }
        
        // Update ARSCNPlaneGeometry to the anchor's new estimated shape.
        if let planeGeometry = plane.meshNode.geometry as? ARSCNPlaneGeometry {
            planeGeometry.update(from: planeAnchor.geometry)
        }

        // Update extent visualization to the anchor's new bounding rectangle.
        if let extentGeometry = plane.extentNode.geometry as? SCNPlane {
            extentGeometry.width = CGFloat(planeAnchor.extent.x)
            extentGeometry.height = CGFloat(planeAnchor.extent.z)
            plane.extentNode.simdPosition = planeAnchor.center
        }
    }
    
    // renderer callback method
    public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        if(takingPicture){
            return
        }
        
        // these always need to be updated
        DispatchQueue.main.async { [weak self] in
            
            guard let self = self else {return}
            
            // update text and nodes scales from measurements
            if (time - self.nodesScaleTimeout > self.nodesScaleTimeout){
                
                for t in self.measurements {
                    t.text.setScale(sceneView: self.sceneView)
                    t.node1.setScale(sceneView: self.sceneView)
                    t.node2.setScale(sceneView: self.sceneView)
                    t.line.setScale(sceneView: self.sceneView, in: t.text)
                }
                
                // scale now, and maybe later
                self.targetNode?.setSphereScale(sceneView: self.sceneView)
                
                self.nodesLastScaled = time
            }
            
            if !self.arReady{
                // remove previous nodes
                self.lineNode?.removeFromParentNode()
                self.lineNode = nil
                self.targetNode?.removeFromParentNode()
                self.targetNode = nil
                self.currentNode?.removeFromParentNode()
                self.currentNode = nil
            }
        }
        
        
        if !arReady {
            lastHitResult = (nil, nil)
            return
        }
        
        let (err, result) = doRayTestOnExistingPlanes(sceneCenter)
        var mustVibrate = false
        
        // if distance between current and last did not change considerably, do nothing
        if let _result = result, let _prev = lastHitResult.1 {
            
            mustVibrate = (_prev.isCloseNode != _result.isCloseNode)
            
            // only do these if error flag didnt change
            if err == lastHitResult.0 {
                let dist = _result.position.distance(to: _prev.position)
                
                // if distance did not change (significantly)
                if dist < _result.distance * 0.002 {
                    return
                }
                
                // otherwise, if we had a close node, check timeout
                if _prev.isCloseNode && (time - self.closeNodeLastTime < self.closeNodeTimeout) {
                    return
                }
                
                if _result.isCloseNode {
                    self.closeNodeLastTime = time
                }
            }
        }
        
        self.lastHitResult = (err, result)
        
        DispatchQueue.main.async { [weak self] in
            
            guard let self = self else {return}
            
            if !self.arReady {
                return
            }
            
            
            let mStatus : String
            
            // remove these since they are always re-created
            // and set/clear label
            self.lineNode?.removeFromParentNode()
            self.lineNode = nil
            self.measurementLabel.text = err != nil ? err : ""
            
            if let position = result?.position, let closeNode = result?.isCloseNode {
            
                // node color if there was an acceptable error
                let color = err != nil ? self.nodeColorErr : (closeNode ? self.nodeColorClose : self.nodeColor)
                
                // if we have 1 node already, draw line
                // also consider if we have errors
                if let start = self.currentNode {
                    
                    // line node
                    self.lineNode = LineNode(from: start.position, to: position, lineColor: color)
                    self.rootNode.addChildNode(self.lineNode!)
                    
                    // target node exists, update it
                    if let target = self.targetNode{
                        target.updatePosition(to: position, color: color)
                    }
                    
                    // otherwise, re-create it
                    else{
                        self.targetNode = TargetNode(at: position, color: color)
                        self.rootNode.addChildNode(self.targetNode!)
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
                        self.rootNode.addChildNode(self.targetNode!)
                    }
                }
                
                
                // throttle rotation changes to avoid odd effects
                if (time - self.donutScaleTimeout > self.donutScaleTimeout * 2){
                    self.targetNode?.setDonutScale(sceneView: self.sceneView, hitResult: result!, animation: self.donutScaleTimeout)
                    
                    self.donutLastScaled = time
                }
                
                // vibration on close changes
                if mustVibrate {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                
                mStatus = err == nil ? "ready" : "error"
            }
            else{
                // also remove target if error
                self.targetNode?.removeFromParentNode()
                self.targetNode = nil
                
                mStatus = "error"
            }
            
            // if target node, scale it at the end even if error
            self.targetNode?.setSphereScale(sceneView: self.sceneView)
            
            if let lineNode = self.lineNode, let targetNode = self.targetNode {
                lineNode.setScale(sceneView: self.sceneView, in: targetNode)
            }
            
            if(mStatus != self.measuringStatus){
                self.measuringStatus = mStatus
                self.onMeasuringStatusChange?(["status": mStatus])
            }
        }
    }
    
    
    // MARK gesture handling
    
    @objc func handleTap(sender:UITapGestureRecognizer) {
        if !arReady {
            return
        }
        
        guard let sceneView = sender.view as? ARSCNView else {return}
        let touchLocation = sender.location(in: sceneView)
        let result = sceneView.hitTest(touchLocation, options: [SCNHitTestOption.searchMode: 1, SCNHitTestOption.rootNode: rootNode])
        
        // search all results to see if we have a text node
        // in one of our measurements
        for r in result {
            
            // we may get a hit on the plane node, or text node
            let textNode: TextNode?
            
            if r.node.name == "textnode" {
                textNode = r.node as? TextNode
            }
            else if r.node.parent?.name == "textnode"{
                textNode = r.node.parent as? TextNode
            }
            else {
                continue
            }
            
            
            if let _textNode = textNode {
                if let measurement = measurements.first(where: {_textNode.id == $0.id}){
                    self.onTextTap?(["measurement": measurement.toDict(), "location": ["x": touchLocation.x, "y": touchLocation.y]])
                    
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    
                    return
                }
            }
        }
    }
    
    
    // MARK: Private functions
    
    private func commonInit() {
        
        // add our main scene view
        addSubview(sceneView)
        
        // add our main root node
        sceneView.scene.rootNode.addChildNode(rootNode)
        
        // coaching view
        coachingView.autoresizingMask = [
          .flexibleWidth, .flexibleHeight
        ]
        coachingView.goal = .anyPlane
        coachingView.activatesAutomatically = true
        addSubview(coachingView)
        
        // Add our main text indixcator
        measurementLabel.backgroundColor = UIColor(white: 1, alpha: 0.0)
        measurementLabel.text = ""
        measurementLabel.textColor = self.textColor
        measurementLabel.font = UIFont.systemFont(ofSize: fontSize, weight: UIFont.Weight.heavy)
        measurementLabel.numberOfLines = 3
        measurementLabel.textAlignment = .center
        addSubview(measurementLabel)
    }
    
    private func getNextId() -> String {
        let next = String(nodeId)
        nodeId += 1
        return next
    }
    
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
    
    private func doRayTestOnExistingPlanes(_ location: CGPoint) -> (String?, HitResult?) {
        
        if(!arReady){
            return ("Not Ready.", nil)
        }
        
        guard let cameraTransform = sceneView.session.currentFrame?.camera.transform else {
            return ("Camera position is unknown.", nil)
        }
        
        let cameraPos = SCNVector3.positionFrom(matrix: cameraTransform)
        
        guard let query = sceneView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .any) else{
            
            // this should never happen
            return ("Detection failed.", nil)
        }
        
        var hitTest = sceneView.session.raycast(query)
        
        // if hit test count is 0, try with an infinite plane
        // this matches more the native app, and prevents us from getting lots of error messages
        if hitTest.count == 0 {
            guard let queryInfinite = sceneView.raycastQuery(from: location, allowing: .existingPlaneInfinite, alignment: .any) else{
                
                // this should never happen
                return ("Detection failed.", nil)
            }
            
            hitTest = sceneView.session.raycast(queryInfinite)
        }
        
            
        // Try to get the most accurate results first.
        // That is, the result has an anchor, and is further than our min distance
        var _result : ARRaycastResult? = nil
        
        
        // first try to get a point that meets min distance
        // no need to check for anchors anymore.
        for r in hitTest {
            if r.distanceFromCamera(cameraPos) >= minDistanceCamera{
                _result = r
                break
            }
        }
        
        // nothing, use first
        if _result == nil {
            _result = hitTest.first
        }
        
        // Assigns the most accurate result to a constant if it is non-nil
        guard let raycastResult = _result else {
            return ("Please check your lightning and make sure you are not too far from the surface.", nil)
        }
        
        let hitPos = SCNVector3.positionFrom(matrix: raycastResult.worldTransform)
        let distance = cameraPos.distance(to: hitPos)
        let closeNode = findNearSphere(hitPos, intersectDistance * distance)
            
        let result = HitResult(distance, closeNode?.position ?? hitPos, closeNode != nil, raycastResult)
        
        
        if(result.distance < self.minDistanceCamera){
            return ("Make sure you are not too close to the surface, or improve lightning conditions.", nil)
        }
        
        // for distance errors, still return hit point for max error
        // so we allow rendering anyways and let the UI handle it
        if(result.distance > self.maxDistanceCamera){
            return ("Make sure you are not too far from the surface, or improve lightning conditions.", result)
        }
        
        return (nil, result)
    }
    
    // given a hit result, searches measurements
    // to find a close match
    func findNearSphere(_ to : SCNVector3, _ minDistance:CGFloat) -> SphereNode? {
        for m in measurements {
            if m.node1.position.distance(to: to) < minDistance {
                return m.node1
            }
            if m.node2.position.distance(to: to) < minDistance {
                return m.node2
            }
        }
        return nil
    }
    
    func toggleTorch(_ on: Bool){
        // delay torch and make sure it runs on the UI thread
        DispatchQueue.main.asyncAfter(deadline: .now() + (on ? 0.5 : 0.1)) {
            guard let device = AVCaptureDevice.default(for: AVMediaType.video)
            else {return}

            if device.hasTorch {
                do {
                    try device.lockForConfiguration()

                    if on {
                        device.torchMode = .on // set on
                    } else {
                        device.torchMode = .off // set off
                    }

                    device.unlockForConfiguration()
                } catch {
                    NSLog("Torch could not be used")
                }
            } else {
                NSLog("Torch is not available")
            }
        }
    }
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


@available(iOS 13.0, *)
extension ARRaycastResult {
    func distanceFromCamera(_ from: ARSCNView) -> CGFloat? {
        
        guard let cameraTransform = from.session.currentFrame?.camera.transform else {
            return nil
        }
        
        return SCNVector3.positionFrom(matrix: cameraTransform).distance(to: SCNVector3.positionFrom(matrix: worldTransform))
    }
    
    func distanceFromCamera(_ from : SCNVector3) -> CGFloat {
        return from.distance(to: SCNVector3.positionFrom(matrix: worldTransform))
    }
}


@available(iOS 11.0, *)
class LineNode: SCNNode {
    private let box = SCNBox()
    private let width = CGFloat(0.002)
    
    init(from vectorA: SCNVector3, to vectorB: SCNVector3, lineColor color: UIColor) {
        super.init()
        
        //let height = self.distance(from: vectorA, to: vectorB)
        let height = vectorA.distance(to: vectorB)
        
        self.position = vectorA
        let nodeVector2 = SCNNode()
        nodeVector2.position = vectorB
        
        let nodeZAlign = SCNNode()
        nodeZAlign.eulerAngles.x = Float.pi/2
        
        // initialize box
        box.width = width
        box.height = height
        box.length = width
        box.chamferRadius = 0
        
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.readsFromDepthBuffer = false
        material.writesToDepthBuffer = false
        box.materials = [material]
        
        
        let nodeLine = SCNNode(geometry: box)
        nodeLine.renderingOrder = 0
        nodeLine.position.y = Float(-height/2) + 0.001
        nodeZAlign.addChildNode(nodeLine)
        
        self.addChildNode(nodeZAlign)
        
        self.constraints = [SCNLookAtConstraint(target: nodeVector2)]
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setScale(sceneView view : ARSCNView, in relationTo:SCNNode){
        guard let pov = view.pointOfView else {
            return
        }
        let distance = min(pov.distance(to: relationTo), 5)
        let scale = CGFloat(0.5 + distance * 0.8)
        
        box.width = CGFloat(width * scale)
        box.length = CGFloat(width * scale)
    }
}


@available(iOS 11.0, *)
class SphereNode: SCNNode {
    
    init(at position: SCNVector3, color nodeColor: UIColor) {
        super.init()
        
        // material
        let material = SCNMaterial()
        material.diffuse.contents = nodeColor
        material.lightingModel = .constant
        material.readsFromDepthBuffer = false
        material.writesToDepthBuffer = false
        
        // Creates an SCNSphere with a radius
        let sphere = SCNSphere(radius: 0.008)
        sphere.firstMaterial = material
        
        // Positions the node based on the passed in position
        self.geometry = sphere
        self.position = position
        self.renderingOrder = 0
    }
    
    func setScale(sceneView view : ARSCNView){
        guard let pov = view.pointOfView else {
            return
        }
        let distance = min(pov.distance(to: self), 5)
        let scale = Float(0.5 + distance * 0.5)
        self.scale = SCNVector3Make(scale, scale, scale)
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
        
        sphereMaterial.readsFromDepthBuffer = false
        sphereMaterial.writesToDepthBuffer = false
        
        let sphere = SCNSphere(radius: 0.008)
        sphere.firstMaterial = sphereMaterial
        
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.name = "sphere"
        sphereNode.renderingOrder = 15
        self.addChildNode(sphereNode)
        
        // Positions the node based on the passed in position
        self.position = position
        self.renderingOrder = 15
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
    
    func setSphereScale(sceneView view : ARSCNView){
        guard let pov = view.pointOfView else {
            return
        }
        guard let sphere = self.childNode(withName: "sphere", recursively: false) else {
            return
        }

        let distance = min(pov.distance(to: self), 5)
        let scale = Float(0.5 + distance * 0.5)
        sphere.scale = SCNVector3Make(scale, scale, scale)
    }
    
    func setDonutScale(sceneView view : ARSCNView, hitResult hit: HitResult, animation duration: Double){
        
        guard let donut = self.childNode(withName: "donut", recursively: false) else {return}
        
        DispatchQueue.main.async {
            // Animate rotation update so it looks nicer
            SCNTransaction.begin()
            SCNTransaction.animationDuration = duration
            
            if let _anchor = hit.anchor {
                guard let anchoredNode = view.node(for: _anchor) else { return }
                
                // rotate our donut based on detected anchor
                donut.eulerAngles.x = anchoredNode.eulerAngles.x
                donut.eulerAngles.y = anchoredNode.eulerAngles.y
                donut.eulerAngles.z = anchoredNode.eulerAngles.z
            }
            else{
                
                let dummy = SCNNode()
                dummy.transform = SCNMatrix4(hit.transform)
                donut.eulerAngles.x = dummy.eulerAngles.x
                donut.eulerAngles.y = dummy.eulerAngles.y
                donut.eulerAngles.z = dummy.eulerAngles.z
            }
            
            SCNTransaction.commit()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}


@available(iOS 13, *)
class TextNode: SCNNode {
    
    private let extrusionDepth: CGFloat = 0.1
    public var id : String?
    public var label = ""
    
    init(between vectorA: SCNVector3, and vectorB: SCNVector3, textLabel label: String, textColor color: UIColor) {
        super.init()
        
        self.label = label
        
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
        
        // Add background
        let bound = SCNVector3Make(max.x - min.x,
                                   max.y - min.y,
                                   max.z - min.z);

        let plane = SCNPlane(width: CGFloat(bound.x + 4),
                            height: CGFloat(bound.y + 4))
        
        plane.cornerRadius = 4
        plane.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.9)
        plane.firstMaterial?.readsFromDepthBuffer = false
        plane.firstMaterial?.writesToDepthBuffer = false

        let planeNode = SCNNode(geometry: plane)
        planeNode.position = SCNVector3(
            CGFloat(min.x) + CGFloat(bound.x) / 2,
            CGFloat(min.y) + CGFloat(bound.y) / 2,
            CGFloat(min.z) - extrusionDepth
        )
        
        planeNode.name = "textnode-plane"
        
        self.addChildNode(planeNode)
        self.name = "textnode"
    }
    
    func setScale(sceneView view : ARSCNView){
        guard let pov = view.pointOfView else {
            return
        }
        let distance = min(pov.distance(to: self), 3)
        let scale = Float(0.001 + 0.007 * distance)
        self.scale = SCNVector3Make(scale, scale, scale)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.label = ""
    }
}


@available(iOS 13.0, *)
class DebugPlane: SCNNode {
    
    let meshNode: SCNNode
    let extentNode: SCNNode
    let color: UIColor
    var classificationNode: SCNNode?
    
    /// - Tag: VisualizePlane
    init(anchor: ARPlaneAnchor, in sceneView: ARSCNView, withColor color: UIColor) {
        
        // Create a mesh to visualize the estimated shape of the plane.
        guard let meshGeometry = ARSCNPlaneGeometry(device: sceneView.device!)
            else { fatalError("Can't create plane geometry") }
        
        meshGeometry.update(from: anchor.geometry)
        meshNode = SCNNode(geometry: meshGeometry)
        
        // Create a node to visualize the plane's bounding rectangle.
        let extentPlane = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        extentNode = SCNNode(geometry: extentPlane)
        extentNode.simdPosition = anchor.center
        
        extentPlane.firstMaterial?.readsFromDepthBuffer = false
        extentPlane.firstMaterial?.writesToDepthBuffer = false
        meshGeometry.firstMaterial?.readsFromDepthBuffer = false
        meshGeometry.firstMaterial?.writesToDepthBuffer = false
        extentNode.renderingOrder = -2
        meshNode.renderingOrder = -1
        
        // `SCNPlane` is vertically oriented in its local coordinate space, so
        // rotate it to match the orientation of `ARPlaneAnchor`.
        extentNode.eulerAngles.x = -.pi / 2
        self.color = color

        super.init()

        self.setupMeshVisualStyle()
        self.setupExtentVisualStyle()

        // Add the plane extent and plane geometry as child nodes so they appear in the scene.
        addChildNode(meshNode)
        addChildNode(extentNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupMeshVisualStyle() {
        // Make the plane visualization semitransparent to clearly show real-world placement.
        //meshNode.opacity = 0.25
        
        // Use color and blend mode to make planes stand out.
        meshNode.geometry?.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.5)
        
    }
    
    private func setupExtentVisualStyle() {
        // Make the extent visualization semitransparent to clearly show real-world placement.
        //extentNode.opacity = 0.6
        extentNode.geometry?.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.5)
    }
}


@available(iOS 13, *)
class HitResult {
    // wrapper for hit results
    var distance : CGFloat
    var transform : simd_float4x4
    var anchor : ARAnchor? = nil
    var position : SCNVector3
    var isCloseNode : Bool
    
    init(_ distance:CGFloat, _ hitPos:SCNVector3, _ closeNode:Bool, _ raycast:ARRaycastResult){
        self.distance = distance
        self.transform = raycast.worldTransform
        self.anchor = raycast.anchor //as? ARPlaneAnchor
        self.position = hitPos
        self.isCloseNode = closeNode
    }
}


public typealias MeasurementLine = Dictionary<String, Any>
public typealias MeasurementLine2D = Dictionary<String, Any>

@available(iOS 13, *)
class MeasurementGroup {
    let id : String
    var node1 : SphereNode
    var node2 : SphereNode
    var line : LineNode
    var text : TextNode
    var distance : Float
    
    init(_ id:String, _ node1:SphereNode, _ node2:SphereNode, _ line:LineNode, _ text:TextNode, _ distance:CGFloat){
        self.id = id
        self.node1 = node1
        self.node2 = node2
        self.line = line
        self.text = text
        self.distance = Float(distance)
        self.text.id = id
    }
    
    func toDict() -> MeasurementLine {
        return [
            "id": id,
            "node1": [
                "x": node1.worldPosition.x,
                "y": node1.worldPosition.y,
                "z": node1.worldPosition.z
            ],
            "node2": [
                "x": node2.worldPosition.x,
                "y": node2.worldPosition.y,
                "z": node2.worldPosition.z
            ],
            "distance": self.distance,
            "label": self.text.label
        ]
    }
    
    // same as to dict, but returns the 2D projections in the current image frame
    func toDict2D(_ view:ARSCNView) -> MeasurementLine2D? {
        
        let size = view.bounds.size
        let orientation = UIApplication.shared.statusBarOrientation
        
        if let camera =  view.session.currentFrame?.camera {
            
            let projected1 = camera.projectPoint(node1.simdWorldPosition, orientation: orientation, viewportSize: size)
            let projected2 = camera.projectPoint(node2.simdWorldPosition, orientation: orientation, viewportSize: size)
                
            
            var res : MeasurementLine2D = [
                "id": id,
                "distance": self.distance,
                "label": self.text.label,
                "bounds": [
                    "width": size.width,
                    "height": size.height
                ]
            ]
            
            if (projected1.x >= 0 && projected1.x <= size.width && projected1.y >= 0 && projected1.y <= size.height){
                
                res["node1"] = [
                    "x": projected1.x,
                    "y": projected1.y
                ]
            }
            
            if (projected2.x >= 0 && projected2.x <= size.width && projected2.y >= 0 && projected2.y <= size.height){
                
                res["node2"] = [
                    "x": projected2.x,
                    "y": projected2.y
                ]
            }
            
            return res
        }
        
        return nil
        
    }
}
