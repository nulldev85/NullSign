import SwiftUI
import AltSourceKit
import UIKit

struct SourceAppActionsView: View {
	@Environment(\.dismiss) private var dismiss
	@State private var copiedIndex: Int?
	@State private var didStartDownload = false
	let route: SourceAppsView.SourceAppRoute

	private struct VersionChoice: Identifiable {
		let id: Int
		let title: String
		let url: URL?
		let version: ASRepository.App.Version?
	}

	private var choices: [VersionChoice] {
		if let versions = route.app.versions, !versions.isEmpty {
			return versions.enumerated().map { index, version in
				VersionChoice(
					id: index, title: version.version.isEmpty ? .localized("Unknown Version") : version.version,
					url: version.downloadURL, version: version
				)
			}
		}
		return [VersionChoice(
			id: 0, title: route.app.currentVersion.flatMap { $0.isEmpty ? nil : $0 } ?? .localized("Current Version"),
			url: route.app.currentDownloadUrl, version: nil
		)]
	}

	var body: some View {
		NullSignMenuSheet(
			title: route.app.currentName, systemImage: "app.badge",
			detail: route.app.id ?? .localized("App Actions")
		) {
			NullSignSettingsSection(.localized("Previous Versions")) {
				ForEach(choices) { choice in
					if choice.id > 0 { NullSignSettingsDivider() }
					NullSignMenuAction(
						title: choice.title, systemImage: "arrow.down.circle",
						detail: choice.url == nil ? .localized("Download unavailable") : .localized("Download this version"),
						isDisabled: choice.url == nil || didStartDownload
					) { download(choice) }
				}
			}
			NullSignSettingsSection(.localized("Copy Download URLs")) {
				ForEach(choices) { choice in
					if choice.id > 0 { NullSignSettingsDivider() }
					NullSignMenuAction(
						title: choice.title,
						systemImage: copiedIndex == choice.id ? "checkmark" : "doc.on.clipboard",
						detail: copiedIndex == choice.id ? .localized("Copied") : (choice.url?.host ?? .localized("Download unavailable")),
						tint: NullSignStyle.success, isDisabled: choice.url == nil
					) {
						guard let url = choice.url else { return }
						UIPasteboard.general.string = url.absoluteString
						copiedIndex = choice.id
						UINotificationFeedbackGenerator().notificationOccurred(.success)
					}
				}
			}
		}
	}

	private func download(_ choice: VersionChoice) {
		guard let url = choice.url, !didStartDownload else { return }
		didStartDownload = true
		_ = DownloadManager.shared.startDownload(
			from: url, id: route.app.currentUniqueId,
			sourceProvenance: SourceAppProvenance(
				sourceURL: route.sourceURL, repository: route.source,
				app: route.app, version: choice.version
			)
		)
		dismiss()
	}
}
