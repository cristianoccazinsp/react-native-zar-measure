import Foundation
import UIKit
import SceneKit
import ARKit


@available(iOS 11.0, *)
@objc public class ZarMeasureView: UIView, ARSCNViewDelegate, UIGestureRecognizerDelegate, ARSessionDelegate {
    

    // MARK: Public properties
    @objc public var units: String = "m"
    @objc public var onReady: RCTDirectEventBlock? = nil
    @objc public var onMountError: RCTDirectEventBlock? = nil
    @objc public var onMeasure: RCTDirectEventBlock? = nil
    
    

    // MARK: Private properties
    private var sceneView = ARSCNView()
    private var spheres: [SCNNode] = []
    private var measurementLabel = UILabel()


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
            
            // remove gesture handlers and stop session
            sceneView.gestureRecognizers?.removeAll()
            
            sceneView.session.pause()
        }
        else{
            
            // Create a session configuration
            let configuration = ARWorldTrackingConfiguration()
            //sceneView.preferredFramesPerSecond = 30
            
            
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
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
        
        add(view: sceneView)
        
        
        // Creates a background for the label
        measurementLabel.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        
        // Makes the background white
        measurementLabel.backgroundColor = UIColor(white: 1, alpha: 0.0)
        
        // Sets some default text
        measurementLabel.text = ""
        measurementLabel.textColor = .white
        
        // Centers the text
        measurementLabel.textAlignment = .center
        
        // Adds the text to the
        //add(view: measurementLabel)
        add(view: measurementLabel)
        
        // set session listener
        sceneView.session.delegate = self
    }
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        self.onMountError?(["message": error.localizedDescription])
    }
    
    @objc func handleTap(sender: UITapGestureRecognizer) {
            
        // Gets the location of the tap and assigns it to a constant
        let location = sender.location(in: sceneView)
        
        // Searches for real world objects such as surfaces and filters out flat surfaces
        let hitTest = sceneView.hitTest(location, types: [ARHitTestResult.ResultType.featurePoint])
        
        // Assigns the most accurate result to a constant if it is non-nil
        guard let result = hitTest.last else { return }
        
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
            
            self.onMeasure?(["distance": distance])
            
            if(self.units == "ft"){
                distance = distance * 3.28084
                unitsStr = "ft"
            }
            
            measurementLabel.text = "\(distance) \(unitsStr)"
            
            
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
        
        // Converts the contents of the PNG file into the material
        material.diffuse.contents = UIColor.orange
        
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
