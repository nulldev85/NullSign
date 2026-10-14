import SwiftUI
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
					HStack(alignment: .top, spacing: 12) {
						AppVersionInfo(
							version: version.version,
							date: version.date?.date,
							description: version.localizedDescription ?? .localized("No release notes available")
						)

						if let url = version.downloadURL {
							VStack(spacing: 8) {
								Button { _download(version, from: url) } label: {
									Image(systemName: "arrow.down")
										.font(.roundedUI(size: 13, weight: .semibold))
								}
								.buttonStyle(NullSignPrimaryButtonStyle(height: 34))
								.accessibilityLabel(.localized("Download Version %1$@", arguments: version.version))
								Button {
									UIPasteboard.general.string = url.absoluteString
									copiedURL = url
									UINotificationFeedbackGenerator().notificationOccurred(.success)
								} label: {
									Image(systemName: copiedURL == url ? "checkmark" : "doc.on.clipboard")
										.font(.roundedUI(size: 13, weight: .semibold))
								}
								.buttonStyle(NullSignSecondaryButtonStyle(height: 34))
								.accessibilityLabel(copiedURL == url ? .localized("Copied") : .localized("Copy Download URL"))
							}
						}
					}
					.padding(14)

					if index < versions.count - 1 {
						Divider().overlay(NullSignStyle.hairline).padding(.leading, 14)
					}
				}
			}
			.sourcePanel(padding: 0)
			.padding(16)
		}
		.background(Color.black)
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
