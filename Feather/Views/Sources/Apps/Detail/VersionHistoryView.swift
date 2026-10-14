import SwiftUI
import UIKit
import AltSourceKit

struct VersionHistoryView: View {
	@Environment(\.dismiss) private var dismiss
	@State private var copiedURL: URL?

	let sourceURL: URL?
	let source: ASRepository
	let app: ASRepository.App
	let versions: [ASRepository.App.Version]

	var body: some View {
		ScrollView {
			VStack(spacing: 0) {
				ForEach(Array(versions.enumerated()), id: \.element.id) { index, version in
					VersionHistoryRow(version: version, copiedURL: $copiedURL) { url in
						_download(version, from: url)
					}
					if index < versions.count - 1 {
						Divider().overlay(NullSignStyle.hairline).padding(.leading, 14)
					}
				}
			}
			.sourcePanel(padding: 0)
			.padding(16)
		}
		.nullSignPage()
		.tint(NullSignStyle.accent)
	}

	private func _download(_ version: ASRepository.App.Version, from url: URL) {
		_ = DownloadManager.shared.startDownload(
			from: url,
			id: app.currentUniqueId,
			sourceProvenance: SourceAppProvenance(
				sourceURL: sourceURL,
				repository: source,
				app: app,
				version: version
			)
		)
		dismiss()
	}
}

/// Separate the row and action buttons so Swift does not infer one large
/// nested ForEach/HStack/VStack/Button expression.
private struct VersionHistoryRow: View {
	let version: ASRepository.App.Version
	@Binding var copiedURL: URL?
	let onDownload: (URL) -> Void

	var body: some View {
		HStack(alignment: .top, spacing: 12) {
			AppVersionInfo(
				version: version.version,
				date: version.date?.date,
				description: version.localizedDescription ?? .localized("No release notes available")
			)
			if let url = version.downloadURL {
				VersionHistoryActions(
					url: url, versionName: version.version,
					copiedURL: $copiedURL, onDownload: { onDownload(url) }
				)
			}
		}
		.padding(14)
	}
}

private struct VersionHistoryActions: View {
	let url: URL
	let versionName: String
	@Binding var copiedURL: URL?
	let onDownload: () -> Void

	private var downloadLabel: String {
		.localized("Download Version %1$@", arguments: versionName)
	}

	private var copyLabel: String {
		copiedURL == url ? .localized("Copied") : .localized("Copy Download URL")
	}

	var body: some View {
		VStack(spacing: 8) {
			downloadButton
			copyButton
		}
	}

	private var downloadButton: some View {
		Button(action: onDownload) {
			Image(systemName: "arrow.down")
				.font(.roundedUI(size: 13, weight: .semibold))
		}
		.buttonStyle(NullSignPrimaryButtonStyle(height: 34))
		.accessibilityLabel(Text(downloadLabel))
	}

	private var copyButton: some View {
		Button(action: copyURL) {
			Image(systemName: copiedURL == url ? "checkmark" : "doc.on.clipboard")
				.font(.roundedUI(size: 13, weight: .semibold))
		}
		.buttonStyle(NullSignSecondaryButtonStyle(height: 34))
		.accessibilityLabel(Text(copyLabel))
	}

	private func copyURL() {
		UIPasteboard.general.string = url.absoluteString
		copiedURL = url
		UINotificationFeedbackGenerator().notificationOccurred(.success)
	}
}
