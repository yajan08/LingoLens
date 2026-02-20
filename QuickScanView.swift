import SwiftUI
import Vision

@available(iOS 26.0, *)
struct QuickScanView: View {
		// MARK: - Properties
	@StateObject private var cameraService = CameraService()
	@State private var detector = ObjectDetector()
	private let aiService = FoundationAIService()
	
		// Core State
	@State private var latestPixelBuffer: CVPixelBuffer?
	@State private var detectedResults: [FoundationAIService.QuizResult] = []
	
		// UI State
	@State private var isAnalyzing = false
	@State private var showHelp = false
	@State private var pulseScale: CGFloat = 1.0
	@State private var scanStatus: ScanStatus = .ready
	
		// NEW: tracks which result the detail sheet is showing
	@State private var selectedResult: FoundationAIService.QuizResult? = nil
	
	enum ScanStatus {
		case ready, processing, displaying, empty
	}
	
	@Environment(\.dismiss) private var dismiss
	private let impact = UIImpactFeedbackGenerator(style: .medium)
	private let notification = UINotificationFeedbackGenerator()
	
		// MARK: - Body
	var body: some View {
		ZStack {
			CameraPreview(session: cameraService.session)
				.ignoresSafeArea()
			
			if scanStatus == .displaying {
				VStack {
					Spacer()
					resultsCarousel
						.transition(.asymmetric(
							insertion: .move(edge: .bottom).combined(with: .opacity),
							removal: .opacity
						))
					Spacer().frame(height: 120)
				}
			}
			
			VStack {
				Spacer()
				if scanStatus == .ready && !isAnalyzing {
					tapToIdentifyHint
				}
				if scanStatus == .empty {
					emptyStateToast
				}
				Spacer()
				bottomActionArea
			}
			
			if isAnalyzing {
				analysisOverlay
			}
		}
		.navigationBarTitleDisplayMode(.inline)
		.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
		.toolbarColorScheme(.dark, for: .navigationBar)
		.toolbar {
			ToolbarItem(placement: .principal) {
				Text("Quick Scan")
					.font(.system(.subheadline, design: .rounded).bold())
					.foregroundStyle(.white.opacity(0.9))
			}
			ToolbarItem(placement: .topBarTrailing) {
				Button { showHelp = true } label: {
					Image(systemName: "questionmark")
						.font(.title3)
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(.white)
				}
			}
		}
		.sheet(isPresented: $showHelp) {
			QuickScanInstructionsSheet()
		}
			// NEW: word detail sheet
		.sheet(item: $selectedResult) { result in
			WordDetailSheet(result: result, aiService: aiService)
		}
		.onAppear {
			setupDetector()
			cameraService.start()
			withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
				pulseScale = 1.04
			}
		}
		.onDisappear { cameraService.stop() }
		.onTapGesture { if scanStatus == .ready { performQuickScan() } }
	}
}

	// MARK: - UI Components
@available(iOS 26.0, *)
private extension QuickScanView {
	
