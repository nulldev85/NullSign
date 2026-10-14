import SwiftUI

struct ConfigurationDictView: View {
	@State private var _isAddingPresenting = false
	@State private var _isRuleMenuPresenting = false
	@State private var _actionRuleKey: String?
	@State private var _pendingDeleteRule: String?

	let title: String
	@Binding var dataDict: [String: String]

	var body: some View {
		ScrollView {
			LazyVStack(spacing: 12) {
				NullSignSettingsCard {
					HStack(spacing: 12) {
						VStack(alignment: .leading, spacing: 3) {
							Text(title)
								.font(.roundedUI(.headline))
							Text("\(dataDict.count) automatic \(dataDict.count == 1 ? "rule" : "rules")")
								.font(.roundedUI(.subheadline))
								.foregroundStyle(.secondary)
						}
						Spacer()
						Button {
							_isAddingPresenting = true
						} label: {
							Label("Add", systemImage: "plus")
						}
						.buttonStyle(NullSignPrimaryButtonStyle(height: 36))
					}
				}

				if dataDict.isEmpty {
					VStack(spacing: 9) {
						Image(systemName: "arrow.triangle.swap")
							.font(.roundedUI(.title2, weight: .regular))
							.foregroundStyle(NullSignStyle.accent)
						Text("No rules configured")
							.font(.roundedUI(.headline))
						Text("Apps keep their original value unless a matching rule is added.")
							.font(.roundedUI(.subheadline))
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
		.nullSignPage()
		.nullSignNavigationTitle(title)
		.navigationDestination(isPresented: $_isAddingPresenting) {
			ConfigurationDictAddView(dataDict: $dataDict)
		}
		.sheet(isPresented: $_isRuleMenuPresenting, onDismiss: _deleteRequestedRule) {
			NullSignMenuSheet(title: "Rule Actions", systemImage: "doc.text", detail: _actionRuleKey) {
				NullSignSettingsCard {
					NullSignMenuAction(title: "Delete", systemImage: "trash", isDestructive: true) {
						_pendingDeleteRule = _actionRuleKey
						_isRuleMenuPresenting = false
					}
				}
			}
		}
	}

	private func _ruleRow(key: String, value: String) -> some View {
		HStack(spacing: 12) {
			VStack(alignment: .leading, spacing: 6) {
				Text(key)
					.font(.roundedUI(.subheadline, weight: .regular))
					.foregroundStyle(.secondary)
					.lineLimit(1)
				HStack(spacing: 7) {
					Image(systemName: "arrow.right")
						.font(.roundedUI(.caption, weight: .semibold))
						.foregroundStyle(NullSignStyle.accent)
					Text(value)
						.font(.roundedUI(.body, weight: .bold))
						.lineLimit(2)
				}
			}
			Spacer()
			Button {
				_actionRuleKey = key
				_isRuleMenuPresenting = true
			} label: {
				Image(systemName: "ellipsis")
					.font(.roundedUI(.body, weight: .semibold))
					.foregroundStyle(.secondary)
					.frame(width: 40, height: 40)
			}
			.buttonStyle(.plain)
		}
		.padding(14)
		.background(NullSignStyle.panel)
		.overlay {
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.stroke(NullSignStyle.hairline, lineWidth: 1)
		}
		.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
	}

	private func _deleteRequestedRule() {
		guard let key = _pendingDeleteRule else { return }
		_pendingDeleteRule = nil
		guard dataDict.removeValue(forKey: key) != nil else { return }
		OptionsManager.shared.saveOptions()
	}
}
