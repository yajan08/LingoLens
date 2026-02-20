import SwiftUI
import Vision

@available(iOS 26.0, *)
struct QuizCameraView: View {
		// MARK: - Properties
	let quizzes: [FoundationAIService.QuizResult]
	let onFinished: (Int) -> Void
	
	@StateObject private var cameraService = CameraService()
	@State private var detector = ObjectDetector()
	
		// Core State
	@State private var latestPixelBuffer: CVPixelBuffer?
	@State private var currentIndex: Int = 0
	@State private var score: Int = 0
	
		// FIX: stable snapshot — never derived from index during async ops
	@State private var activeQuiz: FoundationAIService.QuizResult? = nil
	
		// UI State
	@State private var isDetecting = false
	@State private var showAnswer = false
	@State private var showHelp = false
	@State private var detectionStatus: DetectionStatus = .ready
	@State private var detectionLocked = false
	@State private var pulseScale: CGFloat = 1.0
	
		// Hint sheet
	@State private var showSentenceHint = false
	@State private var hintSentence: FoundationAIService.BilingualSentence? = nil
	@State private var isLoadingHint = false
	
		// Success sentence
	@State private var successSentence: FoundationAIService.BilingualSentence? = nil
	@State private var isLoadingSuccessSentence = false
	
		// Revealed answer sentence
	@State private var revealedSentence: FoundationAIService.BilingualSentence? = nil
	@State private var isLoadingRevealedSentence = false
	
	private let aiService = FoundationAIService()
	
	enum DetectionStatus {
		case ready, detecting, success, failure
	}
	
	@Environment(\.dismiss) private var dismiss
	private let impact = UIImpactFeedbackGenerator(style: .medium)
	private let notification = UINotificationFeedbackGenerator()
	
		// MARK: - Body
	var body: some View {
		NavigationStack {
			ZStack {
				CameraPreview(session: cameraService.session)
					.ignoresSafeArea()
				
					// Top vignette
				VStack {
					LinearGradient(
						colors: [.black.opacity(0.35), .clear],
						startPoint: .top,
						endPoint: .bottom
					)
					.frame(height: 140)
					.ignoresSafeArea()
					Spacer()
				}
				
					// HUD — only renders when activeQuiz is set
				if let quiz = activeQuiz {
					hudLayer(quiz: quiz)
				}
				
					// Processing overlay
				if isDetecting {
					processingOverlay
				}
			}
			.navigationBarTitleDisplayMode(.inline)
			.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
			.toolbarColorScheme(.dark, for: .navigationBar)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button("End") { dismiss() }
						.foregroundStyle(.red)
						.fontWeight(.semibold)
				}
				ToolbarItem(placement: .principal) {
					Text("\(currentIndex + 1) of \(quizzes.count)")
						.font(.system(.subheadline, design: .monospaced).bold())
						.foregroundStyle(.white.opacity(0.8))
				}
				ToolbarItem(placement: .topBarTrailing) {
					Button { showHelp = true } label: {
						Image(systemName: "questionmark")
							.font(.title3)
							.symbolRenderingMode(.hierarchical)
					}
				}
			}
			.sheet(isPresented: $showHelp) {
				InstructionsSheet()
			}
				// FIX: sheet uses activeQuiz snapshot, not live index
			.sheet(isPresented: $showSentenceHint) {
				if let quiz = activeQuiz {
					SentenceHintSheet(
						quiz: quiz,
						sentence: hintSentence,
						isLoading: isLoadingHint,
						revealAnswer: detectionStatus == .success
					)
				}
			}
			.onAppear {
					// FIX: set activeQuiz on appear
				activeQuiz = quizzes[currentIndex]
				setupDetector()
				cameraService.start()
				impact.prepare()
				notification.prepare()
				withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
					pulseScale = 1.02
				}
			}
			.onDisappear { cameraService.stop() }
			.onTapGesture {
					// CHANGE: If answer is shown, tap to detect is disabled to force "Continue"
				if !showAnswer {
					attemptDetection()
				}
			}
		}
	}
	
		// FIX: entire HUD extracted and receives quiz as parameter
		// so all child views render from the same stable snapshot
	@ViewBuilder
	func hudLayer(quiz: FoundationAIService.QuizResult) -> some View {
		VStack(spacing: 0) {
			targetWordBanner(quiz: quiz)
				.padding(.top, 12)
			
			Spacer()
			
				// Show Answer card
			if showAnswer && detectionStatus != .success {
				revealedAnswerCard(quiz: quiz)
					.transition(.move(edge: .bottom).combined(with: .opacity))
					.padding(.bottom, 12)
			}
			
				// Failure toast
			if detectionStatus == .failure {
				failureToast
					.transition(.move(edge: .top).combined(with: .opacity))
					.padding(.bottom, 12)
			}
			
				// Success card
			if detectionStatus == .success {
				successMatchCard(quiz: quiz)
					.transition(.scale(scale: 0.9).combined(with: .opacity))
					.padding(.bottom, 12)
			}
			
				// Tap hint
			if detectionStatus == .ready && !isDetecting && !showAnswer {
				tapToDetectLabel
					.padding(.bottom, 12)
			}
			
			Spacer()
			
			bottomActionArea
				.padding(.horizontal, 20)
				.background(.clear)
		}
		.animation(.spring(response: 0.4, dampingFraction: 0.85), value: detectionStatus)
		.animation(.spring(response: 0.35, dampingFraction: 0.85), value: showAnswer)
	}
}

	// MARK: - Logic
