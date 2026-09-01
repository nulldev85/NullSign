import SwiftUI
import AltSourceKit
import NukeUI

struct SourcesCellView: View {
	let source: AltSource
	let repository: ASRepository?
	let isFetching: Bool
	let didFail: Bool

	var body: some View {
		HStack(spacing: 13) {
			_sourceIcon

			VStack(alignment: .leading, spacing: 5) {
				Text(source.name ?? repository?.name ?? .localized("Unknown"))
					.font(.body.weight(.semibold))
					.foregroundStyle(.primary)
					.lineLimit(1)

				Text(_displayHost)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)

				_status
			}

			Spacer(minLength: 8)
		}
		.padding(.vertical, 9)
		.contentShape(Rectangle())
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
	private var _sourceIcon: some View {
		if let iconURL = source.iconURL ?? repository?.currentIconURL {
			LazyImage(url: iconURL) { state in
				if let image = state.image {
					image.appIconStyle(size: 50, isCircle: false, background: NullSignStyle.raisedPanel)
				} else {
					_placeholderIcon
				}
			}
		} else {
			_placeholderIcon
		}
	}

	private var _placeholderIcon: some View {
		ZStack {
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.fill(NullSignStyle.raisedPanel)
			Image(systemName: "shippingbox")
				.font(.system(size: 20, weight: .medium))
				.foregroundStyle(NullSignStyle.cyan)
		}
		.frame(width: 50, height: 50)
		.overlay {
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.stroke(NullSignStyle.hairline, lineWidth: 1)
		}
	}

	@ViewBuilder
	private var _status: some View {
		if let repository {
			HStack(spacing: 5) {
				if isFetching && !didFail {
					ProgressView().controlSize(.mini).tint(NullSignStyle.cyan)
				} else {
					Circle()
						.fill(didFail ? Color.orange : NullSignStyle.cyan)
						.frame(width: 5, height: 5)
				}
				Text(_loadedStatus(repository.apps.count))
			}
			.font(.caption2.weight(.medium))
			.foregroundStyle(didFail ? Color.orange : Color.secondary)
		} else if isFetching && !didFail {
			HStack(spacing: 6) {
				ProgressView().controlSize(.mini).tint(NullSignStyle.cyan)
				Text("Updating")
			}
			.font(.caption2)
			.foregroundStyle(.secondary)
		} else if didFail {
			Label("Unavailable — pull to retry", systemImage: "exclamationmark.circle")
				.font(.caption2)
				.foregroundStyle(.orange)
		} else {
			Text("Waiting to update")
				.font(.caption2)
				.foregroundStyle(.secondary)
		}
	}

	private func _loadedStatus(_ count: Int) -> String {
		if didFail { return "\(count.formatted()) apps cached — update failed" }
		if isFetching { return "\(count.formatted()) apps — updating" }
		return .localized("%lld Apps", arguments: count)
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
