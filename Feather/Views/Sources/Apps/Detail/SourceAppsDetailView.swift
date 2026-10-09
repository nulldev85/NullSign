import SwiftUI
import AltSourceKit
import NimbleViews
import NukeUI

struct SourceAppsDetailView: View {
	@State private var _isScreenshotPreviewPresented = false
	@State private var _selectedScreenshotIndex = 0

	let sourceURL: URL?
	let source: ASRepository
	let app: ASRepository.App

	var body: some View {
		ScrollView {
			LazyVStack(alignment: .leading, spacing: 26) {
				_header

				if let screenshots = app.screenshotURLs, !screenshots.isEmpty {
					_detailSection(.localized("Screenshots")) {
						_screenshots(screenshots)
					}
				}

				if let version = app.currentVersion,
				   let notes = app.currentAppVersion?.localizedDescription,
				   !notes.isEmpty {
					_detailSection(.localized("What's New")) {
						VStack(alignment: .leading, spacing: 12) {
							AppVersionInfo(version: version, date: app.currentDate?.date, description: notes)
							if let versions = app.versions, versions.count > 1 {
								NavigationLink {
									VersionHistoryView(sourceURL: sourceURL, source: source, app: app, versions: versions)
										.navigationTitle(.localized("Version History"))
										.navigationBarTitleDisplayMode(.inline)
								} label: {
									HStack {
										Text(.localized("Version History"))
										Spacer()
										Image(systemName: "chevron.right")
											.font(.footnote.weight(.semibold))
									}
									.foregroundStyle(NullSignStyle.accent)
								}
								.buttonStyle(.plain)
							}
						}
						.sourcePanel(padding: 16)
					}
				}

				if let description = app.localizedDescription, !description.isEmpty {
					_detailSection(.localized("About")) {
						ExpandableText(text: description, lineLimit: 5)
							.font(.subheadline)
							.foregroundStyle(NullSignStyle.muted)
							.frame(maxWidth: .infinity, alignment: .leading)
							.sourcePanel(padding: 16)
					}
				}

				_detailSection(.localized("Information")) {
					VStack(spacing: 0) {
						_infoRows
					}
					.sourcePanel(padding: 0)
				}

				if let permissions = app.appPermissions {
					_detailSection(.localized("Permissions")) {
						_permissions(permissions)
							.sourcePanel(padding: 16)
					}
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 8)
			.padding(.bottom, 36)
		}
		.background(Color.black)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			NBToolbarButton(systemImage: "square.and.arrow.up", placement: .topBarTrailing) {
				_share()
			}
		}
		.tint(.white)
		.fullScreenCover(isPresented: $_isScreenshotPreviewPresented) {
			if let screenshots = app.screenshotURLs {
				ScreenshotPreviewView(screenshotURLs: screenshots, initialIndex: _selectedScreenshotIndex)
			}
		}
	}

	private var _header: some View {
		HStack(alignment: .top, spacing: 16) {
			SourceRemoteIcon(url: app.iconURL, size: 100, placeholderSystemImage: "app.dashed")

			VStack(alignment: .leading, spacing: 4) {
				Text(app.currentName)
					.font(.title2.weight(.bold))
					.lineLimit(2)

				if let developer = app.developer, !developer.isEmpty {
					Text(developer)
						.font(.subheadline)
						.foregroundStyle(NullSignStyle.muted)
						.lineLimit(1)
				}

				if let summary = app.subtitle ?? app.description, !summary.isEmpty {
					Text(summary)
						.font(.footnote)
						.foregroundStyle(NullSignStyle.faint)
						.lineLimit(2)
				}

				Spacer(minLength: 8)

				DownloadButtonView(sourceURL: sourceURL, source: source, app: app)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}

	@ViewBuilder
	private func _detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			SourceSectionLabel(title: title)
			content()
		}
	}

	@ViewBuilder
	private var _infoRows: some View {
		ForEach(_informationItems.indices, id: \.self) { index in
			let item = _informationItems[index]
			_infoRow(item.title, item.value, isLast: index == _informationItems.count - 1)
		}
	}

