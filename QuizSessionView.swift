import SwiftUI
import Foundation

@available(iOS 26.0, *)
struct QuizSessionView: View {
	
	@Environment(\.dismiss) private var dismiss
	
	let objects: [String]
	
	@State private var quizzes: [FoundationAIService.QuizResult] = []
	@State private var score: Int = 0
	@State private var loading = true
	@State private var showCamera = false
	@State private var showCompletion = false
	@State private var appeared = false
	
	private let aiService = FoundationAIService()
	
	var body: some View {
		Group {
			if showCompletion {
				completionView
			} else if quizzes.isEmpty && !loading {
				emptyView
			} else {
				startView
			}
		}
		.task(id: objects) {
			await loadQuiz()
		}
		.fullScreenCover(isPresented: $showCamera) {
			QuizCameraView(quizzes: quizzes) { finalScore in
				score = finalScore
				showCompletion = true
				showCamera = false
			}
		}
	}
}

	// MARK: - Start View
@available(iOS 26.0, *)
private extension QuizSessionView {
	
	var startView: some View {
		ZStack {
			Color(.systemGroupedBackground).ignoresSafeArea()
			
			VStack(spacing: 0) {
				
				Spacer()
				
					// Hero
				VStack(spacing: 10) {
					Image(systemName: "scope")
						.font(.system(size: 40, weight: .ultraLight))
						.foregroundStyle(
							LinearGradient(colors: [.orange, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
						)
						.symbolEffect(.pulse, options: .repeating)
					
					Text("Scavenger Hunt")
						.font(.system(.title2, design: .rounded).bold())
					
					Text(loading ? "Preparing your hunt…" : "Get ready to hunt for objects around you.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.center)
						.padding(.horizontal, 32)
						.animation(.easeInOut, value: loading)
				}
				.opacity(appeared ? 1 : 0)
				.offset(y: appeared ? 0 : 10)
				.animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appeared)
				
				Spacer()
				
					// Tips card
				VStack(spacing: 0) {
					tipRow(icon: "camera.viewfinder", text: "Point your camera at the object you're looking for.", isLast: false)
					tipRow(icon: "hand.tap.fill", text: "Tap anywhere on screen to scan and identify it.", isLast: false)
					tipRow(icon: "cube.transparent", text: "Isolate one object at a time and in good lighting for best accuracy and try different angles.", isLast: true)
				}
				.background(Color(.secondarySystemGroupedBackground))
				.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
				.padding(.horizontal, 20)
				.opacity(appeared ? 1 : 0)
				.offset(y: appeared ? 0 : 8)
				.animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.12), value: appeared)
				
				Spacer()
				
					// Start button
				Button {
					UIImpactFeedbackGenerator(style: .medium).impactOccurred()
					showCamera = true
				} label: {
					HStack(spacing: 8) {
						if loading {
							ProgressView()
								.tint(.white)
								.scaleEffect(0.8)
						}
						Text(loading ? "Preparing…" : "Start Hunt")
							.font(.headline)
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, 17)
					.background(loading ? Color.secondary.opacity(0.35) : Color.blue)
					.foregroundColor(.white)
					.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
				}
				.disabled(loading)
				.padding(.horizontal, 20)
				.opacity(appeared ? 1 : 0)
				.animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.18), value: appeared)
			}
		}
		.onAppear {
			withAnimation { appeared = true }
		}
		.onDisappear { appeared = false }
	}
	
	func tipRow(icon: String, text: String, isLast: Bool) -> some View {
		VStack(spacing: 0) {
			HStack(spacing: 14) {
				Image(systemName: icon)
					.font(.system(size: 15, weight: .medium))
					.foregroundStyle(.blue)
					.frame(width: 28)
				
				Text(text)
					.font(.system(.subheadline, design: .rounded))
					.foregroundStyle(.primary)
					.fixedSize(horizontal: false, vertical: true)
				
				Spacer()
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 14)
			
			if !isLast {
				Divider().padding(.leading, 58)
			}
		}
	}
}

	// MARK: - Empty View
@available(iOS 26.0, *)
private extension QuizSessionView {
	
	var emptyView: some View {
		VStack(spacing: 16) {
			Image(systemName: "tray.fill")
				.font(.system(size: 44))
				.foregroundStyle(.secondary)
			
			VStack(spacing: 6) {
				Text("Nothing to Hunt")
					.font(.system(.headline, design: .rounded))
				Text("Scan and select some objects first\nto build your session.")
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}
			
			Button("Go Back") { dismiss() }
				.font(.subheadline.bold())
				.padding(.top, 4)
		}
		.padding(32)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color(.systemBackground))
	}
}

	// MARK: - Completion View
@available(iOS 26.0, *)
private extension QuizSessionView {
	
