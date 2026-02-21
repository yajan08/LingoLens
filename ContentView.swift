import SwiftUI

@available(iOS 26.0, *)
struct ContentView: View {
	
	@State private var navigationPath = NavigationPath()
	
		// MARK: - State
	@AppStorage("selected_language")
	private var selectedLanguageRaw = AppLanguage.french.rawValue
	
		// Track which info type to show
	@State private var activeInfoType: InfoType?
	
	private var selectedLanguage: AppLanguage {
		AppLanguage(rawValue: selectedLanguageRaw) ?? .french
	}
	
		// MARK: - Body
	var body: some View {
		NavigationStack(path: $navigationPath) {
			ScrollView(showsIndicators: false) {
				VStack(spacing: 28) {
					descriptionHeader
					
					languagePicker
					
					instructionsSection
					
					modeSelectionArea
					
					privacySection
				}
				.padding(24)
			}
			.navigationTitle("LingoLens")
			.background(Color(.systemGroupedBackground))
			.sheet(item: $activeInfoType) { type in
				LingoInfoSheet(type: type, selectedLanguage: selectedLanguage)
			}
			.onReceive(NotificationCenter.default.publisher(for: .init("dismissToRoot"))) { _ in
				navigationPath = NavigationPath()
			}
		}
	}
}

	// MARK: - Supporting Types
enum InfoType: String, Identifiable {
	case quickScan, scavengerHunt
	var id: String { self.rawValue }
}

	// MARK: - UI Components
@available(iOS 26.0, *)
private extension ContentView {
	
	var descriptionHeader: some View {
		Text("Transform your world into a living language laboratory.")
			.font(.system(.title3, design: .rounded))
			.fontWeight(.medium)
			.foregroundColor(.secondary)
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.top, -10)
	}
	
	var languagePicker: some View {
		Menu {
			Picker("Choose Language", selection: $selectedLanguageRaw) {
				ForEach(AppLanguage.allCases) { language in
					Text("\(language.flag) \(language.displayName)")
						.tag(language.rawValue)
				}
			}
		} label: {
			HStack(spacing: 16) {
				Text(selectedLanguage.flag)
					.font(.system(size: 32))
					.shadow(radius: 2)
				
				VStack(alignment: .leading, spacing: 0) {
					Text("CURRENTLY LEARNING")
						.font(.system(size: 10, weight: .heavy))
						.foregroundStyle(.secondary)
					Text(selectedLanguage.displayName)
						.font(.title3.bold())
				}
				
				Spacer()
				
				Image(systemName: "chevron.up.chevron.down")
					.font(.caption.bold())
					.foregroundColor(.secondary)
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 16)
			.background(Color(.secondarySystemGroupedBackground))
			.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
			.foregroundColor(.primary)
			.shadow(color: .black.opacity(0.05), radius: 10, y: 5)
		}
	}
	
	var instructionsSection: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Learning Modes")
				.font(.system(.headline, design: .rounded))
				.padding(.leading, 4)
			
			VStack(spacing: 0) {
				stepRow(
					icon: "sparkles",
					color: .blue,
					title: "Quick Scan",
					text: "Scan an object and get its \(selectedLanguage.displayName) translation instantly.",
					action: { activeInfoType = .quickScan }
				)
				
				Divider().padding(.leading, 72)
				
				stepRow(
					icon: "map.fill",
					color: .orange,
					title: "Scavenger Hunt",
					text: "Scan a bunch of objects then hunt them using their \(selectedLanguage.displayName) names.",
					action: { activeInfoType = .scavengerHunt }
				)
			}
			.background(Color(.secondarySystemGroupedBackground))
			.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
		}
	}
	
	func stepRow(icon: String, color: Color, title: String, text: String, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			HStack(spacing: 16) {
				ZStack {
					Circle()
						.fill(color.gradient.opacity(0.15))
						.frame(width: 44, height: 44)
					Image(systemName: icon)
						.font(.system(size: 18, weight: .bold))
						.foregroundColor(color)
				}
				
				VStack(alignment: .leading, spacing: 2) {
					Text(title)
						.font(.system(.subheadline, design: .rounded).bold())
						.foregroundColor(.primary)
					Text(text)
						.font(.caption)
						.foregroundColor(.secondary)
				}
				
				Spacer()
				
				Image(systemName: "info.circle.fill")
					.symbolRenderingMode(.hierarchical)
					.font(.title3)
					.foregroundStyle(color)
			}
			.padding(16)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}
	
	var modeSelectionArea: some View {
		HStack(spacing: 16) {
			NavigationLink(destination: QuickScanView(path: $navigationPath)) {
				Label("Quick Scan", systemImage: "bolt.fill")
					.font(.headline)
					.frame(maxWidth: .infinity)
					.frame(height: 60)
					.background(Color.blue.gradient)
					.foregroundColor(.white)
					.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
			}
			
			NavigationLink(destination: ScannerView()) {
				Label("Start Hunt", systemImage: "flag.checkered")
					.font(.headline)
					.frame(maxWidth: .infinity)
					.frame(height: 60)
					.background(Color.orange.gradient)
					.foregroundColor(.white)
					.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
			}
		}
	}
	
	var privacySection: some View {
		VStack(spacing: 16) {
				// Modern Shield Badge
			ZStack {
				Circle()
					.fill(Color.blue.opacity(0.1))
					.frame(width: 60, height: 60)
				
				Image(systemName: "lock.shield.fill")
					.font(.system(size: 28))
					.symbolRenderingMode(.hierarchical)
					.foregroundStyle(Color.blue)
			}
			
			VStack(spacing: 4) {
				Text("Your Privacy, My Priority.")
					.font(.system(.subheadline, design: .rounded).bold())
				
				Text("LingoLens uses secure on-device intelligence to recognize your surroundings and translate the words. No data ever leaves your device.")
					.font(.caption)
					.foregroundColor(.secondary)
					.multilineTextAlignment(.center)
					.padding(.horizontal, 20)
			}
		}
		.padding(.bottom, 12)
	}
}

	// MARK: - The Consolidated Info Sheet

