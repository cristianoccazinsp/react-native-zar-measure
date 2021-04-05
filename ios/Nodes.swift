import Foundation
import UIKit
import ARKit


public typealias MeasurementLine = Dictionary<String, Any>
public typealias MeasurementLine2D = Dictionary<String, Any>
public typealias JSARPlane = Dictionary<String, Any>
public typealias CoordinatePoint = Dictionary<String, NSNumber> // JS may send doubles


@available(iOS 13, *)
class HitResult {
    // wrapper for hit results
    var distance : CGFloat
    var transform : simd_float4x4
    var anchor : ARAnchor? = nil
    var position : SCNVector3
    var isCloseNode : Bool
    var alignment: NodeAlignment // aproximate alignment from raycast result
    
    // Shorthand for plane anchors
    var planeAnchor : ARPlaneAnchor? {
        get {
            return self.anchor as? ARPlaneAnchor
        }
    }
    
    init(_ distance:CGFloat, _ hitPos:SCNVector3, _ closeNode:Bool, _ raycast:ARRaycastResult){
        self.distance = distance
        self.transform = raycast.worldTransform
        self.anchor = raycast.anchor //as? ARPlaneAnchor
        self.position = hitPos
        self.isCloseNode = closeNode
        
        
        // if anchor is available, use it right away
        if let anchor = raycast.anchor as? ARPlaneAnchor {
            self.alignment = anchor.alignment == .vertical ? .vertical : .horizontal
        }
        
        // else, use Y rotation value
        // apropximate: close to 0 is vertical
        // close to 1 is horizontal
        else {
            let ry = abs(self.transform.columns.1.y)
            
            if ry <= 0.15 {
                self.alignment = .vertical
            }
            else if ry >= 0.85 {
                self.alignment = .horizontal
            }
            else {
                self.alignment = .none
            }
        }
    }
    
    // initializer for close node detection
    init(_ distance:CGFloat, _ closeNode: SphereNode){
        self.distance = distance
        self.alignment = closeNode.alignment
        self.transform = simd_float4x4(closeNode.worldTransform)
        self.anchor = closeNode.anchor
        self.position = closeNode.position
        self.isCloseNode = true
    }
}


enum NodeAlignment : UInt8 {
    case none = 0
    case horizontal = 1
    case vertical = 2
}


@available(iOS 13, *)
class MeasurementGroup {
    var id : String
    var planeId: String = "" // if it was added as part of a plane add operation
    var node1 : SphereNode
    var node2 : SphereNode
    var line : LineNode
    var text : TextNode
    var distance : Float
    
    init(_ node1:SphereNode, _ node2:SphereNode, _ line:LineNode, _ text:TextNode, _ distance:CGFloat){
        self.id = UUID().uuidString
        self.node1 = node1
        self.node2 = node2
        self.line = line
        self.text = text
        self.distance = Float(distance)
        self.text.measureId = id
        self.node1.measureId = id
        self.node2.measureId = id
    }
    
    convenience init(_ planeId : String, _ node1:SphereNode, _ node2:SphereNode, _ line:LineNode, _ text:TextNode, _ distance:CGFloat){
        self.init(node1, node2, line, text, distance)
        self.planeId = planeId
    }
    
    func removeNodes(){
        node1.removeFromParentNode()
        node2.removeFromParentNode()
        line.removeFromParentNode()
        text.removeFromParentNode()
    }
    
    func toDict() -> MeasurementLine {
        return [
            "id": id,
            "planeId": planeId,
            "node1": [
                "x": node1.worldPosition.x,
                "y": node1.worldPosition.y,
                "z": node1.worldPosition.z,
                "a": node1.alignment.rawValue
            ],
            "node2": [
                "x": node2.worldPosition.x,
                "y": node2.worldPosition.y,
                "z": node2.worldPosition.z,
                "a": node1.alignment.rawValue
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
                "planeId": planeId,
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
                    "y": projected1.y,
                    "a": node1.alignment.rawValue
                ]
            }
            
            if (projected2.x >= 0 && projected2.x <= size.width && projected2.y >= 0 && projected2.y <= size.height){
                
                res["node2"] = [
                    "x": projected2.x,
                    "y": projected2.y,
                    "a": node2.alignment.rawValue
                ]
            }
            
            return res
        }
        
        return nil
        
    }
}


@available(iOS 11.0, *)
class LineNode: SCNNode {
    private let cylinder : SCNCylinder
    private let width = CGFloat(0.002)
    
