//
//  SourcesAddView.swift
//  NullSign
//
//  Created by samara on 1.05.2025.
//

import SwiftUI
import NimbleViews
import AltSourceKit

// MARK: - View
/// NullSign's Add Source: a repository by URL, moving a source list in or out,
/// and NullSign's featured sources.
struct SourcesAddView: View {
	@Environment(\.dismiss) var dismiss

	@State private var _featured: [(url: URL, data: ASRepository)] = []
	@State private var _allFeatured: [(url: URL, data: ASRepository)] = []
	@State private var _isLoadingFeatured = true
	@State private var _isImporting = false
	@State private var _isSaving = false
	@State private var _sourceURL = ""

	/// NullSign features only its own source, Null's Apps, so it can be added
	/// back after being removed.
	static let featuredSources: [URL] = [Storage.nullSignSourceURL]

	private var _isBusy: Bool { _isImporting || _isSaving }
	private var _trimmedURL: String { _sourceURL.trimmingCharacters(in: .whitespacesAndNewlines) }

	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Add Source"), displayMode: .inline) {
			ScrollView {
				LazyVStack(alignment: .leading, spacing: 24) {
					NullSignSettingsIntro(
						systemImage: "externaldrive.connected.to.line.below",
						title: .localized("Add Source"),
						detail: .localized("Add a repository by URL or move a source list.")
					)
					_urlSection
					_transferSection
					_featuredSection
				}
				.padding(.horizontal, 20)
				.padding(.top, 12)
				.padding(.bottom, 32)
			}
			.scrollDismissesKeyboard(.interactively)
			.nullSignPage()
			.toolbar {
				NBToolbarButton(role: .cancel)
			}
			.tint(NullSignStyle.accent)
			.task {
				await _fetchFeatured()
			}
		}
		.nullSignTypography()
		.preferredColorScheme(.dark)
		.modifier(NullSignSheetChrome())
	}
}

// MARK: - Sections
extension SourcesAddView {
	private var _urlSection: some View {
		VStack(alignment: .leading, spacing: 10) {
			SourceSectionLabel(title: .localized("Repository URL"))

			VStack(alignment: .leading, spacing: 12) {
				Text(.localized("Paste an AltStore-compatible source URL. NullSign checks it before adding anything."))
					.font(.roundedUI(.subheadline))
					.foregroundStyle(NullSignStyle.muted)
					.fixedSize(horizontal: false, vertical: true)

				HStack(spacing: 8) {
					TextField(.localized("https://example.com/apps.json"), text: $_sourceURL)
						.keyboardType(.URL)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
						.submitLabel(.done)
						.onSubmit(_saveSource)
					Button {
						_sourceURL = UIPasteboard.general.string ?? _sourceURL
					} label: {
						Text(.localized("Paste"))
							.font(.roundedUI(.subheadline, weight: .bold))
							.foregroundStyle(NullSignStyle.accent)
					}
					.buttonStyle(.plain)
				}
				.padding(.horizontal, 12)
				.frame(minHeight: 50)
				.background(NullSignStyle.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

				Button(action: _saveSource) {
					HStack(spacing: 8) {
						if _isSaving {
							ProgressView().tint(.white)
						}
						Text(_isSaving ? String.localized("Checking Source…") : String.localized("Add Source"))
					}
					.frame(maxWidth: .infinity)
				}
				.buttonStyle(NullSignPrimaryButtonStyle(height: 46))
				.disabled(_trimmedURL.isEmpty || _isBusy)

				Link(destination: URL(string: "https://faq.altstore.io/developers/make-a-source")!) {
					Text(.localized("How to make a source"))
						.font(.roundedUI(.footnote, weight: .semibold))
						.foregroundStyle(NullSignStyle.accent)
				}
			}
			.padding(16)
			.nullSignSurface(fill: NullSignStyle.groupedSurface)
		}
	}

	private var _transferSection: some View {
		VStack(alignment: .leading, spacing: 10) {
			SourceSectionLabel(title: .localized("Move Sources"))

			VStack(spacing: 0) {
				_transferButton(
					title: _isImporting ? .localized("Importing…") : .localized("Import from Clipboard"),
					subtitle: .localized("Reads KravaSign, MapleSign, or ESign source lists"),
					icon: "square.and.arrow.down",
					disabled: _isBusy,
					action: _importFromClipboard
				)

				Divider().overlay(NullSignStyle.hairline).padding(.leading, 46)

				_transferButton(
					title: .localized("Copy My Source List"),
					subtitle: .localized("Copies every saved URL to the clipboard"),
					icon: "doc.on.doc",
					disabled: _isBusy,
					action: _exportSources
				)
			}
			.padding(8)
			.nullSignSurface(fill: NullSignStyle.groupedSurface)
		}
	}

	/// Shown only while Null's Apps isn't in the library.
	@ViewBuilder
	private var _featuredSection: some View {
		if !_isLoadingFeatured && !_featured.isEmpty {
			VStack(alignment: .leading, spacing: 10) {
				SourceSectionLabel(title: .localized("Featured"))

				VStack(spacing: 0) {
					ForEach(_featured.indices, id: \.self) { index in
						let item = _featured[index]
						_featuredRow(url: item.url, source: item.data)
						if index < _featured.count - 1 {
							Divider().overlay(NullSignStyle.hairline).padding(.leading, 70)
						}
					}
				}
				.nullSignSurface(fill: NullSignStyle.groupedSurface)
			}
		}
	}

	private func _transferButton(
		title: String,
		subtitle: String,
		icon: String,
		disabled: Bool,
		action: @escaping () -> Void
	) -> some View {
		Button(action: action) {
			HStack(spacing: 12) {
				NullSignIconTile(systemImage: icon, tint: NullSignStyle.categoryColor(for: icon), size: 32, filled: true)
				VStack(alignment: .leading, spacing: 2) {
					Text(title)
						.font(.roundedUI(size: 15, weight: .bold))
					Text(subtitle)
						.font(.roundedUI(.caption))
						.foregroundStyle(NullSignStyle.muted)
						.lineLimit(2)
				}
				Spacer()
				Image(systemName: "chevron.right")
					.font(.roundedUI(size: 12, weight: .bold))
					.foregroundStyle(NullSignStyle.faint)
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 10)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.disabled(disabled)
	}

	private func _featuredRow(url: URL, source: ASRepository) -> some View {
		HStack(spacing: 12) {
			SourceRemoteIcon(
				url: source.currentIconURL,
				relativeTo: url,
				size: 46,
				fallbackAssetName: SourceBundledIcon.assetName(for: source)
			)
			VStack(alignment: .leading, spacing: 2) {
				Text(source.name ?? .localized("Unknown"))
					.font(.roundedUI(.headline))
					.lineLimit(1)
				Text(url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString)
					.font(.roundedUI(.subheadline))
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)
				Text(verbatim: .localized("%lld Apps", arguments: source.apps.count))
					.font(.roundedUI(.caption))
					.foregroundStyle(NullSignStyle.faint)
			}
			Spacer(minLength: 8)
			Button {
				Storage.shared.addSource(url, repository: source) { error in
					_refreshFeatured()
					if let error {
						Toast.error(error.localizedDescription, duration: .sticky)
					} else {
						Toast.success(.localized("Added %@", arguments: source.name ?? url.host ?? url.absoluteString))
					}
				}
			} label: {
				Text(.localized("Add"))
			}
			.buttonStyle(NullSignSecondaryButtonStyle(height: 30))
		}
		.padding(12)
	}
}

// MARK: - Actions
extension SourcesAddView {
	private func _saveSource() {
		guard !_trimmedURL.isEmpty, !_isBusy else { return }
		_isSaving = true
		FR.handleSource(_trimmedURL, showAlerts: false) { result in
			_isSaving = false
			switch result {
			case .success(let sourceName):
				Toast.success(.localized("Added %@", arguments: sourceName))
				dismiss()
			case .failure(let error):
				Toast.error(error.localizedDescription, duration: .sticky)
			}
		}
	}

