import Foundation
import Vision
import UIKit

public final class ObjectDetector {
	
	private let visionQueue = DispatchQueue(
		label: "vision.pipeline.queue",
		qos: .userInitiated
	)
	
	private var lastDetectionTime = Date.distantPast
	
	private let detectionInterval: TimeInterval = 0.33
	
	public var onPredictions: (([VNClassificationObservation]) -> Void)?
	
	
	public init() {}
	
	
	public func detect(from pixelBuffer: CVPixelBuffer) {
		
		visionQueue.async { [weak self] in
			
			guard let self else { return }
			
			let now = Date()
			
			guard now.timeIntervalSince(self.lastDetectionTime)
					> self.detectionInterval else {
				return
			}
			
			self.lastDetectionTime = now
			
			
			let orientation = self.exifOrientation()
			
			
				// CREATE NEW request every time (thread-safe)
			let request = VNClassifyImageRequest()
			
			
			let handler = VNImageRequestHandler(
				cvPixelBuffer: pixelBuffer,
				orientation: orientation
			)
			
			
			do {
				
				try handler.perform([request])
				
				
				guard let results =
						request.results as? [VNClassificationObservation]
				else { return }
				
				
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



	//import Foundation
//import Vision
//import UIKit
//
//@MainActor
//public final class ObjectDetector {
//	
//	private let visionQueue = DispatchQueue(
//		label: "vision.pipeline.queue",
//		qos: .userInitiated
//	)
//	
//	private var request: VNClassifyImageRequest!
//	
//	private var lastDetectionTime = Date.distantPast
//	private let detectionInterval: TimeInterval = 0.33
//	
//	public var onPredictions: (([VNClassificationObservation]) -> Void)?
//	
//	
//	public init() {
//		setup()
//	}
//	
//	
//	private func setup() {
//		
//		request = VNClassifyImageRequest { [weak self] request, error in
//			
//			guard
//				error == nil,
//				let results = request.results as? [VNClassificationObservation],
//				let self
//			else { return }
//			
//			Task { @MainActor in
//				self.deliver(results)
//			}
//		}
//	}
//	
//	public func detect(from pixelBuffer: CVPixelBuffer) {
//		
//		let now = Date()
//		
//		guard now.timeIntervalSince(lastDetectionTime) > detectionInterval else {
//			return
//		}
//		
//		lastDetectionTime = now
//		
//		let orientation = exifOrientation()
//		
//			// Vision runs off main thread safely
//		visionQueue.async { [weak self] in
//			
//			guard let self else { return }
//			
//			let handler = VNImageRequestHandler(
//				cvPixelBuffer: pixelBuffer,
//				orientation: orientation
//			)
//			
//			try? handler.perform([self.request])
//		}
//	}
//	
//	
//	private func deliver(_ results: [VNClassificationObservation]) {
//		
//		let filtered = results
//			.filter { $0.confidence > 0.25 }
//			.prefix(5)
//		
//		onPredictions?(Array(filtered))
//	}
//	
//	
//	private func exifOrientation() -> CGImagePropertyOrientation {
//		
//		switch UIDevice.current.orientation {
//				
//			case .portraitUpsideDown:
//				return .left
//				
//			case .landscapeLeft:
//				return .upMirrored
//				
//			case .landscapeRight:
//				return .down
//				
//			default:
//				return .up
//		}
//	}
//}
