import SwiftUI
import AltSourceKit
import NukeUI

struct SourcesCellView: View {
	let source: AltSource
	let repository: ASRepository?
	let isFetching: Bool
	let didFail: Bool

	var body: some View {
		HStack(spacing: 12) {
			SourceRemoteIcon(url: source.iconURL ?? repository?.currentIconURL, size: 46)

			VStack(alignment: .leading, spacing: 2) {
				Text(source.name ?? repository?.name ?? .localized("Unknown"))
					.font(.headline)
					.foregroundStyle(.white)
					.lineLimit(1)

				Text(_displayHost)
					.font(.subheadline)
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)

				_status
					.padding(.top, 2)
			}

			Spacer(minLength: 8)

			Image(systemName: "chevron.right")
				.font(.footnote.weight(.semibold))
				.foregroundStyle(NullSignStyle.faint)
		}
		.padding(12)
		.nullSignSurface()
		.contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		.contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 16, style: .continuous))
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
				.font(.caption)
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
	}

	@ViewBuilder
	private func _contextActions(for source: AltSource) -> some View {
		Button(.localized("Copy"), systemImage: "doc.on.clipboard") {
			UIPasteboard.general.string = source.sourceURL?.absoluteString
		}
	}
}
