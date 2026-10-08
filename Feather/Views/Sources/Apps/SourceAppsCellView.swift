import SwiftUI
import AltSourceKit
import NukeUI

struct SourceAppsCellView: View {
	@AppStorage("Feather.storeCellAppearance") private var _storeCellAppearance: Int = 0

	let sourceURL: URL?
	let source: ASRepository
	let app: ASRepository.App

	var body: some View {
		HStack(alignment: .center, spacing: 14) {
			SourceRemoteIcon(url: app.iconURL, size: 58, placeholderSystemImage: "app.dashed")

			VStack(alignment: .leading, spacing: 5) {
				Text(app.currentName)
					.font(.system(size: 16, weight: .semibold))
					.foregroundStyle(.white)
					.lineLimit(1)

				Text(Self.appDescription(app: app))
					.font(.caption)
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(_storeCellAppearance == 0 ? 1 : 2)

				HStack(spacing: 5) {
					if let version = app.currentVersion, !version.isEmpty {
						NullSignChip(text: "v\(version)", uppercased: false)
					}
					if let sourceName = source.name, !sourceName.isEmpty {
						Text(sourceName)
							.font(NullSignStyle.mono(10, weight: .medium))
							.foregroundStyle(NullSignStyle.faint)
							.lineLimit(1)
					}
				}
			}

			Spacer(minLength: 6)

			DownloadButtonView(sourceURL: sourceURL, source: source, app: app)
		}
		.padding(12)
		.nullSignSurface(cornerRadius: 22)
		.padding(.horizontal, 16)
		.padding(.vertical, 5)
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
