import SwiftUI
import Foundation

@available(iOS 26.0, *)
struct QuizSessionView: View {
	
	@Binding var path: NavigationPath // 1. Add Binding
	
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

	// MARK: - Shared Gradient
private extension ShapeStyle where Self == LinearGradient {
	static var accentGradient: LinearGradient {
		LinearGradient(
			colors: [Color.orange.opacity(0.85), Color.blue.opacity(0.85)],
			startPoint: .topLeading,
			endPoint: .bottomTrailing
		)
	}
}

	// MARK: - Start View
@available(iOS 26.0, *)
private extension QuizSessionView {
	
	var startView: some View {
		ZStack {
				// Adaptive background
			Color(.systemGroupedBackground).ignoresSafeArea()
			
				// Ambient orbs — subtle in both light/dark
			GeometryReader { geo in
				ZStack {
					Circle()
						.fill(
							RadialGradient(
								colors: [Color.orange.opacity(0.12), .clear],
								center: .center, startRadius: 0, endRadius: 180
							)
						)
						.frame(width: 360, height: 360)
						.offset(x: geo.size.width * 0.55, y: -60)
						.blur(radius: 12)
					
					Circle()
						.fill(
							RadialGradient(
								colors: [Color.blue.opacity(0.10), .clear],
								center: .center, startRadius: 0, endRadius: 160
							)
						)
						.frame(width: 320, height: 320)
						.offset(x: -40, y: geo.size.height * 0.6)
						.blur(radius: 12)
				}
			}
			.ignoresSafeArea()
			.allowsHitTesting(false)
			
			VStack(spacing: 0) {
				
				Spacer()
				
					// Hero
				VStack(spacing: 14) {
					ZStack {
							// Soft gradient fill ring
						Circle()
							.fill(
								LinearGradient(
									colors: [Color.orange.opacity(0.10), Color.blue.opacity(0.08)],
									startPoint: .topLeading, endPoint: .bottomTrailing
								)
							)
							.frame(width: 84, height: 84)
						
							// Gradient stroke ring
						Circle()
							.strokeBorder(
								LinearGradient(
									colors: [Color.orange.opacity(0.45), Color.blue.opacity(0.35)],
									startPoint: .topLeading, endPoint: .bottomTrailing
								),
								lineWidth: 1
							)
							.frame(width: 84, height: 84)
						
						Image(systemName: "scope")
							.font(.system(size: 30, weight: .light))
							.foregroundStyle(
								LinearGradient(
									colors: [Color.orange, Color.blue],
									startPoint: .topLeading, endPoint: .bottomTrailing
								)
							)
							.symbolEffect(.pulse, options: .repeating)
					}
					
					VStack(spacing: 6) {
						Text("Scavenger Hunt")
							.font(.system(.title2, design: .rounded).bold())
							.foregroundStyle(.primary)
						
						Text(loading ? "Preparing your hunt…" : "Get ready to hunt for objects around you.")
							.font(.subheadline)
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.center)
							.padding(.horizontal, 32)
							.animation(.easeInOut, value: loading)
					}
				}
				.opacity(appeared ? 1 : 0)
				.offset(y: appeared ? 0 : 12)
				.animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appeared)
				
				Spacer()
				
					// Tips card
				VStack(spacing: 0) {
					tipRow(icon: "sun.max.fill", iconColor: .orange, text: "Point your camera at the object you're looking for.", isLast: false)
					tipRow(icon: "hand.tap.fill", iconColor: .blue, text: "Tap anywhere on screen to scan and identify it.", isLast: false)
					tipRow(icon: "cube.transparent", iconColor: Color(red: 0.45, green: 0.35, blue: 0.9), text: "Isolate one object at a time and in good lighting for best accuracy and try different angles.", isLast: true)
				}
				.background(Color(.secondarySystemGroupedBackground))
				.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
				.overlay(
					RoundedRectangle(cornerRadius: 18, style: .continuous)
						.strokeBorder(
							LinearGradient(
								colors: [
									Color.orange.opacity(0.25),
									Color.blue.opacity(0.15),
									Color.orange.opacity(0.08)
								],
								startPoint: .topLeading, endPoint: .bottomTrailing
							),
							lineWidth: 1
						)
				)
				.shadow(color: Color.orange.opacity(0.04), radius: 8, x: -2, y: 2)
				.shadow(color: Color.blue.opacity(0.04), radius: 8, x: 2, y: 4)
				.padding(.horizontal, 20)
				.opacity(appeared ? 1 : 0)
				.offset(y: appeared ? 0 : 10)
				.animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.12), value: appeared)
				
