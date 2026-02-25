import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
	let session: AVCaptureSession
	
	func makeUIView(context: Context) -> PreviewView {
		let view = PreviewView()
		view.videoPreviewLayer.session = session
		view.videoPreviewLayer.videoGravity = .resizeAspectFill
		return view
	}
	
	func updateUIView(_ uiView: PreviewView, context: Context) {}
}

final class PreviewView: UIView {
	
	override class var layerClass: AnyClass {
		AVCaptureVideoPreviewLayer.self
	}
	
	var videoPreviewLayer: AVCaptureVideoPreviewLayer {
		layer as! AVCaptureVideoPreviewLayer
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		videoPreviewLayer.frame = bounds
		updateRotation()
	}
	
	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		updateRotation()
	}
	
	private func updateRotation() {
		guard let connection = videoPreviewLayer.connection else { return }
		let orientation = UIDevice.current.orientation
		
		let angle: CGFloat
		switch orientation {
			case .landscapeLeft:        angle = 0
			case .landscapeRight:       angle = 180
			case .portraitUpsideDown:   angle = 270
			default:                    angle = 90   // portrait
		}
		
		if connection.isVideoRotationAngleSupported(angle) {
			if #available(iOS 17.0, *) {
				connection.videoRotationAngle = angle
			} else {
					// Fallback on earlier versions
			}
		}
	}
}