	private func _importFromClipboard() {
		let urls = ASDeobfuscator(with: UIPasteboard.general.string ?? "")
			.decode()
			.compactMap(URL.init(string:))
		guard !urls.isEmpty else {
			Toast.error(.localized("Copy a supported source list, then try again."), duration: .sticky)
			return
		}

		_isImporting = true
		Task {
			let fetched = await FR.fetchRepositories(from: urls)
			let repositories = Dictionary(fetched, uniquingKeysWith: { first, _ in first })

			await MainActor.run {
				guard !repositories.isEmpty else {
					_isImporting = false
					Toast.error(.localized("None of the copied sources could be loaded."), duration: .sticky)
					return
				}
				Storage.shared.addSources(repos: repositories) { _ in
					_isImporting = false
					Toast.success(.localized("Imported %lld sources", arguments: repositories.count))
					dismiss()
				}
			}
		}
	}

	private func _exportSources() {
		let urls = Storage.shared.getSources().compactMap(\.sourceURL)
		guard !urls.isEmpty else {
			Toast.error(.localized("No sources to export"), duration: .sticky)
			return
		}
		UIPasteboard.general.string = urls.map(\.absoluteString).joined(separator: "\n")
		Toast.success(.localized("Copied %lld sources to the clipboard", arguments: urls.count))
	}

	private func _refreshFeatured() {
		_featured = _allFeatured
			.filter { url, data in
				url == Storage.nullSignSourceURL
					? !Storage.shared.hasNullSignSource()
					: !Storage.shared.sourceExists(data.id ?? url.absoluteString)
			}
			.sorted {
				($0.data.name ?? "").localizedCaseInsensitiveCompare($1.data.name ?? "") == .orderedAscending
			}
	}

	private func _fetchFeatured() async {
		let fetched = await FR.fetchRepositories(from: Self.featuredSources)
		await MainActor.run {
			_allFeatured = fetched
			_refreshFeatured()
			_isLoadingFeatured = false
		}
	}
}