	private var _informationItems: [(title: String, value: String)] {
		var items: [(String, String)] = []
		if let name = source.name { items.append((.localized("Source"), name)) }
		if let developer = app.developer { items.append((.localized("Developer"), developer)) }
		if let size = app.size { items.append((.localized("Size"), size.formattedByteCount)) }
		if let category = app.category { items.append((.localized("Category"), category.capitalized)) }
		if let version = app.currentVersion { items.append((.localized("Version"), version)) }
		if let date = app.currentDate?.date {
			items.append((.localized("Updated"), DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)))
		}
		if let bundleID = app.id { items.append((.localized("Identifier"), bundleID)) }
		return items
	}

	private func _infoRow(_ title: String, _ value: String, isLast: Bool = false) -> some View {
		VStack(spacing: 0) {
			HStack(alignment: .firstTextBaseline, spacing: 14) {
				Text(title)
					.foregroundStyle(NullSignStyle.muted)
				Spacer()
				Text(value)
					.multilineTextAlignment(.trailing)
					.textSelection(.enabled)
			}
			.font(.subheadline)
			.padding(.horizontal, 14)
			.padding(.vertical, 12)
			if !isLast {
				Rectangle()
					.fill(NullSignStyle.hairline)
					.frame(height: 1)
					.padding(.leading, 14)
			}
		}
	}

	private func _permissions(_ permissions: ASRepository.AppPermissions) -> some View {
		VStack(alignment: .leading, spacing: 16) {
			if let entitlements = permissions.entitlements, !entitlements.isEmpty {
				_permissionGroup(
					icon: "checkmark.shield",
					title: .localized("Entitlements"),
					value: entitlements.map(\.name).joined(separator: "\n")
				)
			}

			if let privacy = permissions.privacy, !privacy.isEmpty {
				ForEach(privacy, id: \.self) { item in
					_permissionGroup(icon: "hand.raised", title: item.name, value: item.usageDescription)
				}
			}

			if permissions.entitlements?.isEmpty != false && permissions.privacy?.isEmpty != false {
				Text(.localized("No permissions are listed by this source."))
					.font(.subheadline)
					.foregroundStyle(NullSignStyle.muted)
			}
		}
	}

	private func _permissionGroup(icon: String, title: String, value: String) -> some View {
		HStack(alignment: .top, spacing: 12) {
			NullSignIconTile(systemImage: icon)
			VStack(alignment: .leading, spacing: 3) {
				Text(title).font(.subheadline.weight(.semibold))
				Text(value)
					.font(.footnote)
					.foregroundStyle(NullSignStyle.muted)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}

	private func _screenshots(_ urls: [URL]) -> some View {
		ScrollView(.horizontal, showsIndicators: false) {
			LazyHStack(spacing: 12) {
				ForEach(urls.indices, id: \.self) { index in
					LazyImage(url: urls[index]) { state in
						if let image = state.image {
							image
								.resizable()
								.aspectRatio(contentMode: .fit)
								.frame(maxWidth: 250, maxHeight: 400)
								.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
								.overlay {
									RoundedRectangle(cornerRadius: 16, style: .continuous)
										.strokeBorder(NullSignStyle.hairline, lineWidth: 1)
								}
								.onTapGesture {
									_selectedScreenshotIndex = index
									_isScreenshotPreviewPresented = true
								}
						} else {
							RoundedRectangle(cornerRadius: 16, style: .continuous)
								.fill(NullSignStyle.surface)
								.frame(width: 210, height: 380)
								.overlay(ProgressView())
						}
					}
				}
			}
			.padding(.horizontal, 16)
		}
		.padding(.horizontal, -16)
	}

	private func _share() {
		let text = """
		\(app.currentName) — \(app.currentVersion ?? "")
		\(app.currentDescription ?? "")
		\(source.website?.absoluteString ?? source.name ?? "")
		"""
		UIActivityViewController.show(activityItems: [text])
	}
}
