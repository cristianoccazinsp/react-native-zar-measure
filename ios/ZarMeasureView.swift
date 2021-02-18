import Foundation
import UIKit
import SceneKit
import ARKit


@available(iOS 11.3, *)
@objc public class ZarMeasureView: UIView, ARSCNViewDelegate, UIGestureRecognizerDelegate, ARSessionDelegate {
    

    // MARK: Public properties
    @objc public var units: String = "m"
    @objc public var minDistanceCamera: CGFloat = 0.05
    @objc public var maxDistanceCamera: CGFloat = 5
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
        while let n = self.sceneView.scene.rootNode.childNodes.first { n.removeFromParentNode()
        }
        lineNode?.removeFromParentNode()
        sphereNode?.removeFromParentNode()
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
            
        if(er != nil || currentPosition == nil || result == nil){
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
                
                let textNode = TextNode(between: last.position, and: sphere.position, textLabel: self.getMeasureString(distance), textColor: self.nodeColor)
                
                self.sceneView.scene.rootNode.addChildNode(textNode)
                
                let measureLine = LineNode(from: last.position, to: sphere.position, lineColor: self.textColor)


                // remove any previous line, if any
                // and add new one
                lineNode?.removeFromParentNode()
                sphereNode?.removeFromParentNode()

                // Adds a second sphere to the array
                spheres.append(sphere)
                self.sceneView.scene.rootNode.addChildNode(sphere)
                
                // add line
                lineNode = measureLine
                self.sceneView.scene.rootNode.addChildNode(measureLine)
                
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
    private var spheres: [SCNNode] = []
    private var measurementLabel = UILabel()
    
    // colors good enough for white surfaces
    private let nodeColor : UIColor = UIColor(red: 255/255.0, green: 153/255.0, blue: 0, alpha: 1)
    private let textColor : UIColor = UIColor(red: 255/255.0, green: 153/255.0, blue: 0, alpha: 1)
    private let fontSize : CGFloat = 16
    
    private var lineNode : LineNode? = nil
    private var sphereNode: SCNNode? = nil
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
            
            configuration.planeDetection = [.horizontal, .vertical]
            
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
            sceneView.automaticallyUpdatesLighting = true
            //sceneView.debugOptions = [.showFeaturePoints]
            sceneView.showsStatistics = false
            
            // Set the view's delegate and session delegate
            sceneView.delegate = self
            sceneView.session.delegate = self
            
            // Run the view's session
            arReady = false
            arStatus = "off"
            measuringStatus = "off"
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
    
    
    // MARK: Session handling ARSessionDelegate
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        arReady = false
        arStatus = "off"
        measuringStatus = "off"
        self.onMountError?(["message": error.localizedDescription])
    }
    
    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }

    public func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }

    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }
    
    // renderer callback method
    public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        if spheres.count > 1 || !arReady {
            return
        }
        
        
        DispatchQueue.main.async {
            
            // double check for race conditions
            if self.spheres.count > 1 || !self.arReady {
                return
            }
            
            let mStatus : String
            
            let (_, currentPosition, _) = self.doHitTestOnExistingPlanes(self.sceneView.center)
            
            
            if (currentPosition != nil) {
                
                // remove previous nodes
                self.lineNode?.removeFromParentNode()
                self.sphereNode?.removeFromParentNode()
                
                // if we have 1 node already, draw line
                if let start = self.spheres.first {
                    // line node
                    self.lineNode = LineNode(from: start.position, to: currentPosition!, lineColor: self.nodeColor)
                    
                    self.sceneView.scene.rootNode.addChildNode(self.lineNode!)
                    
                    // sphere node
                    self.sphereNode = SphereNode(at: currentPosition!, color: self.nodeColor)
                    
                    self.sceneView.scene.rootNode.addChildNode(self.sphereNode!)
                    self.showMeasure(self.sphereNode!.distance(to: start))
                    
                }
                
                // else, just add a node
                else{
                    // sphere node
                    self.sphereNode = SphereNode(at: currentPosition!, color: self.nodeColor)
                    
                    self.sceneView.scene.rootNode.addChildNode(self.sphereNode!)
                }
                
                mStatus = "ready"
            }
            else{
                // remove previous nodes
                self.lineNode?.removeFromParentNode()
                self.sphereNode?.removeFromParentNode()
                
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
    private func doHitTestOnExistingPlanes(_ location: CGPoint) -> (String?, SCNVector3?, ARHitTestResult?) {
        
        if(!arReady){
            return ("Not Ready", nil, nil)
        }
        
        // Searches for real world objects such as surfaces and filters out flat surfaces
        let hitTest = sceneView.hitTest(location, types: [.estimatedHorizontalPlane, .estimatedVerticalPlane, .featurePoint])
        
        // Assigns the most accurate result to a constant if it is non-nil
        guard let result = hitTest.last else {
            measurementLabel.text = "Please check your lightning and make sure you are not too far from the surface."
            
            return ("Detection failed", nil, nil)
        }
        
        if(result.distance < self.minDistanceCamera){
            measurementLabel.text = "Please check your lightning and make sure you are not too close to the surface."
            
            return ("Detection failed: too close to the surface", nil, nil)
        }
        
        if(result.distance > self.maxDistanceCamera){
            measurementLabel.text = "Please check your lightning and make sure you are not too far from the surface."
            
            return ("Detection failed: too far from the surface", nil, nil)
        }
        
        measurementLabel.text = ""
        
        let hitPos = SCNVector3.positionFrom(matrix: result.worldTransform)
        
        return (nil, hitPos, result)
    }
    
    
    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        let status: String

        switch trackingState {
            case .normal where frame.anchors.isEmpty:
                // No planes detected; provide instructions for this app's AR interactions.
                message = "Move the device around to detect surfaces."
                status = "no_anchors"
                arReady = false
                
            case .notAvailable:
                message = "Tracking unavailable."
                status = "not_available"
                arReady = false
                
            case .limited(.excessiveMotion):
                message = "Move the device more slowly."
                status = "excessive_motion"
                arReady = false
                
            case .limited(.insufficientFeatures):
                message = "Point the device at an area with visible surface detail, or improve lighting conditions."
                status = "insufficient_features"
                arReady = false
                
            case .limited(.initializing):
                message = "Move the device around to detect surfaces."
                status = "initializing"
                arReady = false
                
            case .limited(.relocalizing):
                message = "Move the device around to detect surfaces."
                status = "initializing"
                arReady = false
                
            default:
                // No feedback needed when tracking is normal and planes are visible.
                
                // if ready not set yet, clear messages
                if(!arReady){
                    message = ""
                    arReady = true
                }
                
                // otherwise, leave message as is
                else{
                    message = measurementLabel.text ?? ""
                }
                status = "ready"
        }

        measurementLabel.text = message
        
        if(status != arStatus){
            arStatus = status
            onARStatusChange?(["status": status])
        }
    }
}

