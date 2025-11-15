import Foundation
import CoreGraphics
import CoreImage
import Vision
import UIKit

final class FaceAligner {

    /// Target output size matching MobileFaceNet input
    static let outputSize = CGSize(width: 112, height: 112)

    /// Reference landmark positions for a canonical aligned face at 112x112.
    /// These are the standard positions MobileFaceNet expects.
    static let referenceLandmarks: [CGPoint] = [
        CGPoint(x: 38.2946, y: 51.6963),  // left eye
        CGPoint(x: 73.5318, y: 51.5014),  // right eye
        CGPoint(x: 56.0252, y: 71.7366),  // nose
        CGPoint(x: 41.5493, y: 92.3655),  // left mouth
        CGPoint(x: 70.7299, y: 92.2041),  // right mouth
    ]

    struct FiveLandmarks {
        let leftEye: CGPoint
        let rightEye: CGPoint
        let nose: CGPoint
        let leftMouth: CGPoint
        let rightMouth: CGPoint

        var asArray: [CGPoint] {
            [leftEye, rightEye, nose, leftMouth, rightMouth]
        }
    }

    /// Extract 5-point landmarks from VNFaceLandmarks2D
    static func extractFiveLandmarks(
        from vnLandmarks: VNFaceLandmarks2D,
        boundingBox: CGRect,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> FiveLandmarks? {
        guard let leftEyeRegion = vnLandmarks.leftEye,
              let rightEyeRegion = vnLandmarks.rightEye,
              let noseRegion = vnLandmarks.nose,
              let outerLipsRegion = vnLandmarks.outerLips else {
            return nil
        }

        let leftEyePoints = leftEyeRegion.normalizedPoints
        let rightEyePoints = rightEyeRegion.normalizedPoints
        let nosePoints = noseRegion.normalizedPoints
        let lipsPoints = outerLipsRegion.normalizedPoints

        guard !leftEyePoints.isEmpty,
              !rightEyePoints.isEmpty,
              !nosePoints.isEmpty,
              lipsPoints.count >= 6 else {
            return nil
        }

        // Convert from normalized-to-bounding-box to pixel coordinates
        func toPixel(_ normalizedPoint: CGPoint) -> CGPoint {
            // Vision normalized points are relative to the bounding box
            // and in Vision coordinate system (bottom-left origin)
            let pixelX = (boundingBox.origin.x + normalizedPoint.x * boundingBox.width) * imageWidth
            let pixelY = (boundingBox.origin.y + normalizedPoint.y * boundingBox.height) * imageHeight
            // Flip Y for top-left origin
            return CGPoint(x: pixelX, y: imageHeight - pixelY)
        }

        let leftEyeCenter = centerOfPoints(leftEyePoints.map(toPixel))
        let rightEyeCenter = centerOfPoints(rightEyePoints.map(toPixel))
        let noseTip = toPixel(nosePoints[nosePoints.count / 2]) // middle point of nose
        // Outer lips: typically index 0 is left corner, ~count/2 is right corner
        let leftMouth = toPixel(lipsPoints[0])
        let rightMouth = toPixel(lipsPoints[lipsPoints.count / 2])

        return FiveLandmarks(
            leftEye: leftEyeCenter,
            rightEye: rightEyeCenter,
            nose: noseTip,
            leftMouth: leftMouth,
            rightMouth: rightMouth
        )
    }

    /// Compute the centroid of a set of points
    static func centerOfPoints(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    /// Align a face crop using 5-point landmarks via affine transformation.
    /// Returns a 112x112 CGImage suitable for MobileFaceNet input.
    static func alignFace(
        image: CGImage,
        boundingBox: CGRect,
        landmarks: FiveLandmarks
    ) -> CGImage? {
        let srcPoints = landmarks.asArray
        let dstPoints = referenceLandmarks

        // Compute similarity transform (rotation + uniform scale + translation)
        // using least squares on the 5 point pairs
        guard let transform = computeSimilarityTransform(from: srcPoints, to: dstPoints) else {
            return nil
        }

        // Apply the transform using Core Graphics
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 112,
            height: 112,
            bitsPerComponent: 8,
            bytesPerRow: 112 * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.concatenate(transform)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        return context.makeImage()
    }

    /// Compute a similarity transform (rotation + scale + translation)
    /// that maps srcPoints to dstPoints using least squares.
    private static func computeSimilarityTransform(
        from src: [CGPoint],
        to dst: [CGPoint]
    ) -> CGAffineTransform? {
        guard src.count == dst.count, src.count >= 2 else { return nil }

        let n = src.count

        // Solve for [a, b, tx, ty] where:
        //   dst_x = a * src_x - b * src_y + tx
        //   dst_y = b * src_x + a * src_y + ty
        //
        // This is a similarity transform (rotation + uniform scale + translation)

        var sumSrcX: CGFloat = 0, sumSrcY: CGFloat = 0
        var sumDstX: CGFloat = 0, sumDstY: CGFloat = 0
        var sumSrcXSrcX: CGFloat = 0, sumSrcYSrcY: CGFloat = 0
        var sumSrcXDstX: CGFloat = 0, sumSrcYDstX: CGFloat = 0
        var sumSrcXDstY: CGFloat = 0, sumSrcYDstY: CGFloat = 0

        for i in 0..<n {
            sumSrcX += src[i].x
            sumSrcY += src[i].y
            sumDstX += dst[i].x
            sumDstY += dst[i].y
            sumSrcXSrcX += src[i].x * src[i].x
            sumSrcYSrcY += src[i].y * src[i].y
            sumSrcXDstX += src[i].x * dst[i].x
            sumSrcYDstX += src[i].y * dst[i].x
            sumSrcXDstY += src[i].x * dst[i].y
            sumSrcYDstY += src[i].y * dst[i].y
        }

        let N = CGFloat(n)
        let sumSrcSrc = sumSrcXSrcX + sumSrcYSrcY

        let denom = N * sumSrcSrc - sumSrcX * sumSrcX - sumSrcY * sumSrcY
        guard abs(denom) > 1e-10 else { return nil }

        let a = (N * (sumSrcXDstX + sumSrcYDstY) - sumSrcX * sumDstX - sumSrcY * sumDstY) / denom
        let b = (N * (sumSrcXDstY - sumSrcYDstX) - sumSrcX * sumDstY + sumSrcY * sumDstX) / denom
        let tx = (sumDstX - a * sumSrcX + b * sumSrcY) / N
        let ty = (sumDstY - b * sumSrcX - a * sumSrcY) / N

        return CGAffineTransform(a: a, b: b, c: -b, d: a, tx: tx, ty: ty)
    }
}
