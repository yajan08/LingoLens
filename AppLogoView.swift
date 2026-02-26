import SwiftUI

struct AppLogoView: View {
	
	@Environment(\.colorScheme) private var scheme
	
	var body: some View {
		ZStack {
			scheme == .dark ? Color.black : Color.white
			logo
		}
		.ignoresSafeArea()
	}
}

	// MARK: - Logo Components
private extension AppLogoView {
	
	var logo: some View {
		ZStack {
			
				// MARK: Glass Container
			
			let shape = RoundedRectangle(cornerRadius: 64, style: .continuous)
			
			shape
				// Base lift
				.fill(
					scheme == .dark
					? Color.white.opacity(0.025)
					: Color.black.opacity(0.035)
				)
			
				// Top-left soft light
				.overlay(
					LinearGradient(
						colors: [
							scheme == .dark
							? Color.white.opacity(0.14)
							: Color.black.opacity(0.12),
							.clear
						],
						startPoint: .topLeading,
						endPoint: .center
					)
					.mask(shape)
				)
			
				// Top-right soft light
				.overlay(
					LinearGradient(
						colors: [
							scheme == .dark
							? Color.white.opacity(0.14)
							: Color.black.opacity(0.12),
							.clear
						],
						startPoint: .topTrailing,
						endPoint: .center
					)
					.mask(shape)
				)
			
				// Bottom depth
				.overlay(
					LinearGradient(
						colors: [
							.clear,
							scheme == .dark
							? Color.black.opacity(0.70)
							: Color.white.opacity(0.65)
						],
						startPoint: .center,
						endPoint: .bottomTrailing
					)
					.mask(shape)
				)
				.frame(width: 260, height: 260)
			
				// Inner highlight
				.overlay(
					shape
						.stroke(
							LinearGradient(
								colors: [
									scheme == .dark
									? Color.white.opacity(0.25)
									: Color.black.opacity(0.18),
									
									scheme == .dark
									? Color.white.opacity(0.05)
									: Color.black.opacity(0.04),
									
										.clear
								],
								startPoint: .top,
								endPoint: .center
							),
							lineWidth: 1
						)
						.blendMode(.overlay)
				)
			
				// Outer glow
				.shadow(
					color: (scheme == .dark
							? Color.orange
							: Color.orange.opacity(0.6))
					.opacity(0.15),
					radius: 20,
					x: -10,
					y: -10
				)
				.shadow(
					color: (scheme == .dark
							? Color.blue
							: Color.blue.opacity(0.6))
					.opacity(0.15),
					radius: 20,
					x: 10,
					y: 10
				)
			
			
				// MARK: Magnifying Glass
			
			Image(systemName: "magnifyingglass")
				.font(.system(size: 190, weight: .light))
				.offset(x: -3, y: -3)
				.foregroundStyle(
					scheme == .dark ? Color.white : Color.black
				)
			
			
				// MARK: Translate Icon
			
			Image(systemName: "translate")
				.font(.system(size: 80, weight: .bold))
				.symbolRenderingMode(.palette)
				.foregroundStyle(
					Color.orange,
					Color.blue
				)
				.offset(x: -6, y: -3)
		}
	}
}

#Preview {
	AppLogoView()
}
