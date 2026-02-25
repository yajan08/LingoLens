import Foundation
import AVFoundation

final class CameraService: NSObject, ObservableObject, @unchecked Sendable {
	
	let session = AVCaptureSession()
	
	var frameHandler: ((CVPixelBuffer) -> Void)?
	
	private let videoOutput = AVCaptureVideoDataOutput()
	
	private let videoQueue = DispatchQueue(
		label: "VideoOutputQueue",
		qos: .userInitiated
	)
	
	private let sessionQueue = DispatchQueue(
		label: "CameraSessionQueue",
		qos: .userInitiated
	)
	
	private var isConfigured = false
	
		// MARK: - Public
	
	func start() {
		
		sessionQueue.async {
			
			if !self.isConfigured {
				self.configureSession()
				self.isConfigured = true
			}
			
			if !self.session.isRunning {
				self.session.startRunning()
			}
		}
	}
	
	func stop() {
		
		sessionQueue.async {
			
			guard self.session.isRunning else { return }
			
			self.session.stopRunning()
			
			self.session.beginConfiguration()
			
			self.session.inputs.forEach {
				self.session.removeInput($0)
			}
			
			self.session.outputs.forEach {
				self.session.removeOutput($0)
			}
			
			self.session.commitConfiguration()
			
			self.isConfigured = false
		}
	}
	
		// MARK: - Private
	
	private func configureSession() {
		
		session.beginConfiguration()
		
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
			print("Camera input failed")
			session.commitConfiguration()
			return
		}
		
		session.addInput(input)
		
		if session.canAddOutput(videoOutput) {
			
			videoOutput.alwaysDiscardsLateVideoFrames = true
			
			videoOutput.videoSettings = [
				kCVPixelBufferPixelFormatTypeKey as String:
					Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
			]
			
			videoOutput.setSampleBufferDelegate(
				self,
				queue: videoQueue
			)
			
			session.addOutput(videoOutput)
			
			if let connection = videoOutput.connection(with: .video) {
				
//				if #available(iOS 17.0, *) {
//					connection.videoRotationAngle = 90
//				}
				
				connection.isEnabled = true
			}
		}
		
		session.commitConfiguration()
	}
}

	// MARK: - Delegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
	
	func captureOutput(
		_ output: AVCaptureOutput,
		didOutput sampleBuffer: CMSampleBuffer,
		from connection: AVCaptureConnection
	) {
		
		guard
			let buffer = CMSampleBufferGetImageBuffer(sampleBuffer),
			let handler = frameHandler
		else { return }
		
		handler(buffer)
	}
}