@available(iOS 26.0, *)
private extension QuizCameraView {
	
	func setupDetector() {
		cameraService.frameHandler = { buffer in
			self.latestPixelBuffer = buffer
		}
		detector.onPredictions = { [self] observations in
			guard isDetecting, let quiz = activeQuiz else { return }
			let labels = observations.map { $0.identifier.lowercased() }
				// FIX: match against snapshot, not live computed property
			let target = quiz.correctEnglish
				.replacingOccurrences(of: "_", with: " ")
				.lowercased()
			let isMatch = labels.contains {
				$0.contains(target) || target.contains($0)
			}
			finalizeDetection(isMatch: isMatch)
		}
	}
	
	func attemptDetection() {
		guard
			!detectionLocked,
			detectionStatus != .success,
			let buffer = latestPixelBuffer
		else { return }
		
		detectionLocked = true
		impact.impactOccurred(intensity: 0.8)
		withAnimation(.easeInOut(duration: 0.3)) {
			isDetecting = true
			detectionStatus = .detecting
			showAnswer = false
		}
		detector.detect(from: buffer)
	}
	
	func finalizeDetection(isMatch: Bool) {
		DispatchQueue.main.async {
			withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
				self.isDetecting = false
				if isMatch {
					self.detectionStatus = .success
					self.score += 1
					self.notification.notificationOccurred(.success)
					self.loadSuccessSentence()
				} else {
					self.detectionStatus = .failure
					self.notification.notificationOccurred(.error)
					DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
						withAnimation {
							if self.detectionStatus == .failure {
								self.detectionStatus = .ready
								self.detectionLocked = false
							}
						}
					}
				}
			}
		}
	}
	
	func nextObject() {
		let nextIndex = currentIndex + 1
		if nextIndex >= quizzes.count {
			onFinished(score)
		} else {
				// FIX: update snapshot FIRST, then reset all state atomically
			let nextQuiz = quizzes[nextIndex]
			withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
				currentIndex = nextIndex
				activeQuiz = nextQuiz
				detectionStatus = .ready
				showAnswer = false
				detectionLocked = false
				isDetecting = false
				hintSentence = nil
				successSentence = nil
				revealedSentence = nil
				isLoadingHint = false
				isLoadingSuccessSentence = false
				isLoadingRevealedSentence = false
			}
		}
	}
	
	func loadHintSentence() {
			// FIX: capture snapshot word before async boundary
		guard let quiz = activeQuiz else { return }
		guard hintSentence == nil, !isLoadingHint else {
			showSentenceHint = true
			return
		}
		isLoadingHint = true
		showSentenceHint = true
		let word = quiz.correctEnglish
		let capturedIndex = currentIndex
		Task {
			let result = await aiService.generateBilingualSentence(for: word)
			await MainActor.run {
					// FIX: only apply if still on same question
				guard currentIndex == capturedIndex else { return }
				hintSentence = result
				isLoadingHint = false
			}
		}
	}
	
	func loadSuccessSentence() {
		guard let quiz = activeQuiz else { return }
		guard successSentence == nil, !isLoadingSuccessSentence else { return }
		isLoadingSuccessSentence = true
		let word = quiz.correctEnglish
		let capturedIndex = currentIndex
		Task {
			let result = await aiService.generateBilingualSentence(for: word)
			await MainActor.run {
				guard currentIndex == capturedIndex else { return }
				successSentence = result
				isLoadingSuccessSentence = false
			}
		}
	}
	
	func loadRevealedSentence() {
		guard let quiz = activeQuiz else { return }
		guard revealedSentence == nil, !isLoadingRevealedSentence else { return }
		isLoadingRevealedSentence = true
		let word = quiz.correctEnglish
		let capturedIndex = currentIndex
		Task {
			let result = await aiService.generateBilingualSentence(for: word)
			await MainActor.run {
				guard currentIndex == capturedIndex else { return }
				revealedSentence = result
				isLoadingRevealedSentence = false
			}
		}
	}
	
		// Sanitize display strings — removes underscores from Vision labels
	func display(_ raw: String) -> String {
		raw.replacingOccurrences(of: "_", with: " ")
	}
}

	// MARK: - UI Components
