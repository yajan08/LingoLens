import Foundation
import SwiftUI
import AVFoundation

	/// Handles all text-to-speech playback for the app.
@MainActor
final class SpeechService {
	
	@AppStorage("selected_language")
	private var selectedLanguageRaw = AppLanguage.french.rawValue
	
	private let synthesizer = AVSpeechSynthesizer()
	
	static let shared = SpeechService()
	
	private init() {}
	
		/// Speaks the provided text using the best available voice for the selected language.
	func speak(_ text: String) {
		guard !text.isEmpty else { return }
		
		let language = AppLanguage(rawValue: selectedLanguageRaw) ?? .french
		let code = speechCode(for: language)
		
		let utterance = AVSpeechUtterance(string: text)
		utterance.voice = bestAvailableVoice(for: code)
		utterance.rate = 0.4
		utterance.pitchMultiplier = 1.0
		utterance.volume = 1.0
		
		synthesizer.stopSpeaking(at: .immediate)
		synthesizer.speak(utterance)
	}
	
		/// Immediately stops any ongoing speech playback.
	func stop() {
		synthesizer.stopSpeaking(at: .immediate)
	}
	
		/// Returns the highest-quality available voice for the given language code.
		/// Prefers enhanced/premium quality, then falls back to any matching voice.
	private func bestAvailableVoice(for languageCode: String) -> AVSpeechSynthesisVoice {
		let voices = AVSpeechSynthesisVoice.speechVoices()
		let prefix = languageCode.prefix(2).lowercased()
		
		let candidates = voices.filter {
			$0.language.lowercased().hasPrefix(prefix)
		}
		
		if #available(iOS 17.0, *) {
			if let premium = candidates.first(where: {
				$0.quality == .premium
			}) {
				return premium
			}
		}
		
		if let enhanced = candidates.first(where: {
			$0.quality == .enhanced
		}) {
			return enhanced
		}
		
		if let exact = candidates.first(where: {
			$0.language.lowercased() == languageCode.lowercased()
		}) {
			return exact
		}
		
		if let any = candidates.first {
			return any
		}
		
		return AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
		?? AVSpeechSynthesisVoice(language: "en-US")!
	}
}

	/// Maps an app language to its BCP-47 locale code for the speech engine.
private func speechCode(for language: AppLanguage) -> String {
	switch language {
		case .french:   return "fr-FR"
		case .german:   return "de-DE"
		case .spanish:  return "es-ES"
		case .japanese: return "ja-JP"
	}
}
