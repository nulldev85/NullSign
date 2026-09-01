import SwiftUI
import AltSourceKit
import NukeUI

struct SourceAppsCellView: View {
	@AppStorage("Feather.storeCellAppearance") private var _storeCellAppearance: Int = 0

	let sourceURL: URL?
	let source: ASRepository
	let app: ASRepository.App

	var body: some View {
		HStack(alignment: .top, spacing: 13) {
			_appIcon

			VStack(alignment: .leading, spacing: 5) {
				Text(app.currentName)
					.font(.body.weight(.semibold))
					.lineLimit(1)

				Text(Self.appDescription(app: app))
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(_storeCellAppearance == 0 ? 1 : 2)

				HStack(spacing: 6) {
					if let version = app.currentVersion, !version.isEmpty {
						Text("v\(version)")
					}
					if app.currentVersion?.isEmpty == false, source.name?.isEmpty == false {
						Circle().fill(Color.secondary.opacity(0.65)).frame(width: 3, height: 3)
					}
					if let sourceName = source.name {
						Text(sourceName)
					}
				}
				.font(.caption2.weight(.medium))
				.foregroundStyle(.secondary)
				.lineLimit(1)
			}

			Spacer(minLength: 5)

			DownloadButtonView(sourceURL: sourceURL, source: source, app: app)
				.padding(.top, 8)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 12)
		.overlay(alignment: .bottom) {
			Rectangle()
				.fill(NullSignStyle.hairline)
				.frame(height: 1)
				.padding(.leading, 87)
		}
	}

	@ViewBuilder
	private var _appIcon: some View {
		if let iconURL = app.iconURL {
			LazyImage(url: iconURL) { state in
				if let image = state.image {
					image.appIconStyle(size: 58, isCircle: false, background: NullSignStyle.raisedPanel)
				} else {
					_placeholderIcon
				}
			}
		} else {
			_placeholderIcon
		}
	}

	private var _placeholderIcon: some View {
		Image("App_Unknown")
			.appIconStyle(size: 58, isCircle: false, background: NullSignStyle.raisedPanel)
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