// This is needed so the view uses the parent's space
// no longer needed, just use layoutSubviews
//private extension UIView {
//    func add(view: UIView) {
//        view.translatesAutoresizingMaskIntoConstraints = false
//        addSubview(view)
//        let views = ["view": view]
//        let hConstraints = NSLayoutConstraint.constraints(withVisualFormat: "|[view]|", options: [], metrics: nil, views: views)
//        let vConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]|", options: [], metrics: nil, views: views)
//        self.addConstraints(hConstraints)
//        self.addConstraints(vConstraints)
//    }
//}

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
        
        let box = SCNBox(width: 0.004, height: height, length: 0.004, chamferRadius: 0)
        let material = SCNMaterial()
        material.diffuse.contents = color
        box.materials = [material]
        
        
        let nodeLine = SCNNode(geometry: box)
        nodeLine.position.y = Float(-height/2) + 0.004
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
        
        // Creates an SCNSphere with a radius
        let sphere = SCNSphere(radius: 0.02)
        
        // Creates a material that is recognized by SceneKit
        let material = SCNMaterial()
        
        // Add color
        material.diffuse.contents = nodeColor
        
        // Creates realistic shadows around the sphere
        material.lightingModel = .blinn
        
        // Wraps the newly made material around the sphere
        sphere.firstMaterial = material
        
        // Positions the node based on the passed in position
        self.geometry = sphere
        self.position = position
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}


@available(iOS 11.0, *)
class TextNode: SCNNode {
    
    private let extrusionDepth: CGFloat = 0.1
    private let textNodeScale = SCNVector3Make(0.01, 0.01, 0.01)
    
    init(between vectorA: SCNVector3, and vectorB: SCNVector3, textLabel label: String, textColor color: UIColor) {
        super.init()
        
        let constraint = SCNBillboardConstraint()
        
        
        let text = SCNText(string: label, extrusionDepth: extrusionDepth)
        text.font = UIFont.systemFont(ofSize: 5, weight: UIFont.Weight.heavy)
        text.firstMaterial?.diffuse.contents = color
        text.firstMaterial?.isDoubleSided = true
        
        
        let x = (vectorA.x + vectorB.x) / 2
        let y = (vectorA.y + vectorB.y) / 2
        let z = (vectorA.z + vectorB.z) / 2
        
        let max = text.boundingBox.max
        let min = text.boundingBox.min
        let tx = (max.x + min.x) / 2.0
        let ty = (max.y + min.y) / 2.0
        let tz = Float(extrusionDepth) / 2.0
    
        
        self.pivot = SCNMatrix4MakeTranslation(tx, ty, tz)
        self.geometry = text
        self.scale = textNodeScale
        self.position = SCNVector3(x, y, z)
        self.constraints = [constraint]
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
}
