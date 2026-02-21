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
					ScanningStatusBadge()
						.padding(.top, 12)
					
					Spacer()
					
					bottomActionCard
				}
			}
			.navigationTitle("Environment Scan")
			.navigationBarTitleDisplayMode(.inline)
			.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
					.onAppear {
						cameraService.stop()   // HARD STOP camera
					}
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
	
	struct ScanningStatusBadge: View {
		
		private let scanningSymbols = [
			"viewfinder",
			"text.viewfinder",
			"person.fill.viewfinder",
			"location.viewfinder",
			"camera.viewfinder",
			"document.viewfinder",
			"ellipsis.viewfinder",
			"dot.circle.viewfinder"
		]
		
		@State private var symbolIndex = 0
		
		private let timer = Timer.publish(
			every: 0.8,
			on: .main,
			in: .common
		).autoconnect()
		
		var body: some View {
			HStack(spacing: 8) {
				
				Image(systemName: scanningSymbols[symbolIndex])
					.foregroundStyle(.primary)
					.symbolEffect(.pulse, options: .repeating)
					.contentTransition(.symbolEffect(.replace))
					.animation(
						.easeInOut(duration: 0.35),
						value: symbolIndex
					)
				
				Text("Analyzing Space...")
					.font(.caption.weight(.semibold))
					.foregroundStyle(.primary)
			}
			.padding(.horizontal, 14)
			.padding(.vertical, 8)
			.background(
				.ultraThinMaterial,
				in: Capsule()
			)
			.onReceive(timer) { _ in
				symbolIndex = (symbolIndex + 1) % scanningSymbols.count
			}
		}
	}
	
	var bottomActionCard: some View {
		VStack(spacing: 20) {
			
			VStack(spacing: 4) {
				Text(seenObjects.count < 10 ? "Keep exploring..." : "Looking good.")
					.font(.subheadline.bold())
					.foregroundStyle(.primary)
				
				Text("Walk around and try different angles for better results.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.multilineTextAlignment(.center)
			.padding(.horizontal, 20)
			.padding(.vertical, 14)
			.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
			
				// Progress dots
			HStack(spacing: 6) {
				ForEach(0..<min(seenObjects.count, 8), id: \.self) { _ in
					Circle()
						.fill(Color.blue)
						.frame(width: 6, height: 6)
				}
			}
			.animation(.spring(), value: seenObjects.count)
			
				// Primary action button
			Button(action: stopScanAndProceed) {
				HStack {
					Text(seenObjects.count < 3 ? "Still Looking..." : "Done Exploring")
						.font(.headline)
					Image(systemName: "arrow.right.circle.fill")
				}
				.frame(maxWidth: .infinity)
				.padding(.vertical, 18)
				.background(seenObjects.count < 3 ? Color.secondary.opacity(0.5) : Color.blue)
				.foregroundColor(.white)
				.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
			}
			.disabled(seenObjects.count < 1)
			.padding(.horizontal, 24)
		}
		.padding(.bottom, 34)
		.background {
			LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
				.ignoresSafeArea()
		}
	}
	
	func startDetection() {
		detector.onPredictions = { results in
			for observation in results {
				if !seenObjects.contains(observation.identifier) {
					seenObjects.insert(observation.identifier)
					UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
		self.rawLabelsToFilter = Array(seenObjects)
		self.navigateToResults = true
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
						title: "Prioritise Good Lighting",
						detail: "Well-lit environments significantly improve detection accuracy. Natural light works best."
					)
					InstructionRow(
						icon: "camera.viewfinder",
						color: .blue,
						title: "Vary Your Angles",
						detail: "Move around the object. Top-down, diagonal, and side views each provide different visual context."
					)
					InstructionRow(
						icon: "cube.box.fill",
						color: .purple,
						title: "Scan Multiple Objects",
						detail: "Aim for five to seven distinct objects to build a well-rounded and engaging session."
					)
				}
			}
			.navigationTitle("Scanner Guide")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button { dismiss() } label: {
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
