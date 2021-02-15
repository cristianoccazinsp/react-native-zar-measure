import Foundation
import UIKit
import SceneKit
import ARKit


@available(iOS 11.0, *)
@objc public class ZarMeasureView: UIView, ARSCNViewDelegate, UIGestureRecognizerDelegate, ARSessionDelegate {
    

    // MARK: Public properties
    @objc public var units: String = "m"
    @objc public var hideHelp: Bool = false
    @objc public var minDistanceCamera: CGFloat = 0.05
    @objc public var maxDistanceCamera: CGFloat = 1
    @objc public var onReady: RCTDirectEventBlock? = nil
    @objc public var onMountError: RCTDirectEventBlock? = nil
    @objc public var onDetect: RCTDirectEventBlock? = nil
    @objc public var onMeasure: RCTDirectEventBlock? = nil
    @objc public var onMeasureError: RCTDirectEventBlock? = nil
    
    
    // MARK: Public methods
    
    func clear() -> Void
    {
        // no need for locks since everything runs on the UI thread
        spheres.removeAll()
        while let n = self.sceneView.scene.rootNode.childNodes.first { n.removeFromParentNode()
        }
        lineNode?.removeFromParentNode()
        measurementLabel.text = ""
    }
    

    // MARK: Private properties
    private var sceneView = ARSCNView()
    private var spheres: [SCNNode] = []
    private var measurementLabel = UILabel()
    private let nodeColor : UIColor = UIColor.orange
    private var lineNode : LineNode? = nil
    

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
        sceneView.session.pause()
    }
    
    public override func willMove(toSuperview newSuperview: UIView?){
        super.willMove(toSuperview: newSuperview)
        
        if(newSuperview == nil){
            
            // remove gesture handlers, delegates, and stop session
            sceneView.gestureRecognizers?.removeAll()
            sceneView.delegate = nil
            sceneView.session.delegate = nil
            sceneView.session.pause()
        }
        else{
            
            // Create a session configuration
            let configuration = ARWorldTrackingConfiguration()
            
            //sceneView.preferredFramesPerSecond = 30
            sceneView.automaticallyUpdatesLighting = true
            sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
            sceneView.showsStatistics = false
            
            // Set the view's delegate and session delegate
            sceneView.delegate = self
            sceneView.session.delegate = self
            
            // Add gesture handlers
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            
            // Sets the amount of taps needed to trigger the handler
            tapRecognizer.numberOfTapsRequired = 1
            
            // Adds the handler to the scene view
            sceneView.addGestureRecognizer(tapRecognizer)
            
            // Run the view's session
            sceneView.session.run(configuration)
            
            self.onReady?(nil)
            
        }
    }

    private func commonInit() {
        
        
        add(view: sceneView)
        
        
        // Creates a background for the label
        measurementLabel.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        
        // Makes the background white
        measurementLabel.backgroundColor = UIColor(white: 1, alpha: 0.0)
        
        // Sets some default text
        measurementLabel.text = ""
        measurementLabel.textColor = .white
        measurementLabel.numberOfLines = 3
        
        // Centers the text
        measurementLabel.textAlignment = .center
        
        // Adds the text to the
        //add(view: measurementLabel)
        add(view: measurementLabel)
        
        
    }
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        self.onMountError?(["message": error.localizedDescription])
    }
    
    @objc func handleTap(sender: UITapGestureRecognizer) {
            
        // Gets the location of the tap and assigns it to a constant
        let location = sender.location(in: sceneView)
        
        // Searches for real world objects such as surfaces and filters out flat surfaces
        let hitTest = sceneView.hitTest(location, types: [.featurePoint])
        
        // Assigns the most accurate result to a constant if it is non-nil
        guard let result = hitTest.last else {
            if(!hideHelp){
                measurementLabel.text = "Detection failed. Please check your lightning and make sure you are not too far from the surface."
            }
            self.onMeasureError?(["message": "Detection failed"])
            return
        }
        
        if(result.distance < self.minDistanceCamera){
            if(!hideHelp){
                measurementLabel.text = "Detection failed. Please check your lightning and make sure you are not too close to the surface."
            }
            self.onMeasureError?(["message": "Detection failed: too close to the surface."])
            return
        }
        
        if(result.distance > self.maxDistanceCamera){
            if(!hideHelp){
                measurementLabel.text = "Detection failed. Please check your lightning and make sure you are not too far from the surface."
            }
            self.onMeasureError?(["message": "Detection failed: too far from the surface."])
            return
        }
        
        measurementLabel.text = ""
        
        self.onDetect?(["cameraDistance": result.distance])
        
        // Converts the matrix_float4x4 to an SCNMatrix4 to be used with SceneKit
        let transform = SCNMatrix4.init(result.worldTransform)
        
        // Creates an SCNVector3 with certain indexes in the matrix
        let vector = SCNVector3Make(transform.m41, transform.m42, transform.m43)
        
        // Makes a new sphere with the created method
        let sphere = newSphere(at: vector)
        
        // Checks if there is at least one sphere in the array
        if let last = spheres.last {
            
            // Adds a second sphere to the array
            spheres.append(sphere)
            
            var distance = sphere.distance(to: last)
            var unitsStr = "m"
            
            // safe to call since we know these fire in the UI thread
            self.onMeasure?(["distance": distance, "cameraDistance": result.distance])
            
            if(self.units == "ft"){
                distance = distance * 3.28084
                unitsStr = "ft"
            }
            
            measurementLabel.text = "\(distance) \(unitsStr)"
            
            let measureLine = LineNode(from: last.position, to: sphere.position, lineColor: self.nodeColor)
            
            
            // remove any previous line, if any
            // and add new one
            lineNode?.removeFromParentNode()
            lineNode = measureLine
            self.sceneView.scene.rootNode.addChildNode(measureLine)
            
            // remove extra spheres
            while spheres.count > 2 {
                let f = spheres.removeFirst()
                f.removeFromParentNode()
            }
            
        
        // If there are no spheres...
        } else {
            // Add the sphere
            spheres.append(sphere)
        }
        
        self.sceneView.scene.rootNode.addChildNode(sphere)
        
    }
    
    // Creates measuring endpoints
    func newSphere(at position: SCNVector3) -> SCNNode {
        
        // Creates an SCNSphere with a radius of 0.4
        let sphere = SCNSphere(radius: 0.01)
        
        // Converts the sphere into an SCNNode
        let node = SCNNode(geometry: sphere)
        
        // Positions the node based on the passed in position
        node.position = position
        
        // Creates a material that is recognized by SceneKit
        let material = SCNMaterial()
        
        // Add color
        material.diffuse.contents = self.nodeColor
        
        // Creates realistic shadows around the sphere
        material.lightingModel = .blinn
        
        // Wraps the newly made material around the sphere
        sphere.firstMaterial = material
        
        // Returns the node to the function
        return node
        
    }

    public override func layoutSubviews() {
        sceneView.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        sceneView.setNeedsDisplay()
        
        super.layoutSubviews()
    }
}

