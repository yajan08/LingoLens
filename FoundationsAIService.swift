import Foundation
import FoundationModels
import SwiftUI
import Combine

	/// Actor-based service wrapping Apple's on-device language model for translation, filtering, and sentence generation.
@available(iOS 26.0, *)
final actor FoundationAIService: ObservableObject {
	
	private let model = SystemLanguageModel.default
	
	@AppStorage("selected_language")
	private var selectedLanguageRaw = AppLanguage.french.rawValue
	
	private var sharedSession: LanguageModelSession?
	
		/// Result pairing a translated word with its English source.
	struct QuizResult: Identifiable, Sendable {
		let id = UUID()
		let translatedWord: String
		let correctEnglish: String
	}
	
		/// A bilingual example sentence in English and the target language.
	struct BilingualSentence: Sendable {
		let english: String
		let translated: String
	}
	
		/// Creates a throwaway session to warm up the model before first use.
	nonisolated func prewarm() {
		Task.detached(priority: .utility) {
			guard SystemLanguageModel.default.isAvailable else { return }
			let _ = LanguageModelSession()
		}
	}
	
		/// Filters a raw list of Vision labels down to specific, discrete physical objects.
	func filterObjects(from predictions: [String]) async -> [String] {
		guard model.isAvailable else { return [] }
		
		let prompt = """
 Analyze these labels: \(predictions.joined(separator: ", "))
 
 Task: Identify only specific, discrete, and physical objects. 
 
 Strict Exclusion Rules:
 1. NO generic categories (e.g., 'electronics', 'machinery', 'appliance', 'conveyance').
 2. NO materials or textures (e.g., 'wood_processed', 'metal', 'plastic', 'fabric').
 3. NO abstract concepts, people, or environments (e.g., 'adult', 'structure', 'indoor', 'portal').
 4. NO collective nouns (e.g., 'furniture', 'equipment', 'material').
 
 Requirement: Return only the names of individual items. 
 
 Output Format: A comma-separated list of Objects. If no specific objects are found, return 'NONE'.
 """
		
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
	
		/// Translates all objects concurrently and returns a shuffled array of quiz results.
	func generateQuizSession(from objects: [String]) async -> [QuizResult] {
		guard !objects.isEmpty else { return [] }
		
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
	
		/// Translates a single English word into the currently selected language.
	private func translate(_ object: String) async -> QuizResult? {
		let prompt = "You are a translation expert, translate the English word '\(object)' to \(selectedLanguageRaw). Return ONLY the translated word."
		
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
	
		/// Generates a simple bilingual example sentence using the given word.
	func generateBilingualSentence(for word: String) async -> BilingualSentence? {
		guard model.isAvailable else { return nil }
		
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
