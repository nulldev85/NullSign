import SwiftUI

/// A fully app-owned selector: native Picker menus can ignore SwiftUI typography.
struct NullSignChoiceRow<Value: Hashable>: View {
	let title: String
	let systemImage: String
	@Binding var selection: Value
	let values: [Value]
	let label: (Value) -> String
	@State private var isPresenting = false

	var body: some View {
		Button { isPresenting = true } label: {
			NullSignSettingsRow(
				title: title, detail: nil, systemImage: systemImage,
				value: label(selection), tint: NullSignStyle.categoryColor(for: systemImage)
			)
		}
		.buttonStyle(NullSignPressableStyle())
		.accessibilityLabel(Text(title))
		.accessibilityValue(Text(label(selection)))
		.sheet(isPresented: $isPresenting) { choices }
	}

	private var choices: some View {
		NullSignMenuSheet(title: title, systemImage: systemImage, detail: "Choose an option for \(title.lowercased()).") {
			NullSignSettingsCard {
				ForEach(Array(values.enumerated()), id: \.element) { index, value in
					if index > 0 { NullSignSettingsDivider() }
					NullSignMenuAction(
						title: label(value), systemImage: systemImage,
						isSelected: selection == value
					) {
						selection = value
						isPresenting = false
					}
				}
			}
		}
	}
}
