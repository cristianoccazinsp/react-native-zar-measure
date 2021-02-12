import Foundation
import UIKit
import SceneKit
import ARKit


@available(iOS 11.0, *)
@objc public class CTZarMeasureView: UIView, ARSCNViewDelegate, UIGestureRecognizerDelegate {
    

    // MARK: Public properties
//    @objc public var onReady: RCTDirectEventBlock? = nil
//    @objc public var onMountError: RCTDirectEventBlock? = nil
    

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

    private func commonInit() {
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
                        
        // Creates a tap handler and then sets it to a constant
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        
        // Sets the amount of taps needed to trigger the handler
        tapRecognizer.numberOfTapsRequired = 1
        
        // Adds the handler to the scene view
        sceneView.addGestureRecognizer(tapRecognizer)
        sceneView.frame = frame
        
        add(view: sceneView)
        
        
        // Creates a background for the label
        measurementLabel.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        
        // Makes the background white
        measurementLabel.backgroundColor = UIColor(white: 1, alpha: 0.0)
        
        // Sets some default text
        measurementLabel.text = "0 m"
        measurementLabel.textColor = .white
        
        // Centers the text
        measurementLabel.textAlignment = .center
        
        // Adds the text to the
        //add(view: measurementLabel)
        add(view: measurementLabel)
        
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
        
        //self.onReady?(nil)
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
        if let first = spheres.first {
            
            // Adds a second sphere to the array
            spheres.append(sphere)
            measurementLabel.text = "\(sphere.distance(to: first)) m"
            
            // If more that two are present...
            if spheres.count > 2 {
                
                // Iterate through spheres array
                for sphere in spheres {
                    
                    // Remove all spheres
                    sphere.removeFromParentNode()
                }
                
                // Remove extraneous spheres
                spheres = [spheres[2]]
            }
        
        // If there are no spheres...
        } else {
            // Add the sphere
            spheres.append(sphere)
        }
        
        // Iterate through spheres array
        for sphere in spheres {
            
            // Add all spheres in the array
            self.sceneView.scene.rootNode.addChildNode(sphere)
        }
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
    

//    public override func willMove(toSuperview newSuperview: UIView?){
//        if(newSuperview == nil){
//            sceneView.session.pause()
//        }
//        else{
//            // Create a session configuration
//            let configuration = ARWorldTrackingConfiguration()
//
//            // Run the view's session
//            sceneView.session.run(configuration)
//        }
//        super.willMove(toSuperview: newSuperview)
//    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        sceneView.frame = frame
        sceneView.setNeedsDisplay()
    }
}

// review if needed
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
