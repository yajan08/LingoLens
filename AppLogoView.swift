import SwiftUI

struct AppLogoView: View {
	
	var body: some View {
		
		ZStack {
			
			background
			
			logo
		}
		.ignoresSafeArea()
	}
}


	// MARK: Background

private extension AppLogoView {
	
	var background: some View {
		
		ZStack {
			
				// Base adaptive color
			Color(.systemBackground)
			
			
				// MARK: Center color diffusion (KEY FIX)
//			RadialGradient(
//				colors: [
//					Color.orange.opacity(0.35),
//					Color.blue.opacity(0.30),
//					Color.clear
//				],
//				center: .center,
//				startRadius: 80,
//				endRadius: 600
//			)
			
			
				// MARK: Top-left accent
			RadialGradient(
				colors: [
					Color.orange.opacity(0.65),
					Color.orange.opacity(0.65),
					Color.clear
				],
				center: .topLeading,
				startRadius: 40,
				endRadius: 650
			)
			
			
				// MARK: Bottom-right accent
			RadialGradient(
				colors: [
					Color.blue.opacity(0.65),
					Color.blue.opacity(0.35),
					Color.clear
				],
				center: .bottomTrailing,
				startRadius: 40,
				endRadius: 650
			)
			
			
				// MARK: Subtle mesh blend (modern depth)
//			LinearGradient(
//				colors: [
//					Color.orange.opacity(0.12),
//					Color.clear,
//					Color.blue.opacity(0.12)
//				],
//				startPoint: .topLeading,
//				endPoint: .bottomTrailing
//			)
		}
	}
}


	// MARK: Logo

private extension AppLogoView {
	
	var logo: some View {
		
		ZStack {
			
				// Glass plate
			RoundedRectangle(cornerRadius: 64, style: .continuous)
				.fill(.ultraThinMaterial)
				.background(
					RoundedRectangle(cornerRadius: 64, style: .continuous)
						.fill(
							LinearGradient(
								colors: [
									Color.white.opacity(0.30),
									Color.white.opacity(0.05)
								],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
				)
				.overlay(
					RoundedRectangle(cornerRadius: 64, style: .continuous)
						.stroke(
							LinearGradient(
								colors: [
									Color.white.opacity(0.7),
									Color.white.opacity(0.15),
								],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							),
							lineWidth: 1.5
						)
				)
				.frame(width: 260, height: 260)
				.shadow(color: .black.opacity(0.18), radius: 40, y: 20)
			
			
				// Magnifying glass
			Image(systemName: "magnifyingglass")
				.font(.system(size: 200, weight: .light))
				.foregroundStyle(
					LinearGradient(
						colors: [
							Color.primary.opacity(0.95),
							Color.primary.opacity(0.7)
						],
						startPoint: .top,
						endPoint: .bottom
					)
				)
			
			
				// Translate overlay
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
