import SwiftUI

/// Branded text entry used instead of app-owned system alert fields.
struct NullSignTextPrompt: View {
	@Environment(\.dismiss) private var dismiss
	@FocusState private var isFocused: Bool
	let title: String
	let detail: String
	let placeholder: String
	@Binding var text: String
	var allowsEmpty = false
	let onSave: () -> Void

	var body: some View {
		NullSignMenuSheet(title: title, systemImage: "pencil", detail: detail, detents: [.large]) {
			VStack(spacing: 16) {
				TextField(placeholder, text: $text)
					.font(.roundedUI(.body))
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled()
					.submitLabel(.done)
					.onSubmit(save)
					.focused($isFocused)
					.padding(18)
					.nullSignSurface(fill: NullSignStyle.groupedSurface)
				Button(action: save) { Text("Save").frame(maxWidth: .infinity) }
					.buttonStyle(NullSignPrimaryButtonStyle())
					.disabled(!allowsEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
				Button("Cancel") { dismiss() }
					.font(.roundedUI(.body, weight: .bold))
					.frame(minHeight: 44)
			}
		}
		.task { isFocused = true }
	}

	private func save() {
		guard allowsEmpty || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
		onSave()
		dismiss()
	}
}
