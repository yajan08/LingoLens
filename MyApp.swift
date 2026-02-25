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
//	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	var body: some Scene {
		WindowGroup {
			LaunchScreenView()
		}
	}
}

//class AppDelegate: NSObject, UIApplicationDelegate {
//	func application(_ application: UIApplication,
//					 supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
//		return .all  // ← allow all rotations
//	}
//}
