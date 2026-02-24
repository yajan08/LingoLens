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
	
	@State private var selectedResult: FoundationAIService.QuizResult? = nil
	
	enum ScanStatus {
		case ready, processing, displaying, empty
	}
	
	@Environment(\.dismiss) private var dismiss
	private let impact = UIImpactFeedbackGenerator(style: .medium)
	private let notification = UINotificationFeedbackGenerator()
	@Binding var path: NavigationPath
	
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
		.preferredColorScheme(ColorScheme.dark)
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
					resultCard(result)
				}
			}
			.padding(.horizontal, 20)
		}
	}
	
	func resultCard(_ result: FoundationAIService.QuizResult) -> some View {
		Button {
			selectedResult = result
		} label: {
			HStack(alignment: .center, spacing: 12) {
				
				VStack(alignment: .leading, spacing: 6) {
					
					HStack{
						Text(result.translatedWord.capitalized)
							.font(.system(.title3, design: .rounded).bold())
							.foregroundStyle(.primary)
						Spacer()
						Image(systemName: "info.circle")
							.font(.system(size: 17, weight: .semibold))
							.foregroundStyle(.tertiary)
					}
					
					
					Text(result.correctEnglish.uppercased())
						.font(.system(size: 10, weight: .bold, design: .monospaced))
						.foregroundStyle(.secondary)
				}
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 18)
			.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 24, style: .continuous)
					.stroke(
						LinearGradient(
							colors: [
								Color.orange.opacity(0.5),
								Color.blue.opacity(0.4)
							],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						),
						lineWidth: 1
					)
			)
		}
		.buttonStyle(.plain)
	}
	
	var tapToIdentifyHint: some View {
		HStack(spacing: 10) {
			Image(systemName: "hand.tap.fill")
			Text("Tap anywhere to identify")
		}
		.font(.subheadline.bold())
		.foregroundColor(.white)
		.padding(.horizontal, 24)
		.padding(.vertical, 14)
		.background(.black.opacity(0.3), in: Capsule())
		.scaleEffect(pulseScale)
	}
	
	var emptyStateToast: some View {
		HStack(spacing: 8) {
			Image(systemName: "xmark.circle.fill")
				.foregroundStyle(.red)
			
			Text("No objects found. Try another angle.")
				.font(.caption.bold())
				.foregroundStyle(.white)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 10)
		.background(.ultraThinMaterial, in: Capsule())
			// Optional: add a subtle border to make it pop against dark backgrounds
		.overlay(
			Capsule()
				.stroke(.white.opacity(0.1), lineWidth: 0.5)
		)
	}
	
//	var emptyStateToast: some View {
//		Text("No objects found. Try another angle.")
//			.font(.caption.bold())
//			.foregroundStyle(.white)
//			.padding(.horizontal, 16)
//			.padding(.vertical, 10)
//			.background(.ultraThinMaterial, in: Capsule())
//	}
	
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


	// MARK: - Word Detail Sheet


@available(iOS 26.0, *)
struct WordDetailSheet: View {
	
	let result: FoundationAIService.QuizResult
	let aiService: FoundationAIService
	
	@Environment(\.dismiss) private var dismiss
	
	@State private var sentence: FoundationAIService.BilingualSentence? = nil
	@State private var isLoading = true
	
	private let speech = SpeechService.shared
	