				Spacer()
				
					// Start button
				Button {
					UIImpactFeedbackGenerator(style: .medium).impactOccurred()
					showCamera = true
				} label: {
					ZStack {
						if loading {
							HStack(spacing: 10) {
								ProgressView().tint(.white).scaleEffect(0.85)
								Text("Preparing…").font(.headline).foregroundStyle(.white)
							}
						} else {
							HStack(spacing: 8) {
								Text("Start Hunt").font(.headline).foregroundStyle(.white)
								Image(systemName: "arrow.right.circle.fill")
									.font(.headline)
									.foregroundStyle(.white.opacity(0.85))
							}
						}
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, 18)
					.background(loading ? Color.secondary.opacity(0.3) : Color.blue)
					.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
					.shadow(color: loading ? .clear : Color.blue.opacity(0.22), radius: 10, x: 0, y: 5)
				}
				.disabled(loading)
				.padding(.horizontal, 20)
				.opacity(appeared ? 1 : 0)
				.animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.18), value: appeared)
			}
		}
		.navigationBarBackButtonHidden(true)
		.toolbar {
			ToolbarItem(placement: .topBarLeading) {
				Button {
					NotificationCenter.default.post(name: .init("dismissToRoot"), object: nil)
				} label: {
					HStack(spacing: 4) {
						Image(systemName: "chevron.left")
						Text("Home")
					}
				}
			}
		}
		.onAppear { withAnimation { appeared = true } }
		.onDisappear { appeared = false }
	}
	
	func tipRow(icon: String, iconColor: Color, text: String, isLast: Bool) -> some View {
		VStack(spacing: 0) {
			HStack(spacing: 14) {
				ZStack {
					RoundedRectangle(cornerRadius: 8, style: .continuous)
						.fill(iconColor.opacity(0.10))
						.frame(width: 30, height: 30)
					
					Image(systemName: icon)
						.font(.system(size: 14, weight: .semibold))
						.foregroundStyle(iconColor)
				}
				
				Text(text)
					.font(.system(.subheadline, design: .rounded))
					.foregroundStyle(.primary)
					.fixedSize(horizontal: false, vertical: true)
				
				Spacer()
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 14)
			
			if !isLast {
				Divider()
					.padding(.leading, 60)
					.opacity(0.5)
			}
		}
	}
}

	// MARK: - Empty View
@available(iOS 26.0, *)
private extension QuizSessionView {
	
	var emptyView: some View {
		VStack(spacing: 20) {
			ZStack {
				Circle()
					.fill(
						LinearGradient(
							colors: [Color.orange.opacity(0.08), Color.blue.opacity(0.06)],
							startPoint: .topLeading, endPoint: .bottomTrailing
						)
					)
					.frame(width: 80, height: 80)
				
				Circle()
					.strokeBorder(
						LinearGradient(
							colors: [Color.orange.opacity(0.2), Color.blue.opacity(0.15)],
							startPoint: .topLeading, endPoint: .bottomTrailing
						),
						lineWidth: 1
					)
					.frame(width: 80, height: 80)
				
				Image(systemName: "tray.fill")
					.font(.system(size: 28, weight: .light))
					.foregroundStyle(.secondary)
			}
			
			VStack(spacing: 6) {
				Text("Nothing to Hunt")
					.font(.system(.headline, design: .rounded).bold())
					.foregroundStyle(.primary)
				
				Text("Scan and select some objects first\nto build your session.")
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}
			
			Button("Go Back") { dismiss() }
				.font(.subheadline.bold())
				.foregroundStyle(.blue)
				.padding(.top, 4)
		}
		.padding(32)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color(.systemGroupedBackground))
	}
}

	// MARK: - Completion View
