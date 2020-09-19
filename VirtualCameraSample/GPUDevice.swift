//import Foundation
import Metal
import simd

class GPUDevice {
    static let shared = GPUDevice()
    
    let device = MTLCreateSystemDefaultDevice()!
    var library : MTLLibrary!
    lazy var vertexFunction : MTLFunction = library.makeFunction(name: "vertexShaderX")!
    
    var resolutionBuffer : MTLBuffer! = nil
    var timeBuffer : MTLBuffer! = nil

    private init() {
        library = device.makeDefaultLibrary()
        
        setUpBeffers()
    }
    
    func setUpBeffers() {
        resolutionBuffer = device.makeBuffer(length: 2 * MemoryLayout<Float>.size, options: [])
        timeBuffer = device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
    }
    
    func updateResolution(width: Float, height: Float) {
        memcpy(resolutionBuffer.contents(), [width, height], MemoryLayout<Float>.size * 2)
    }
    
    func updateTime(_ time: Float) {
        updateBuffer(time, timeBuffer)
    }

    func render() {
        
    }
    
    private func updateBuffer<T>(_ data:T, _ buffer: MTLBuffer) {
        let pointer = buffer.contents()
        let value = pointer.bindMemory(to: T.self, capacity: 1)
        value[0] = data
    }
}
