import Foundation
import UIKit
import ARKit


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


// helper to create a translation matrix
func translateTransform(_ x: Float, _ y: Float, _ z: Float) -> float4x4 {
    var tf = float4x4(diagonal: SIMD4<Float>(repeating: 1))
    tf.columns.3 = SIMD4<Float>(x: x, y: y, z: z, w: 1)
    return tf
}

@available(iOS 13.0, *)
extension ARPlaneAnchor {
    var color: UIColor {
        switch self.alignment {
            case .horizontal: return .blue
            case .vertical: return .yellow
            @unknown default: return .blue
        }
    }
    
    func getId() -> String {
        return identifier.uuidString
    }
    
    func toDict() -> JSARPlane {
        let (topLeft, _, _, _) = worldPoints()
        
        return [
            "id": getId(),
            "x": topLeft.x,
            "y": topLeft.y,
            "z": topLeft.z,
            "width": extent.x,
            "height": extent.z,
            "vertical": alignment == .vertical
        ]
    }
    
    func area() -> Float {
        return extent.x * extent.z
    }
    
    // returns all 4 world coordinates of the given plane
    // (topLeft, topRight, bottomLeft, bottomRight)
    func worldPoints() -> (SCNVector3, SCNVector3, SCNVector3, SCNVector3) {
        
        // Get world's updated center
        let worldTransform = transform * translateTransform(center.x, 0, center.z)
        
        let width = extent.x
        let height = extent.z

        let topLeft = worldTransform * translateTransform(-width / 2.0, 0, -height / 2.0)
        let topRight = worldTransform * translateTransform(width / 2.0, 0, -height / 2.0)
        let bottomLeft = worldTransform * translateTransform(-width / 2.0, 0, height / 2.0)
        let bottomRight = worldTransform * translateTransform(width / 2.0, 0, height / 2.0)

       
        let pointTopLeft = SCNVector3(
            x: topLeft.columns.3.x,
            y: topLeft.columns.3.y,
            z: topLeft.columns.3.z
        )

        let pointTopRight = SCNVector3(
            x: topRight.columns.3.x,
            y: topRight.columns.3.y,
            z: topRight.columns.3.z
        )

        let pointBottomLeft = SCNVector3(
            x: bottomLeft.columns.3.x,
            y: bottomLeft.columns.3.y,
            z: bottomLeft.columns.3.z
        )

        let pointBottomRight = SCNVector3(
            x: bottomRight.columns.3.x,
            y: bottomRight.columns.3.y,
            z: bottomRight.columns.3.z
        )
        
        return (
            pointTopLeft,
            pointTopRight,
            pointBottomLeft,
            pointBottomRight
        )
    }
}


@available(iOS 13.4, *)
extension ARMeshClassification {
    var description: String {
        switch self {
            case .ceiling: return "Ceiling"
            case .door: return "Door"
            case .floor: return "Floor"
            case .seat: return "Seat"
            case .table: return "Table"
            case .wall: return "Wall"
            case .window: return "Window"
            case .none: return "None"
            @unknown default: return "Unknown"
        }
    }
    
    // make more or less same vertical/horizontal colors as planes
    var color: UIColor {
        switch self {
            case .ceiling: return .blue
            case .door: return .white
            case .floor: return .blue
            case .seat: return .white
            case .table: return .white
            case .wall: return .yellow
            case .window: return .white
            case .none: return .white
            @unknown default: return .white
        }
    }
}


@available(iOS 13.4, *)
extension SCNGeometry {
    
    /**
     Constructs an SCNGeometry element from an ARMeshAnchor.
     
     Note, the underlying vertex data is owned by the ARMeshAnchor so this geometry becomes invalid when the
     anchor is updated or removed.
    */
    public static func fromAnchor(meshAnchor: ARMeshAnchor) -> SCNGeometry {
        let vertices = meshAnchor.geometry.vertices
        let faces = meshAnchor.geometry.faces
        
        // use the MTL buffer that ARKit gives us
        let vertexSource = SCNGeometrySource(buffer: vertices.buffer, vertexFormat: vertices.format, semantic: .vertex, vertexCount: vertices.count, dataOffset: vertices.offset, dataStride: vertices.stride)
        
        // Copy bytes as we may use them later
        let faceData = Data(bytes: faces.buffer.contents(), count: faces.buffer.length)
        
        // create the geometry element
        let geometryElement = SCNGeometryElement(data: faceData, primitiveType: .of(faces.primitiveType), primitiveCount: faces.count, bytesPerIndex: faces.bytesPerIndex)
        let geometry = SCNGeometry(sources: [vertexSource], elements: [geometryElement])
        
        return geometry;
    }
}


@available(iOS 13.4, *)
extension SCNGeometryPrimitiveType {
    static  func  of(_ type: ARGeometryPrimitiveType) -> SCNGeometryPrimitiveType {
       switch type {
       case .line:
            return .line
       case .triangle:
            return .triangles
       @unknown default:
            return .line
       }
    }
}


@available(iOS 13.4, *)
extension ARMeshGeometry {
    func classificationOf(faceWithIndex index: Int) -> ARMeshClassification {
        guard let classification = classification else { return .none }
        let classificationAddress = classification.buffer.contents().advanced(by: index)
        let classificationValue = Int(classificationAddress.assumingMemoryBound(to: UInt8.self).pointee)
        return ARMeshClassification(rawValue: classificationValue) ?? .none
    }
}