@available(iOS 26.0, *)
private extension QuizSessionView {
	
	var completionView: some View {
		ZStack {
			Color(.systemGroupedBackground).ignoresSafeArea()
			
				// Ambient orbs
			GeometryReader { geo in
				ZStack {
					Circle()
						.fill(
							RadialGradient(
								colors: [Color.orange.opacity(0.10), .clear],
								center: .center, startRadius: 0, endRadius: 200
							)
						)
						.frame(width: 400, height: 400)
						.offset(x: geo.size.width * 0.5, y: -80)
						.blur(radius: 14)
					
					Circle()
						.fill(
							RadialGradient(
								colors: [Color.blue.opacity(0.09), .clear],
								center: .center, startRadius: 0, endRadius: 160
							)
						)
						.frame(width: 320, height: 320)
						.offset(x: -30, y: geo.size.height * 0.65)
						.blur(radius: 12)
				}
			}
			.ignoresSafeArea()
			.allowsHitTesting(false)
			
			VStack(spacing: 0) {
				
				Spacer()
				
					// Score card
				VStack(spacing: 20) {
						// Emoji in gradient ring
					ZStack {
						Circle()
							.fill(
								LinearGradient(
									colors: [Color.orange.opacity(0.09), Color.blue.opacity(0.07)],
									startPoint: .topLeading, endPoint: .bottomTrailing
								)
							)
							.frame(width: 88, height: 88)
						
						Circle()
							.strokeBorder(
								LinearGradient(
									colors: [Color.orange.opacity(0.35), Color.blue.opacity(0.25)],
									startPoint: .topLeading, endPoint: .bottomTrailing
								),
								lineWidth: 1
							)
							.frame(width: 88, height: 88)
						
						Text(scoreEmoji)
							.font(.system(size: 40))
					}
					
					VStack(spacing: 6) {
						Text("Hunt Complete")
							.font(.system(.title2, design: .rounded).bold())
							.foregroundStyle(.primary)
						
						Text(performanceLabel)
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
					
						// Score number with gradient
					VStack(spacing: 4) {
						Text("\(score) / \(quizzes.count)")
							.font(.system(size: 54, weight: .bold, design: .rounded))
							.foregroundStyle(
								LinearGradient(
									colors: [.orange, .blue],
									startPoint: .leading, endPoint: .trailing
								)
							)
							.contentTransition(.numericText())
						
						Text("Correct")
							.font(.system(.caption, design: .rounded).bold())
							.foregroundStyle(.secondary)
							.textCase(.uppercase)
							.tracking(1.5)
					}
					
						// Progress bar
					GeometryReader { geo in
						ZStack(alignment: .leading) {
							Capsule()
								.fill(Color(.systemFill))
								.frame(height: 6)
							
							Capsule()
								.fill(
									LinearGradient(
										colors: [.orange, .blue],
										startPoint: .leading, endPoint: .trailing
									)
								)
								.frame(width: geo.size.width * scorePercent, height: 6)
								.animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.3), value: showCompletion)
						}
					}
					.frame(height: 6)
				}
				.frame(maxWidth: .infinity)
				.padding(24)
				.background(Color(.secondarySystemGroupedBackground))
				.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
				.overlay(
					RoundedRectangle(cornerRadius: 24, style: .continuous)
						.strokeBorder(
							LinearGradient(
								colors: [
									Color.orange.opacity(0.30),
									Color.blue.opacity(0.20),
									Color.orange.opacity(0.06)
								],
								startPoint: .topLeading, endPoint: .bottomTrailing
							),
							lineWidth: 1
						)
				)
				.shadow(color: Color.orange.opacity(0.05), radius: 10, x: -2, y: 2)
				.shadow(color: Color.blue.opacity(0.05), radius: 10, x: 2, y: 6)
				.padding(.horizontal, 20)
				
				Spacer()
				
					// Results list
				VStack(alignment: .leading, spacing: 10) {
					HStack {
						Text("Results")
							.font(.system(.footnote, design: .rounded).bold())
							.foregroundStyle(.secondary)
							.textCase(.uppercase)
							.tracking(1)
						
						Spacer()
						
						Text("\(score) correct")
							.font(.system(.caption, design: .rounded).bold())
							.foregroundStyle(
								LinearGradient(
									colors: [.orange, .blue],
									startPoint: .leading, endPoint: .trailing
								)
							)
							.padding(.horizontal, 10)
							.padding(.vertical, 4)
							.background(
								Capsule()
									.fill(
										LinearGradient(
											colors: [Color.orange.opacity(0.10), Color.blue.opacity(0.08)],
											startPoint: .leading, endPoint: .trailing
										)
									)
									.overlay(
										Capsule().strokeBorder(
											LinearGradient(
												colors: [Color.orange.opacity(0.2), Color.blue.opacity(0.15)],
												startPoint: .leading, endPoint: .trailing
											),
											lineWidth: 0.5
										)
									)
							)
					}
					.padding(.horizontal, 20)
					
					ScrollView(showsIndicators: false) {
						VStack(spacing: 0) {
							ForEach(Array(quizzes.enumerated()), id: \.offset) { index, quiz in
								VStack(spacing: 0) {
									HStack(spacing: 14) {
										Text("\(index + 1)")
											.font(.system(.footnote, design: .monospaced))
											.foregroundStyle(.quaternary)
											.frame(width: 22, alignment: .trailing)
										
										Text(quiz.correctEnglish.capitalized)
											.font(.system(.body, design: .rounded).weight(.medium))
											.foregroundStyle(.primary)
										
										Spacer()
										
										if index < score {
											Image(systemName: "checkmark.circle.fill")
												.font(.subheadline)
												.foregroundStyle(Color.green)
										} else {
											Image(systemName: "circle")
												.font(.subheadline)
												.foregroundStyle(Color(.quaternaryLabel))
										}
									}
									.padding(.horizontal, 16)
									.padding(.vertical, 13)
									
									if index < quizzes.count - 1 {
										Divider()
											.padding(.leading, 52)
											.opacity(0.45)
									}
								}
							}
						}
						.background(Color(.secondarySystemGroupedBackground))
						.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
						.overlay(
							RoundedRectangle(cornerRadius: 16, style: .continuous)
								.strokeBorder(
									LinearGradient(
										colors: [
											Color.orange.opacity(0.18),
											Color.blue.opacity(0.12),
											Color.orange.opacity(0.05)
										],
										startPoint: .topLeading, endPoint: .bottomTrailing
									),
									lineWidth: 0.75
								)
						)
						.padding(.horizontal, 20)
					}
				}
				
				Spacer()
				
					// Done button
				Button {
					path = NavigationPath()
				} label: {
					Text("Done")
						.font(.headline)
						.foregroundStyle(.white)
						.frame(maxWidth: .infinity)
						.padding(.vertical, 18)
						.background(Color.blue)
						.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
						.shadow(color: Color.blue.opacity(0.22), radius: 10, x: 0, y: 5)
				}
				.padding(.horizontal, 20)
			}
		}
		.navigationBarBackButtonHidden(true)
		.toolbar {
			ToolbarItem(placement: .topBarLeading) {
				Button {
					NotificationCenter.default.post(name: .init("dismissToRoot"), object: nil)
				} label: {
					HStack(spacing: 4) {
						Image(systemName: "chevron.left")
						Text("Home")
					}
				}
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
	
	var scoreEmoji: String {
		if scorePercent == 1.0 { return "🏆" }
		if scorePercent >= 0.7 { return "🎯" }
		if scorePercent >= 0.4 { return "💪" }
		return "🔁"
	}
	
	var scoreColor: Color {
		if scorePercent == 1.0 { return .orange }
		if scorePercent >= 0.7 { return .green }
		if scorePercent >= 0.4 { return .blue }
		return Color(red: 0.55, green: 0.4, blue: 0.9)
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