    init(from vectorA: SCNVector3, to vectorB: SCNVector3, lineColor color: UIColor) {
        
        let distance = vectorA.distance(to: vectorB)
        cylinder = SCNCylinder(radius: width, height: distance)
        cylinder.radialSegmentCount = 3
        cylinder.firstMaterial?.diffuse.contents = color
        cylinder.firstMaterial?.readsFromDepthBuffer = false
        cylinder.firstMaterial?.writesToDepthBuffer = false

        let lineNode = SCNNode(geometry: cylinder)

        lineNode.position = SCNVector3(x: (vectorA.x + vectorB.x) / 2,
                                       y: (vectorA.y + vectorB.y) / 2,
                                       z: (vectorA.z + vectorB.z) / 2)

        lineNode.eulerAngles = SCNVector3(
            Float.pi / 2,
            acos((vectorB.z-vectorA.z)/Float(distance)),
            atan2((vectorB.y-vectorA.y),(vectorB.x-vectorA.x))
        )
        lineNode.renderingOrder = 0
        
        super.init()
        self.addChildNode(lineNode)

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setScale(sceneView view : ARSCNView, in relationTo:SCNNode){
        guard let pov = view.pointOfView else {
            return
        }
        let distance = min(pov.distance(to: relationTo), 5)
        let scale = CGFloat(0.5 + distance * 0.8)
        cylinder.radius = width * scale
    }
}


@available(iOS 11.0, *)
class SphereNode: SCNNode {
    var measureId : String?
    var alignment: NodeAlignment = .none
    
    // to be set for sticky planes
    var anchor: ARPlaneAnchor? = nil
    
    init(at position: SCNVector3, color nodeColor: UIColor, alignment: NodeAlignment) {
        super.init()
        
        self.alignment = alignment
        self.name = "spherenode"
        
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
        
        
        // add a small invisible sphere that is bigger in order to
        // receive hit tests
        let hitSphere = SCNSphere(radius: 0.05)
        let hitNode = SCNNode(geometry: hitSphere)
        hitNode.isHidden = true
        
        let material2 = SCNMaterial()
        material2.diffuse.contents = UIColor.red
        material2.fillMode = .lines
        hitSphere.firstMaterial = material2
        
        self.addChildNode(hitNode)
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
        fatalError("init(coder:) has not been implemented")
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
        sphereNode.name = "targetsphere"
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
            
            self.childNode(withName: "targetsphere", recursively: false)?.geometry?.firstMaterial?.diffuse.contents = color
        }
    }
    
    func setSphereScale(sceneView view : ARSCNView){
        guard let pov = view.pointOfView else {
            return
        }
        guard let sphere = self.childNode(withName: "targetsphere", recursively: false) else {
            return
        }

        let distance = min(pov.distance(to: self), 5)
        let scale = Float(0.5 + distance * 0.5)
        sphere.scale = SCNVector3Make(scale, scale, scale)
    }
    
