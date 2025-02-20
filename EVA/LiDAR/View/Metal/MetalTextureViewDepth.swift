/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view that draws depth textures and extracts raw depth data.
*/

import Foundation
import SwiftUI
import MetalKit
import Metal

struct MetalTextureDepthView: UIViewRepresentable, MetalRepresentable {
    var rotationAngle: Double

    @Binding var maxDepth: Float
    @Binding var minDepth: Float
    var capturedData: CameraCapturedData
    
    func makeCoordinator() -> MTKDepthTextureCoordinator {
        MTKDepthTextureCoordinator(parent: self)
    }
}

final class MTKDepthTextureCoordinator: MTKCoordinator<MetalTextureDepthView> {
    // flag to cntrl frame capture
    var isFrameCaptured = false
    
    override func preparePipelineAndDepthState() {
        guard let metalDevice = mtkView.device else { fatalError("Expected a Metal device.") }
        do {
            let library = MetalEnvironment.shared.metalLibrary
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "planeVertexShader")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "planeFragmentShaderDepth")
            pipelineDescriptor.vertexDescriptor = createPlaneMetalVertexDescriptor()
            pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
            pipelineState = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            let depthDescriptor = MTLDepthStencilDescriptor()
            depthDescriptor.isDepthWriteEnabled = true
            depthDescriptor.depthCompareFunction = .less
            depthState = metalDevice.makeDepthStencilState(descriptor: depthDescriptor)
        } catch {
            print("Unexpected error: \(error).")
        }
    }
    
    override func draw(in view: MTKView) {
        guard let depthTexture = parent.capturedData.depth else {
            print("There's no content to display.")
            return
        }
        
        // capture 1 frame
        if isFrameCaptured { return } // exit if a frame is already captured
        
        // retrieve the raw depth data from the texture
        let depthBytesPerRow = depthTexture.width * MemoryLayout<Float>.size
        var rawDepthData = [Float](repeating: 0.0, count: depthTexture.width * depthTexture.height)
        
        let region = MTLRegionMake2D(0, 0, depthTexture.width, depthTexture.height)
        depthTexture.getBytes(&rawDepthData, bytesPerRow: depthBytesPerRow, from: region, mipmapLevel: 0)

        // rawDepthData contains the raw depth values from the LiDAR sensor
        print("Raw depth data extracted: \(rawDepthData)")
        
        // count number of lidar points(non-zero depth vals)
        let points = rawDepthData.filter { $0 > 0 }.count
        print("Number of lidar points: \(points)")
        
        // make frame as captured
        isFrameCaptured = true
        
        guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else { return }
        guard let passDescriptor = view.currentRenderPassDescriptor else { return }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }
        
        // vertex and Texture coordinates data (x,y,u,v) * 4 ordered for triangle strip
        let vertexData: [Float] = [  -1, -1, 1, 1,
                                     1, -1, 1, 0,
                                     -1, 1, 0, 1,
                                     1, 1, 0, 0]
        encoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
        encoder.setFragmentBytes(&parent.minDepth, length: MemoryLayout<Float>.stride, index: 0)
        encoder.setFragmentBytes(&parent.maxDepth, length: MemoryLayout<Float>.stride, index: 1)
        encoder.setFragmentTexture(depthTexture, index: 0)
        encoder.setDepthStencilState(depthState)
        encoder.setRenderPipelineState(pipelineState)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
    }
}
