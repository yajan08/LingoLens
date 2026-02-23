import SwiftUI

struct AppLogoView: View {
	
	var body: some View {
		ZStack {
				// Pure Black Background
			Color.black
			
			logo
		}
		.ignoresSafeArea()
	}
}

	// MARK: - Logo Components
private extension AppLogoView {
	
	var logo: some View {
		ZStack {
			
				// Subtle Orange Glow
			Circle()
				.fill(
					RadialGradient(
						colors: [
							Color.orange.opacity(0.35),
							Color.orange.opacity(0.15),
							.clear
						],
						center: .center,
						startRadius: 0,
						endRadius: 140
					)
				)
				.frame(width: 260, height: 260)
				.offset(x: -18, y: -18)
				.blur(radius: 35)
			
				// Subtle Blue Glow
			Circle()
				.fill(
					RadialGradient(
						colors: [
							Color.blue.opacity(0.35),
							Color.blue.opacity(0.15),
							.clear
						],
						center: .center,
						startRadius: 0,
						endRadius: 140
					)
				)
				.frame(width: 260, height: 260)
				.offset(x: 18, y: 18)
				.blur(radius: 35)
			
				// Magnifying Glass
			Image(systemName: "magnifyingglass")
				.font(.system(size: 200, weight: .light))
				.foregroundStyle(.white)
			
				// Translate Icon
			Image(systemName: "translate")
				.font(.system(size: 85, weight: .bold))
				.symbolRenderingMode(.palette)
				.foregroundStyle(
					Color.orange,
					Color.blue
				)
				.offset(x: -3, y: -3)
		}
	}
}

#Preview {
	AppLogoView()
}
