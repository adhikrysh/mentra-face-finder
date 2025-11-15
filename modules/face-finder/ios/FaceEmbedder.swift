import Foundation
import CoreML
import CoreGraphics
import CoreImage
import Accelerate

final class FaceEmbedder {

    private let model: MLModel
    private let ciContext = CIContext()

    init() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all // Use Neural Engine when available

        // Load bundled MobileFaceNet.mlmodel
        guard let modelURL = Bundle.main.url(forResource: "MobileFaceNet", withExtension: "mlmodelc") else {
            throw FaceEmbedderError.modelNotFound
        }
        self.model = try MLModel(contentsOf: modelURL, configuration: config)
    }

    /// Generate a 512-dim face embedding from an aligned 112x112 face image
    func generateEmbedding(from alignedFace: CGImage) throws -> [Float] {
        guard alignedFace.width == 112 && alignedFace.height == 112 else {
            throw FaceEmbedderError.invalidInputSize(
                width: alignedFace.width,
                height: alignedFace.height
            )
        }

        // Convert CGImage to MLMultiArray (1 x 3 x 112 x 112)
        let inputArray = try imageToMLMultiArray(alignedFace)

        // Create model input
        let inputFeatures = try MLDictionaryFeatureProvider(
            dictionary: ["input": MLFeatureValue(multiArray: inputArray)]
        )

        // Run inference
        let output = try model.prediction(from: inputFeatures)

        // Extract embedding from output
        guard let embeddingValue = output.featureValue(for: "embedding"),
              let embeddingArray = embeddingValue.multiArrayValue else {
            throw FaceEmbedderError.invalidOutput
        }

        // Convert MLMultiArray to [Float] and L2-normalize
        var embedding = [Float](repeating: 0, count: 512)
        for i in 0..<512 {
            embedding[i] = embeddingArray[i].floatValue
        }

        return EmbeddingMatcher.l2Normalize(embedding)
    }

    /// Convert a 112x112 CGImage to MLMultiArray in NCHW format (1x3x112x112)
    /// with pixel values normalized to [-1, 1]
    private func imageToMLMultiArray(_ image: CGImage) throws -> MLMultiArray {
        let width = 112
        let height = 112

        // Render to raw RGBA pixel buffer
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw FaceEmbedderError.pixelBufferCreationFailed
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Create MLMultiArray: [1, 3, 112, 112]
        let array = try MLMultiArray(shape: [1, 3, 112, 112] as [NSNumber], dataType: .float32)

        // Copy RGBA pixels to CHW format, normalize to [-1, 1]
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * 4
                let r = Float(pixelData[pixelIndex]) / 127.5 - 1.0
                let g = Float(pixelData[pixelIndex + 1]) / 127.5 - 1.0
                let b = Float(pixelData[pixelIndex + 2]) / 127.5 - 1.0

                array[[0, 0, y, x] as [NSNumber]] = NSNumber(value: r)
                array[[0, 1, y, x] as [NSNumber]] = NSNumber(value: g)
                array[[0, 2, y, x] as [NSNumber]] = NSNumber(value: b)
            }
        }

        return array
    }
}

enum FaceEmbedderError: Error {
    case modelNotFound
    case invalidInputSize(width: Int, height: Int)
    case invalidOutput
    case pixelBufferCreationFailed
}
