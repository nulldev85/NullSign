import SwiftUI
import AltSourceKit

struct VersionHistoryView: View {
	@Environment(\.dismiss) private var dismiss

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
							Button { _download(version, from: url) } label: {
								Image(systemName: "arrow.down")
									.font(.subheadline.weight(.bold))
									.foregroundStyle(.black)
									.frame(width: 34, height: 34)
									.background(NullSignStyle.accent)
									.clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
							}
							.buttonStyle(.plain)
							.contextMenu {
								Button(.localized("Copy Download URL"), systemImage: "doc.on.clipboard") {
									UIPasteboard.general.string = url.absoluteString
								}
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
