//
//  Language.swift
//  LingoLense
//
//  Created by SDC-USER on 14/02/26.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
	
	case french = "French"
	case spanish = "Spanish"
	case german = "German"
	case japanese = "Japanese"
	
	var id: String { rawValue }
	
	var displayName: String {
		rawValue
	}
	
	var flag: String {
		switch self {
			case .french: return "🇫🇷"
			case .spanish: return "🇪🇸"
			case .german: return "🇩🇪"
			case .japanese: return "🇯🇵"
		}
	}
}