	func display(_ raw: String) -> String {
		raw.replacingOccurrences(of: "_", with: " ")
	}
	
	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				
					// Hero (IDENTICAL STYLE TO WORD HINT)
				ZStack {
					LinearGradient(
						colors: [Color.blue.opacity(0.09), Color.orange.opacity(0.06)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
					
					VStack(spacing: 8) {
						HStack(spacing: 8) {
							Text(display(result.translatedWord).capitalized)
								.font(.system(size: 40, weight: .bold, design: .rounded))
								.foregroundStyle(.primary)
							
							Button {
								speech.speak(display(result.translatedWord))
							} label: {
								Image(systemName: "speaker.wave.2.fill")
									.font(.system(size: 20, weight: .semibold))
									.symbolRenderingMode(.hierarchical)
									.foregroundStyle(.secondary)
							}
						}
						
						HStack(spacing: 6) {
							Image(systemName: "text.quote")
								.font(.caption)
								.foregroundStyle(.tertiary)
							
							Text(display(result.correctEnglish).capitalized)
								.font(.system(.title3, design: .rounded))
								.foregroundStyle(.secondary)
						}
					}
					.padding(.vertical, 36)
				}
				
				ScrollView {
					VStack(spacing: 12) {
						
						if isLoading {
							
							VStack(spacing: 14) {
								ProgressView().controlSize(.regular)
								Text("Generating example sentence...")
									.font(.system(.subheadline, design: .rounded))
									.foregroundStyle(.secondary)
							}
							.frame(maxWidth: .infinity)
							.padding(.top, 48)
							
						} else if let s = sentence {
							
							VStack(spacing: 12) {
								
								HStack {
									Image(systemName: "translate")
										.foregroundStyle(.blue)
									
									Text("Example Sentence")
										.font(.system(.subheadline, design: .rounded).bold())
										.foregroundStyle(.secondary)
									
									Spacer()
									
//									Button {
//										speech.speak(s.translated)
//									} label: {
//										Image(systemName: "speaker.wave.2.fill")
//											.font(.system(size: 14, weight: .semibold))
//											.symbolRenderingMode(.hierarchical)
//											.foregroundStyle(.secondary)
//									}
								}
								
									// Translated card (IDENTICAL STYLE)
								VStack(alignment: .leading, spacing: 6) {
									HStack{
										Label("Translated", systemImage: "character.bubble.fill")
											.font(.system(size: 11, weight: .bold))
											.foregroundStyle(.blue)
										
										Spacer()
											// SPEAKER BUTTON NOW LIVES HERE
										Button {
											speech.speak(s.translated)
										} label: {
											Image(systemName: "speaker.wave.2.fill")
												.font(.system(size: 15, weight: .semibold))
												.symbolRenderingMode(.hierarchical)
												.foregroundStyle(.blue.opacity(0.6)) // Styled to match the card
										}
									}
									Text(s.translated)
										.font(.system(.body, design: .rounded).weight(.medium))
										.foregroundStyle(.primary)
										.fixedSize(horizontal: false, vertical: true)
									
								}
								.frame(maxWidth: .infinity, alignment: .leading)
								.padding(14)
								.background(
									Color.blue.opacity(0.07),
									in: RoundedRectangle(cornerRadius: 14, style: .continuous)
								)
								.overlay(
									RoundedRectangle(cornerRadius: 14, style: .continuous)
										.strokeBorder(Color.blue.opacity(0.14), lineWidth: 1)
								)
								
									// English card (IDENTICAL STYLE)
								VStack(alignment: .leading, spacing: 6) {
									Label("English", systemImage: "textformat.abc")
										.font(.system(size: 11, weight: .bold))
										.foregroundStyle(.orange)
									
									Text(s.english)
										.font(.system(.body, design: .rounded))
										.foregroundStyle(.secondary)
										.fixedSize(horizontal: false, vertical: true)
								}
								.frame(maxWidth: .infinity, alignment: .leading)
								.padding(14)
								.background(
									Color.orange.opacity(0.06),
									in: RoundedRectangle(cornerRadius: 14, style: .continuous)
								)
								.overlay(
									RoundedRectangle(cornerRadius: 14, style: .continuous)
										.strokeBorder(Color.orange.opacity(0.14), lineWidth: 1)
								)
							}
							.padding(20)
							
						} else {
							
							VStack(spacing: 10) {
								Image(systemName: "text.bubble")
									.font(.system(size: 28))
									.foregroundStyle(.secondary)
								
								Text("No example available")
									.font(.system(.subheadline, design: .rounded).bold())
									.foregroundStyle(.secondary)
								
								Text("Try again later to load an example sentence.")
									.font(.system(.caption, design: .rounded))
									.foregroundStyle(.tertiary)
									.multilineTextAlignment(.center)
							}
							.frame(maxWidth: .infinity)
							.padding(.top, 48)
							.padding(.horizontal, 32)
						}
					}
				}
				
				Spacer()
			}
			.navigationTitle("Word Details")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button { dismiss() } label: {
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
}

	// MARK: - Instructions (untouched)
struct QuickScanInstructionsSheet: View {
	@Environment(\.dismiss) var dismiss
	
	var body: some View {
		NavigationStack {
			List {
				Section("Scanner Guide") {
					InstructionRow(
						icon: "sun.max.fill",
						color: .orange,
						title: "Bright Lighting",
						detail: "Scan in well-lit areas. Natural light ensures the fastest and most accurate detection."
					)
					
					InstructionRow(
						icon: "arrow.up.and.down.and.arrow.left.and.right",
						color: .blue,
						title: "Stay 2–3 Feet Away",
						detail: "Don't get too close. Keeping a short distance helps the AI see the entire object."
					)
					
					InstructionRow(
						icon: "camera.viewfinder",
						color: .purple,
						title: "Capture Better Angles",
						detail: "Try multiple angles, center one object at a time and avoid cluttered backgrounds."
					)
				}
			}
			.navigationTitle("Quick Scan Guide")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button {
						dismiss()
					} label : {
						Image(systemName: "xmark")
					}
						.fontWeight(.semibold)
				}
			}
		}
	}
}