// This is needed so the view uses the parent's space
private extension UIView {
    func add(view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        let views = ["view": view]
        let hConstraints = NSLayoutConstraint.constraints(withVisualFormat: "|[view]|", options: [], metrics: nil, views: views)
        let vConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]|", options: [], metrics: nil, views: views)
        self.addConstraints(hConstraints)
        self.addConstraints(vConstraints)
    }
}

extension SCNNode {
    
    // Gets distance between two SCNNodes in meters
    func distance(to destination: SCNNode) -> CGFloat {
        
        // Difference between x-positions
        let dx = destination.position.x - position.x
        
        // Difference between x-positions
        let dy = destination.position.y - position.y
        
        // Difference between x-positions
        let dz = destination.position.z - position.z
        
        // Formula to get meters
        let meters = sqrt(dx*dx + dy*dy + dz*dz)
        
        // Returns inches
        return CGFloat(meters)
    }
}


class LineNode: SCNNode {
    
    init(from vectorA: SCNVector3, to vectorB: SCNVector3, lineColor color: UIColor) {
        super.init()
        
        let height = self.distance(from: vectorA, to: vectorB)
        
        self.position = vectorA
        let nodeVector2 = SCNNode()
        nodeVector2.position = vectorB
        
        let nodeZAlign = SCNNode()
        nodeZAlign.eulerAngles.x = Float.pi/2
        
        let box = SCNBox(width: 0.001, height: height, length: 0.001, chamferRadius: 0)
        let material = SCNMaterial()
        material.diffuse.contents = color
        box.materials = [material]
        
        
        let nodeLine = SCNNode(geometry: box)
        nodeLine.position.y = Float(-height/2) + 0.001
        nodeZAlign.addChildNode(nodeLine)
        
        self.addChildNode(nodeZAlign)
        
        self.constraints = [SCNLookAtConstraint(target: nodeVector2)]
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func distance(from vectorA: SCNVector3, to vectorB: SCNVector3)-> CGFloat {
        return CGFloat (sqrt(
            (vectorA.x - vectorB.x) * (vectorA.x - vectorB.x)
                +   (vectorA.y - vectorB.y) * (vectorA.y - vectorB.y)
                +   (vectorA.z - vectorB.z) * (vectorA.z - vectorB.z)))
    }
    
}