	var resultsCarousel: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 12) {
				ForEach(detectedResults) { result in
						// NEW: card + info button side by side
					resultCard(result)
				}
			}
			.padding(.horizontal, 20)
		}
	}
	
	func resultCard(_ result: FoundationAIService.QuizResult) -> some View {
		HStack(alignment: .top, spacing: 0) {
			
				// Main card content
			VStack(alignment: .leading, spacing: 6) {
				
				Text(result.translatedWord.capitalized)
					.font(.system(.title3, design: .rounded).bold())
					.foregroundStyle(.primary)
				
				Text(result.correctEnglish.uppercased())
					.font(.system(size: 10, weight: .bold, design: .monospaced))
					.foregroundStyle(.secondary)
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 18)
			
				// NEW: info button pinned to top-right of card
			Button {
				selectedResult = result
			} label: {
				Image(systemName: "info.circle.fill")
					.font(.system(size: 18))
					.symbolRenderingMode(.hierarchical)
					.foregroundStyle(.blue)
			}
			.padding(.top, 14)
			.padding(.trailing, 14)
		}
		.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
	}
	
	var tapToIdentifyHint: some View {
		HStack(spacing: 10) {
			Image(systemName: "hand.tap.fill")
			Text("Tap to identify")
		}
		.font(.subheadline.bold())
		.foregroundColor(.white)
		.padding(.horizontal, 24)
		.padding(.vertical, 14)
		.background(.black.opacity(0.3), in: Capsule())
		.scaleEffect(pulseScale)
	}
	
	var emptyStateToast: some View {
		Text("No objects found. Try another angle.")
			.font(.caption.bold())
			.foregroundStyle(.white)
			.padding(.horizontal, 16)
			.padding(.vertical, 10)
			.background(.ultraThinMaterial, in: Capsule())
	}
	
	var bottomActionArea: some View {
		VStack {
			if scanStatus == .displaying {
				Button(action: resetScan) {
					HStack(spacing: 8) {
						Image(systemName: "arrow.clockwise")
						Text("New Scan")
					}
					.font(.headline.bold())
					.foregroundStyle(.black)
					.padding(.horizontal, 32)
					.padding(.vertical, 16)
					.background(.white, in: Capsule())
					.shadow(color: .black.opacity(0.15), radius: 10, y: 5)
				}
				.transition(.scale.combined(with: .opacity))
			}
		}
		.padding(.bottom, 40)
	}
	
	var analysisOverlay: some View {
		ZStack {
			Color.black.opacity(0.2).ignoresSafeArea()
			VStack(spacing: 16) {
				ProgressView()
					.tint(.white)
					.controlSize(.large)
				Text("Analyzing...")
					.font(.subheadline.bold())
					.foregroundStyle(.white)
			}
		}
	}
}

	// MARK: - Logic (untouched)
@available(iOS 26.0, *)
private extension QuickScanView {
	func setupDetector() {
		cameraService.frameHandler = { buffer in self.latestPixelBuffer = buffer }
	}
	
	func performQuickScan() {
		guard let buffer = latestPixelBuffer else { return }
		
		impact.impactOccurred(intensity: 0.7)
		withAnimation(.easeInOut) {
			isAnalyzing = true
			scanStatus = .processing
		}
		
		detector.detect(from: buffer)
		detector.onPredictions = { observations in
			let genericBlacklist = ["structure", "room", "indoor", "interior", "architecture", "machine", "object", "material"]
			
			let rawLabels = observations
				.map { $0.identifier.lowercased() }
				.filter { label in
					!genericBlacklist.contains(where: { label.contains($0) })
				}
			
			Task(priority: .userInitiated) {
				guard !rawLabels.isEmpty else {
					await handleEmptyResult()
					return
				}
				
				let filtered = await aiService.filterObjects(from: rawLabels)
				
				if filtered.isEmpty {
					await handleEmptyResult()
					return
				}
				
				let results = await aiService.generateQuizSession(from: filtered)
				
				await MainActor.run {
					finalizeScan(with: results)
				}
			}
		}
	}
	
	func finalizeScan(with results: [FoundationAIService.QuizResult]) {
		withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
			isAnalyzing = false
			detectedResults = results
			scanStatus = .displaying
			notification.notificationOccurred(.success)
		}
	}
	
	@MainActor
	func handleEmptyResult() async {
		withAnimation(.spring()) {
			isAnalyzing = false
			scanStatus = .empty
			notification.notificationOccurred(.warning)
		}
		try? await Task.sleep(for: .seconds(2))
		withAnimation { scanStatus = .ready }
	}
	
	func resetScan() {
		impact.impactOccurred()
		withAnimation(.spring()) {
			detectedResults = []
			scanStatus = .ready
		}
	}
}


	// MARK: - Word Detail Sheet (NEW)

@available(iOS 26.0, *)
struct WordDetailSheet: View {
	
	let result: FoundationAIService.QuizResult
	let aiService: FoundationAIService
	
	@Environment(\.dismiss) private var dismiss
	
	@State private var sentence: FoundationAIService.BilingualSentence? = nil
	@State private var isLoading = true
	
