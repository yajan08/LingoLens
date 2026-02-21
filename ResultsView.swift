import SwiftUI

	/// The landing page for LingoLens, designed for the Swift Student Challenge.
	/// Uses native navigation patterns and a modern floating action button.
@available(iOS 26.0, *)
struct ResultsView: View {
	
		// MARK: - Properties
	
		/// Raw labels passed instantly from the ScannerView to avoid camera-to-result lag.
	let rawDetectedLabels: [String]
	private let aiService = FoundationAIService()
	
	@Environment(\.dismiss) private var dismiss
	
	@FocusState private var isTextFieldFocused: Bool
	
		// MARK: - State
	
	@State private var filteredObjects: [String] = []
	@State private var manualObjects: [String] = []
	@State private var selectedObjects: Set<String> = []
	@State private var isFiltering = true
	@State private var navigateToQuiz = false
	@State private var newObjectText: String = ""
	@State private var showHelp = false
	
	
		/// Combined list with manual objects FIRST (instant priority)
	private var allObjects: [String] {
		var seen = Set<String>()
		return (manualObjects + filteredObjects)
			.filter { !$0.isEmpty && seen.insert($0).inserted }
	}
	
		// FIX 1: canStart now correctly derives from allObjects + selectedObjects,
		// not just selectedObjects — handles the manual-only case properly.
	private var canStart: Bool {
		!isFiltering && !selectedObjects.isEmpty
	}
	
	
		// MARK: - Body
	
	var body: some View {
		VStack(spacing: 0) {
			
			header
			
			ScrollView {
				LazyVStack(spacing: 12) {
					
					addObjectRow
						.padding(.bottom, 8)
					
					if isFiltering {
						loadingShimmer
					}
					else if allObjects.isEmpty {
						emptyStateContent
					}
					else {
						ForEach(allObjects, id: \.self) { object in
							selectableRow(object)
						}
					}
				}
				.padding()
			}
			
			startButton
		}
		.navigationTitle("Review Items")
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			
			ToolbarItem(placement: .topBarTrailing) {
				
				Button {
					showHelp = true
				} label: {
					Image(systemName: "questionmark")
						.symbolRenderingMode(.hierarchical)
						.font(.title3)
				}
				.buttonStyle(.borderless)
			}
		}
		.navigationDestination(isPresented: $navigateToQuiz) {
				// FIX 2: Snapshot selectedObjects at navigation time so the quiz
				// always receives the correct set, even if state mutates after.
			QuizSessionView(objects: Array(selectedObjects).sorted())
				.id(selectedObjects)
		}
		.sheet(isPresented: $showHelp) {
			ResultsInstructionsSheet()
		}
		.onAppear {
			performFiltering()
		}
	}
}

	//
	// MARK: - UI Components
	//

@available(iOS 26.0, *)
private extension ResultsView {
	
	var header: some View {
		VStack(alignment: .leading, spacing: 6) {
			
			Text("Review Detected Items")
				.font(.system(.largeTitle, design: .rounded).bold())
			
			Text("Confirm or add objects you want to include in your scavenger hunt.")
				.font(.subheadline)
				.foregroundColor(.secondary)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding()
	}
	
	
	var loadingShimmer: some View {
		VStack(spacing: 12) {
			ForEach(0..<6, id: \.self) { _ in
				
				RoundedRectangle(cornerRadius: 14)
					.fill(Color.gray.opacity(0.15))
					.frame(height: 60)
					.overlay(
						HStack {
							Circle()
								.fill(Color.gray.opacity(0.2))
								.frame(width: 24)
							
							Rectangle()
								.fill(Color.gray.opacity(0.2))
								.frame(width: 120, height: 12)
							
							Spacer()
						}
							.padding(.horizontal)
					)
			}
		}
		.opacity(0.6)
	}
	
	var addObjectRow: some View {
		HStack(spacing: 12) {
			
				// Main Input Field
			HStack {
				Image(systemName: "plus.circle.fill")
					.foregroundColor(.blue)
					.symbolEffect(.bounce, value: !newObjectText.isEmpty)
				
				TextField("Add object manually...", text: $newObjectText)
					.submitLabel(.done)
					.focused($isTextFieldFocused)
					.onSubmit { addManualObjectInstant() }
			}
			.padding()
			.background(
				Color(.secondarySystemBackground),
				in: RoundedRectangle(cornerRadius: 14)
			)
				// FIX 3: Only set focus if not already focused — eliminates the
				// first-tap delay caused by redundant focus state toggling.
			.onTapGesture {
				if !isTextFieldFocused {
					isTextFieldFocused = true
				}
			}
			
				// Animated "Add" Button
			if !newObjectText.isEmpty {
				Button("Add") {
					addManualObjectInstant()
				}
				.fontWeight(.bold)
				.transition(.move(edge: .trailing).combined(with: .opacity))
			}
		}
		.animation(.spring(response: 0.35, dampingFraction: 0.8), value: newObjectText.isEmpty)
	}
	
	func selectableRow(_ object: String) -> some View {
		
		let isSelected = selectedObjects.contains(object)
		
		return Button {
			toggle(object)
		} label: {
			
			HStack(spacing: 16) {
				
				Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
					.font(.title2)
					.foregroundColor(isSelected ? .green : .secondary)
				
				Text(object.capitalized)
					.font(.body.weight(.medium))
				
				Spacer()
			}
			.padding()
			.background(
				Color(.secondarySystemBackground),
				in: RoundedRectangle(cornerRadius: 14)
			)
		}
		.buttonStyle(.plain)
	}
	
	var startButton: some View {
		
		Button {
			UIImpactFeedbackGenerator(style: .medium).impactOccurred()
			navigateToQuiz = true
			
		} label: {
			
			Text("Start Scavenger Hunt")
				.font(.headline)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 18)
				// FIX 4: Use canStart computed property consistently
				// in both background and disabled modifier.
				.background(canStart ? Color.blue : Color.gray)
				.foregroundColor(.white)
				.clipShape(Capsule())
		}
		.disabled(!canStart)
	}
	