struct LingoInfoSheet: View {
	@Environment(\.dismiss) private var dismiss
	let type: InfoType
	let selectedLanguage: AppLanguage
	
	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .center, spacing: 32) {
						// Icon and Header Section
					VStack(spacing: 16) {
						ZStack {
							Circle()
								.fill((type == .quickScan ? Color.blue : Color.orange).gradient.opacity(0.1))
								.frame(width: 100, height: 100)
							
							Image(systemName: type == .quickScan ? "bolt.horizontal.circle.fill" : "flag.checkered.2.crossed")
								.font(.system(size: 50))
								.symbolRenderingMode(.hierarchical)
								.foregroundStyle(type == .quickScan ? Color.blue : Color.orange)
						}
						
						VStack(spacing: 8) {
							Text(type == .quickScan ? "Quick Scan" : "Scavenger Hunt")
								.font(.system(.title, design: .rounded).bold())
							
							Text(type == .quickScan ? "Identify and translate objects in your surroundings instantly on-device." : "Turn your room into an interactive puzzle. Scan, curate, and test your memory.")
								.font(.subheadline)
								.foregroundColor(.secondary)
								.multilineTextAlignment(.center)
								.padding(.horizontal, 16)
						}
					}
					
						// Instruction List
					VStack(spacing: 0) {
						if type == .quickScan {
							InstructionDetailRow(
								icon: "camera.viewfinder",
								color: .blue,
								title: "Explore Your Space",
								detail: "Point your camera at objects. LingoLens detects and labels items that are visible in the frame."
							)
							Divider().padding(.leading, 72)
							InstructionDetailRow(
								icon: "sparkles.rectangle.stack.fill",
								color: .blue,
								title: "Instant Vocabulary",
								detail: "Bridge the gap between seeing an object and knowing its name. Perfect for rapid-fire visual learning."
							)
						} else {
							InstructionDetailRow(
								icon: "dot.viewfinder",
								color: .orange,
								title: "1. Scan & Extract",
								detail: "Move around your environment. LingoLens intelligently identifies all visible objects."
							)
							Divider().padding(.leading, 72)
							InstructionDetailRow(
								icon: "slider.horizontal.3",
								color: .orange,
								title: "2. Refine Your List",
								detail: "Review extracted items. Manually remove objects or add custom challenges to tailor your experience."
							)
							Divider().padding(.leading, 72)
							InstructionDetailRow(
								icon: "character.bubble.fill",
								color: .orange,
								title: "3. The Language Test",
								detail: "The hunt begins! You'll be prompted with names in \(selectedLanguage.displayName). You must recall the object."
							)
							Divider().padding(.leading, 72)
							InstructionDetailRow(
								icon: "target",
								color: .orange,
								title: "4. Verify & Win",
								detail: "Physically find and scan the object. Once recognized, the challenge is complete!"
							)
						}
					}
					.background(Color(.secondarySystemGroupedBackground))
					.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
				}
				.padding(.horizontal, 20)
			}
			.background(Color(.systemGroupedBackground))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { dismiss() }
						.fontWeight(.bold)
				}
			}
		}
	}
}

struct InstructionDetailRow: View {
	let icon: String
	let color: Color
	let title: String
	let detail: String
	
	var body: some View {
		HStack(spacing: 20) {
			Image(systemName: icon)
				.symbolRenderingMode(.hierarchical)
				.font(.system(size: 28))
				.foregroundColor(color)
				.frame(width: 44)
			
			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.system(.subheadline, design: .rounded).bold())
					.foregroundColor(.primary)
				Text(detail)
					.font(.footnote)
					.foregroundColor(.secondary)
					.fixedSize(horizontal: false, vertical: true)
					.lineSpacing(2)
			}
			
			Spacer()
		}
		.padding(.vertical, 20)
		.padding(.horizontal, 20)
	}
}