@available(iOS 26.0, *)
private extension QuizCameraView {
	
	var blueOrangeGradient: LinearGradient {
		LinearGradient(
			colors: [.blue.opacity(0.85), Color(red: 0.9, green: 0.45, blue: 0.1).opacity(0.85)],
			startPoint: .leading,
			endPoint: .trailing
		)
	}
	
		// FIX: all card views receive quiz as explicit parameter
	func targetWordBanner(quiz: FoundationAIService.QuizResult) -> some View {
		HStack(spacing: 12) {
			VStack(alignment: .leading, spacing: 2) {
				Text("FIND THE OBJECT")
					.font(.system(size: 9, weight: .black))
					.foregroundStyle(.white.opacity(0.45))
					.tracking(1.4)
				Text(display(quiz.translatedWord).uppercased())
					.font(.system(.title3, design: .rounded).bold())
					.foregroundStyle(.white)
					.lineLimit(1)
					.minimumScaleFactor(0.7)
			}
			
			Spacer()
			
			Button {
				loadHintSentence()
			} label: {
				Group {
					if isLoadingHint && hintSentence == nil {
						ProgressView()
							.tint(.white)
							.controlSize(.mini)
							.frame(width: 32, height: 32)
					} else {
						Image(systemName: "info")
							.font(.system(size: 12, weight: .medium))
							.foregroundStyle(.white.opacity(0.8))
							.frame(width: 32, height: 32)
					}
				}
				.background(.white.opacity(0.1), in: Circle())
			}
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 13)
		.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: 18, style: .continuous)
				.strokeBorder(
					LinearGradient(
						colors: [.blue.opacity(0.4), .orange.opacity(0.3)],
						startPoint: .leading,
						endPoint: .trailing
					),
					lineWidth: 1
				)
		)
		.padding(.horizontal, 16)
		.shadow(color: .black.opacity(0.18), radius: 10, y: 4)
	}
	
	var tapToDetectLabel: some View {
		VStack(spacing: 6) {
			HStack(spacing: 7) {
				Image(systemName: "hand.tap.fill")
					.font(.system(size: 13))
				Text("Tap anywhere to scan")
					.font(.system(.subheadline, design: .rounded).bold())
			}
			.foregroundStyle(.white)
			Text("Point camera at the object")
				.font(.system(.caption, design: .rounded))
				.foregroundStyle(.white.opacity(0.55))
		}
		.padding(.horizontal, 22)
		.padding(.vertical, 13)
		.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: 18, style: .continuous)
				.strokeBorder(
					LinearGradient(
						colors: [.blue.opacity(0.35), .orange.opacity(0.25)],
						startPoint: .leading,
						endPoint: .trailing
					),
					lineWidth: 1
				)
		)
		.scaleEffect(pulseScale)
	}
	
	var failureToast: some View {
		HStack(spacing: 8) {
			Image(systemName: "xmark.circle.fill")
				.font(.system(size: 13))
				.foregroundStyle(.red.opacity(0.85))
			Text("No match — try a different angle")
				.font(.system(.subheadline, design: .rounded).bold())
				.foregroundStyle(.white)
		}
		.padding(.horizontal, 18)
		.padding(.vertical, 11)
		.background(.ultraThinMaterial, in: Capsule())
		.overlay(Capsule().strokeBorder(.red.opacity(0.25), lineWidth: 1))
	}
	
		// FIX: Show Answer card — "No worries, the answer was..."
	func revealedAnswerCard(quiz: FoundationAIService.QuizResult) -> some View {
		VStack(spacing: 14) {
			
			VStack(spacing: 6) {
				Image(systemName: "lightbulb.fill")
					.font(.system(size: 30))
					.foregroundStyle(
						LinearGradient(
							colors: [.blue, .orange],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
				
				VStack(spacing: 3) {
					Text("No worries, the answer was")
						.font(.system(.caption, design: .rounded).bold())
						.foregroundStyle(.secondary)
					Text(display(quiz.correctEnglish).capitalized)
						.font(.system(.headline, design: .rounded).bold())
						.foregroundStyle(.primary)
					Text("→ \(display(quiz.translatedWord).capitalized)")
						.font(.system(.subheadline, design: .rounded).bold())
						.foregroundStyle(.orange)
				}
			}
			
				// Sentence
			if isLoadingRevealedSentence {
				HStack(spacing: 7) {
					ProgressView().controlSize(.mini)
					Text("Loading example...")
						.font(.system(.caption, design: .rounded))
						.foregroundStyle(.secondary)
				}
			} else if let s = revealedSentence {
				VStack(spacing: 8) {
					Divider().overlay(.white.opacity(0.1))
					sentenceCards(sentence: s)
				}
			}
		}
		.padding(.vertical, 18)
		.padding(.horizontal, 20)
		.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: 24, style: .continuous)
				.strokeBorder(.white.opacity(0.09), lineWidth: 1)
		)
		.padding(.horizontal, 20)
	}
	
	func successMatchCard(quiz: FoundationAIService.QuizResult) -> some View {
		VStack(spacing: 14) {
			
			VStack(spacing: 6) {
				Image(systemName: "checkmark.seal.fill")
					.font(.system(size: 38))
					.foregroundStyle(.green)
				
				VStack(spacing: 3) {
					Text("Match Found!")
						.font(.system(.caption, design: .rounded).bold())
						.foregroundStyle(.secondary)
					HStack(spacing: 6) {
						Text(display(quiz.correctEnglish).capitalized)
							.foregroundStyle(.primary)
						Text("·")
							.foregroundStyle(.tertiary)
						Text(display(quiz.translatedWord).capitalized)
							.foregroundStyle(.orange)
					}
					.font(.system(.headline, design: .rounded).bold())
				}
			}
			
			if isLoadingSuccessSentence {
				HStack(spacing: 7) {
					ProgressView().controlSize(.mini)
					Text("Loading example...")
						.font(.system(.caption, design: .rounded))
						.foregroundStyle(.secondary)
				}
			} else if let s = successSentence {
				VStack(spacing: 8) {
					Divider().overlay(.white.opacity(0.1))
					sentenceCards(sentence: s)
				}
			}
		}
		.padding(.vertical, 18)
		.padding(.horizontal, 20)
		.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: 24, style: .continuous)
				.strokeBorder(.white.opacity(0.09), lineWidth: 1)
		)
		.padding(.horizontal, 20)
	}
	
		// Shared sentence card pair — used in both success and revealed answer
	func sentenceCards(sentence: FoundationAIService.BilingualSentence) -> some View {
		VStack(spacing: 8) {
			VStack(alignment: .leading, spacing: 4) {
				Label("Translated", systemImage: "character.bubble.fill")
					.font(.system(size: 10, weight: .bold))
					.foregroundStyle(.blue)
				Text(sentence.translated)
					.font(.system(.subheadline, design: .rounded).weight(.medium))
					.foregroundStyle(.primary)
					.fixedSize(horizontal: false, vertical: true)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(11)
			.background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
			.overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
				.strokeBorder(Color.blue.opacity(0.18), lineWidth: 1))
			
			VStack(alignment: .leading, spacing: 4) {
				Label("English", systemImage: "textformat.abc")
					.font(.system(size: 10, weight: .bold))
					.foregroundStyle(.orange)
				Text(sentence.english)
					.font(.system(.subheadline, design: .rounded))
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(11)
			.background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
			.overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
				.strokeBorder(Color.orange.opacity(0.18), lineWidth: 1))
		}
	}
	
	var bottomActionArea: some View {
		VStack(spacing: 12) {
				// CHANGE: Simplified check. If detection is successful OR answer is shown, we show the "Continue" button
			if detectionStatus == .success || showAnswer {
				Button(action: nextObject) {
					HStack(spacing: 8) {
						Text("Continue Hunt")
							.font(.system(.headline, design: .rounded).bold())
						Image(systemName: "arrow.right.circle.fill")
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, 17)
					.background(blueOrangeGradient, in: Capsule())
					.foregroundStyle(.white)
					.shadow(color: .blue.opacity(0.25), radius: 14, y: 5)
				}
			} else {
					// Single Show Answer button
				Button {
					withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
						showAnswer = true // CHANGE: Just set to true, once tapped it stays until nextObject
					}
					if showAnswer {
						impact.impactOccurred()
						loadRevealedSentence()
					}
				} label: {
					HStack(spacing: 7) {
						Image(systemName: "eye")
							.font(.system(size: 13, weight: .semibold))
						Text("Show Answer")
							.font(.system(.subheadline, design: .rounded).bold())
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, 16)
					.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
					.overlay(
						RoundedRectangle(cornerRadius: 18, style: .continuous)
							.strokeBorder(
								LinearGradient(
									colors: [.blue.opacity(0.35), .orange.opacity(0.25)],
									startPoint: .leading,
									endPoint: .trailing
								),
								lineWidth: 1
							)
					)
					.foregroundStyle(.white)
				}
			}
		}
	}
	
	var processingOverlay: some View {
		ZStack {
			Color.black.opacity(0.28).ignoresSafeArea()
			VStack(spacing: 18) {
				ZStack {
					Circle()
						.strokeBorder(
							LinearGradient(
								colors: [.blue, .orange],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							),
							lineWidth: 2
						)
						.frame(width: 56, height: 56)
					ProgressView()
						.tint(.white)
						.controlSize(.regular)
				}
				VStack(spacing: 4) {
					Text("Analyzing Environment")
						.font(.system(.subheadline, design: .rounded).bold())
						.foregroundStyle(.white)
					Text("Looking for a match...")
						.font(.system(.caption, design: .rounded))
						.foregroundStyle(.white.opacity(0.6))
				}
			}
			.padding(28)
			.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 24, style: .continuous)
					.strokeBorder(.white.opacity(0.08), lineWidth: 1)
			)
		}
	}
}


	// MARK: - Sentence Hint Sheet
