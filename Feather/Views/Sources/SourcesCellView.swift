import SwiftUI
import AltSourceKit

struct SourcesCellView: View {
	@State private var _isActionsPresenting = false
	@State private var _didCopyURL = false
	@State private var _deleteAfterDismissal = false
	let source: AltSource
	let repository: ASRepository?
	let isFetching: Bool
	let didFail: Bool
	let onSelect: () -> Void

	var body: some View {
		HStack(spacing: 12) {
			SourceRemoteIcon(
				url: source.iconURL ?? repository?.currentIconURL,
				relativeTo: source.sourceURL,
				size: 46,
				fallbackAssetName: SourceBundledIcon.assetName(for: repository)
			)

			VStack(alignment: .leading, spacing: 2) {
				Text(source.name ?? repository?.name ?? .localized("Unknown"))
					.font(.roundedUI(.headline))
					.foregroundStyle(.white)
					.lineLimit(1)

				Text(_displayHost)
					.font(.roundedUI(.subheadline))
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)

				_status
					.padding(.top, 2)
			}

			Spacer(minLength: 8)

			Image(systemName: "chevron.right")
				.font(.roundedUI(.footnote, weight: .semibold))
				.foregroundStyle(NullSignStyle.faint)
		}
		.padding(16)
		.nullSignSurface()
		.contentShape(RoundedRectangle(cornerRadius: NullSignStyle.cardRadius, style: .continuous))
		.swipeActions {
			_actions(for: source)
			_contextActions(for: source)
		}
		.gesture(
			LongPressGesture().exclusively(before: TapGesture()).onEnded { value in
				switch value {
				case .first:
					_didCopyURL = false
					UIImpactFeedbackGenerator(style: .light).impactOccurred()
					_isActionsPresenting = true
				case .second: onSelect()
				}
			}
		)
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(.isButton)
		.accessibilityAction { onSelect() }
		.accessibilityAction(named: Text(.localized("Repository Actions"))) {
			_didCopyURL = false
			_isActionsPresenting = true
		}
		.sheet(isPresented: $_isActionsPresenting, onDismiss: _deleteRequestedSource) {
			NullSignMenuSheet(
				title: source.name ?? repository?.name ?? .localized("Repository"),
				systemImage: "externaldrive.connected.to.line.below", detail: _displayHost
			) {
				NullSignSettingsCard {
					NullSignMenuAction(
						title: _didCopyURL ? .localized("Copied") : .localized("Copy Source URL"),
						systemImage: _didCopyURL ? "checkmark" : "doc.on.clipboard",
						isDisabled: source.sourceURL == nil
					) {
						UIPasteboard.general.string = source.sourceURL?.absoluteString
						_didCopyURL = true
						UINotificationFeedbackGenerator().notificationOccurred(.success)
					}
					NullSignSettingsDivider()
					NullSignMenuAction(title: .localized("Delete"), systemImage: "trash", isDestructive: true) {
						_deleteAfterDismissal = true
						_isActionsPresenting = false
					}
				}
			}
		}
	}

	private func _deleteRequestedSource() {
		guard _deleteAfterDismissal else { return }
		_deleteAfterDismissal = false
		guard source.managedObjectContext != nil, !source.isDeleted else { return }
		Storage.shared.deleteSource(for: source)
	}

	@ViewBuilder
	private var _status: some View {
		HStack(spacing: 6) {
			if isFetching && !didFail {
				ProgressView()
					.controlSize(.mini)
			} else {
				Circle()
					.fill(didFail ? NullSignStyle.danger : NullSignStyle.success)
					.frame(width: 6, height: 6)
			}
			Text(_statusText)
				.font(.roundedUI(.caption))
				.foregroundStyle(didFail ? NullSignStyle.danger : NullSignStyle.muted)
				.lineLimit(1)
		}
	}

	private var _statusText: String {
		guard let repository else {
			if didFail { return "Couldn't load · pull to retry" }
			return isFetching ? "Updating…" : "Waiting to update"
		}
		let count = repository.apps.count == 1 ? "1 app" : "\(repository.apps.count.formatted()) apps"
		if didFail { return "\(count) · offline" }
		return count
	}

	private var _displayHost: String {
		guard let url = source.sourceURL else { return .localized("Repository") }
		return url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
	}
}

extension SourcesCellView {
	@ViewBuilder
	private func _actions(for source: AltSource) -> some View {
		Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteSource(for: source)
		}
		.tint(NullSignStyle.danger)
	}

	@ViewBuilder
	private func _contextActions(for source: AltSource) -> some View {
		Button(.localized("Copy"), systemImage: "doc.on.clipboard") {
			UIPasteboard.general.string = source.sourceURL?.absoluteString
			UINotificationFeedbackGenerator().notificationOccurred(.success)
		}
		.tint(NullSignStyle.accent)
	}
}
