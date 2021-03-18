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


// Init these only once to avoid excessive calls and array creation
let SIMD4_FLOAT_STRIDE = MemoryLayout<SIMD4<Float>>.stride
let FLOAT_STRIDE = MemoryLayout<Float>.stride
let VECTOR_WHITE : SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
let VECTOR_YELLOW: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 0, 1.0)
let VECTOR_BLUE: SIMD4<Float> = SIMD4<Float>(0, 0, 1.0, 1.0)


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
    
    var colorVector: SIMD4<Float> {
        switch self {
            case .ceiling: return VECTOR_BLUE
            case .door: return VECTOR_WHITE
            case .floor: return VECTOR_BLUE
            case .seat: return VECTOR_WHITE
            case .table: return VECTOR_WHITE
            case .wall: return VECTOR_YELLOW
            case .window: return VECTOR_WHITE
            case .none: return VECTOR_WHITE
            @unknown default: return VECTOR_WHITE
        }
    }
}

@available(iOS 13.4, *)
extension SCNGeometry {
    
    /**
     Constructs an SCNGeometry element from an ARMeshAnchor.
     
      if setColors, will set colors automatically on each face based on ARMeshClassification above
    */
    public static func fromAnchor(meshAnchor: ARMeshAnchor, setColors: Bool) -> SCNGeometry {
        let meshGeometry = meshAnchor.geometry
        let vertices = meshGeometry.vertices
        let normals = meshGeometry.normals
        let faces = meshGeometry.faces
        
        // use the MTL buffer that ARKit gives us
        let vertexSource = SCNGeometrySource(buffer: vertices.buffer, vertexFormat: vertices.format, semantic: .vertex, vertexCount: vertices.count, dataOffset: vertices.offset, dataStride: vertices.stride)
        
        let normalsSource = SCNGeometrySource(buffer: normals.buffer, vertexFormat: normals.format, semantic: .normal, vertexCount: normals.count, dataOffset: normals.offset, dataStride: normals.stride)

        // Copy bytes as we may use them later
        let faceData = Data(bytes: faces.buffer.contents(), count: faces.buffer.length)
        
        // create the geometry element
        let geometryElement = SCNGeometryElement(data: faceData, primitiveType: .of(faces.primitiveType), primitiveCount: faces.count, bytesPerIndex: faces.bytesPerIndex)
        
        
        let geometry : SCNGeometry
        
        if setColors {
            // calculate colors for each indivudal face, instead of the entire mesh
            
            var colors = [SIMD4<Float>]()
            
            for i in 0..<faces.count {
                colors.append(meshGeometry.classificationOf(faceWithIndex: i).colorVector)
            }
            
            let colorSource = SCNGeometrySource(data: Data(bytes: &colors, count: colors.count * SIMD4_FLOAT_STRIDE),
                semantic: .color,
                vectorCount: colors.count,
                usesFloatComponents: true,
                componentsPerVector: 4,
                bytesPerComponent: FLOAT_STRIDE,
                dataOffset: 0,
                dataStride: SIMD4_FLOAT_STRIDE
            )
            
            geometry = SCNGeometry(sources: [vertexSource, normalsSource, colorSource], elements: [geometryElement])
        }
        else {
            geometry = SCNGeometry(sources: [vertexSource, normalsSource], elements: [geometryElement])
        }

        return geometry;
    }
}


@available(iOS 13.4, *)
extension SCNGeometryPrimitiveType {
    static func of(_ type: ARGeometryPrimitiveType) -> SCNGeometryPrimitiveType {
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

    func vertex(at index: UInt32) -> (Float, Float, Float) {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: (Float, Float, Float).self).pointee
        return vertex
    }
    
    // leaving this here just in case we need it later
    //    func classificationOf(faceWithIndex index: Int) -> ARMeshClassification {
    //        guard let classification = classification else { return .none }
    //        let classificationAddress = classification.buffer.contents().advanced(by: index)
    //        let classificationValue = Int(classificationAddress.assumingMemoryBound(to: UInt8.self).pointee)
    //        return ARMeshClassification(rawValue: classificationValue) ?? .none
    //    }
        
    func classificationOf(faceWithIndex index: Int) -> ARMeshClassification {
        guard let classification = classification else { return .none }
        assert(classification.format == MTLVertexFormat.uchar, "Expected one unsigned char (one byte) per classification")
        let classificationPointer = classification.buffer.contents().advanced(by: classification.offset + (classification.stride * index))
        let classificationValue = Int(classificationPointer.assumingMemoryBound(to: CUnsignedChar.self).pointee)
        return ARMeshClassification(rawValue: classificationValue) ?? .none
    }
    
    func vertexIndicesOf(faceWithIndex faceIndex: Int) -> [UInt32] {
        assert(faces.bytesPerIndex == MemoryLayout<UInt32>.size, "Expected one UInt32 (four bytes) per vertex index")
        let vertexCountPerFace = faces.indexCountPerPrimitive
        let vertexIndicesPointer = faces.buffer.contents()
        var vertexIndices = [UInt32]()
        vertexIndices.reserveCapacity(vertexCountPerFace)
        for vertexOffset in 0..<vertexCountPerFace {
            let vertexIndexPointer = vertexIndicesPointer.advanced(by: (faceIndex * vertexCountPerFace + vertexOffset) * MemoryLayout<UInt32>.size)
            vertexIndices.append(vertexIndexPointer.assumingMemoryBound(to: UInt32.self).pointee)
        }
        return vertexIndices
    }
    
    func verticesOf(faceWithIndex index: Int) -> [(Float, Float, Float)] {
        let vertexIndices = vertexIndicesOf(faceWithIndex: index)
        let vertices = vertexIndices.map { vertex(at: $0) }
        return vertices
    }
    
    func centerOf(faceWithIndex index: Int) -> (Float, Float, Float) {
        let vertices = verticesOf(faceWithIndex: index)
        let sum = vertices.reduce((0, 0, 0)) { ($0.0 + $1.0, $0.1 + $1.1, $0.2 + $1.2) }
        let geometricCenter = (sum.0 / 3, sum.1 / 3, sum.2 / 3)
        return geometricCenter
    }
}
