import SwiftUI

	/// Animated launch screen that transitions into the main app content.
struct LaunchScreenView: View {
	
	@State private var isAnimating = false
	@State private var textVisible = false
	@State private var showContent = false
	@State private var heroBreath = false
	@State private var finalZoom = false
	
	private let symbols = FloatingSymbolModel.generate(count: 24)
	
	var body: some View {
		
		ZStack {
			
			if showContent {
				
				if #available(iOS 26.0, *) {
					ContentView()
						.transition(
							.asymmetric(
								insertion: .opacity.combined(with: .scale(scale: 0.985)),
								removal: .opacity
							)
						)
				} else {
					UnsupportedOSView()
						.transition(.opacity)
				}
			}
			
			if !showContent {
				
				ZStack {
					
					modernBackground
					
					floatingSymbols
					
					VStack(spacing: 34) {
						
						heroIcon
						
						brandTypography
							.opacity(finalZoom ? 0 : 1)
							.animation(.easeOut(duration: 0.4), value: finalZoom)
					}
				}
				.ignoresSafeArea()
				.transition(.opacity)
			}
		}
		.onAppear {
			startAnimationSequence()
		}
	}
}

private extension LaunchScreenView {
	
		/// Layered radial gradient background.
	var modernBackground: some View {
		
		ZStack {
			
			Color(.systemBackground)
			
			RadialGradient(
				colors: [
					Color.orange.opacity(0.22),
					.clear
				],
				center: .topLeading,
				startRadius: 40,
				endRadius: 520
			)
			
			RadialGradient(
				colors: [
					Color.blue.opacity(0.22),
					.clear
				],
				center: .bottomTrailing,
				startRadius: 40,
				endRadius: 560
			)
			
			RadialGradient(
				colors: [
					.clear,
					Color(.systemBackground).opacity(0.35)
				],
				center: .center,
				startRadius: 180,
				endRadius: 460
			)
		}
	}
}

private extension LaunchScreenView {
	
		/// Animated hero icon composed of a glow, glass plate, magnifying glass, and translate badge.
	var heroIcon: some View {
		
		ZStack {
			
			breathingGlow
			
			glassPlate
			
			magnifyingGlass
			
			translateIcon
		}
		.scaleEffect(isAnimating ? 1 : 0.86)
		.animation(.spring(response: 0.7, dampingFraction: 0.7), value: isAnimating)
		.animation(.easeInOut(duration: 0.8), value: finalZoom)
	}
	
		/// Soft pulsing gradient glow behind the icon.
	var breathingGlow: some View {
		
		Circle()
			.fill(
				LinearGradient(
					colors: [
						Color.orange.opacity(0.35),
						Color.blue.opacity(0.35)
					],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
			)
			.frame(width: 150, height: 150)
			.blur(radius: 32)
			.scaleEffect(heroBreath ? 1.16 : 0.9)
			.opacity(finalZoom ? 0 : 1)
			.animation(
				.easeInOut(duration: 2.2)
				.repeatForever(autoreverses: true),
				value: heroBreath
			)
	}
	
		/// Frosted glass card behind the icon.
	var glassPlate: some View {
		
		Group {
			
			if #available(iOS 15.0, *) {
				
				RoundedRectangle(cornerRadius: 32, style: .continuous)
					.fill(.ultraThinMaterial)
			}
			else {
				
				RoundedRectangle(cornerRadius: 32, style: .continuous)
					.fill(Color.white.opacity(0.85))
			}
		}
		.frame(width: 118, height: 118)
		.shadow(color: .black.opacity(0.08), radius: 25, y: 10)
		.opacity(finalZoom ? 0 : 1)
	}
	
		/// Spinning magnifying glass with a zoom-out transition on exit.
	var magnifyingGlass: some View {
		
		Group {
			
			if #available(iOS 17.0, *) {
				
				if #available(iOS 18.0, *) {
					Image(systemName: "magnifyingglass")
						.font(.system(size: 92, weight: .light))
						.foregroundStyle(.primary.opacity(0.95))
						.symbolEffect(
							.rotate.counterClockwise.byLayer,
							options: .repeat(.periodic(delay: 1.3)),
							value: isAnimating
						)
				} else {
					Image(systemName: "magnifyingglass")
						.font(.system(size: 92, weight: .light))
						.foregroundColor(.primary.opacity(0.95))
						.rotationEffect(.degrees(isAnimating ? -360 : 0))
						.animation(
							.linear(duration: 4)
							.repeatForever(autoreverses: false),
							value: isAnimating
						)
				}
			}
			else {
				
				Image(systemName: "magnifyingglass")
					.font(.system(size: 92, weight: .light))
					.foregroundColor(.primary.opacity(0.95))
					.rotationEffect(.degrees(isAnimating ? 360 : 0))
					.animation(
						.linear(duration: 4)
						.repeatForever(autoreverses: false),
						value: isAnimating
					)
			}
		}
		.scaleEffect(finalZoom ? 15 : 1)
	}
	
		/// Bouncing translate badge overlaid on the magnifying glass.
	var translateIcon: some View {
		
		Group {
			
			if #available(iOS 17.0, *) {
				
				if #available(iOS 18.0, *) {
					Image(systemName: "translate")
						.font(.system(size: 40, weight: .semibold))
						.symbolRenderingMode(.palette)
						.foregroundStyle(.orange, .blue)
						.offset(x: -2, y: -2)
						.symbolEffect(
							.bounce,
							options: .repeat(.periodic(delay: 2)),
							value: isAnimating
						)
				} else {
					Image(systemName: "translate")
						.font(.system(size: 40, weight: .semibold))
						.foregroundColor(.orange)
						.offset(x: -2, y: -2)
						.scaleEffect(isAnimating ? 1.12 : 1.0)
						.animation(
							.easeInOut(duration: 1.2)
							.repeatForever(autoreverses: true),
							value: isAnimating
						)
				}
			}
			else {
				
				Image(systemName: "translate")
					.font(.system(size: 40, weight: .semibold))
					.foregroundColor(.orange)
					.offset(x: -2, y: -2)
					.scaleEffect(isAnimating ? 1.1 : 1)
					.animation(
						.easeInOut(duration: 1.2)
						.repeatForever(autoreverses: true),
						value: isAnimating
					)
			}
		}
		.scaleEffect(finalZoom ? 4 : 1)
		.opacity(finalZoom ? 0 : 1)
	}
}