		// NEW: speech service
	private let speech = SpeechService.shared
	
	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				
					// Word hero section
				VStack(spacing: 12) {
					
						// Translation pair
					VStack(spacing: 6) {
						
							// NEW: word + speak button
						HStack(spacing: 10) {
							
							Text(result.translatedWord.capitalized)
								.font(.system(size: 42, weight: .bold, design: .rounded))
								.foregroundStyle(.primary)
							
							Button {
								speech.speak(result.translatedWord)
							} label: {
								Image(systemName: "speaker.wave.2.fill")
									.font(.title2)
									.symbolRenderingMode(.hierarchical)
									.foregroundStyle(.blue)
							}
						}
						
						HStack(spacing: 6) {
							Image(systemName: "arrow.up.arrow.down")
								.font(.caption)
								.foregroundStyle(.tertiary)
							
							Text(result.correctEnglish.capitalized)
								.font(.system(.title3, design: .rounded))
								.foregroundStyle(.secondary)
						}
					}
				}
				.frame(maxWidth: .infinity)
				.padding(.vertical, 36)
				.background(.ultraThinMaterial)
				
				
					// Sentence section
				Group {
					if isLoading {
						sentenceLoadingView
					} else if let sentence {
						sentenceView(sentence)
					} else {
						sentenceErrorView
					}
				}
				.padding(24)
				
