import SwiftUI
import Vision

	/// Camera-based view that guides the user through identifying each quiz object in real life.
@available(iOS 26.0, *)
struct QuizCameraView: View {
	let quizzes: [FoundationAIService.QuizResult]
	let onFinished: (Int) -> Void
	
	@StateObject private var cameraService = CameraService()
	@State private var detector = ObjectDetector()
	
	@State private var latestPixelBuffer: CVPixelBuffer?
	@State private var currentIndex: Int = 0
	@State private var score: Int = 0
	@State private var activeQuiz: FoundationAIService.QuizResult? = nil
	
	@State private var isDetecting = false
	@State private var showAnswer = false
	@State private var showHelp = false
	@State private var detectionStatus: DetectionStatus = .ready
	@State private var detectionLocked = false
	@State private var pulseScale: CGFloat = 1.0
	
	@State private var showSentenceHint = false
	@State private var hintSentence: FoundationAIService.BilingualSentence? = nil
	@State private var isLoadingHint = false
	
	@State private var successSentence: FoundationAIService.BilingualSentence? = nil
	@State private var isLoadingSuccessSentence = false
	
	@State private var revealedSentence: FoundationAIService.BilingualSentence? = nil
	@State private var isLoadingRevealedSentence = false
	
	private let aiService = FoundationAIService()
	
	enum DetectionStatus {
		case ready, detecting, success, failure
	}
	
	@Environment(\.dismiss) private var dismiss
	private let impact = UIImpactFeedbackGenerator(style: .medium)
	private let notification = UINotificationFeedbackGenerator()
	
	var body: some View {
		NavigationStack {
			ZStack {
				CameraPreview(session: cameraService.session)
					.ignoresSafeArea()
				
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
				
				if let quiz = activeQuiz {
					hudLayer(quiz: quiz)
				}
				
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
						.foregroundStyle(.primary.opacity(0.8))
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
				if !showAnswer {
					attemptDetection()
				}
			}
		}
	}
	
