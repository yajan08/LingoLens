import Foundation
import FoundationModels
import SwiftUI
import Combine

@available(iOS 26.0, *)
final actor FoundationAIService: ObservableObject {
	
		// MARK: - Model
	private let model = SystemLanguageModel.default
	
	@AppStorage("selected_language")
	private var selectedLanguageRaw = AppLanguage.french.rawValue
	
		// Using a shared session for most tasks, but we'll use local ones for generation
		// to avoid "Context Contamination" which often triggers safety guardrails.
	private var sharedSession: LanguageModelSession?
	
		// MARK: - Models
	struct QuizResult: Identifiable, Sendable {
		let id = UUID()
		let translatedWord: String
		let correctEnglish: String
	}
	
	struct BilingualSentence: Sendable {
		let english: String
		let translated: String
	}
	
		// MARK: - PREWARM
	nonisolated func prewarm() {
		Task.detached(priority: .utility) {
			guard SystemLanguageModel.default.isAvailable else { return }
				// Warming up the system intelligence
			let _ = LanguageModelSession()
		}
	}
	
		// MARK: - Object Filtering
	func filterObjects(from predictions: [String]) async -> [String] {
		guard model.isAvailable else { return [] }
		

		let prompt = """
	Analyze these labels: \(predictions.joined(separator: ", "))
	
	Task: Identify only specific, discrete, and countable physical objects. 
	
	Strict Exclusion Rules:
	1. NO generic categories (e.g., 'electronics', 'machinery', 'appliance', 'conveyance').
	2. NO materials or textures (e.g., 'wood_processed', 'metal', 'plastic', 'fabric').
	3. NO abstract concepts, people, or environments (e.g., 'adult', 'structure', 'indoor', 'portal').
	4. NO collective nouns (e.g., 'furniture', 'equipment', 'material').
	
	Requirement: Return only the concrete names of individual items (e.g., 'Hammer', 'Chair', 'Coffee Mug'). 
	
	Output Format: A comma-separated list of nouns. If no specific objects are found, return 'NONE'.
	"""
		

//		let prompt = """
//		Analyze these labels: \(predictions.joined(separator: ", "))
//		Extract only specific, concrete, physical objects.
//		Remove all: environments, abstract concepts, and generic categories (like 'structure', 'electronics','adult', 'people', 'portal', or any other generic terms or anyhting that isnt an object.).
//		Output: Comma-separated list of nouns only. If none, return 'NONE'.
//		"""
		
		do {
			let session = LanguageModelSession()
			let response = try await session.respond(to: prompt)
			let text = response.content.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
			
			if text.contains("none") || text.isEmpty { return [] }
			
			return text.components(separatedBy: ",")
				.map { $0.trimmingCharacters(in: .whitespaces) }
				.filter { !$0.isEmpty }
		} catch {
			return []
		}
	}
	
		// MARK: - Quiz Generation (Batched for Speed)
	func generateQuizSession(from objects: [String]) async -> [QuizResult] {
		guard !objects.isEmpty else { return [] }
		
			// We process these in a group to allow Apple Intelligence to optimize power usage
		return await withTaskGroup(of: QuizResult?.self) { group in
			for object in objects {
				group.addTask {
					await self.translate(object)
				}
			}
			
			var results: [QuizResult] = []
			for await result in group {
				if let result = result { results.append(result) }
			}
			return results.shuffled()
		}
	}
	
		// MARK: - Translation
	private func translate(_ object: String) async -> QuizResult? {
			// Shorter, instructional prompts trigger fewer safety guardrails
		let prompt = "Translate the English word '\(object)' to \(selectedLanguageRaw). Return ONLY the translated word."
		
		do {
			let session = LanguageModelSession()
			let response = try await session.respond(to: prompt)
			let translated = response.content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
			
			guard !translated.isEmpty else { return nil }
			return QuizResult(translatedWord: translated, correctEnglish: object)
		} catch {
			return nil
		}
	}
	
		// MARK: - Bilingual Sentence Generation (Safety Optimized)
	func generateBilingualSentence(for word: String) async -> BilingualSentence? {
		guard model.isAvailable else { return nil }
		
			// REFINEMENT: Explicitly telling the AI to be "Educational and Neutral"
			// helps bypass over-sensitive safety filters.
		let prompt = """
		Objective: Educational language example.
		Word: \(word)
		Language: \(selectedLanguageRaw)
		
		Task: Write a neutral, simple English sentence using '\(word)'. 
		Then translate it to \(selectedLanguageRaw).
		
		Format:
		E: [English]
		T: [Translation]
		"""
		
		do {
			let session = LanguageModelSession()
			let response = try await session.respond(to: prompt)
			
				// Refined parsing logic (more robust than component matching)
			let content = response.content
			let lines = content.components(separatedBy: .newlines)
			
			var english = ""
			var translated = ""
			
			for line in lines {
				if line.starts(with: "E:") {
					english = line.replacingOccurrences(of: "E:", with: "").trimmingCharacters(in: .whitespaces)
				} else if line.starts(with: "T:") {
					translated = line.replacingOccurrences(of: "T:", with: "").trimmingCharacters(in: .whitespaces)
				}
			}
			
				// Final safety check: If the model returned a "Safety" warning as text
			if english.lowercased().contains("guardrail") || english.isEmpty {
				return nil
			}
			
			return BilingualSentence(english: english, translated: translated)
			
		} catch {
			print("Safety or Model Error: \(error)")
			return nil
		}
	}
}
