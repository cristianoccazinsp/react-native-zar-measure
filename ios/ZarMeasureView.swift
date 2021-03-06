import Foundation
import UIKit
import SceneKit
import ARKit


@available(iOS 13, *)
@objc public class ZarMeasureView: UIView, ARSCNViewDelegate, UIGestureRecognizerDelegate, ARSessionDelegate, ARCoachingOverlayViewDelegate {
    
    public static var SUPPORTS_MESH : Bool {
        if #available(iOS 13.4, *) {
            return ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
        }
        return false
    }

    // MARK: Public properties
    
    @objc public var units: String = "m"
    @objc public var minDistanceCamera: CGFloat = 0.05
    @objc public var maxDistanceCamera: CGFloat = 5
    @objc public var intersectDistance: CGFloat = 0.1
    @objc public var onARStatusChange: RCTDirectEventBlock? = nil
    @objc public var onMeasuringStatusChange: RCTDirectEventBlock? = nil
    @objc public var onMountError: RCTDirectEventBlock? = nil
    @objc public var onTextTap: RCTDirectEventBlock? = nil
    @objc public var onPlaneTap: RCTDirectEventBlock? = nil
    
    
    // MARK: Public methods and properties with setters
    
    
    // when either planes or meshes visualization is updated
    // we need to add or delete all anchor visualization nodes
    // we know that all these nodes are in the view's root
    @objc public var showPlanes = false {
        willSet {
            if showPlanes != newValue {
                if !newValue {
                    // recursively loop through all nodes and remove our anchor planes
                    sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
                        if let plane = node as? AnchorPlaneNode {
                            plane.removeFromParentNode()
                        }
                    }
                }
                else{
                    if let anchors = sceneView.session.currentFrame?.anchors {
                        for anchor in anchors {
                            if let node = sceneView.node(for: anchor), let planeAnchor = anchor as? ARPlaneAnchor {
                                    
                                let plane = AnchorPlaneNode(anchor: planeAnchor)
                                node.addChildNode(plane)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @objc public var strictPlanes = false {
        willSet {
            // if turning off strict planes, set all anchors visible
            // as render call will not do that.
            if !newValue && strictPlanes {
                if let anchors = sceneView.session.currentFrame?.anchors {
                    for anchor in anchors {
                        if let node = sceneView.node(for: anchor), let _ = anchor as? ARPlaneAnchor {
                            node.isHidden = false
                        }
                    }
                }
            }
        }
    }
    
    @objc public var stickyPlanes = false
    
    @objc public var showGeometry = false {
        willSet {
            if showGeometry != newValue {
                if !newValue {
                    // recursively loop through all nodes and remove our anchor geometry meshes
                    sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
                        if let mesh = node as? AnchorGeometryNode {
                            mesh.removeFromParentNode()
                        }
                    }
                }
                else{
                    if let anchors = sceneView.session.currentFrame?.anchors {
                        for anchor in anchors {
                            if let node = sceneView.node(for: anchor), let planeAnchor = anchor as? ARPlaneAnchor {
                                    
                                let plane = AnchorGeometryNode(anchor: planeAnchor, in: sceneView)
                                node.addChildNode(plane)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @objc public var showMeshes = false {
        willSet {
            if showMeshes != newValue {
                if #available(iOS 13.4, *){
                    
                    if !newValue {
                        // recursively loop through all nodes and remove our anchor meshes
                        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
                            if let mesh = node as? AnchorMeshNode {
                                mesh.removeFromParentNode()
                            }
                        }
                    }
                    else{
                        if let anchors = sceneView.session.currentFrame?.anchors {
                            for anchor in anchors {
                                if let node = sceneView.node(for: anchor), let meshAnchor = anchor as? ARMeshAnchor {
                                    
                                    let mesh = AnchorMeshNode(anchor: meshAnchor)
                                    node.addChildNode(mesh)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    @objc public var showHitPlane = false;
    @objc public var showHitGeometry = false;
    @objc public var allowPan = true;
    
    @objc public var torchOn = false {
        willSet {
            if torchOn != newValue {
                toggleTorch(newValue)
            }
        }
    }
    
    @objc public var paused = false {
        willSet {
            if paused != newValue {
                DispatchQueue.main.async {
                    self.toggleSession(!self.paused)
                }
            }
        }
    }
    
    
    // Removes all nodes and lines
    // Must be called on UI thread
    // clear: all | points | planes
    func clear(_ clear:String, _ vibrate: Bool)
    {
        if panNode != nil {
            return
        }
        
        // Need to use locks since we are modifying the measurements collection
        lock.wait()
        defer {
            lock.signal()
        }
        
        if clear == "all"{
            
            // Remove these in all case
            lineNode?.removeFromParentNode()
            targetNode?.removeFromParentNode()
            currentNode?.removeFromParentNode()
            
            // remove all nodes from measurements, then clear the list
            // need a lock here?
            for m in measurements {
                m.removeNodes()
            }
            measurements.removeAll()
            
            lineNode = nil
            targetNode = nil
            currentNode = nil
            measurementLabel.text = ""
        }
        
        else if clear == "points" {
            for (i, m) in measurements.enumerated().reversed() {
                if m.planeId.isEmpty {
                    m.removeNodes()
                    measurements.remove(at: i)
                }
            }
        }
        else if clear == "planes" {
            for (i, m) in measurements.enumerated().reversed() {
                if !m.planeId.isEmpty {
                    m.removeNodes()
                    measurements.remove(at: i)
                }
            }
        }
        else{
            return
        }
        
        lastHitResult = (nil, nil)
        
        if vibrate {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    // removes the current measurement step, if any
    func clearCurrent()
    {
        if panNode != nil {
            return
        }
        
        lock.wait()
        defer {
            lock.signal()
        }
        
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
    // Must be called on UI thread
    // clear: all | points | planes, same as clear
    func removeLast(_ clear:String)
    {
        if panNode != nil {
            return
        }
        
        lock.wait()
        defer {
            lock.signal()
        }
        
        if let current = currentNode {
            current.removeFromParentNode()
            lineNode?.removeFromParentNode()
            currentNode = nil
            lineNode = nil
            lastHitResult = (nil, nil)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        
        if clear == "all" || clear == "full" {
            
            if let last = measurements.last {
                last.removeNodes()
                measurements.removeLast()
                
                // if full and plane ID, remove all measurements of the plane
                let planeId = last.planeId
                
                if !planeId.isEmpty && clear == "full" {
                    for (i, m) in measurements.enumerated().reversed() {
                        // assign the first plane id and start removing from there.
                        if m.planeId == planeId {
                            m.removeNodes()
                            measurements.remove(at: i)
                        }
                    }
                }
                
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        else if clear == "points" {
            for (i, m) in measurements.enumerated().reversed() {
                if m.planeId.isEmpty {
                    m.removeNodes()
                    measurements.remove(at: i)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    break
                }
            }
        }
        else if clear == "planes" {
            
            var planeId = ""
            
            for (i, m) in measurements.enumerated().reversed() {
                // assign the first plane id and start removing from there.
                if !m.planeId.isEmpty && (planeId.isEmpty || m.planeId == planeId) {
                    planeId = m.planeId
                    m.removeNodes()
                    measurements.remove(at: i)
                }
            }
            
            // if we found a plane, vibrate
            if !planeId.isEmpty {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }
    
    func resetWorld() -> String? {
        if takingPicture {
            return "Capture in progres."
        }
        
        clear("all", true)
        clearHitTargets()
        
        toggleSession(true, true, true)
        
        return nil
    }
    
    func removeMeasurement(_ id:String) -> MeasurementLine?
    {
        if panNode != nil {
            return nil
        }
        
        lock.wait()
        defer {
            lock.signal()
        }
        
        guard let idx = measurements.firstIndex(where: {$0.id == id}) else { return nil}
        
        let node = measurements[idx]
        measurements.remove(at: idx)
        node.removeNodes()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        return node.toDict()
    }
    
    func removePlane(_ planeId:String) -> [MeasurementLine]
    {
        if panNode != nil {
            return []
        }
        
        lock.wait()
        defer {
            lock.signal()
        }
        
        var deleted : [MeasurementLine] = []
        
        for (i, m) in measurements.enumerated().reversed() {
            // assign the first plane id and start removing from there.
            if m.planeId == planeId {
                m.removeNodes()
                measurements.remove(at: i)
                deleted.append(m.toDict())
            }
        }
        
        if deleted.count > 0 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        return deleted
    }
    
    func editMeasurement(_ id:String, _ text:String, _ clearPlane:Bool) -> MeasurementLine?
    {
        if panNode != nil {
            return nil
        }
        
        lock.wait()
        defer {
            lock.signal()
        }
        
        guard let idx = measurements.firstIndex(where: {$0.id == id}) else { return nil}
        
        let node = measurements[idx]
        
        // remove node, and create a new one with the text
        node.text.removeFromParentNode()
        
        node.text = TextNode(between: node.node1.position, and: node.node2.position, textLabel: text, textColor: self.nodeColor)
        node.text.measureId = node.id
        node.text.setScale(sceneView: self.sceneView)
        
        if clearPlane {
            node.planeId = ""
        }
        
        self.rootNode.addChildNode(node.text)
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        return node.toDict()
    }
    
    func getMeasurements() -> [MeasurementLine]{
        lock.wait()
        defer {
            lock.signal()
        }
        
        return measurements.enumerated().map { (index, element) in
            return element.toDict()
        }
    }
    
    func planeIsStrict(_ planeAnchor:ARPlaneAnchor) -> Bool {
        switch(planeAnchor.classification) {
        case .ceiling, .floor, .wall:
            return true
        default:
            return false
        }
    }
    
    func getPlanes(_ minDimension: Float, _ alignment: String, _ strict: Bool) -> [JSARPlane]{
        if let anchors = sceneView.session.currentFrame?.anchors {
            
            var res : [MeasurementLine] = []
            let horizontal = alignment == "all" || alignment == "horizontal"
            let vertical = alignment == "all" || alignment == "vertical"
            
            for anchor in anchors {
                // let node = sceneView.node(for: anchor)
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    if planeAnchor.extent.x >= minDimension && planeAnchor.extent.z >= minDimension && (planeAnchor.alignment == .horizontal && horizontal || planeAnchor.alignment == .vertical && vertical) {
                        
                        if strict {
                            if planeIsStrict(planeAnchor) {
                                res.append(planeAnchor.toDict())
                            }
                        }
                        else {
                            res.append(planeAnchor.toDict())
                        }
                            
                    }
                }
            }
            
            return res
        }
        else{
            return []
        }
    }
    
    // Adds a new point (or calculates distance if there was one already)
    // returns (err, measurement, cameraDistance)
    // if setCurrent is true, sets the newly added point as the current one
    func addPoint(_ setCurrent : Bool) -> (String?, MeasurementLine?, CGFloat?)
    {
        if panNode != nil {
            return ("Node movement already in progress", nil, nil)
        }
        
        lock.wait()
        defer {
            lock.signal()
        }
        
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
        let sphere = SphereNode(at: result.position, color: self.nodeColor, alignment: result.alignment)
        sphere.anchor = result.planeAnchor
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
           
            let newMeasure = MeasurementGroup(current, sphere, newLine, newText, distance)
            
            measurements.append(newMeasure)
            
            // add all objects to the scene
            self.rootNode.addChildNode(sphere)
            self.rootNode.addChildNode(newLine)
            self.rootNode.addChildNode(newText)
            
            // clear current node to allow new measurement
            if setCurrent{
                // clone it
                currentNode = SphereNode(at: sphere.position, color: self.nodeColor, alignment: sphere.alignment)
                currentNode?.setScale(sceneView: self.sceneView)
                currentNode?.anchor = sphere.anchor
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
    
    
    // Adds a new dummy point (if add) where both nodes are in the same location
    // in the current hit location
    func addDummyPoint(_ add: Bool, _ text:String, _ planeId:String) -> (String?, MeasurementLine?, CGFloat?)
    {
        if panNode != nil {
            return ("Node movement already in progress", nil, nil)
        }
        
        lock.wait()
        defer {
            lock.signal()
        }
        
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
        let sphere = SphereNode(at: result.position, color: self.nodeColor, alignment: result.alignment)
        sphere.setScale(sceneView: self.sceneView)
        sphere.anchor = result.planeAnchor
        
        let newText = TextNode(between: sphere.position, and: sphere.position, textLabel: text, textColor: self.nodeColor)
        newText.setScale(sceneView: self.sceneView)
        
        let newLine = LineNode(from: sphere.position, to: sphere.position, lineColor: self.textColor)
        newLine.setScale(sceneView: self.sceneView, in: newText)
       
        let newMeasure = MeasurementGroup(planeId, sphere, sphere, newLine, newText, 0)
        
        if add {
        
            measurements.append(newMeasure)
            
            // add all objects to the scene
            self.rootNode.addChildNode(sphere)
            self.rootNode.addChildNode(newLine)
            self.rootNode.addChildNode(newText)
                
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        return (nil, newMeasure.toDict(), result.distance)
    }
    
    
    // Adds a new measurement line from two nodes
    func addLine(_ node1:CoordinatePoint, _ node2:CoordinatePoint, _ text:String) -> (String?, MeasurementLine?)
    {
        if panNode != nil {
            return ("Node movement already in progress", nil)
        }
        
        lock.wait()
        defer {
            lock.signal()
        }
        
        let point1 = SCNVector3.positionFrom(node: node1)
        let point2 = SCNVector3.positionFrom(node: node2)
        
        
        let sphere1 = SphereNode(at: point1, color: self.nodeColor, alignment: .none)
        let sphere2 = SphereNode(at: point2, color: self.nodeColor, alignment: .none)
        let distance = point2.distance(to: point1)
        
        let label : String;
        if text.isEmpty {
            label = self.getMeasureString(distance)
        }
        else {
            label = text
        }
        
        let textNode = TextNode(between: point1, and: point2, textLabel: label, textColor: self.nodeColor)
        
        let line = LineNode(from: point1, to: point2, lineColor: self.textColor)
       
        let newMeasure = MeasurementGroup(sphere1, sphere2, line, textNode, distance)
        
        
        measurements.append(newMeasure)
        
        // call sacale funs
        sphere1.setScale(sceneView: self.sceneView)
        sphere2.setScale(sceneView: self.sceneView)
        textNode.setScale(sceneView: self.sceneView)
        line.setScale(sceneView: self.sceneView, in: textNode)
        
        // add all objects to the scene
        self.rootNode.addChildNode(sphere1)
        self.rootNode.addChildNode(sphere2)
        self.rootNode.addChildNode(line)
        self.rootNode.addChildNode(textNode)
        
        return (nil, newMeasure.toDict())
    }
    
    
    // Adds a new set of edges to a target plane, or currently focused node
    // if ID is not given
    // must be called on UI thread
    func addPlane(_ id:String, _ left:Bool, _ top:Bool, _ right:Bool, _ bottom:Bool, _ setId:Bool, _ vibrate:Bool) -> (String?, [MeasurementLine], JSARPlane?)
    {
        lock.wait()
        defer {
            // clear hit results on adding point so we refresh existing nodes
            // due to some shapes needing to change
            self.lastHitResult = (nil, nil)
            
            lock.signal()
        }
        
        var plane : ARPlaneAnchor? = nil
        
        // if ID not given
        if id.isEmpty {
            let (er, resultx) = self.lastHitResult
            
            guard let result = resultx else {
                return (er, [], nil)
            }
            
            plane = result.anchor as? ARPlaneAnchor
        }
        
        else{
            // find anchor by ID
            if let anchors = sceneView.session.currentFrame?.anchors {
                for anchor in anchors {
                    if let _plane = anchor as? ARPlaneAnchor{
                        if _plane.getId() == id {
                            plane = _plane
                            break
                        }
                    }
                }
            }
        }
        
        if let _plane = plane {
            
            var added : [MeasurementLine] = []
            
            func addNode (_ planeId: String, _ point1: SCNVector3, _ point2: SCNVector3, _ alignment: NodeAlignment) {
                
                let sphere1 = SphereNode(at: point1, color: self.nodeColor, alignment: alignment)
                sphere1.anchor = _plane
                
                let sphere2 = SphereNode(at: point2, color: self.nodeColor, alignment: alignment)
                sphere2.anchor = _plane
                
                let distance = point2.distance(to: point1)
                
                let text = TextNode(between: point1, and: point2, textLabel: self.getMeasureString(distance), textColor: self.nodeColor)
                
                let line = LineNode(from: point1, to: point2, lineColor: self.textColor)
               
                let newMeasure = MeasurementGroup(sphere1, sphere2, line, text, distance)
                
                if setId {
                    newMeasure.planeId = planeId
                }
                
                measurements.append(newMeasure)
                
                // call sacale funs
                sphere1.setScale(sceneView: self.sceneView)
                sphere2.setScale(sceneView: self.sceneView)
                text.setScale(sceneView: self.sceneView)
                line.setScale(sceneView: self.sceneView, in: text)
                
                // add all objects to the scene
                self.rootNode.addChildNode(sphere1)
                self.rootNode.addChildNode(sphere2)
                self.rootNode.addChildNode(line)
                self.rootNode.addChildNode(text)
                
                added.append(newMeasure.toDict())
            }
            
            
            let (topLeft, topRight, bottomLeft, bottomRight) = _plane.worldPoints()
            let planeId = _plane.getId()
            let alignment : NodeAlignment = (_plane.alignment == .horizontal ? .horizontal : .vertical)
            
            if left {
                addNode(planeId, topLeft, bottomLeft, alignment)
            }
            
            if top {
                addNode(planeId, topLeft, topRight, alignment)
            }
            
            if right {
                addNode(planeId, topRight, bottomRight, alignment)
            }
            
            if bottom {
                addNode(planeId, bottomLeft, bottomRight, alignment)
            }
            
            if (vibrate && added.count > 0) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            
            return (nil, added, _plane.toDict())
        }
        else {
            return ("Plane not found.", [], nil)
        }
    }
    
    
    // Takes a PNG picture of the scene.
    // Calls completion handler with a string if there was an error
    // or nil otherwise.
    // Must be called on UI thread
    func takePicture(_ path : String, completion: @escaping (String?, [MeasurementLine2D]) -> Void)
    {
        if takingPicture {
            completion("Capture already in progress.", [])
            return
        }
        
        lock.wait()
        defer {
            lock.signal()
        }
        
        takingPicture = true
        
        // temporary remove target nodes from view
        // and any anchor vewer node
        
        targetNode?.isHidden = true
        lineNode?.isHidden = true
        
        // we know that all anchor view nodes are added to the view's
        // root node, and not our own root node
        for n in sceneView.scene.rootNode.childNodes {
            if n != rootNode {
                n.isHidden = true
            }
        }
        
        let image = sceneView.snapshot()
        var points : [MeasurementLine2D] = []
        var idx = 0
        
        for m in measurements {
            if let d = m.toDict2D(sceneView){
                points.append(d)
            }
            idx += 1
        }
        
        // re add nodes back
        targetNode?.isHidden = false
        lineNode?.isHidden = false
        
        for n in sceneView.scene.rootNode.childNodes {
            if n != rootNode {
                n.isHidden = false
            }
        }
        
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
    
    // Saves a snapshot of the current world data as usdz file
    // resolves with nil if no error, or with an error message otherwise.
    // Must be called on UI thread
    func saveToFile(_ path : String, completion: @escaping (String?) -> Void)
    {
        if(takingPicture){
            completion("Capture already in progress.")
            return
        }
        
        lock.wait()
        defer {
            lock.signal()
        }
        
        // use same flag for now
        takingPicture = true
        
        // temporary remove target nodes
        
        self.targetNode?.removeFromParentNode()
        self.lineNode?.removeFromParentNode()
        
        let fileUrl = URL(fileURLWithPath: path)
        
        // heavy operation, run in background
        DispatchQueue.global(qos: .background).async {
            
            // it's unclear whether this method returns right away
            // but it seems like it fires both callbacks and onyl returns once completed
            let res = self.sceneView.scene.write(to: fileUrl, options: nil, delegate: nil){ (progress, error, obj) in
                //NSLog("Progress: \(progress) - \(String(describing: error)) \(obj)")
            }
            
            // back to main thread
            DispatchQueue.main.async {
                
                // re add nodes back
                if let t = self.targetNode {
                    self.rootNode.addChildNode(t)
                }
                if let t = self.lineNode {
                    self.rootNode.addChildNode(t)
                }
                
                if(!res){
                    completion("Export failed: scene writing returned an error")
                }
                else{
                    completion(nil)
                }
                
                self.takingPicture = false
            }
        }
    }
    

    // MARK: Private properties
    private let lock = DispatchSemaphore(value: 1)
    //private let dispatchQueue = DispatchQueue.init(label: "ZarMeasureViewSession", qos: .userInteractive)
    private var sceneView = ARSCNView()
    private var configuration = ARWorldTrackingConfiguration()
    private var isRunning = false // to control session toggles
    private var sceneCenter = CGPoint(x: 0, y: 0)
    private var rootNode = SCNNode()
    private var coachingView : ARCoachingOverlayView = ARCoachingOverlayView()
    private var lastHitResult: (String?, HitResult?) = (nil, nil)
    private var takingPicture = false
    
    // throttle some operations
    private var donutScaleTimeout = 0.05
    private var donutScaleAnimation = 0.25
    private var nodesScaleTimeout = 0.05
    private var closeNodeTimeout = 0.8
    private var donutLastScaled = TimeInterval(0)
    private var nodesLastScaled = TimeInterval(0)
    private var closeNodeLastTime = TimeInterval(0)
    
    // For pan gestures
    private var panNode: SphereNode? = nil
    private var panMeasurement: MeasurementGroup? = nil
    
    // colors good enough for white surfaces
    private let nodeColor : UIColor = UIColor(red: 255/255.0, green: 153/255.0, blue: 0, alpha: 1)
    private let nodeColorErr : UIColor = UIColor(red: 240/255.0, green: 0, blue: 0, alpha: 1)
    private let nodeColorClose : UIColor = UIColor(red: 0, green: 153/255.0, blue: 51/255.0, alpha: 1)
    private let textColor : UIColor = UIColor(red: 255/255.0, green: 153/255.0, blue: 0, alpha: 1)
    private let fontSize : CGFloat = 16
    
    private var measurementLabel = UILabel() // general purpose message
    
    private var measurements: [MeasurementGroup] = []
    private var currentNode : SphereNode? = nil // to start a measurement
    private var lineNode : LineNode? = nil
    private var targetNode: TargetNode? = nil
    private var hitPlane: AnchorPlaneNode? = nil
    private var hitGeometry: AnchorGeometryNode? = nil
    private var hitMesh: SCNNode? = nil // will need to be casted when used
    
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
            toggleSession(false)
        }
        else{
            toggleSession(true, true)
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
        isRunning = false
        self.onMountError?(["message": error.localizedDescription])
    }
    
    public func sessionWasInterrupted(_ session: ARSession) {
        // do some soft cleanup - restart
        let status = "off"
        arReady = false
        measuringStatus = "off"
        lastHitResult = (nil, nil)
        isRunning = false
        
        if(status != arStatus){
            arStatus = status
            onARStatusChange?(["status": status])
        }
    }
    
    public func sessionInterruptionEnded(_ session: ARSession) {
        
        // try to recover from interruption.
        // Sometimes it happens automatically, sometimes it doesn't
        startCoach()
        
        // if interruption ended and we had flash, try to turn it on again
        if torchOn {
            toggleTorch(true)
        }
        isRunning = true
    }
    
    public func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        startCoach()
        return true
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {

        if(showPlanes){
            // Place content only for anchors found by plane detection.
            if let planeAnchor = anchor as? ARPlaneAnchor {
                // Create a node to visualize the plane's bounding rectangle.
                // Create a custom object to visualize the plane geometry and extent.
                let plane = AnchorPlaneNode(anchor: planeAnchor)
                
                // Add the visualization to the ARKit-managed node so that it tracks
                // changes in the plane anchor as plane estimation continues.
                node.addChildNode(plane)
            }
        }
        
        if(showGeometry){
            // Place content only for anchors found by plane detection.
            if let planeAnchor = anchor as? ARPlaneAnchor{
                // Create a node to visualize the plane's bounding rectangle.
                // Create a custom object to visualize the plane geometry and extent.
                let mesh = AnchorGeometryNode(anchor: planeAnchor, in: sceneView)
                
                // Add the visualization to the ARKit-managed node so that it tracks
                // changes in the geometry anchor as plane estimation continues.
                node.addChildNode(mesh)
            }
        }
        
        if(showMeshes){
            if #available(iOS 13.4, *){
                if let meshAnchor = anchor as? ARMeshAnchor {
                    
                    let meshNode = AnchorMeshNode(anchor: meshAnchor)
                    
                    node.addChildNode(meshNode)
                }
            }
        }
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        
        // Update only anchors and nodes set up by `renderer(_:didAdd:for:)`.
        if(showPlanes){
            if let planeAnchor = anchor as? ARPlaneAnchor {
                for child in node.childNodes {
                    if let plane = child as? AnchorPlaneNode {
                        plane.updatePlane(planeAnchor)
                    }
                }
            }
        }
        
        if(showGeometry){
            if let planeAnchor = anchor as? ARPlaneAnchor{
                for child in node.childNodes {
                    if let mesh = child as? AnchorGeometryNode {
                        mesh.updateMesh(planeAnchor)
                    }
                }
            }
        }
        
        if(showMeshes){
            if #available(iOS 13.4, *){
                if let meshAnchor = anchor as? ARMeshAnchor {
                    for child in node.childNodes {
                        if let mesh = child as? AnchorMeshNode {
                            mesh.updateMesh(meshAnchor)
                        }
                    }
                }
            }
        }
    }

    // renderer callback method to fire hit tests and scale items
    public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        if(takingPicture){
            return
        }
        
        // process ARPlane anchors if strict mode
        // if not strict, our willSet will handle it
        if (strictPlanes) {
            if let anchors = sceneView.session.currentFrame?.anchors {
                for anchor in anchors {
                    if let node = sceneView.node(for: anchor), let planeAnchor = anchor as? ARPlaneAnchor {
                        node.isHidden = !planeIsStrict(planeAnchor)
                    }
                }
            }
        }
        
        // these always need to be updated
        // update text and nodes scales from measurements
        if (time - nodesLastScaled > nodesScaleTimeout) {
            
            // protect the measurements collection here
            lock.wait()
            
            for t in measurements {
                t.text.setScale(sceneView: sceneView)
                t.node1.setScale(sceneView: sceneView)
                t.node2.setScale(sceneView: sceneView)
                t.line.setScale(sceneView: sceneView, in: t.text)
            }
            
            // scale now, and maybe later
            targetNode?.setSphereScale(sceneView: sceneView)
            
            nodesLastScaled = time
            
            lock.signal()
        }
        
        if !arReady {
            // remove previous nodes
            lineNode?.removeFromParentNode()
            lineNode = nil
            targetNode?.removeFromParentNode()
            targetNode = nil
            currentNode?.removeFromParentNode()
            currentNode = nil
            clearHitTargets()
            
            lastHitResult = (nil, nil)
            return
        }
        
        // short circuit here if panning
        if panNode != nil {
            lastHitResult = (nil, nil)
            return
        }
        
        let (err, result) = doRayTestOnExistingPlanes(sceneCenter)
        var mustVibrate = false
        
        // check previous results so we throttle node snagging
        if let _result = result, let _prev = lastHitResult.1 {
            
            mustVibrate = (_prev.isCloseNode != _result.isCloseNode)
            
            // only do these if error flag didnt change
            if err == lastHitResult.0 {
                
                // otherwise, if we had a close node, check timeout
                if _prev.isCloseNode && (time - closeNodeLastTime < closeNodeTimeout) {
                    return
                }
                
                if _result.isCloseNode {
                    closeNodeLastTime = time
                }
            }
        }
        
        lastHitResult = (err, result)
        
        
        
        // remove these since they are always re-created
        // and set/clear label
        lineNode?.removeFromParentNode()
        lineNode = nil
        clearHitTargets()
        
        
        // update label in UI thread
        var newText = err != nil ? err : ""
        
        
        let mStatus : String
        
        if let _result = result  {
            
            let position = _result.position
            let closeNode = _result.isCloseNode
        
            // node color if there was an acceptable error
            let color = err != nil ? nodeColorErr : (closeNode ? nodeColorClose : nodeColor)
            
            // if we have 1 node already, draw line
            // also consider if we have errors
            if let start = currentNode {
                
                // line node
                let _lineNode = LineNode(from: start.position, to: position, lineColor: color)
                rootNode.addChildNode(_lineNode)
                lineNode = _lineNode
                
                // target node exists, update it
                if let target = targetNode {
                    target.updatePosition(to: position, color: color)
                }
                
                // otherwise, re-create it
                else{
                    let _targetNode = TargetNode(at: position, color: color)
                    rootNode.addChildNode(_targetNode)
                    targetNode = _targetNode
                }
              
                
                if err == nil, let distance = targetNode?.distance(to: start) {
                    newText = getMeasureString(distance)
                }
            }
            
            // else, just add a target node
            else{
                
                // target node exists, update it
                if let target = targetNode{
                    target.updatePosition(to: position, color: color)
                }
                
                // otherwise, re-create it
                else{
                    let _targetNode = TargetNode(at: position, color: color)
                    rootNode.addChildNode(_targetNode)
                    targetNode = _targetNode
                }
            }
            
            
            // throttle rotation changes to avoid odd effects
            // for non plane hits, make delay even bigger, otherwise
            // the donut may spin like crazy
            // unless it is a close node, since we want the right position immediately
            if let _target = targetNode, let donutScaleMult = _result.anchor as? ARPlaneAnchor != nil ? 1.0 : 5.0, (time - donutLastScaled > (donutScaleTimeout * donutScaleMult)) || closeNode {
                
                // Animate this so it looks nicer
                SCNTransaction.begin()
                SCNTransaction.animationDuration = donutScaleAnimation
                _target.setDonutScale(sceneView: sceneView, hitResult: _result)
                donutLastScaled = time
                SCNTransaction.commit()
            }
            
            // show/hide hit plane if configured
            if showHitPlane && !closeNode {
                if let anchor = _result.anchor as? ARPlaneAnchor, let node = sceneView.node(for: anchor) {
                    
                    let _hitPlane = AnchorPlaneNode(anchor: anchor)
                    
                    // add it not to root node, but rather the anchor's node
                    node.addChildNode(_hitPlane)
                    hitPlane = _hitPlane
                }
            }
            
            // show/hide hit plane if configured
            if showHitGeometry && !closeNode {
                if let anchor = result?.anchor as? ARPlaneAnchor, let node = sceneView.node(for: anchor) {
                    
                    let _hitGeometry = AnchorGeometryNode(anchor: anchor, in: sceneView)
                    
                    // add it not to root node, but rather the anchor's node
                    node.addChildNode(_hitGeometry)
                    hitGeometry = _hitGeometry
                }
            }
            
            // vibration on close changes
            if mustVibrate {
                DispatchQueue.main.async {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            
            mStatus = err == nil ? "ready" : "error"
        }
        else{
            // also remove target if error
            targetNode?.removeFromParentNode()
            targetNode = nil
            
            mStatus = "error"
        }
        
        // if target node, scale it at the end even if error
        targetNode?.setSphereScale(sceneView: sceneView)
        
        if let lineNode = lineNode, let targetNode = targetNode {
            lineNode.setScale(sceneView: sceneView, in: targetNode)
        }
        
        if (mStatus != measuringStatus) {
            measuringStatus = mStatus
            onMeasuringStatusChange?(["status": mStatus])
        }
        
        
        DispatchQueue.main.async {
            if self.arReady {
                self.measurementLabel.text = newText
            }
            else {
                self.measurementLabel.text = ""
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
        
        
        // First try to hit against our text nodes
        // only if text tap was defined
        if onTextTap != nil {
            let result = sceneView.hitTest(touchLocation, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue, SCNHitTestOption.ignoreHiddenNodes: false, SCNHitTestOption.backFaceCulling: false, SCNHitTestOption.rootNode: rootNode])
            
            // search all results to see if we have a text node in one of our measurements
            // or ultimately a plane node
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
                    if let measurement = measurements.first(where: {_textNode.measureId == $0.id}){
                        onTextTap?(["measurement": measurement.toDict(), "location": ["x": touchLocation.x, "y": touchLocation.y]])
                        
                        if onTextTap != nil {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        
                        return
                    }
                }
            }
        }
        
        // if we got here, no hits, do a raycast and try to get a plane anchor
        // Only hit against planes, no estimations, and if onPlaneTap is defined
        if onPlaneTap != nil {
            guard let query = sceneView.raycastQuery(from: touchLocation, allowing: .existingPlaneGeometry, alignment: .any) else{
                
                // this should never happen
                return
            }
            
            if let first = sceneView.session.raycast(query).first, let anchor = first.anchor as? ARPlaneAnchor {
                
                onPlaneTap?(["plane": anchor.toDict(), "location": ["x": touchLocation.x, "y": touchLocation.y]])
                
                if onPlaneTap != nil {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                return
            }
        }
    }
    
    @objc private func handleLongTap(sender: UIPanGestureRecognizer) {
        if !allowPan {
            return
        }
        
        if !arReady {
            return
        }
        
        guard let sceneView = sender.view as? ARSCNView else {return}
        
        let location = sender.location(in: sceneView)
        
        
        if sender.state == .began {
            panMeasurement = nil
            panNode = nil
                        
            // hit test and see if we get a sphere node to pan
            
            let result = sceneView.hitTest(location, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue, SCNHitTestOption.ignoreHiddenNodes: false, SCNHitTestOption.backFaceCulling: false, SCNHitTestOption.rootNode: rootNode])
            
            // search all results to see if we have a text node in one of our measurements
            for r in result {
                
                var sphereNode: SphereNode? = nil
                var textNode: TextNode? = nil
                
                if r.node.name == "spherenode" {
                    sphereNode = r.node as? SphereNode
                }
                else if r.node.parent?.name == "spherenode"{
                    sphereNode = r.node.parent as? SphereNode
                }
                else if r.node.name == "textnode" {
                    textNode = r.node as? TextNode
                }
                else if r.node.parent?.name == "textnode"{
                    textNode = r.node.parent as? TextNode
                }
                else {
                    continue
                }
                
                // we may get a hit on the plane node, or text node
                if let sphere = sphereNode {
                    if let measurement = measurements.first(where: {sphere.measureId == $0.id}){
                        panNode = sphere
                        panMeasurement = measurement
                                            
                        break
                    }
                }
                
                else if let text = textNode {
                    if let measurement = measurements.first(where: {text.measureId == $0.id}){
                        panMeasurement = measurement
                        
                        if r.worldCoordinates.distance(to: measurement.node1.worldPosition) <= r.worldCoordinates.distance(to: measurement.node2.worldPosition) {
                            panNode = measurement.node1
                        }
                        else {
                            panNode = measurement.node2
                        }
                                            
                        break
                    }
                }
            }
            
            if panNode != nil {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                
                // clear target and line nodes and everything added by renderer
                targetNode?.removeFromParentNode()
                targetNode = nil
                lineNode?.removeFromParentNode()
                lineNode = nil
                clearHitTargets()
                
            }

        } else if sender.state == .changed {
            
            if let node = panNode, let measurement = panMeasurement {
                
                // easy approach: Find a plane with the same alignment
                // as the node, and hit test there to move the node there.
                // If sticky planes, also enforce the same plane ID
                
                // move hit location a bit up the thumb of the user
                let queryLocation = CGPoint(
                    x: location.x + 40,
                    y: location.y - 40
                )
                
                let alignment : ARRaycastQuery.TargetAlignment
                
                switch (node.alignment) {
                case .horizontal: alignment = .horizontal
                case .vertical: alignment = .vertical
                default: alignment = .any
                }
                
                var hitTest : [ARRaycastResult] = []
                
                // if sticky, try to find the related anchor
                if stickyPlanes, let _anchor = node.anchor {
                    
                    guard let query = sceneView.raycastQuery(from: queryLocation, allowing: .existingPlaneInfinite, alignment: alignment) else {
                        return
                    }
                    
                    hitTest = sceneView.session.raycast(query).filter({ (ar) -> Bool in
                        if let _a = ar.anchor as? ARPlaneAnchor {
                            return _a.identifier == _anchor.identifier
                        }
                        return false
                    })
                }
                
                // if not sticky, or sticky found nothing
                if hitTest.count == 0 {
                    
                    guard let query = sceneView.raycastQuery(from: queryLocation, allowing: .existingPlaneGeometry, alignment: alignment) else {
                        return
                    }
                    
                    hitTest = sceneView.session.raycast(query)
                    
                    // if no hits, give it another try
                    if hitTest.count == 0 {
                        
                        guard let query = sceneView.raycastQuery(from: queryLocation, allowing: .existingPlaneInfinite, alignment: alignment) else{
                            return
                        }
                        
                        hitTest = sceneView.session.raycast(query)
                    }
                }
                
                
                if let result = hitTest.first {
                    
                    // we need to move all measurement group's
                    // based on user movement
                    
                    clearHitTargets()
                    
                    // some copy paste from renderer for now
                    // TODO: Improve this duplicated code
                    var transform = result.worldTransform
                    
                    if let anchor = result.anchor as? ARPlaneAnchor, let distance =  result.distanceFromCamera(sceneView) {
                        
                        let hitPos = SCNVector3.positionFrom(matrix: result.worldTransform)
                        
                        // make distance smaller for these fine movements
                        let closeNode = findNearSphere(hitPos, intersectDistance * distance / 2, excluding: node)
                        
                        if let _close = closeNode {
                            transform = _close.simdWorldTransform
                        }
                        
                        // show/hide hit plane if configured
                        if showHitPlane && closeNode == nil {
                            if let node = sceneView.node(for: anchor) {
                                
                                let _hitPlane = AnchorPlaneNode(anchor: anchor)
                                
                                // add it not to root node, but rather the anchor's node
                                node.addChildNode(_hitPlane)
                                hitPlane = _hitPlane
                            }
                        }
                        
                        // show/hide hit plane if configured
                        if showHitGeometry && closeNode == nil {
                            if let node = sceneView.node(for: anchor) {
                                
                                let _hitGeometry = AnchorGeometryNode(anchor: anchor, in: sceneView)
                                
                                // add it not to root node, but rather the anchor's node
                                node.addChildNode(_hitGeometry)
                                hitGeometry = _hitGeometry
                            }
                        }
                    }
                    
                    
                    // need to re create these
                    measurement.line.removeFromParentNode()
                    measurement.text.removeFromParentNode()
                    
                    
                    // set new location to our panned node
                    // which should be either node1 or node 2
                    // for sanity, make sure the nodes are the same
                    if measurement.node1 == panNode {
                        measurement.node1.simdWorldTransform = transform
                    }
                    else if measurement.node2 == panNode {
                        measurement.node2.simdWorldTransform = transform
                    }
                    else {
                        NSLog("Warning: Dragged node does not belong to measurement")
                    }
                    

                    // update text and line nodes and values
                    let distance = measurement.node1.position.distance(to: measurement.node2.position)
                    
                    measurement.text = TextNode(between: measurement.node1.position, and: measurement.node2.position, textLabel: self.getMeasureString(distance), textColor: self.nodeColor)
                    
                    measurement.text.measureId = measurement.id
                    measurement.line = LineNode(from: measurement.node1.position, to:  measurement.node2.position, lineColor: self.textColor)
                    
                    measurement.node1.setScale(sceneView: sceneView)
                    measurement.node2.setScale(sceneView: sceneView)
                    measurement.text.setScale(sceneView: sceneView)
                    measurement.line.setScale(sceneView: sceneView, in: measurement.text)
                    rootNode.addChildNode(measurement.text)
                    rootNode.addChildNode(measurement.line)
                }
                
            }
        } else if sender.state == .ended || sender.state == .cancelled || sender.state == .failed {
            if panNode != nil {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                panNode = nil
                panMeasurement = nil
            }
        }
    }
    
    
    // MARK: Private functions
    
    private func commonInit() {
        
        // Main view setup
        configuration.planeDetection = [.vertical, .horizontal]
        configuration.worldAlignment = .gravity
        
        // this should technically use Lidar sensors and greatly
        // improve accuracy
        if #available(iOS 13.4, *) {
            if(ZarMeasureView.SUPPORTS_MESH){
                configuration.sceneReconstruction = .meshWithClassification
            }
        }
        
        // sceneView.preferredFramesPerSecond = 30 // do not set anymore, allow the platform to pick it
        sceneView.rendersCameraGrain = false
        //sceneView.debugOptions = [.showFeaturePoints]
        //sceneView.debugOptions = [.showWorldOrigin]
        sceneView.showsStatistics = false
        sceneView.antialiasingMode = .multisampling2X
        
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
    
    
    // must be called on UI thread
    private func toggleSession(_ on:Bool, _ reset: Bool = false, _ force: Bool = false){
        
        if(on){
            // avoid starting it if it was running, unless forcing it
            if isRunning && !force {
                return
            }
            
            // Set the view's delegate and session delegate
            sceneView.delegate = self
            sceneView.session.delegate = self
            
            // Run the view's session
            arReady = false
            arStatus = "off"
            measuringStatus = "off"
            panNode = nil
            panMeasurement = nil
            
            // Add coaching view
            coachingView.delegate = self
            coachingView.session = sceneView.session
            
            // start session
            if reset {
                sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetSceneReconstruction, .resetTracking, .stopTrackedRaycasts])
            }
            else {
                sceneView.session.run(configuration)
            }
            
            isRunning = true
            
            // run this afterwards, for some reason the session takes time to start
            startCoach()
            
            // add tap gestures as well
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            tapGestureRecognizer.cancelsTouchesInView = false
            self.sceneView.addGestureRecognizer(tapGestureRecognizer)
            
            let longTapRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongTap))
            sceneView.addGestureRecognizer(longTapRecognizer)
            
            // only turn on torch if we were set to turn it on
            // otherwise we would call this unnecessarily.
            if(self.torchOn){
                toggleTorch(self.torchOn)
            }
        }
        else{
            
            // remove gesture handlers, delegates, and stop session
            sceneView.session.pause()
            sceneView.gestureRecognizers?.removeAll()
            
            coachingView.delegate = nil
            coachingView.session = nil
            sceneView.delegate = nil
            sceneView.session.delegate = nil
            panNode = nil
            panMeasurement = nil
            
            arReady = false
            arStatus = "off"
            measuringStatus = "off"
            
            // only turn off torch if we were set to turn it on
            // otherwise we would call this unnecessarily.
            if(self.torchOn){
                toggleTorch(false)
            }
            
            isRunning = false
        }
    }
    
    
    // start coach only if not already running
    private func startCoach(){
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else {return}
            
            if self.sceneView.delegate != nil && !self.coachingView.isActive && !self.arReady {
                self.coachingView.setActive(true, animated: true)
            }
        }
    }
    
    
    private func getMeasureString(_ value: CGFloat) -> String {
        if(self.units == "ft"){
            // get cm
            let cm = value * 100.0
            
            let v = cm / 30.48
            let v_inch = v.truncatingRemainder(dividingBy: 1.0) * 12
            let feet = floor(v)
            let inch = round(v_inch)
            
            if feet < 1 {
                return "\(String(format: "%.0f", inch))''"
            }
            if inch == 0 {
                return "\(String(format: "%.0f", feet))'"
            }
            return "\(String(format: "%.0f", feet))' \(String(format: "%.0f", inch))''"
        }
        else {
            let formatted = String(format: "%.2f", CGFloat.round_decimal(value, 2))
            return "\(formatted) m"
        }
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
        var hitTest : [ARRaycastResult]
        
        // if sticky and enough info info
        if stickyPlanes, let _current = currentNode, let _anchor = _current.anchor {
            
            let alignment : ARRaycastQuery.TargetAlignment
            
            switch (_anchor.alignment) {
                case .horizontal: alignment = .horizontal
                case .vertical: alignment = .vertical
                default: alignment = .any
            }
            
            guard let query = sceneView.raycastQuery(from: location, allowing: .existingPlaneInfinite, alignment: alignment) else {
                
                return ("Detection failed.", nil)
            }
            
            // filter results by our anchor value
            hitTest = sceneView.session.raycast(query).filter({ (ar) -> Bool in
                if let _a = ar.anchor as? ARPlaneAnchor {
                    return _a.identifier == _anchor.identifier
                }
                return false
            })
            
            // if we got no results, fallback to geometry hit test
            // as the plane anchor may have been lost.
            // but don't fall back to feature detection
            if hitTest.count == 0 {
                guard let query = sceneView.raycastQuery(from: location, allowing: .existingPlaneGeometry, alignment: alignment) else {
                    
                    return ("Detection failed.", nil)
                }
                
                hitTest = sceneView.session.raycast(query)
                
                if hitTest.count == 0 {
                    guard let query = sceneView.raycastQuery(from: location, allowing: .existingPlaneInfinite, alignment: alignment) else {
                        
                        return ("Detection failed.", nil)
                    }
                    
                    hitTest = sceneView.session.raycast(query)
                }
            }
        }
        else {
            
            // try highest precision plane first
            guard let query = sceneView.raycastQuery(from: location, allowing: .existingPlaneGeometry, alignment: .any) else{
                
                return ("Detection failed.", nil)
            }
            
            hitTest = sceneView.session.raycast(query)
            
            // if hit test count is 0, try with an estimated and then an infinite plane
            // this matches more the native app, and prevents us from getting lots of error messages
            if hitTest.count == 0 {
                guard let query = sceneView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .any) else{
                    
                    return ("Detection failed.", nil)
                }
                
                hitTest = sceneView.session.raycast(query)
                
                if hitTest.count == 0 {
                    guard let query = sceneView.raycastQuery(from: location, allowing: .existingPlaneInfinite, alignment: .any) else{
                        
                        return ("Detection failed.", nil)
                    }
                    
                    hitTest = sceneView.session.raycast(query)
                }
            }
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
            
        let result : HitResult;
        
        if let _close = closeNode {
            result = HitResult(distance, _close)
        }
        else {
            result = HitResult(distance, hitPos, false, raycastResult)
        }
        
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
    
    func findNearSphere(_ to : SCNVector3, _ minDistance:CGFloat, excluding: SphereNode) -> SphereNode? {
        for m in measurements {
            if m.node1 != excluding && m.node1.position.distance(to: to) < minDistance {
                return m.node1
            }
            if m.node2 != excluding && m.node2.position.distance(to: to) < minDistance {
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
    
    func clearHitTargets() {
        hitPlane?.removeFromParentNode()
        hitPlane = nil
        hitGeometry?.removeFromParentNode()
        hitGeometry = nil
        hitMesh?.removeFromParentNode()
        hitMesh = nil
    }
}