		/// The full camera HUD rendered from a stable quiz snapshot to avoid stale state during async ops.
	@ViewBuilder
	func hudLayer(quiz: FoundationAIService.QuizResult) -> some View {
		VStack(spacing: 0) {
			targetWordBanner(quiz: quiz)
				.padding(.top, 12)
			
			Spacer()
			
			if showAnswer && detectionStatus != .success {
				revealedAnswerCard(quiz: quiz)
					.transition(.move(edge: .bottom).combined(with: .opacity))
					.padding(.bottom, 12)
			}
			
			if detectionStatus == .failure {
				failureToast
					.transition(.move(edge: .top).combined(with: .opacity))
					.padding(.bottom, 12)
			}
			
			if detectionStatus == .success {
				successMatchCard(quiz: quiz)
					.transition(.scale(scale: 0.9).combined(with: .opacity))
					.padding(.bottom, 12)
			}
			
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

@available(iOS 26.0, *)
private extension QuizCameraView {
	
		/// Wires up the camera frame handler and Vision prediction callback.
	func setupDetector() {
		cameraService.frameHandler = { buffer in
			self.latestPixelBuffer = buffer
		}
		detector.onPredictions = { [self] observations in
			guard isDetecting, let quiz = activeQuiz else { return }
			let labels = observations.map { $0.identifier.lowercased() }
			let target = quiz.correctEnglish
				.replacingOccurrences(of: "_", with: " ")
				.lowercased()
			let isMatch = labels.contains {
				$0.contains(target) || target.contains($0)
			}
			finalizeDetection(isMatch: isMatch)
		}
	}
	
		/// Triggers a Vision scan on the latest camera frame.
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
	
		/// Applies the detection result and updates UI state accordingly.
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
	
		/// Advances to the next quiz object, or finishes the session if all objects are done.
	func nextObject() {
		let nextIndex = currentIndex + 1
		if nextIndex >= quizzes.count {
			onFinished(score)
		} else {
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
	
		/// Loads an AI-generated bilingual example sentence for the hint sheet.
	func loadHintSentence() {
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
				guard currentIndex == capturedIndex else { return }
				hintSentence = result
				isLoadingHint = false
			}
		}
	}
	
		/// Loads a bilingual sentence to show after a successful object match.
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
	
		/// Loads a bilingual sentence to show when the user reveals the answer.
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
	
		/// Replaces underscores with spaces for display purposes.
	func display(_ raw: String) -> String {
		raw.replacingOccurrences(of: "_", with: " ")
	}
}

@available(iOS 26.0, *)
private extension QuizCameraView {
	
		/// Banner showing the current target word and a hint button.
	func targetWordBanner(quiz: FoundationAIService.QuizResult) -> some View {
		HStack(spacing: 12) {
			VStack(alignment: .leading, spacing: 2) {
				Text("FIND THE OBJECT")
					.font(.system(size: 9, weight: .black))
					.foregroundStyle(.primary.opacity(0.45))
					.tracking(1.4)
				Text(display(quiz.translatedWord).uppercased())
					.font(.system(.title3, design: .rounded).bold())
					.foregroundStyle(.primary)
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
							.tint(.primary)
							.controlSize(.mini)
							.frame(width: 32, height: 32)
					} else {
						Image(systemName: "info")
							.font(.system(size: 12, weight: .medium))
							.foregroundStyle(.foreground)
							.frame(width: 32, height: 32)
					}
				}
				.background(.regularMaterial.opacity(0.3), in: Circle())
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
		.contentShape(RoundedRectangle(cornerRadius: 18))
		.onTapGesture {
			loadHintSentence()
		}
		.padding(.horizontal, 16)
		.shadow(color: .black.opacity(0.18), radius: 10, y: 4)
	}
	
		/// Pulsing label prompting the user to tap and scan.
	var tapToDetectLabel: some View {
		VStack(spacing: 6) {
			HStack(spacing: 7) {
				Image(systemName: "hand.tap.fill")
					.font(.system(size: 13))
				Text("Tap anywhere to scan")
					.font(.system(.subheadline, design: .rounded).bold())
			}
			.foregroundStyle(.primary)
			Text("Point camera at the object")
				.font(.system(.caption, design: .rounded))
				.foregroundStyle(.primary.opacity(0.55))
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
	
		/// Small toast shown when the scanned object didn't match the target.
	var failureToast: some View {
		HStack(spacing: 8) {
			Image(systemName: "xmark.circle.fill")
				.font(.system(size: 13))
				.foregroundStyle(.red.opacity(0.85))
			Text("No match — try a different angle")
				.font(.system(.subheadline, design: .rounded).bold())
				.foregroundStyle(.primary)
		}
		.padding(.horizontal, 18)
		.padding(.vertical, 11)
		.background(.ultraThinMaterial, in: Capsule())
		.overlay(Capsule().strokeBorder(.red.opacity(0.25), lineWidth: 1))
	}
	
		/// Card shown when the user chooses to reveal the answer without finding the object.
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
			
			if isLoadingRevealedSentence {
				HStack(spacing: 7) {
					ProgressView().controlSize(.mini)
					Text("Loading example...")
						.font(.system(.caption, design: .rounded))
						.foregroundStyle(.secondary)
				}
			} else if let s = revealedSentence {
				VStack(spacing: 8) {
					Divider().overlay(.primary.opacity(0.1))
					sentenceCards(sentence: s)
				}
			}
		}
		.padding(.vertical, 18)
		.padding(.horizontal, 20)
		.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: 24, style: .continuous)
				.strokeBorder(.primary.opacity(0.09), lineWidth: 1)
		)
		.padding(.horizontal, 20)
	}
	
		/// Card shown after a successful match, with the word pair and an example sentence.
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
					Divider().overlay(.primary.opacity(0.1))
					sentenceCards(sentence: s)
				}
			}
		}
		.padding(.vertical, 18)
		.padding(.horizontal, 20)
		.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: 24, style: .continuous)
				.strokeBorder(.primary.opacity(0.09), lineWidth: 1)
		)
		.padding(.horizontal, 20)
	}
	
		/// Reusable bilingual sentence display used in both success and revealed answer cards.
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
	
		/// Bottom area with a combined Show Answer / Continue Hunt button.
	var bottomActionArea: some View {
		VStack(spacing: 12) {
			let isComplete = detectionStatus == .success || showAnswer
			
			Button {
				if isComplete {
					nextObject()
				} else {
					withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
						showAnswer = true
					}
					impact.impactOccurred()
					loadRevealedSentence()
				}
			} label: {
				HStack(spacing: 8) {
					Image(systemName: isComplete ? "arrow.right.circle.fill" : "eye")
						.font(.system(size: 16, weight: .semibold))
					
					Text(isComplete ? "Continue Hunt" : "Show Answer")
						.font(.system(.headline, design: .rounded).bold())
				}
				.frame(maxWidth: .infinity)
				.padding(.vertical, 17)
				.background(isComplete ? Color.blue : Color.primary.opacity(0.1), in: Capsule())
				.background(isComplete ? .thinMaterial : .ultraThinMaterial, in: Capsule())
				.foregroundStyle(.white)
				.overlay(
					Capsule()
						.strokeBorder(
							LinearGradient(
								colors: [.blue.opacity(0.35), .orange.opacity(0.25)],
								startPoint: .leading,
								endPoint: .trailing
							),
							lineWidth: 1
						)
				)
			}
			.animation(.spring(response: 0.35), value: isComplete)
		}
	}
	
		/// Full-screen overlay shown while Vision is analyzing the camera frame.
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
						.tint(.primary)
						.controlSize(.regular)
				}
				VStack(spacing: 4) {
					Text("Analyzing Environment")
						.font(.system(.subheadline, design: .rounded).bold())
						.foregroundStyle(.primary)
					Text("Looking for a match...")
						.font(.system(.caption, design: .rounded))
						.foregroundStyle(.primary.opacity(0.6))
				}
			}
			.padding(28)
			.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 24, style: .continuous)
					.strokeBorder(.primary.opacity(0.08), lineWidth: 1)
			)
		}
	}
}

	/// Sheet showing a bilingual example sentence as a hint for the current target word.
