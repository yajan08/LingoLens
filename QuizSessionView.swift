import SwiftUI
import Foundation

@available(iOS 26.0, *)
struct QuizSessionView: View {
	
	@Environment(\.dismiss) private var dismiss
	
	let objects: [String]
	
		// 1. Update the type to the unified FoundationAIService result
	@State private var quizzes: [FoundationAIService.QuizResult] = []
	@State private var score: Int = 0
	
	@State private var loading = true
	@State private var showCamera = false
	@State private var showCompletion = false
	
		// 2. Use the unified FoundationAIService
	private let aiService = FoundationAIService()
	
	var body: some View {
		Group {
			if loading {
				loadingView
			}
			else if quizzes.isEmpty {
				emptyView
			}
			else if showCompletion {
				completionView
			}
			else {
				startView
			}
		}
		.task(id: objects) {
			await loadQuiz()
		}
		.fullScreenCover(isPresented: $showCamera) {
				// 3. Quizzes now correctly match the expected type in QuizCameraView
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
		VStack(spacing: 24) {
			Spacer()
			
			Image(systemName: "camera.viewfinder")
				.font(.system(size: 56))
				.foregroundColor(.secondary)
			
			Text("Scavenger Hunt")
				.font(.title.bold())
			
			Text("\(quizzes.count) objects to find")
				.font(.subheadline)
				.foregroundColor(.secondary)
			
			Spacer()
			
			Button {
				showCamera = true
			} label: {
				Text("Start")
					.font(.headline)
					.frame(maxWidth: .infinity)
					.padding()
					.background(Color.blue)
					.foregroundColor(.white)
					.cornerRadius(12)
			}
		}
		.padding(24)
	}
}

	// MARK: - Loading View
@available(iOS 26.0, *)
private extension QuizSessionView {
	var loadingView: some View {
		VStack(spacing: 16) {
			ProgressView()
				.controlSize(.large)
			Text("Preparing Your Hunt...")
				.font(.headline)
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}

	// MARK: - Empty View
@available(iOS 26.0, *)
private extension QuizSessionView {
	var emptyView: some View {
		VStack(spacing: 12) {
			Image(systemName: "tray")
				.font(.system(size: 40))
				.foregroundColor(.secondary)
			
			Text("No hunt available")
				.font(.headline)
			
			Text("Scan objects first to build a session.")
				.font(.subheadline)
				.foregroundColor(.secondary)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}

	// MARK: - Completion View
@available(iOS 26.0, *)
private extension QuizSessionView {
	var completionView: some View {
		VStack(spacing: 24) {
			Spacer()
			
			Image(systemName: scoreIcon)
				.font(.system(size: 56))
				.foregroundColor(scoreColor)
			
			Text("Hunt Complete")
				.font(.title.bold())
			
			VStack(spacing: 4) {
				Text("\(score) / \(quizzes.count)")
					.font(.system(size: 64, weight: .bold, design: .rounded))
				Text("Correct matches")
					.font(.caption.bold())
					.foregroundStyle(.secondary)
					.textCase(.uppercase)
			}
			
			Spacer()
			
			Button {
				dismiss()
			} label: {
				Text("Done")
					.font(.headline)
					.frame(maxWidth: .infinity)
					.padding()
					.background(Color.blue)
					.foregroundColor(.white)
					.cornerRadius(12)
			}
		}
		.padding(24)
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
		if scorePercent == 1.0 { return .yellow }
		if scorePercent >= 0.7 { return .green }
		return .secondary
	}
}

	// MARK: - Load Quiz Logic
@available(iOS 26.0, *)
private extension QuizSessionView {

	func loadQuiz() async {
		
		loading = true
		
			// Clean objects
		let cleanObjects = objects
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
		
			// Get AI results
		let aiResults = await aiService.generateQuizSession(from: cleanObjects)
		
			// Build lookup of English words already present
		let existingEnglish = Set(
			aiResults.map { $0.correctEnglish.lowercased() }
		)
		
		var finalQuiz = aiResults
		
			// Add fallback entries for missing objects
		for object in cleanObjects {
			
			if !existingEnglish.contains(object.lowercased()) {
				
				finalQuiz.append(
					FoundationAIService.QuizResult(
						translatedWord: object,      // fallback uses same word
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
	
		//	func loadQuiz() async {
//		loading = true
//		
//			// 4. Call the new unified aiService
//		let result = await aiService.generateQuizSession(from: objects)
//		
//		await MainActor.run {
//			self.quizzes = result
//			self.score = 0
//			self.loading = false
//		}
//	}
}
