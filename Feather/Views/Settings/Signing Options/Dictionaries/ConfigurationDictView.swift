import SwiftUI

struct ConfigurationDictView: View {
	@State private var _isAddingPresenting = false

	let title: String
	@Binding var dataDict: [String: String]

	var body: some View {
		ScrollView {
			LazyVStack(spacing: 12) {
				NullSignSettingsCard {
					HStack(spacing: 12) {
						VStack(alignment: .leading, spacing: 3) {
							Text(title)
								.font(.headline)
							Text("\(dataDict.count) automatic \(dataDict.count == 1 ? "rule" : "rules")")
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
						Spacer()
						Button {
							_isAddingPresenting = true
						} label: {
							Label("Add", systemImage: "plus")
								.font(.subheadline.weight(.semibold))
								.foregroundStyle(.black)
								.padding(.horizontal, 12)
								.frame(height: 36)
								.background(NullSignStyle.cyan)
								.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
						}
						.buttonStyle(.plain)
					}
				}

				if dataDict.isEmpty {
					VStack(spacing: 9) {
						Image(systemName: "arrow.triangle.swap")
							.font(.title2)
							.foregroundStyle(NullSignStyle.cyan)
						Text("No rules configured")
							.font(.headline)
						Text("Apps keep their original value unless a matching rule is added.")
							.font(.subheadline)
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.center)
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, 34)
					.padding(.horizontal, 20)
					.background(NullSignStyle.panel)
					.overlay {
						RoundedRectangle(cornerRadius: 18, style: .continuous)
							.stroke(NullSignStyle.hairline, lineWidth: 1)
					}
					.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
				} else {
					ForEach(dataDict.sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }), id: \.key) { key, value in
						_ruleRow(key: key, value: value)
					}
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 12)
			.padding(.bottom, 28)
		}
		.background(Color.black.ignoresSafeArea())
		.navigationTitle(title)
		.navigationDestination(isPresented: $_isAddingPresenting) {
			ConfigurationDictAddView(dataDict: $dataDict)
		}
	}

	private func _ruleRow(key: String, value: String) -> some View {
		HStack(spacing: 12) {
			VStack(alignment: .leading, spacing: 6) {
				Text(key)
					.font(.subheadline.weight(.medium))
					.foregroundStyle(.secondary)
					.lineLimit(1)
				HStack(spacing: 7) {
					Image(systemName: "arrow.right")
						.font(.caption.weight(.semibold))
						.foregroundStyle(NullSignStyle.cyan)
					Text(value)
						.font(.body.weight(.semibold))
						.lineLimit(2)
				}
			}
			Spacer()
			Menu {
				Button("Delete", systemImage: "trash", role: .destructive) {
					dataDict.removeValue(forKey: key)
					OptionsManager.shared.saveOptions()
				}
			} label: {
				Image(systemName: "ellipsis")
					.font(.body.weight(.semibold))
					.foregroundStyle(.secondary)
					.frame(width: 40, height: 40)
			}
		}
		.padding(14)
		.background(NullSignStyle.panel)
		.overlay {
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.stroke(NullSignStyle.hairline, lineWidth: 1)
		}
		.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
	}
}
