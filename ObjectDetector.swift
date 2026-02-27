import Foundation
import Vision
import UIKit

	/// Runs Vision image classification on camera frames and reports results via a callback.
public final class ObjectDetector: @unchecked Sendable {
	
	private let visionQueue = DispatchQueue(
		label: "vision.pipeline.queue",
		qos: .userInitiated
	)
	
	private var lastDetectionTime = Date.distantPast
	private let detectionInterval: TimeInterval = 0.15
	
	public var onPredictions: (([VNClassificationObservation]) -> Void)?
	
	public init() {}
	
		/// Performs classification on the given pixel buffer, throttled by the detection interval.
	public func detect(from pixelBuffer: CVPixelBuffer) {
		
		visionQueue.async { [weak self] in
			
			guard let self else { return }
			
			let now = Date()
			
			guard now.timeIntervalSince(self.lastDetectionTime) > self.detectionInterval else {
				return
			}
			
			self.lastDetectionTime = now
			
			let orientation = self.exifOrientation()
			let request = VNClassifyImageRequest()
			let handler = VNImageRequestHandler(
				cvPixelBuffer: pixelBuffer,
				orientation: orientation
			)
			
			do {
				
				try handler.perform([request])
				
				guard let results = request.results else { return }
				
				let filtered = results
					.filter { $0.confidence > 0.25 }
					.prefix(5)
				
				DispatchQueue.main.async {
					self.onPredictions?(Array(filtered))
				}
				
			} catch {
				print("Vision error:", error)
			}
		}
	}
	
		/// Maps the current device orientation to the matching EXIF orientation for Vision.
	private func exifOrientation() -> CGImagePropertyOrientation {
		
		switch UIDevice.current.orientation {
				
			case .portraitUpsideDown:
				return .left
				
			case .landscapeLeft:
				return .upMirrored
				
			case .landscapeRight:
				return .down
				
			default:
				return .up
		}
	}
}
