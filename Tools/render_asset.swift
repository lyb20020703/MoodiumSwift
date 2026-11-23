import Foundation
import RealityKit
import Metal
import CoreImage
import ImageIO
import UniformTypeIdentifiers

@main struct RenderAsset {
    @MainActor static func main() async throws {
        let renderer=try RealityRenderer()
        let model=try await Entity(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))
        let bounds=model.visualBounds(relativeTo:nil)
        let pivot=Entity();pivot.addChild(model)
        model.position -= bounds.center
        let longest=max(bounds.extents.x,max(bounds.extents.y,bounds.extents.z))
        pivot.scale = .init(repeating:1/longest)
        let camera=PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees=40
        camera.look(at:[0,0,0],from:[0.9,0.55,1.8],relativeTo:nil)
        let key=DirectionalLight();key.light.intensity=2000
        key.look(at:[0,0,0],from:[1,2,2],relativeTo:nil)
        let fill=DirectionalLight();fill.light.intensity=700
        fill.look(at:[0,0,0],from:[-2,1,-1],relativeTo:nil)
        renderer.entities.append(contentsOf:[pivot,camera,key,fill]);renderer.activeCamera=camera
        renderer.cameraSettings.colorBackground = .color(CGColor(red:0.10,green:0.08,blue:0.14,alpha:1))
        let device=MTLCreateSystemDefaultDevice()!
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm_srgb,width:1000,height:800,mipmapped:false)
        descriptor.usage=[.renderTarget,.shaderRead];descriptor.storageMode = .shared
        let texture=device.makeTexture(descriptor:descriptor)!
        let output=try RealityRenderer.CameraOutput(.singleProjection(colorTexture:texture))
        for _ in 0..<4 {
            try await withCheckedThrowingContinuation { (continuation:CheckedContinuation<Void,Error>) in
                do { try renderer.updateAndRender(deltaTime:1/30,cameraOutput:output,onComplete:{_ in continuation.resume()}) }
                catch { continuation.resume(throwing:error) }
            }
        }
        let context=CIContext(mtlDevice:device)
        let image=CIImage(mtlTexture:texture,options:[.colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!])!.oriented(.downMirrored)
        let cg=context.createCGImage(image,from:image.extent)!
        let destination=CGImageDestinationCreateWithURL(URL(fileURLWithPath:CommandLine.arguments[2]) as CFURL,UTType.png.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(destination,cg,nil);CGImageDestinationFinalize(destination)
        print("Rendered",CommandLine.arguments[2])
    }
}