				Spacer()
			}
			.navigationTitle("Word Details")
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
		.task {
			sentence = await aiService.generateBilingualSentence(for: result.correctEnglish)
			isLoading = false
		}
	}
	
	
		// Sentence loaded
	func sentenceView(_ s: FoundationAIService.BilingualSentence) -> some View {
		VStack(spacing: 16) {
			
				// Section label
			HStack {
				Image(systemName: "text.quote")
					.foregroundStyle(.blue)
				
				Text("Example Sentence")
					.font(.system(.subheadline, design: .rounded).bold())
					.foregroundStyle(.secondary)
				
				Spacer()
				
					// NEW: speak full translated sentence
				Button {
					speech.speak(s.translated)
				} label: {
					Image(systemName: "speaker.wave.2.fill")
						.font(.title3)
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(.blue)
				}
			}
			
			
				// Translated sentence card
			VStack(alignment: .leading, spacing: 8) {
				
				Label("Translated", systemImage: "character.bubble.fill")
					.font(.system(size: 11, weight: .bold))
					.foregroundStyle(.blue)
				
				Text(s.translated)
					.font(.system(.body, design: .rounded).weight(.medium))
					.foregroundStyle(.primary)
					.fixedSize(horizontal: false, vertical: true)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(16)
			.background(
				Color.blue.opacity(0.08),
				in: RoundedRectangle(cornerRadius: 16, style: .continuous)
			)
			
			
				// English sentence card
			VStack(alignment: .leading, spacing: 8) {
				
				Label("English", systemImage: "textformat.abc")
					.font(.system(size: 11, weight: .bold))
					.foregroundStyle(.secondary)
				
				Text(s.english)
					.font(.system(.body, design: .rounded))
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(16)
			.background(
				Color(.tertiarySystemBackground),
				in: RoundedRectangle(cornerRadius: 16, style: .continuous)
			)
		}
	}
	
	
		// Loading state
	var sentenceLoadingView: some View {
		VStack(spacing: 14) {
			
			ProgressView()
				.controlSize(.regular)
			
			Text("Generating example sentence...")
				.font(.system(.subheadline, design: .rounded))
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity)
		.padding(.top, 32)
	}
	
	
		// Error / nil state
	var sentenceErrorView: some View {
		VStack(spacing: 10) {
			
			Image(systemName: "exclamationmark.circle")
				.font(.system(size: 32))
				.foregroundStyle(.secondary)
			
			Text("Couldn't load an example sentence.")
				.font(.subheadline)
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity)
		.padding(.top, 32)
	}
}
//struct WordDetailSheet: View {
//	
//	let result: FoundationAIService.QuizResult
//	let aiService: FoundationAIService
//	
//	@Environment(\.dismiss) private var dismiss
//	
//	@State private var sentence: FoundationAIService.BilingualSentence? = nil
//	@State private var isLoading = true
//	
//	var body: some View {
//		NavigationStack {
//			VStack(spacing: 0) {
//				
//					// Word hero section
//				VStack(spacing: 12) {
//					
//						// Translation pair
//					VStack(spacing: 6) {
//						Text(result.translatedWord.capitalized)
//							.font(.system(size: 42, weight: .bold, design: .rounded))
//							.foregroundStyle(.primary)
//						
//						HStack(spacing: 6) {
//							Image(systemName: "arrow.up.arrow.down")
//								.font(.caption)
//								.foregroundStyle(.tertiary)
//							Text(result.correctEnglish.capitalized)
//								.font(.system(.title3, design: .rounded))
//								.foregroundStyle(.secondary)
//						}
//					}
//				}
//				.frame(maxWidth: .infinity)
//				.padding(.vertical, 36)
//				.background(.ultraThinMaterial)
//				
//					// Sentence section
//				Group {
//					if isLoading {
//						sentenceLoadingView
//					} else if let sentence {
//						sentenceView(sentence)
//					} else {
//						sentenceErrorView
//					}
//				}
//				.padding(24)
//				
//				Spacer()
//			}
//			.navigationTitle("Word Details")
//			.navigationBarTitleDisplayMode(.inline)
//			.toolbar {
//				ToolbarItem(placement: .cancellationAction) {
//					Button {
//						dismiss()
//					} label: {
//						Image(systemName: "xmark")
//					}
//				}
//			}
//		}
//		.task {
//			sentence = await aiService.generateBilingualSentence(for: result.correctEnglish)
//			isLoading = false
//		}
//	}
//	
//		// Sentence loaded
//	func sentenceView(_ s: FoundationAIService.BilingualSentence) -> some View {
//		VStack(spacing: 16) {
//			
//				// Section label
//			HStack {
//				Image(systemName: "text.quote")
//					.foregroundStyle(.blue)
//				Text("Example Sentence")
//					.font(.system(.subheadline, design: .rounded).bold())
//					.foregroundStyle(.secondary)
//				Spacer()
//			}
//			
//				// Translated sentence card
//			VStack(alignment: .leading, spacing: 8) {
//				Label("Translated", systemImage: "character.bubble.fill")
//					.font(.system(size: 11, weight: .bold))
//					.foregroundStyle(.blue)
//				
//				Text(s.translated)
//					.font(.system(.body, design: .rounded).weight(.medium))
//					.foregroundStyle(.primary)
//					.fixedSize(horizontal: false, vertical: true)
//			}
//			.frame(maxWidth: .infinity, alignment: .leading)
//			.padding(16)
//			.background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
//			
//				// English sentence card
//			VStack(alignment: .leading, spacing: 8) {
//				Label("English", systemImage: "textformat.abc")
//					.font(.system(size: 11, weight: .bold))
//					.foregroundStyle(.secondary)
//				
//				Text(s.english)
//					.font(.system(.body, design: .rounded))
//					.foregroundStyle(.secondary)
//					.fixedSize(horizontal: false, vertical: true)
//			}
//			.frame(maxWidth: .infinity, alignment: .leading)
//			.padding(16)
//			.background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
//		}
//	}
//	
//		// Loading state
//	var sentenceLoadingView: some View {
//		VStack(spacing: 14) {
//			ProgressView()
//				.controlSize(.regular)
//			Text("Generating example sentence...")
//				.font(.system(.subheadline, design: .rounded))
//				.foregroundStyle(.secondary)
//		}
//		.frame(maxWidth: .infinity)
//		.padding(.top, 32)
//	}
//	
//		// Error / nil state
//	var sentenceErrorView: some View {
//		VStack(spacing: 10) {
//			Image(systemName: "exclamationmark.circle")
//				.font(.system(size: 32))
//				.foregroundStyle(.secondary)
//			Text("Couldn't load an example sentence.")
//				.font(.subheadline)
//				.foregroundStyle(.secondary)
//		}
//		.frame(maxWidth: .infinity)
//		.padding(.top, 32)
//	}
//}


	// MARK: - Instructions (untouched)
struct QuickScanInstructionsSheet: View {
	@Environment(\.dismiss) var dismiss
	var body: some View {
		NavigationStack {
			List {
				Section {
					InstructionRow(
						icon: "bolt.fill",
						color: .blue,
						title: "Instant Scan",
						detail: "Tap once to identify and translate everything in view."
					)
					InstructionRow(
						icon: "camera.viewfinder",
						color: .orange,
						title: "Best Results",
						detail: "Keep your phone 2-3 feet away and ensure good lighting."
					)
					InstructionRow(
						icon: "move.3d",
						color: .purple,
						title: "Angles Matter",
						detail: "Try a 45° angle rather than looking straight down."
					)
				}
			}
			.navigationTitle("Quick Scan Guide")
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
