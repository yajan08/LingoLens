import Foundation
import AVFoundation
import Combine

final class CameraService: NSObject, ObservableObject {
	
	let session = AVCaptureSession()
	var frameHandler: ((CVPixelBuffer) -> Void)?
	
	private let videoDataOutput = AVCaptureVideoDataOutput()
	private let videoQueue = DispatchQueue(
		label: "VideoDataOutputQueue",
		qos: .userInitiated
	)
	
	override init() {
		super.init()
		configureSession()
	}
	
	private func configureSession() {
		
		session.beginConfiguration()
		
			// ✅ Use high resolution for better Vision accuracy
		session.sessionPreset = .high
		
		guard
			let device = AVCaptureDevice.default(
				.builtInWideAngleCamera,
				for: .video,
				position: .back
			),
			let input = try? AVCaptureDeviceInput(device: device),
			session.canAddInput(input)
		else {
			print("❌ Failed to setup camera input")
			session.commitConfiguration()
			return
		}
		
		session.addInput(input)
		
		if session.canAddOutput(videoDataOutput) {
			
				// Prevent frame backlog (important for real-time classification)
			videoDataOutput.alwaysDiscardsLateVideoFrames = true
			
				// Explicit pixel format for Vision stability
			videoDataOutput.videoSettings = [
				kCVPixelBufferPixelFormatTypeKey as String:
					Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
			]
			
			videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
			session.addOutput(videoDataOutput)
			
			if let connection = videoDataOutput.connection(with: .video) {
				if #available(iOS 17.0, *) {
					connection.videoRotationAngle = 90.0
				} else {
						// Fallback on earlier versions
				}
				connection.isEnabled = true
			}
			
		} else {
			print("❌ Could not add video output")
			session.commitConfiguration()
			return
		}
		
		session.commitConfiguration()
	}
	private let sessionQueue = DispatchQueue(label: "CameraSessionQueue")
	
	func start() {
		sessionQueue.async {
			self.session.startRunning()
		}
	}
	
	func stop() {
		sessionQueue.async {
			self.session.stopRunning()
		}
	}
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
	
	func captureOutput(
		_ output: AVCaptureOutput,
		didOutput sampleBuffer: CMSampleBuffer,
		from connection: AVCaptureConnection
	) {
		
		guard
			let frameHandler = frameHandler,
			let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
		else { return }
		
		frameHandler(pixelBuffer)
	}
	
//	func captureOutput(_ output: AVCaptureOutput,
//					   didOutput sampleBuffer: CMSampleBuffer,
//					   from connection: AVCaptureConnection) {
//		
//		guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
//			return
//		}
//		
//		frameHandler?(pixelBuffer)
//	}
	
	
}