    func setDonutScale(sceneView view : ARSCNView, hitResult hit: HitResult){
        
        guard let donut = self.childNode(withName: "donut", recursively: false) else {return}
                
        if let _anchor = hit.anchor {
            guard let anchoredNode = view.node(for: _anchor) else { return }
            
            // rotate our donut based on detected anchor
            donut.rotation = anchoredNode.rotation
        }
        else{
            
            let dummy = SCNNode()
            dummy.transform = SCNMatrix4(hit.transform)
            donut.rotation = dummy.rotation
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


@available(iOS 13, *)
class TextNode: SCNNode {
    
    private let extrusionDepth: CGFloat = 0.1
    var measureId : String?
    var label = ""
    
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

        let plane = SCNPlane(width: CGFloat(bound.x + 6),
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
        fatalError("init(coder:) has not been implemented")
    }
}


let PLANE_BORDER_SM =
    "float u = _surface.diffuseTexcoord.x; \n" +
    "float v = _surface.diffuseTexcoord.y; \n" +
    "int u100 = int(u * 1000.0); \n" +
    "int v100 = int(v * 1000.0); \n" +
    "if (u100 % 100 == 0 || u100 % 100 == 99 || v100 % 100 == 0 || v100 % 100 == 99) { \n" +
    "    // do nothing \n" +
    "} else { \n" +
    "    discard_fragment(); \n" +
    "} \n"

@available(iOS 13.0, *)
class AnchorPlaneNode: SCNNode {
    let extentNode: SCNNode
    let sphereNode: SCNNode
    let gridNode: SCNNode?
    
    
    init(anchor: ARPlaneAnchor, grid: Bool = true) {
        
        let color = anchor.color
        
        // Create a node to visualize the plane's bounding rectangle.
        let extentPlane = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        extentNode = SCNNode(geometry: extentPlane)
        extentNode.simdPosition = anchor.center
        extentPlane.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.4)
        extentNode.renderingOrder = -5
        
        // `SCNPlane` is vertically oriented in its local coordinate space, so
        // rotate it to match the orientation of `ARPlaneAnchor`.
        extentNode.eulerAngles.x = -.pi / 2
        
        
        // to visualize the plane's center
        let sphere = SCNSphere(radius: 0.005)
        sphere.firstMaterial?.diffuse.contents = color
        
        sphereNode = SCNNode(geometry: sphere)
        sphereNode.simdPosition = anchor.center
        sphereNode.renderingOrder = -4
        
        // if grid node
        if grid {
            let gridPlane = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
            gridPlane.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.8)
            gridPlane.firstMaterial?.shaderModifiers = [SCNShaderModifierEntryPoint.surface:PLANE_BORDER_SM]
            
            let _gridNode = SCNNode(geometry: gridPlane)
            _gridNode.simdPosition = anchor.center
            _gridNode.renderingOrder = -4
            _gridNode.eulerAngles.x = -.pi / 2
            
            gridNode = _gridNode
        }
        else {
            gridNode = nil
        }

        super.init()
        self.name = "AnchorPlaneNode"

        // Add the plane extent and plane geometry as child nodes so they appear in the scene.
        //addChildNode(geometryNode)
        addChildNode(extentNode)
        addChildNode(sphereNode)
        
        if gridNode != nil {
            addChildNode(gridNode!)
        }
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func updatePlane(_ anchor: ARPlaneAnchor){
        let color = anchor.color
        
        // Update extent visualization to the anchor's new bounding rectangle.
        if let extentGeometry = extentNode.geometry as? SCNPlane {
            extentGeometry.width = CGFloat(anchor.extent.x)
            extentGeometry.height = CGFloat(anchor.extent.z)
            extentGeometry.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.4)
            extentNode.simdPosition = anchor.center
        }
        
        if let _gridNode = gridNode, let gridGeometry = _gridNode.geometry as? SCNPlane {
            gridGeometry.width = CGFloat(anchor.extent.x)
            gridGeometry.height = CGFloat(anchor.extent.z)
            gridGeometry.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.8)
            _gridNode.simdPosition = anchor.center
        }
        
        sphereNode.simdPosition = anchor.center
        sphereNode.geometry?.firstMaterial?.diffuse.contents = color
        
    }
}


@available(iOS 13.0, *)
class AnchorGeometryNode: SCNNode {
    let meshNode: SCNNode
    
    init(anchor: ARPlaneAnchor, in sceneView: ARSCNView) {
        
        // Create a mesh to visualize the estimated shape of the plane.
        guard let meshGeometry = ARSCNPlaneGeometry(device: sceneView.device!)
            else { fatalError("Can't create plane geometry") }
        
        meshGeometry.update(from: anchor.geometry)
        meshGeometry.firstMaterial?.diffuse.contents = anchor.color.withAlphaComponent(0.5)
        meshNode = SCNNode(geometry: meshGeometry)
        meshNode.renderingOrder = -5

        super.init()
        self.name = "AnchorGeometryNode"
        
        addChildNode(meshNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func updateMesh(_ anchor: ARPlaneAnchor){
        if let meshGeometry = meshNode.geometry as? ARSCNPlaneGeometry {
            meshGeometry.update(from: anchor.geometry)
            meshGeometry.firstMaterial?.diffuse.contents = anchor.color.withAlphaComponent(0.5)
        }
    }
}


@available(iOS 13.4, *)
class AnchorMeshNode: SCNNode {
    
    let meshNode: SCNNode
    var defaultMaterial = SCNMaterial()
    
    /// - Tag: VisualizePlane
    init(anchor: ARMeshAnchor) {
        
        let geometry = SCNGeometry.fromAnchor(meshAnchor: anchor, setColors: true)
        
        // assign a material suitable for default visualization
        defaultMaterial.fillMode = .lines
        geometry.materials = [defaultMaterial]
        
        meshNode = SCNNode()
        meshNode.geometry = geometry
        
        super.init()
        self.name = "AnchorMeshNode"
        self.renderingOrder = -4
        
        addChildNode(meshNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func updateMesh(_ anchor: ARMeshAnchor){
        let newGeometry = SCNGeometry.fromAnchor(meshAnchor: anchor, setColors: true)
        meshNode.geometry = newGeometry
        newGeometry.materials = [defaultMaterial]
    }
}