@available(iOS 26.0, *)
struct SentenceHintSheet: View {
	
	let quiz: FoundationAIService.QuizResult
	let sentence: FoundationAIService.BilingualSentence?
	let isLoading: Bool
	let revealAnswer: Bool
	
	@Environment(\.dismiss) private var dismiss
	private let speech = SpeechService.shared
	
		/// Replaces underscores with spaces for display purposes.
	func display(_ raw: String) -> String {
		raw.replacingOccurrences(of: "_", with: " ")
	}
	
	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				
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
								.lineLimit(1)
								.minimumScaleFactor(0.5)
								.allowsTightening(true)
							
							Button {
								speech.speak(display(quiz.translatedWord))
							} label: {
								Image(systemName: "speaker.wave.2.fill")
									.font(.system(size: 16, weight: .semibold))
									.symbolRenderingMode(.hierarchical)
							}
						}
						.padding(.horizontal, 20)
						
						if revealAnswer {
							HStack(spacing: 6) {
								Image(systemName: "textformat.abc")
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
								}
								
								VStack(alignment: .leading, spacing: 6) {
									HStack {
										Label("Translated", systemImage: "character.bubble.fill")
											.font(.system(size: 11, weight: .bold))
											.foregroundStyle(.blue)
										
										Spacer()
										
										if let s = sentence {
											Button {
												speech.speak(s.translated)
											} label: {
												Image(systemName: "speaker.wave.2.fill")
													.font(.system(size: 15, weight: .semibold))
													.symbolRenderingMode(.hierarchical)
													.foregroundStyle(.blue)
											}
										}
									}
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

	/// Sheet showing quick tips for how to use the scavenger hunt camera.
struct InstructionsSheet: View {
	@Environment(\.dismiss) var dismiss
	var body: some View {
		NavigationStack {
			List {
				Section {
					InstructionRow(
						icon: "sun.max.fill",
						color: .orange,
						title: "Accuracy",
						detail: "Scan in bright light, stay about 1–2 feet away and center the object"
					)
					
					InstructionRow(
						icon: "camera.rotate",
						color: .purple,
						title: "Try Angles",
						detail: "Move around the object and try multiple angles if detection fails."
					)
					
					InstructionRow(
						icon: "hand.tap.fill",
						color: .green,
						title: "Can't Find It?",
						detail: "Tap Show Answer to continue, lighting, clutter, or object type may affect results.."
					)
					
				} header: {
					Text("Quick Guide")
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
