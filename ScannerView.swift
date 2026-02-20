import SwiftUI
import Vision

@available(iOS 26.0, *)
struct ScannerView: View {
	@StateObject private var cameraService = CameraService()
	@State private var detector = ObjectDetector()
	
	@State private var navigateToResults = false
	@State private var rawLabelsToFilter: [String] = []
	@State private var seenObjects: Set<String> = []
	@State private var showHelp = false
	
	var body: some View {
		NavigationStack {
			ZStack {
				CameraPreview(session: cameraService.session)
					.ignoresSafeArea()
				
				VStack {
						// Top HUD showing active status
					scanningStatusBadge
						.padding(.top, 12)
					
					Spacer()
					
						// Unified Guidance and Action Card
					bottomActionCard
				}
			}
			.navigationTitle("Environment Scan")
			.navigationBarTitleDisplayMode(.inline)
			.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
			.toolbarColorScheme(.dark, for: .navigationBar)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button { showHelp = true } label: {
						Image(systemName: "questionmark")
							.symbolRenderingMode(.hierarchical)
					}
				}
			}
			.navigationDestination(isPresented: $navigateToResults) {
				ResultsView(rawDetectedLabels: rawLabelsToFilter)
			}
			.sheet(isPresented: $showHelp) {
				ScannerInstructionsSheet()
			}
		}
		.onAppear { startDetection() }
		.onDisappear { cameraService.stop() }
	}
}

@available(iOS 26.0, *)
private extension ScannerView {
	var scanningStatusBadge: some View {
		HStack(spacing: 8) {
			Image(systemName: "sparkles")
				.symbolEffect(.pulse)
				.foregroundStyle(.yellow)
			
			Text("Analyzing Space")
				.font(.caption.bold())
				.foregroundColor(.white)
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 6)
		.background(.ultraThinMaterial, in: Capsule())
	}
	
	var bottomActionCard: some View {
		VStack(spacing: 20) {
				// Enhanced Guidance with Background for Visibility
			VStack(spacing: 8) {
				VStack(spacing: 4) {
					Text(seenObjects.count < 5 ? "Scan multiple objects" : "Great progress!")
						.font(.subheadline.bold())
					
					Text("Capture items from various angles for better accuracy. Tap 'Finish Scanning' when you are ready.")
						.font(.caption)
						.foregroundColor(.secondary.opacity(0.8))
				}
				.multilineTextAlignment(.center)
				.padding(.horizontal, 20)
				.padding(.vertical, 12)
				.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
			}
			
				// Progress Indicators (Dots)
			HStack(spacing: 6) {
				ForEach(0..<min(seenObjects.count, 8), id: \.self) { _ in
					Circle()
						.fill(.blue.gradient)
						.frame(width: 6, height: 6)
				}
			}
			.animation(.spring(), value: seenObjects.count)
			
				// Primary Action Button
			Button(action: stopScanAndProceed) {
				HStack {
					Text(seenObjects.count < 3 ? "Keep Exploring..." : "Finish Scanning")
						.font(.headline)
					Image(systemName: "arrow.right.circle.fill")
				}
				.frame(maxWidth: .infinity)
				.padding(.vertical, 18)
				.background(seenObjects.count < 3 ? .secondary.opacity(0.5) : Color.blue)
				.foregroundColor(.white)
				.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
			}
			.disabled(seenObjects.count < 1)
			.padding(.horizontal, 24)
		}
		.padding(.bottom, 34)
		.background {
			LinearGradient(colors: [.clear, .black.opacity(0.4)], startPoint: .top, endPoint: .bottom)
				.ignoresSafeArea()
		}
	}
	
	func startDetection() {
		
		detector.onPredictions = { results in
			
			for observation in results {
				
				if !seenObjects.contains(observation.identifier) {
					
					seenObjects.insert(observation.identifier)
					
					UIImpactFeedbackGenerator(style: .light)
						.impactOccurred()
				}
			}
		}
		
		
		cameraService.frameHandler = { buffer in
			
			detector.detect(from: buffer)
			
		}
		
		
		cameraService.start()
	}
	
	func stopScanAndProceed() {
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		cameraService.stop()
		if #available(iOS 26.0, *) {
			self.rawLabelsToFilter = Array(seenObjects)
		} else {
				// Fallback on earlier versions
		}
		if #available(iOS 26.0, *) {
			self.navigateToResults = true
		} else {
				// Fallback on earlier versions
		}
	}
}

	// MARK: - Instructions Sheet
struct ScannerInstructionsSheet: View {
	@Environment(\.dismiss) var dismiss
	
	var body: some View {
		NavigationStack {
			List {
				Section("Scanning Tips") {
					InstructionRow(
						icon: "sun.max.fill",
						color: .orange,
						title: "Find the Light",
						detail: "LingoLens loves sunshine! AI identifies objects best in bright, well-lit environments."
					)
					InstructionRow(
						icon: "camera.viewfinder",
						color: .blue,
						title: "Multiple Perspectives",
						detail: "Move your phone to see the top and sides of objects. This helps the AI verify exactly what it sees."
					)
					InstructionRow(
						icon: "cube.box.fill",
						color: .purple,
						title: "Build Your Session",
						detail: "Aim to scan 5-7 different objects. This ensures a more engaging and effective scavenger hunt later."
					)
				}
				
				Section("What's Next?") {
					InstructionRow(
						icon: "checklist",
						color: .green,
						title: "Curate Your List",
						detail: "Review the detected items and select the ones you want to hunt. You can also manually add items."
					)
					InstructionRow(
						icon: "gamecontroller.fill",
						color: .red,
						title: "The Scavenger Hunt",
						detail: "Once confirmed, the challenge begins! Find those objects again using their names in your target language."
					)
				}
			}
			.navigationTitle("Scanner Guide")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button {
						dismiss()
					} label: {
						Image(systemName: "xmark")
					}
				}
			}
		}
	}
}

struct InstructionRow: View {
	let icon: String
	let color: Color
	let title: String
	let detail: String
	
	var body: some View {
		HStack(spacing: 14) {
			ZStack {
				RoundedRectangle(cornerRadius: 12, style: .continuous)
					.fill(color.opacity(0.15))
					.frame(width: 42, height: 42)
				
				Image(systemName: icon)
					.font(.system(size: 18, weight: .bold))
					.foregroundColor(color)
			}
			
			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.system(.subheadline, design: .rounded).bold())
					.foregroundColor(.primary)
				
				Text(detail)
					.font(.caption)
					.foregroundColor(.secondary)
					.lineLimit(3)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.padding(.vertical, 6)
	}
}
