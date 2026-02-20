	//
	//  SpeechService.swift
	//  LingoLens
	//

import Foundation
import SwiftUI
import AVFoundation

@MainActor
final class SpeechService {
	
	@AppStorage("selected_language")
	private var selectedLanguageRaw = AppLanguage.french.rawValue
	
	private let synthesizer = AVSpeechSynthesizer()
	
		// Singleton (recommended)
	static let shared = SpeechService()
	
	private init() {}
	
		// MARK: - Public
	
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
	
	
	func stop() {
		synthesizer.stopSpeaking(at: .immediate)
	}
	
	
		// MARK: - Voice Selection (OFFLINE SAFE)
	
	private func bestAvailableVoice(
		for languageCode: String
	) -> AVSpeechSynthesisVoice {
		
		let voices = AVSpeechSynthesisVoice.speechVoices()
		
			// 1. Exact match (fr-FR)
		if let exact = voices.first(where: {
			$0.language.lowercased() == languageCode.lowercased()
		}) {
			return exact
		}
		
			// 2. Match language prefix (fr matches fr-FR)
		let prefix = languageCode.prefix(2).lowercased()
		
		if let prefixMatch = voices.first(where: {
			$0.language.lowercased().hasPrefix(prefix)
		}) {
			return prefixMatch
		}
		
			// 3. Last resort: system default voice (always exists offline)
		return AVSpeechSynthesisVoice(language:
										AVSpeechSynthesisVoice.currentLanguageCode()
		)!
	}
}

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
