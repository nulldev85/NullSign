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
			LazyVStack(alignment: .leading, spacing: 24) {
				_hero

				if let screenshots = app.screenshotURLs, !screenshots.isEmpty {
					_detailSection(.localized("Screenshots")) {
						_screenshots(screenshots)
					}
				}

				if let version = app.currentVersion,
				   let notes = app.currentAppVersion?.localizedDescription,
				   !notes.isEmpty {
					_detailSection(.localized("What's New")) {
						VStack(alignment: .leading, spacing: 14) {
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
										Image(systemName: "arrow.right")
											.font(.caption.weight(.bold))
									}
									.font(.system(size: 14, weight: .bold))
									.foregroundStyle(NullSignStyle.accentHighlight)
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
					_infoGrid
				}

				if let permissions = app.appPermissions {
					_detailSection(.localized("Permissions")) {
						_permissions(permissions)
							.sourcePanel(padding: 16)
					}
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 6)
			.padding(.bottom, 36)
		}
		.background(NullSignBackdrop(intensity: 0.7))
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

	/// Centered identity lit by a blurred wash of the app's own icon.
	private var _hero: some View {
		VStack(spacing: 16) {
			SourceRemoteIcon(url: app.iconURL, size: 104, placeholderSystemImage: "app.dashed")
				.shadow(color: .black.opacity(0.5), radius: 18, y: 10)

			VStack(spacing: 6) {
				Text(app.currentName)
					.font(NullSignStyle.display(24, weight: .bold))
					.multilineTextAlignment(.center)
					.lineLimit(2)

				if let developer = app.developer, !developer.isEmpty {
					Text(developer)
						.font(.system(size: 14, weight: .semibold))
						.foregroundStyle(NullSignStyle.accentHighlight)
				}

				if let summary = app.subtitle ?? app.description, !summary.isEmpty {
					Text(summary)
						.font(.subheadline)
						.foregroundStyle(NullSignStyle.muted)
						.multilineTextAlignment(.center)
						.lineLimit(2)
						.padding(.horizontal, 8)
				}
			}

			HStack(spacing: 6) {
				if let version = app.currentVersion {
					NullSignChip(text: "v\(version)", systemImage: "tag.fill", uppercased: false)
				}
				if let size = app.size {
					NullSignChip(text: size.formattedByteCount, systemImage: "archivebox.fill", uppercased: false)
				}
				if let category = app.category {
					NullSignChip(text: category.capitalized, tint: NullSignStyle.violet, uppercased: false)
				}
			}

			DownloadButtonView(sourceURL: sourceURL, source: source, app: app)
				.scaleEffect(1.15)
				.padding(.top, 2)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 26)
		.padding(.horizontal, 16)
		.background {
			ZStack {
				if let iconURL = app.iconURL {
					LazyImage(url: iconURL) { state in
						if let image = state.image {
							image
								.resizable()
								.scaledToFill()
								.blur(radius: 46)
								.opacity(0.55)
						} else {
							Color.clear
						}
					}
				}
				LinearGradient(
					colors: [Color.black.opacity(0.1), Color.black.opacity(0.65)],
					startPoint: .top,
					endPoint: .bottom
				)
			}
		}
		.nullSignSurface(cornerRadius: 30)
	}

	@ViewBuilder
	private func _detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			SourceSectionLabel(title: title)
				.padding(.horizontal, 6)
			content()
		}
	}

	private var _infoGrid: some View {
		LazyVGrid(
			columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
			spacing: 10
		) {
			ForEach(_informationItems.indices, id: \.self) { index in
				let item = _informationItems[index]
				VStack(alignment: .leading, spacing: 5) {
					Text(item.title.uppercased())
						.font(NullSignStyle.mono(9.5, weight: .bold))
						.tracking(0.8)
						.foregroundStyle(NullSignStyle.faint)
					Text(item.value)
						.font(.system(size: 14, weight: .semibold))
						.foregroundStyle(.white)
						.lineLimit(2)
						.minimumScaleFactor(0.8)
						.textSelection(.enabled)
				}
				.frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
				.padding(13)
				.nullSignSurface(cornerRadius: 18)
			}
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
			NullSignIconTile(systemImage: icon, size: 30)
			VStack(alignment: .leading, spacing: 3) {
				Text(title).font(.system(size: 14, weight: .semibold))
				Text(value)
					.font(.caption)
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
								.background(NullSignStyle.panel)
								.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
								.overlay {
									RoundedRectangle(cornerRadius: 20, style: .continuous)
										.strokeBorder(NullSignStyle.edge, lineWidth: 1)
								}
								.onTapGesture {
									_selectedScreenshotIndex = index
									_isScreenshotPreviewPresented = true
								}
						} else {
							RoundedRectangle(cornerRadius: 20, style: .continuous)
								.fill(NullSignStyle.panel)
								.frame(width: 210, height: 380)
								.overlay(ProgressView().tint(NullSignStyle.accent))
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
