import SwiftUI

@main
struct MyApp: App {
	init() {
		
		if #available(iOS 26.0, *) {
			Task.detached(priority: .utility) {
				FoundationAIService().prewarm()
			}
		}
	}
	var body: some Scene {
		WindowGroup {
			LaunchScreenView()
		}
	}
}
