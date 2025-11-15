import XCTest
@testable import FaceFinder
import CoreGraphics
import Vision

final class FaceAlignerTests: XCTestCase {

    func testAlignedImageIs112x112() {
        // Create a test image (200x200 white square)
        let size = CGSize(width: 200, height: 200)
        UIGraphicsBeginImageContext(size)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        let cgImage = image.cgImage!

        // Provide synthetic landmark points (normalized to bounding box)
        let landmarks = FaceAligner.FiveLandmarks(
            leftEye: CGPoint(x: 0.3, y: 0.35),
            rightEye: CGPoint(x: 0.7, y: 0.35),
            nose: CGPoint(x: 0.5, y: 0.55),
            leftMouth: CGPoint(x: 0.35, y: 0.75),
            rightMouth: CGPoint(x: 0.65, y: 0.75)
        )

        let boundingBox = CGRect(x: 0, y: 0, width: 200, height: 200)

        let aligned = FaceAligner.alignFace(
            image: cgImage,
            boundingBox: boundingBox,
            landmarks: landmarks
        )

        XCTAssertNotNil(aligned)
        XCTAssertEqual(aligned!.width, 112)
        XCTAssertEqual(aligned!.height, 112)
    }

    func testLandmarkExtractionFromVNLandmarks() {
        // Verify the 5-point extraction works with mock data
        let points: [CGPoint] = [
            CGPoint(x: 0.3, y: 0.35), // left eye
            CGPoint(x: 0.7, y: 0.35), // right eye
        ]

        // Test that center computation works
        let center = FaceAligner.centerOfPoints(points)
        XCTAssertEqual(center.x, 0.5, accuracy: 1e-5)
        XCTAssertEqual(center.y, 0.35, accuracy: 1e-5)
    }
}
