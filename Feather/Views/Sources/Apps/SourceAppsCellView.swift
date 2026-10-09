import SwiftUI
import AltSourceKit
import NukeUI

struct SourceAppsCellView: View {
	@AppStorage("Feather.storeCellAppearance") private var _storeCellAppearance: Int = 0

	let sourceURL: URL?
	let source: ASRepository
	let app: ASRepository.App

	var body: some View {
		HStack(alignment: .center, spacing: 12) {
			SourceRemoteIcon(url: app.iconURL, size: 56, placeholderSystemImage: "app.dashed")

			VStack(alignment: .leading, spacing: 2) {
				Text(app.currentName)
					.font(.headline)
					.foregroundStyle(.white)
					.lineLimit(1)

				Text(Self.appDescription(app: app))
					.font(.subheadline)
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(_storeCellAppearance == 0 ? 1 : 2)

				Text(_footnote)
					.font(.caption)
					.foregroundStyle(NullSignStyle.faint)
					.lineLimit(1)
					.padding(.top, 1)
			}

			Spacer(minLength: 6)

			DownloadButtonView(sourceURL: sourceURL, source: source, app: app)
		}
		.padding(12)
		.nullSignSurface()
		.padding(.horizontal, 16)
		.padding(.vertical, 5)
	}

	private var _footnote: String {
		[app.currentVersion.flatMap { $0.isEmpty ? nil : $0 }, source.name]
			.compactMap { $0 }
			.joined(separator: " · ")
	}

	static func appDescription(app: ASRepository.App) -> String {
		let candidates = [app.subtitle, app.description, app.id]
		for candidate in candidates {
			if let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
				return value
			}
		}
		return .localized("No description provided")
	}
}
