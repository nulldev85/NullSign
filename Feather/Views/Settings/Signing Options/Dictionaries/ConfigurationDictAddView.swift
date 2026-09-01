import SwiftUI
import NimbleViews

struct ConfigurationDictAddView: View {
	@Environment(\.dismiss) private var dismiss

	@State private var _newKey = ""
	@State private var _newValue = ""
	@State private var _showOverrideAlert = false

	@Binding var dataDict: [String: String]

	private var normalizedKey: String {
		_newKey.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	private var normalizedValue: String {
		_newValue.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	private var saveButtonDisabled: Bool {
		normalizedKey.isEmpty || normalizedValue.isEmpty
	}

	var body: some View {
		ScrollView {
			VStack(spacing: 22) {
				NullSignSettingsIntro(
					systemImage: "arrow.triangle.swap",
					title: "New Replacement Rule",
					detail: "When an imported app matches the original value exactly, NullSign uses the replacement while signing."
				)

				NullSignSettingsSection("Rule") {
					VStack(alignment: .leading, spacing: 6) {
						Text("Match")
							.font(.caption.weight(.semibold))
							.foregroundStyle(.secondary)
						TextField("Original value", text: $_newKey)
							.textInputAutocapitalization(.never)
							.autocorrectionDisabled()
					}

					NullSignSettingsDivider()

					VStack(alignment: .leading, spacing: 6) {
						Text("Replace With")
							.font(.caption.weight(.semibold))
							.foregroundStyle(.secondary)
						TextField("New value", text: $_newValue)
							.textInputAutocapitalization(.never)
							.autocorrectionDisabled()
					}
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 12)
			.padding(.bottom, 28)
		}
		.background(Color.black.ignoresSafeArea())
		.navigationTitle("New Rule")
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			NBToolbarButton(
				"Save",
				style: .text,
				placement: .confirmationAction,
				isDisabled: saveButtonDisabled
			) {
				if dataDict[normalizedKey] != nil {
					_showOverrideAlert = true
				} else {
					_save()
				}
			}
		}
		.alert("Replace Existing Rule?", isPresented: $_showOverrideAlert) {
			Button("Cancel", role: .cancel) { }
			Button("Replace") { _save() }
		} message: {
			Text("A rule already matches “\(normalizedKey)”.")
		}
	}

	private func _save() {
		dataDict[normalizedKey] = normalizedValue
		OptionsManager.shared.saveOptions()
		dismiss()
	}
}
