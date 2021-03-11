import Foundation
import UIKit
import ARKit


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
    let extentNode: SCNNode
    let color: UIColor
    var classificationNode: SCNNode?
    
    /// - Tag: VisualizePlane
    init(anchor: ARPlaneAnchor) {
        
        color = anchor.color
        
        // Create a node to visualize the plane's bounding rectangle.
        let extentPlane = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        extentNode = SCNNode(geometry: extentPlane)
        extentNode.simdPosition = anchor.center
        
        extentPlane.firstMaterial?.readsFromDepthBuffer = false
        extentPlane.firstMaterial?.writesToDepthBuffer = false
        extentPlane.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.5)
        
        extentNode.renderingOrder = -5
        
        // `SCNPlane` is vertically oriented in its local coordinate space, so
        // rotate it to match the orientation of `ARPlaneAnchor`.
        extentNode.eulerAngles.x = -.pi / 2

        super.init()


        // Add the plane extent and plane geometry as child nodes so they appear in the scene.
        //addChildNode(geometryNode)
        addChildNode(extentNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func updatePlane(_ anchor: ARPlaneAnchor){

        // Update extent visualization to the anchor's new bounding rectangle.
        if let extentGeometry = extentNode.geometry as? SCNPlane {
            extentGeometry.width = CGFloat(anchor.extent.x)
            extentGeometry.height = CGFloat(anchor.extent.z)
            extentNode.simdPosition = anchor.center
        }
    }
}

@available(iOS 13.4, *)
class DebugMesh: SCNNode {
    
    let meshNode: SCNNode
    var classification: ARMeshClassification
    
    /// - Tag: VisualizePlane
    init(anchor: ARMeshAnchor) {
        
        let geometry = SCNGeometry.fromAnchor(meshAnchor: anchor)

        classification = anchor.geometry.classificationOf(faceWithIndex: 0)
        
        // assign a material suitable for default visualization
        let defaultMaterial = SCNMaterial()
        defaultMaterial.fillMode = .lines
        defaultMaterial.diffuse.contents = classification.color.withAlphaComponent(0.8)
        defaultMaterial.readsFromDepthBuffer = false
        defaultMaterial.writesToDepthBuffer = false
        geometry.materials = [defaultMaterial]
        
        meshNode = SCNNode()
        meshNode.geometry = geometry
        meshNode.renderingOrder = -4
        
        super.init()
        self.renderingOrder = -4
        
        addChildNode(meshNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func updateMesh(_ anchor: ARMeshAnchor){
        classification = anchor.geometry.classificationOf(faceWithIndex: 0)
        let newGeometry = SCNGeometry.fromAnchor(meshAnchor: anchor)
        let defaultMaterial = SCNMaterial()
        defaultMaterial.fillMode = .lines
        defaultMaterial.diffuse.contents = classification.color.withAlphaComponent(0.8)
        defaultMaterial.readsFromDepthBuffer = false
        defaultMaterial.writesToDepthBuffer = false
        newGeometry.materials = [defaultMaterial]
        meshNode.geometry = newGeometry
    }
}
