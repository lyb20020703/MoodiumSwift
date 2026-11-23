import RealityKit
import Metal
import simd

@MainActor final class SoftDeformation {
    struct Vertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
        var uv: SIMD2<Float>
        var pad = SIMD2<Float>.zero
        var tangent: SIMD3<Float>
        var bitangent: SIMD3<Float>
    }
    struct Parameters {
        var touch: SIMD3<Float>
        var inward: SIMD3<Float>
        var grab: SIMD3<Float>
        var radius: Float
        var depth: Float
        var weight: Float
        var grabRadius: Float
        var count: UInt32
    }
    let entity: Entity
    let mesh: LowLevelMesh
    let originalBounds: BoundingBox
    private let queue: MTLCommandQueue
    private let deform: MTLComputePipelineState
    private let normals: MTLComputePipelineState
    private let source: MTLBuffer, indices: MTLBuffer, offsets: MTLBuffer, faces: MTLBuffer
    private let count: Int
    private var weight: Float = 0
    private var touch = SIMD3<Float>.zero
    private var touching = false
    private var dirty = false
    var strength: Float = 0.12, radius: Float = 0.45, recoverySpeed: Float = 7, maximum: Float = 0.18

    init(entity: Entity) throws {
        guard var component = entity.components[ModelComponent.self],
              let model = component.mesh.contents.models.first,
              component.mesh.contents.models.count == 1,
              let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(), let deformFunction = library.makeFunction(name:"deformSoft"),
              let normalsFunction = library.makeFunction(name:"normalsSoft") else { throw CocoaError(.featureUnsupported) }
        self.entity = entity; self.queue = queue
        deform = try device.makeComputePipelineState(function:deformFunction)
        normals = try device.makeComputePipelineState(function:normalsFunction)
        var vertices: [Vertex] = [], allIndices: [UInt32] = [], parts: [LowLevelMesh.Part] = []
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude), hi = -SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        for part in model.parts {
            let positions = part.positions.elements
            let ns = part.normals?.elements ?? Array(repeating:SIMD3<Float>(0,1,0),count:positions.count)
            let uv = part.textureCoordinates?.elements ?? Array(repeating:SIMD2<Float>.zero,count:positions.count)
            let ts = part.tangents?.elements ?? Array(repeating:SIMD3<Float>(1,0,0),count:positions.count)
            let bs = part.bitangents?.elements ?? Array(repeating:SIMD3<Float>(0,0,1),count:positions.count)
            guard let triangles = part.triangleIndices?.elements else { throw CocoaError(.featureUnsupported) }
            let base = UInt32(vertices.count), indexOffset = allIndices.count * MemoryLayout<UInt32>.stride
            for i in positions.indices {
                vertices.append(.init(position:positions[i],normal:ns[i],uv:uv[i],tangent:ts[i],bitangent:bs[i]))
                lo = simd_min(lo,positions[i]); hi = simd_max(hi,positions[i])
            }
            allIndices.append(contentsOf:triangles.map{$0+base})
            parts.append(.init(indexOffset:indexOffset,indexCount:triangles.count,materialIndex:part.materialIndex,bounds:.init(min:lo,max:hi)))
        }
        guard !vertices.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        count = vertices.count; originalBounds = .init(min:lo,max:hi)
        var adjacency = Array(repeating:[UInt32](),count:vertices.count)
        for i in stride(from:0,to:allIndices.count,by:3) {
            for j in 0..<3 { adjacency[Int(allIndices[i+j])].append(UInt32(i/3)) }
        }
        var flat: [UInt32] = [], starts: [UInt32] = []
        for adjacent in adjacency { starts.append(UInt32(flat.count)); flat.append(contentsOf:adjacent) }
        starts.append(UInt32(flat.count))
        func buffer<T>(_ array: [T]) throws -> MTLBuffer {
            guard let result = array.withUnsafeBytes({device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)}) else { throw CocoaError(.coderInvalidValue) }
            return result
        }
        source = try buffer(vertices); indices = try buffer(allIndices); offsets = try buffer(starts); faces = try buffer(flat)
        let descriptor = LowLevelMesh.Descriptor(vertexCapacity:vertices.count,vertexAttributes:[
            .init(semantic:.position,format:.float3,offset:0),.init(semantic:.normal,format:.float3,offset:16),
            .init(semantic:.uv0,format:.float2,offset:32),.init(semantic:.tangent,format:.float3,offset:48),
            .init(semantic:.bitangent,format:.float3,offset:64)
        ],vertexLayouts:[.init(bufferIndex:0,bufferStride:MemoryLayout<Vertex>.stride)],indexCapacity:allIndices.count)
        mesh = try LowLevelMesh(descriptor:descriptor)
        mesh.withUnsafeMutableBytes(bufferIndex:0) { dst in vertices.withUnsafeBytes { dst.copyMemory(from:$0) } }
        mesh.withUnsafeMutableIndices { dst in allIndices.withUnsafeBytes { dst.copyMemory(from:$0) } }
        let padding = max(hi.x-lo.x,max(hi.y-lo.y,hi.z-lo.z)) * maximum
        for i in parts.indices { parts[i].bounds = .init(min:lo-SIMD3(repeating:padding),max:hi+SIMD3(repeating:padding)) }
        mesh.parts.replaceAll(parts)
        component.mesh = try MeshResource(from:mesh)
        entity.components.set(component)
    }
    func begin(worldPosition: SIMD3<Float>) { touch = entity.convert(position:worldPosition,from:nil); touching = true; dirty = true }
    func hold(worldPosition: SIMD3<Float>) { touch = entity.convert(position:worldPosition,from:nil) }
    func end() { touching = false }
    func update(delta: Float) {
        guard dirty else { return }
        let target: Float = touching ? 1 : 0
        let step = recoverySpeed * (touching ? 1.5 : 1) * max(0,delta)
        weight += min(step,max(-step,target-weight))
        let size = max(0.0001,max(originalBounds.extents.x,max(originalBounds.extents.y,originalBounds.extents.z)))
        var inward = originalBounds.center-touch
        inward = simd_length_squared(inward)<0.000001 ? [0,0,1] : simd_normalize(inward)
        var params = Parameters(touch:touch,inward:inward,grab:.zero,radius:size*radius,depth:size*min(strength,maximum),weight:weight,grabRadius:size*0.48,count:UInt32(count))
        guard let command = queue.makeCommandBuffer(), let encoder = command.makeComputeCommandEncoder() else { return }
        let destination = mesh.replace(bufferIndex:0,using:command)
        encoder.setComputePipelineState(deform)
        encoder.setBuffer(source,offset:0,index:0);encoder.setBuffer(destination,offset:0,index:1)
        encoder.setBytes(&params,length:MemoryLayout<Parameters>.stride,index:2)
        encoder.dispatchThreads(.init(width:count,height:1,depth:1),threadsPerThreadgroup:.init(width:min(256,deform.maxTotalThreadsPerThreadgroup),height:1,depth:1));encoder.endEncoding()
        if let normalEncoder = command.makeComputeCommandEncoder() {
            var vertexCount = UInt32(count)
            normalEncoder.setComputePipelineState(normals)
            for (i,b) in [destination,indices,offsets,faces].enumerated() { normalEncoder.setBuffer(b,offset:0,index:i) }
            normalEncoder.setBytes(&vertexCount,length:4,index:4)
            normalEncoder.dispatchThreads(.init(width:count,height:1,depth:1),threadsPerThreadgroup:.init(width:min(256,normals.maxTotalThreadsPerThreadgroup),height:1,depth:1));normalEncoder.endEncoding()
        }
        command.commit()
        if weight == 0 && !touching { dirty = false }
    }
}
