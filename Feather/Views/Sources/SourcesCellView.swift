import SwiftUI
import AltSourceKit
import NukeUI

struct SourcesCellView: View {
	let source: AltSource
	let repository: ASRepository?
	let isFetching: Bool
	let didFail: Bool

	var body: some View {
		HStack(spacing: 14) {
			SourceRemoteIcon(url: source.iconURL ?? repository?.currentIconURL, size: 50)

			VStack(alignment: .leading, spacing: 5) {
				Text(source.name ?? repository?.name ?? .localized("Unknown"))
					.font(.system(size: 16, weight: .semibold))
					.foregroundStyle(.white)
					.lineLimit(1)

				Text(_displayHost)
					.font(NullSignStyle.mono(11, weight: .medium))
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)

				_status
			}

			Spacer(minLength: 8)

			Image(systemName: "chevron.right")
				.font(.system(size: 13, weight: .bold))
				.foregroundStyle(NullSignStyle.faint)
		}
		.padding(12)
		.nullSignSurface(cornerRadius: 22)
		.contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
		.contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 22, style: .continuous))
		.swipeActions {
			_actions(for: source)
			_contextActions(for: source)
		}
		.contextMenu {
			_contextActions(for: source)
			Divider()
			_actions(for: source)
		}
	}

	@ViewBuilder
	private var _status: some View {
		if let repository {
			if isFetching && !didFail {
				NullSignChip(text: "\(repository.apps.count) apps · updating", systemImage: "arrow.triangle.2.circlepath", tint: NullSignStyle.muted)
			} else if didFail {
				NullSignChip(text: "\(repository.apps.count) cached · offline", systemImage: "exclamationmark", tint: NullSignStyle.warning)
			} else {
				NullSignChip(text: .localized("%lld Apps", arguments: repository.apps.count), systemImage: "checkmark", tint: NullSignStyle.success)
			}
		} else if isFetching && !didFail {
			HStack(spacing: 6) {
				ProgressView()
					.controlSize(.mini)
					.tint(NullSignStyle.accent)
				Text("UPDATING")
					.font(NullSignStyle.mono(9.5, weight: .bold))
					.foregroundStyle(NullSignStyle.muted)
			}
		} else if didFail {
			NullSignChip(text: "Unavailable · pull to retry", systemImage: "exclamationmark", tint: NullSignStyle.danger)
		} else {
			NullSignChip(text: "Waiting", tint: NullSignStyle.muted)
		}
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
	}

	@ViewBuilder
	private func _contextActions(for source: AltSource) -> some View {
		Button(.localized("Copy"), systemImage: "doc.on.clipboard") {
			UIPasteboard.general.string = source.sourceURL?.absoluteString
		}
	}
}