@available(iOS 26.0, *)
struct SentenceHintSheet: View {
	
	let quiz: FoundationAIService.QuizResult
	let sentence: FoundationAIService.BilingualSentence?
	let isLoading: Bool
	let revealAnswer: Bool
	
	@Environment(\.dismiss) private var dismiss
	private let speech = SpeechService.shared
	
	func display(_ raw: String) -> String {
		raw.replacingOccurrences(of: "_", with: " ")
	}
	
	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				
					// Hero
				ZStack {
					LinearGradient(
						colors: [Color.blue.opacity(0.09), Color.orange.opacity(0.06)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
					VStack(spacing: 8) {
						HStack(spacing: 8) {
							Text(display(quiz.translatedWord).capitalized)
								.font(.system(size: 40, weight: .bold, design: .rounded))
								.foregroundStyle(.primary)
							
							Button {
								speech.speak(display(quiz.translatedWord))
							} label: {
								Image(systemName: "speaker.wave.2.fill")
									.font(.system(size: 16, weight: .semibold))
									.symbolRenderingMode(.hierarchical)
									.foregroundStyle(.secondary)
							}
						}
						
						if revealAnswer {
							HStack(spacing: 6) {
								Image(systemName: "arrow.left.arrow.right")
									.font(.caption)
									.foregroundStyle(.tertiary)
								Text(display(quiz.correctEnglish).capitalized)
									.font(.system(.title3, design: .rounded))
									.foregroundStyle(.secondary)
							}
						} else {
							Text("Example usage in context")
								.font(.system(.subheadline, design: .rounded))
								.foregroundStyle(.tertiary)
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
									Image(systemName: "text.quote")
										.foregroundStyle(.blue)
									Text("Example Sentence")
										.font(.system(.subheadline, design: .rounded).bold())
										.foregroundStyle(.secondary)
									Spacer()
									
									if let s = sentence {
										Button {
											speech.speak(s.translated)
										} label: {
											Image(systemName: "speaker.wave.2.fill")
												.font(.system(size: 14, weight: .semibold))
												.symbolRenderingMode(.hierarchical)
												.foregroundStyle(.secondary)
										}
									}
								}
								
									// Translated sentence — always shown
								VStack(alignment: .leading, spacing: 6) {
									Label("Translated", systemImage: "character.bubble.fill")
										.font(.system(size: 11, weight: .bold))
										.foregroundStyle(.blue)
									Text(s.translated)
										.font(.system(.body, design: .rounded).weight(.medium))
										.foregroundStyle(.primary)
										.fixedSize(horizontal: false, vertical: true)
								}
								.frame(maxWidth: .infinity, alignment: .leading)
								.padding(14)
								.background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
								.overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
									.strokeBorder(Color.blue.opacity(0.14), lineWidth: 1))
								
									// English — only after correct guess
								if revealAnswer {
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
									.background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
									.overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
										.strokeBorder(Color.orange.opacity(0.14), lineWidth: 1))
								} else {
									HStack(spacing: 5) {
										Image(systemName: "lock")
											.font(.system(size: 10))
										Text("Find the object to unlock the English translation")
											.font(.system(.caption, design: .rounded))
									}
									.foregroundStyle(.secondary.opacity(0.7))
									.padding(.top, 2)
								}
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
								Text("Try scanning the object to continue.")
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
			.navigationTitle("Word Hint")
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


	// MARK: - Instruction Sheet
struct InstructionsSheet: View {
	@Environment(\.dismiss) var dismiss
	var body: some View {
		NavigationStack {
			List {
				Section {
					InstructionRow(
						icon: "sun.max.fill",
						color: .orange,
						title: "1. Check Your Lighting",
						detail: "AI works best in bright, even lighting. Avoid dark rooms or heavy shadows for the best accuracy."
					)
					InstructionRow(
						icon: "arrow.up.and.down.and.arrow.left.and.right",
						color: .blue,
						title: "2. Adjust Your Distance",
						detail: "Try to keep the object centered and about 1-2 feet away. Too close or too far can make it harder to identify."
					)
					InstructionRow(
						icon: "camera.viewfinder",
						color: .purple,
						title: "3. Try Different Angles",
						detail: "If it's not working, move your phone! A top-down or side view might help the AI recognize the shape better."
					)
				} header: {
					Text("Optimization Tips")
				}
				
				Section {
					InstructionRow(
						icon: "hand.tap.fill",
						color: .green,
						title: "Verify Instantly",
						detail: "When you think you've found it, tap anywhere on the camera feed to start the analysis."
					)
					InstructionRow(
						icon: "eye",
						color: .blue,
						title: "Need a Hint?",
						detail: "Tap 'Show Answer' at the bottom to reveal the word and see an example sentence."
					)
				} header: {
					Text("How to Play")
				}
			}
			.navigationTitle("Scavenger Guide")
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
