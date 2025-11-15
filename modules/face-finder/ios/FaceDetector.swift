import Foundation
import Vision
import CoreImage
import UIKit

struct DetectedFaceInfo {
    let boundingBox: CGRect           // Normalized (0-1), Vision coordinates (bottom-left origin)
    let landmarks: VNFaceLandmarks2D?
    let quality: Float
    let trackingId: Int?
}

final class FaceDetector {

    private let minFaceSize: CGFloat = 80.0 / 1024.0  // 80px at 1024px image width
    private let minQuality: Float = 0.5

    // Reusable requests (allocated once)
    private let faceDetectionRequest = VNDetectFaceRectanglesRequest()
    private let landmarkRequest = VNDetectFaceLandmarksRequest()
    private let qualityRequest = VNDetectFaceCaptureQualityRequest()

    init() {
        faceDetectionRequest.revision = VNDetectFaceRectanglesRequestRevision3
        landmarkRequest.revision = VNDetectFaceLandmarksRequestRevision3
    }

    /// Detect faces in a CVPixelBuffer (from camera frame)
    func detectFaces(in pixelBuffer: CVPixelBuffer) throws -> [DetectedFaceInfo] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([faceDetectionRequest, qualityRequest])
        return processFaceObservations()
    }

    /// Detect faces in a CGImage (from photo library)
    func detectFaces(in image: CGImage) throws -> [DetectedFaceInfo] {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([faceDetectionRequest, qualityRequest])
        return processFaceObservations()
    }

    /// Detect faces with landmarks (needed for alignment before embedding)
    func detectFacesWithLandmarks(in image: CGImage) throws -> [DetectedFaceInfo] {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([faceDetectionRequest, landmarkRequest, qualityRequest])
        return processFaceObservationsWithLandmarks()
    }

    func detectFacesWithLandmarks(in pixelBuffer: CVPixelBuffer) throws -> [DetectedFaceInfo] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([faceDetectionRequest, landmarkRequest, qualityRequest])
        return processFaceObservationsWithLandmarks()
    }

    // MARK: - Private

    private func processFaceObservations() -> [DetectedFaceInfo] {
        guard let results = faceDetectionRequest.results else { return [] }

        let qualityResults = qualityRequest.results ?? []
        let qualityMap = Dictionary(
            uniqueKeysWithValues: qualityResults.compactMap { obs in
                obs.uuid.map { ($0, obs.faceCaptureQuality ?? 0) }
            } ?? qualityResults.enumerated().map { (i, obs) in
                (i, obs.faceCaptureQuality ?? 0)
            }
        )

        return results.enumerated().compactMap { index, face in
            let box = face.boundingBox

            // Filter: minimum face size
            guard box.width >= minFaceSize && box.height >= minFaceSize else { return nil }

            // Filter: quality score
            let quality = qualityResults.indices.contains(index)
                ? qualityResults[index].faceCaptureQuality ?? 0
                : 0
            guard quality >= minQuality else { return nil }

            return DetectedFaceInfo(
                boundingBox: box,
                landmarks: nil,
                quality: quality,
                trackingId: nil
            )
        }
    }

    private func processFaceObservationsWithLandmarks() -> [DetectedFaceInfo] {
        guard let faceResults = faceDetectionRequest.results else { return [] }
        let landmarkResults = landmarkRequest.results ?? []
        let qualityResults = qualityRequest.results ?? []

        return faceResults.enumerated().compactMap { index, face in
            let box = face.boundingBox

            guard box.width >= minFaceSize && box.height >= minFaceSize else { return nil }

            let quality = qualityResults.indices.contains(index)
                ? qualityResults[index].faceCaptureQuality ?? 0
                : 0
            guard quality >= minQuality else { return nil }

            let landmarks = landmarkResults.indices.contains(index)
                ? landmarkResults[index].landmarks
                : nil

            return DetectedFaceInfo(
                boundingBox: box,
                landmarks: landmarks,
                quality: quality,
                trackingId: nil
            )
        }
    }

    // MARK: - Coordinate Conversion

    /// Convert Vision coordinates (bottom-left origin, normalized) to
    /// screen coordinates (top-left origin, pixel values)
    static func visionRectToScreen(
        _ visionRect: CGRect,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> CGRect {
        let x = visionRect.origin.x * imageWidth
        let y = (1.0 - visionRect.origin.y - visionRect.height) * imageHeight
        let w = visionRect.width * imageWidth
        let h = visionRect.height * imageHeight
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Expand bounding box by a margin (30%) for better face crops
    static func expandRect(_ rect: CGRect, margin: CGFloat = 0.3) -> CGRect {
        let dx = rect.width * margin
        let dy = rect.height * margin
        return rect.insetBy(dx: -dx, dy: -dy)
    }
}