private extension LaunchScreenView {
	
		/// App name and tagline with a fade-in entrance animation.
	var brandTypography: some View {
		
		VStack(spacing: 8) {
			
			Text("LingoLens")
				.font(.system(size: 36, weight: .bold, design: .rounded))
				.foregroundStyle(
					LinearGradient(
						colors: [.orange, .blue],
						startPoint: .leading,
						endPoint: .trailing
					)
				)
			
			Text("See the world. Learn the words.")
				.font(.system(.subheadline, design: .rounded))
				.fontWeight(.medium)
				.foregroundStyle(.secondary)
		}
		.opacity(textVisible ? 1 : 0)
		.offset(y: textVisible ? 0 : 16)
		.animation(.easeOut(duration: 0.9).delay(0.25), value: textVisible)
	}
}

private extension LaunchScreenView {
	
		/// Scattered SF Symbol icons that float and pulse in the background.
	var floatingSymbols: some View {
		
		ZStack {
			
			ForEach(symbols) { symbol in
				
				Image(systemName: symbol.name)
					.font(.system(size: symbol.size))
					.foregroundStyle(symbol.color.opacity(0.32))
					.offset(symbol.offset)
					.scaleEffect(isAnimating ? 1 : 0.5)
					.opacity(isAnimating ? (finalZoom ? 0 : 1) : 0)
					.animation(
						.easeInOut(duration: symbol.duration)
						.repeatForever(autoreverses: true)
						.delay(symbol.delay),
						value: isAnimating
					)
					.animation(.easeOut(duration: 0.4), value: finalZoom)
			}
		}
	}
}

private extension LaunchScreenView {
	
		/// Kicks off the timed animation sequence that ends by revealing the main content.
	func startAnimationSequence() {
		
		isAnimating = true
		heroBreath = true
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
			textVisible = true
		}
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
			withAnimation {
				finalZoom = true
			}
		}
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
			withAnimation(.easeInOut(duration: 0.4)) {
				showContent = true
			}
		}
	}
}

	/// Data model for a single floating background symbol.
private struct FloatingSymbolModel: Identifiable {
	
	let id = UUID()
	
	let name: String
	let offset: CGSize
	let size: CGFloat
	let delay: Double
	let duration: Double
	let color: Color
	
		/// Generates a randomised array of floating symbol models.
	static func generate(count: Int) -> [FloatingSymbolModel] {
		
		let names = [
			"globe", "character.bubble", "camera.viewfinder", "sparkles",
			"brain", "textformat.abc", "waveform", "eye",
			"mic", "ellipsis.bubble", "book", "quote.bubble",
			"text.magnifyingglass"
		]
		
		return (0..<count).map { i in
			
			FloatingSymbolModel(
				name: names[i % names.count],
				offset: CGSize(
					width: CGFloat.random(in: -180...180),
					height: CGFloat.random(in: -360...360)
				),
				size: CGFloat.random(in: 14...24),
				delay: Double.random(in: 0...0.8),
				duration: Double.random(in: 2.5...4.5),
				color: Bool.random() ? .orange : .blue
			)
		}
	}
}

	/// Displayed when the app is run on an iOS version below the minimum requirement.
struct UnsupportedOSView: View {
	
	var body: some View {
		VStack(spacing: 20) {
			
			Image(systemName: "iphone.slash")
				.font(.system(size: 48))
				.foregroundStyle(.secondary)
			
			Text("Unsupported iOS Version")
				.font(.title2.bold())
			
			Text("""
This experience requires a newer version of iOS \
to access real-time camera scanning and Vision features.

Please update your device to continue.
""")
			.font(.body)
			.foregroundStyle(.secondary)
			.multilineTextAlignment(.center)
			.padding(.horizontal)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color(.systemBackground))
	}
}

#Preview {
	LaunchScreenView()
}