	var emptyStateContent: some View {
		
		VStack(spacing: 16) {
			
			Image(systemName: "viewfinder.circle")
				.font(.system(size: 60))
				.foregroundColor(.secondary)
				.padding(.top, 40)
			
			Text("No objects yet")
				.font(.headline)
			
			Text("Scan again or add objects manually.")
				.font(.subheadline)
				.foregroundColor(.secondary)
			
			Button("Go Back") {
				dismiss()
			}
			.font(.headline)
			.padding(.top, 10)
		}
	}
}

	//
	// MARK: - Logic
	//

@available(iOS 26.0, *)
private extension ResultsView {
	
	func performFiltering() {
		
		guard !rawDetectedLabels.isEmpty else {
			isFiltering = false
			return
		}
		
		Task(priority: .userInitiated) {
			
			let cleaned = await aiService.filterObjects(from: rawDetectedLabels)
			
			await MainActor.run {
				
				let sanitized = cleaned
					.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
					.filter { !$0.isEmpty }
				
				filteredObjects = Array(Set(sanitized))
					// FIX 5: Only auto-select filtered objects that aren't already
					// manually added, preserving any manual selections made during load.
				let newSelections = Set(sanitized).subtracting(manualObjects)
				selectedObjects = selectedObjects.union(newSelections)
				isFiltering = false
			}
		}
	}
	
	
		/// ZERO latency manual add — instant state update
	func addManualObjectInstant() {
		
		let text = newObjectText
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.lowercased()
		
		guard !text.isEmpty else { return }
		
			// FIX 6: Dismiss keyboard AFTER capturing text, not before,
			// to prevent the text field from clearing before we read it.
		let captured = text
		newObjectText = ""
		isTextFieldFocused = false
		
		if !manualObjects.contains(captured) && !captured.isEmpty {
			manualObjects.insert(captured, at: 0)
		}
		
			// Always ensure manual objects are selected when added.
		selectedObjects.insert(captured)
		
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
	}
	
	
	func toggle(_ object: String) {
		
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
		
		if selectedObjects.contains(object) {
			selectedObjects.remove(object)
		} else {
			selectedObjects.insert(object)
		}
	}
}

	//
	// MARK: - Instructions Sheet
	//

struct ResultsInstructionsSheet: View {
	
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		
		NavigationStack {
			
			List {
				
				Section("Review your objects") {
					
					Label("Tap items to include or exclude them.", systemImage: "checkmark.circle")
					
					Label("Add missing objects that were not detected manually.", systemImage: "plus.circle")
					
					Label("Only selected items will appear in your scavenger hunt.", systemImage: "target")
				}
			}
			.navigationTitle("About Reviewing")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				
				ToolbarItem(placement: .cancellationAction) {
					
					Button {
						dismiss()
					} label: {
						Image(systemName: "xmark")
					}
				}
			}
		}
	}
}
