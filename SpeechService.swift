import Foundation
import SwiftUI
import AVFoundation

/// Handles all text-to-speech playback for the app.
@MainActor
final class SpeechService {
	
	/// Stores the user’s selected language persistently.
	@AppStorage("selected_language")
	private var selectedLanguageRaw = AppLanguage.french.rawValue
	
	/// Apple speech engine responsible for audio playback.
	private let synthesizer = AVSpeechSynthesizer()
	
	/// Shared singleton instance  of SpeechSrvice used across the app.
	static let shared = SpeechService()
	
	private init() {}
	
	
	/// Speaks the provided text using the selected language voice.
	/// Stops any currently playing speech before starting new audio.
	func speak(_ text: String) {
		guard !text.isEmpty else { return }
		
		let language = AppLanguage(rawValue: selectedLanguageRaw) ?? .french
		let code = speechCode(for: language)
		
		let utterance = AVSpeechUtterance(string: text)
		utterance.voice = AVSpeechSynthesisVoice(language: code)
		
		utterance.rate = 0.5
		utterance.pitchMultiplier = 1.0
		utterance.volume = 1.0
		
		synthesizer.stopSpeaking(at: .immediate)
		synthesizer.speak(utterance)
	}
	
	
	/// Immediately stops any ongoing speech playback.
	func stop() {
		synthesizer.stopSpeaking(at: .immediate)
	}
	
	
	/// Finds the best available offline voice for a language code.
	/// Falls back safely if an exact match is unavailable.
	private func bestAvailableVoice(
		for languageCode: String
	) -> AVSpeechSynthesisVoice {
		
		let voices = AVSpeechSynthesisVoice.speechVoices()
		
		// Try exact match (e.g. fr-FR)
		if let exact = voices.first(where: {
			$0.language.lowercased() == languageCode.lowercased()
		}) {
			return exact
		}
		
		// Match by language prefix (e.g. fr matches fr-CA)
		let prefix = languageCode.prefix(2).lowercased()
		
		if let prefixMatch = voices.first(where: {
			$0.language.lowercased().hasPrefix(prefix)
		}) {
			return prefixMatch
		}
		
			// Guaranteed offline fallback
		return AVSpeechSynthesisVoice(
			language: AVSpeechSynthesisVoice.currentLanguageCode()
		)!
	}
}

/// Converts an app language into the correct speech engine locale code.
private func speechCode(for language: AppLanguage) -> String {
	switch language {
		case .french:
			return "fr-FR"
		case .german:
			return "de-DE"
		case .spanish:
			return "es-ES"
		case .japanese:
			return "ja-JP"
	}
}
