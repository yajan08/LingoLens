import SwiftUI

struct AppLogoView: View {
	
	var body: some View {
		ZStack {
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
			
				// MARK: Glass Container
			let shape = RoundedRectangle(cornerRadius: 64, style: .continuous)
			
			shape
				// Base subtle lift
				.fill(Color.white.opacity(0.025))
			
				// Top-left soft light
				.overlay(
					LinearGradient(
						colors: [
							Color.white.opacity(0.12),
							Color.clear
						],
						startPoint: .topLeading,
						endPoint: .center
					)
					.mask(shape)
				)
				.overlay(
					LinearGradient(
						colors: [
							Color.white.opacity(0.12),
							Color.clear
						],
						startPoint: .topTrailing,
						endPoint: .center
					)
					.mask(shape)
				)
			
				// Bottom-right depth
				.overlay(
					LinearGradient(
						colors: [
							Color.clear,
							Color.black.opacity(0.70)
						],
						startPoint: .center,
						endPoint: .bottomTrailing
					)
					.mask(shape)
				)
			
				.frame(width: 260, height: 260)
			
				// Subtle top inner highlight
				.overlay(
					shape
						.stroke(
							LinearGradient(
								colors: [
									Color.white.opacity(0.25),
									Color.white.opacity(0.05),
									Color.clear
								],
								startPoint: .top,
								endPoint: .center
							),
							lineWidth: 1
						)
						.blendMode(.overlay)
				)
			
				// Color border
//				.overlay(
//					shape
//						.stroke(
//							LinearGradient(
//								colors: [
//									Color.orange.opacity(0.45),
//									Color.blue.opacity(0.45)
//								],
//								startPoint: .topLeading,
//								endPoint: .bottomTrailing
//							),
//							lineWidth: 1.5
//						)
//				)
			
				// Outer glow
				.shadow(color: .orange.opacity(0.15), radius: 20, x: -10, y: -10)
				.shadow(color: .blue.opacity(0.15), radius: 20, x: 10, y: 10)
			
			
				// Magnifying Glass
			Image(systemName: "magnifyingglass")
				.font(.system(size: 190, weight: .light))
				.offset(x: -3, y: -3)
				.foregroundStyle(.white)
			
			
				// Translate Icon
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


	//import SwiftUI
//
//struct AppLogoView: View {
//	
//	var body: some View {
//		ZStack {
//				// Pure Black Background
//			Color.black
//			
//			logo
//		}
//		.ignoresSafeArea()
//	}
//}
//
//	// MARK: - Logo Components
//private extension AppLogoView {
//	
//	var logo: some View {
//		ZStack {
//				// MARK: Glass Container
//			RoundedRectangle(cornerRadius: 64, style: .continuous)
//				// Slight dark lift so it's not "lost" in the black
//				.fill(Color.white.opacity(0.03))
//				.frame(width: 260, height: 260)
//				// Inner Glass Border (Orange to Blue)
//				.overlay(
//					RoundedRectangle(cornerRadius: 64, style: .continuous)
//						.stroke(
//							LinearGradient(
//								colors: [
//									.orange.opacity(0.6),
//										.blue.opacity(0.6)
//								],
//								startPoint: .topLeading,
//								endPoint: .bottomTrailing
//							),
//							lineWidth: 1.5
//						)
//				)
//				// Subtle Outer Glow
//				.shadow(color: .orange.opacity(0.15), radius: 20, x: -10, y: -10)
//				.shadow(color: .blue.opacity(0.15), radius: 20, x: 10, y: 10)
//			
//				// MARK: Magnifying Glass
//			Image(systemName: "magnifyingglass")
//				.font(.system(size: 180, weight: .light)) // Slightly smaller to breathe inside border
//				.foregroundStyle(.white)
//			
//				// MARK: Translate Icon
//			Image(systemName: "translate")
//				.font(.system(size: 80, weight: .bold))
//				.symbolRenderingMode(.palette)
//				.foregroundStyle(
//					Color.orange,
//					Color.blue
//				)
//				.offset(x: -3, y: -3)
//		}
//	}
//}
//
//#Preview {
//	AppLogoView()
//}
//
//
//	//import SwiftUI
////
////struct AppLogoView: View {
////	
////	var body: some View {
////		ZStack {
////				// Pure Black Background
////			Color.black
////			
////			logo
////		}
////		.ignoresSafeArea()
////	}
////}
////
////	// MARK: - Logo Components
////private extension AppLogoView {
////	
////	var logo: some View {
////		ZStack {
////			
////				// Subtle Orange Glow
////			Circle()
////				.fill(
////					RadialGradient(
////						colors: [
////							Color.orange.opacity(0.35),
////							Color.orange.opacity(0.15),
////							.clear
////						],
////						center: .center,
////						startRadius: 0,
////						endRadius: 140
////					)
////				)
////				.frame(width: 260, height: 260)
////				.offset(x: -18, y: -18)
////				.blur(radius: 35)
////			
////				// Subtle Blue Glow
////			Circle()
////				.fill(
////					RadialGradient(
////						colors: [
////							Color.blue.opacity(0.35),
////							Color.blue.opacity(0.15),
////							.clear
////						],
////						center: .center,
////						startRadius: 0,
////						endRadius: 140
////					)
////				)
////				.frame(width: 260, height: 260)
////				.offset(x: 18, y: 18)
////				.blur(radius: 35)
////			
////				// Magnifying Glass
////			Image(systemName: "magnifyingglass")
////				.font(.system(size: 200, weight: .light))
////				.foregroundStyle(.white)
////			
////				// Translate Icon
////			Image(systemName: "translate")
////				.font(.system(size: 85, weight: .bold))
////				.symbolRenderingMode(.palette)
////				.foregroundStyle(
////					Color.orange,
////					Color.blue
////				)
////				.offset(x: -3, y: -3)
////		}
////	}
////}
////
////#Preview {
////	AppLogoView()
////}
