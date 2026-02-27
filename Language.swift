import Foundation

	/// Supported target languages for translation throughout the app.
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
	
	case french = "French"
	case spanish = "Spanish"
	case german = "German"
	case japanese = "Japanese"
	
	var id: String { rawValue }
	
	var displayName: String {
		rawValue
	}
	
		/// Flag emoji for the language.
	var flag: String {
		switch self {
			case .french: return "🇫🇷"
			case .spanish: return "🇪🇸"
			case .german: return "🇩🇪"
			case .japanese: return "🇯🇵"
		}
	}
}