	var completionView: some View {
		ZStack {
			Color(.systemGroupedBackground).ignoresSafeArea()
			
			VStack(spacing: 0) {
				
				Spacer()
				
					// Score card
				VStack(spacing: 16) {
					Image(systemName: scoreIcon)
						.font(.system(size: 48, weight: .light))
						.foregroundStyle(scoreColor)
						.symbolEffect(.bounce, value: showCompletion)
					
					VStack(spacing: 6) {
						Text("Hunt Complete")
							.font(.system(.title2, design: .rounded).bold())
						
						Text(performanceLabel)
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
					
					VStack(spacing: 4) {
						Text("\(score) / \(quizzes.count)")
							.font(.system(size: 52, weight: .bold, design: .rounded))
							.foregroundStyle(scoreColor)
							.contentTransition(.numericText())
						
						Text("Correct")
							.font(.system(.caption, design: .rounded).bold())
							.foregroundStyle(.secondary)
							.textCase(.uppercase)
					}
					
					GeometryReader { geo in
						ZStack(alignment: .leading) {
							RoundedRectangle(cornerRadius: 5)
								.fill(Color(.systemFill))
								.frame(height: 6)
							RoundedRectangle(cornerRadius: 5)
								.fill(
									LinearGradient(
										colors: [.orange, scoreColor],
										startPoint: .leading,
										endPoint: .trailing
									)
								)
								.frame(width: geo.size.width * scorePercent, height: 6)
								.animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.3), value: showCompletion)
						}
					}
					.frame(height: 6)
				}
				.frame(maxWidth: .infinity)
				.padding(28)
				.background(Color(.secondarySystemGroupedBackground))
				.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
				.overlay(
					RoundedRectangle(cornerRadius: 24, style: .continuous)
						.stroke(scoreColor.opacity(0.18), lineWidth: 1)
				)
				.padding(.horizontal, 20)
				
				Spacer()
				
					// Results list
				VStack(alignment: .leading, spacing: 10) {
					Text("Results")
						.font(.system(.footnote, design: .rounded).bold())
						.foregroundStyle(.secondary)
						.textCase(.uppercase)
						.padding(.horizontal, 20)
					
					ScrollView(showsIndicators: false) {
						VStack(spacing: 0) {
							ForEach(Array(quizzes.enumerated()), id: \.offset) { index, quiz in
								VStack(spacing: 0) {
									HStack(spacing: 14) {
										Text("\(index + 1)")
											.font(.system(.footnote, design: .monospaced))
											.foregroundStyle(.tertiary)
											.frame(width: 22, alignment: .trailing)
										
										Text(quiz.correctEnglish.capitalized)
											.font(.system(.body, design: .rounded).weight(.medium))
											.foregroundStyle(.primary)
										
										Spacer()
										
										Image(systemName: index < score ? "checkmark.circle.fill" : "circle")
											.font(.subheadline)
											.foregroundStyle(index < score ? Color.green : Color(.quaternaryLabel))
									}
									.padding(.horizontal, 16)
									.padding(.vertical, 13)
									
									if index < quizzes.count - 1 {
										Divider().padding(.leading, 52)
									}
								}
							}
						}
						.background(Color(.secondarySystemGroupedBackground))
						.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
						.padding(.horizontal, 20)
					}
				}
				
				Spacer()
				
				Button {
					UIImpactFeedbackGenerator(style: .medium).impactOccurred()
					dismiss()
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
						NotificationCenter.default.post(name: .init("dismissToRoot"), object: nil)
					}
				} label: {
					Text("Done")
						.font(.headline)
						.frame(maxWidth: .infinity)
						.padding(.vertical, 17)
						.background(Color.blue)
						.foregroundColor(.white)
						.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
				}
				.padding(.horizontal, 20)
			}
		}
	}
}

	// MARK: - Score Helpers
@available(iOS 26.0, *)
private extension QuizSessionView {
	
	var scorePercent: Double {
		guard quizzes.count > 0 else { return 0 }
		return Double(score) / Double(quizzes.count)
	}
	
	var scoreIcon: String {
		if scorePercent == 1.0 { return "star.fill" }
		if scorePercent >= 0.7 { return "checkmark.circle.fill" }
		return "circle"
	}
	
	var scoreColor: Color {
		if scorePercent == 1.0 { return .orange }
		if scorePercent >= 0.7 { return .green }
		return .secondary
	}
	
	var performanceLabel: String {
		if scorePercent == 1.0 { return "Perfect score. Impressive." }
		if scorePercent >= 0.7 { return "Great work. Keep it up." }
		if scorePercent >= 0.4 { return "Good effort. Try again to improve." }
		return "Keep practising. You'll get there."
	}
}

	// MARK: - Load Quiz Logic
@available(iOS 26.0, *)
private extension QuizSessionView {
	
	func loadQuiz() async {
		loading = true
		
		let cleanObjects = objects
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
		
		let aiResults = await aiService.generateQuizSession(from: cleanObjects)
		
		let existingEnglish = Set(aiResults.map { $0.correctEnglish.lowercased() })
		
		var finalQuiz = aiResults
		
		for object in cleanObjects {
			if !existingEnglish.contains(object.lowercased()) {
				finalQuiz.append(
					FoundationAIService.QuizResult(
						translatedWord: object,
						correctEnglish: object
					)
				)
			}
		}
		
		await MainActor.run {
			self.quizzes = finalQuiz.shuffled()
			self.score = 0
			self.loading = false
		}
	}
}
