import SwiftUI
import NimbleViews
import AltSourceKit
import NimbleJSON
import NukeUI
import OSLog

struct SourcesAddView: View {
	typealias RepositoryDataHandler = Result<ASRepository, Error>
	@Environment(\.dismiss) var dismiss

	private let _dataService = NBFetchService()

	@State private var _filteredRecommendedSourcesData: [(url: URL, data: ASRepository)] = []
	@State var recommendedSourcesData: [(url: URL, data: ASRepository)] = []
	@State private var _isImporting = false
	@State private var _isSaving = false
	@State private var _isLoadingFeatured = true
	@State private var _sourceURL = ""

	let recommendedSources: [URL] = [
		"https://raw.githubusercontent.com/Aidoku/Aidoku/altstore/apps.json",
		"https://github.com/chachillie/Flycast-iOS/raw/main/flycast-ios.json",
		"https://xitrix.github.io/iTorrent/AltStore.json",
		"https://altstore.oatmealdome.me/",
		"https://raw.githubusercontent.com/LiveContainer/LiveContainer/refs/heads/main/apps.json",
		"https://pokemmo.com/altstore",
		"https://provenance-emu.com/apps.json",
		"https://community-apps.sidestore.io/sidecommunity.json",
		"https://alt.getutm.app",
		"https://raw.githubusercontent.com/paigely/Navic/refs/heads/master/app-repo.json",
		"https://stikdebug.xyz/index.json",
		"https://apps.manicemu.site/altstore",
		"https://alt.crystall1ne.dev"
	].map { URL(string: $0)! }

	private var _isBusy: Bool { _isImporting || _isSaving }
	private var _trimmedURL: String { _sourceURL.trimmingCharacters(in: .whitespacesAndNewlines) }

	var body: some View {
		NBNavigationView(.localized("Add Source"), displayMode: .inline) {
			ScrollView {
				LazyVStack(alignment: .leading, spacing: 24) {
					_urlSection
					_transferSection
					_featuredSection
				}
				.padding(.horizontal, 16)
				.padding(.top, 12)
				.padding(.bottom, 32)
			}
			.scrollDismissesKeyboard(.interactively)
			.background(Color.black.ignoresSafeArea())
			.toolbar {
				NBToolbarButton(role: .cancel)
			}
			.tint(NullSignStyle.cyan)
			.task {
				await _fetchRecommendedRepositories()
			}
		}
	}

	private var _urlSection: some View {
		VStack(alignment: .leading, spacing: 10) {
			SourceSectionLabel(title: .localized("Repository URL"))

			VStack(alignment: .leading, spacing: 12) {
				Text("Paste an AltStore-compatible source URL. NullSign will check it before adding anything.")
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)

				HStack(spacing: 8) {
					Image(systemName: "link")
						.foregroundStyle(NullSignStyle.cyan)
					TextField(.localized("https://example.com/apps.json"), text: $_sourceURL)
						.keyboardType(.URL)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
					Button {
						_sourceURL = UIPasteboard.general.string ?? _sourceURL
					} label: {
						Image(systemName: "doc.on.clipboard")
							.font(.subheadline.weight(.semibold))
							.foregroundStyle(NullSignStyle.cyan)
					}
					.buttonStyle(.plain)
				}
				.padding(.horizontal, 12)
				.frame(height: 46)
				.background(NullSignStyle.raisedPanel)
				.clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

				Button(action: _saveSource) {
					HStack(spacing: 8) {
						if _isSaving {
							ProgressView().tint(.black)
						} else {
							Image(systemName: "plus")
						}
						Text(_isSaving ? "Checking Source" : .localized("Add Source"))
					}
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(.black)
					.frame(maxWidth: .infinity)
					.frame(height: 42)
					.background(NullSignStyle.cyan.opacity(_trimmedURL.isEmpty || _isBusy ? 0.45 : 1))
					.clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
				}
				.buttonStyle(.plain)
				.disabled(_trimmedURL.isEmpty || _isBusy)
			}
			.sourcePanel()
		}
	}

	private var _transferSection: some View {
		VStack(alignment: .leading, spacing: 10) {
			SourceSectionLabel(title: .localized("Move Sources"))

			VStack(spacing: 0) {
				_transferButton(
					title: _isImporting ? "Importing…" : "Import from Clipboard",
					subtitle: "Reads KravaSign, MapleSign, or ESign source lists",
					icon: "square.and.arrow.down",
					disabled: _isBusy
				) {
					_isImporting = true
					_fetchImportedRepositories(UIPasteboard.general.string) { dismiss() }
				}

				Divider().overlay(NullSignStyle.hairline).padding(.leading, 46)

				_transferButton(
					title: "Copy My Source List",
					subtitle: "Copies every saved URL to the clipboard",
					icon: "doc.on.doc",
					disabled: _isBusy,
					action: _exportSources
				)
			}
			.sourcePanel(padding: 4)
		}
	}

	@ViewBuilder
	private var _featuredSection: some View {
		VStack(alignment: .leading, spacing: 10) {
			SourceSectionLabel(
				title: .localized("Featured"),
				count: _isLoadingFeatured ? nil : _filteredRecommendedSourcesData.count
			)

			if _isLoadingFeatured {
				SourceLoadingState(label: "Checking featured sources")
					.frame(maxWidth: .infinity)
					.sourcePanel()
			} else if _filteredRecommendedSourcesData.isEmpty {
				HStack(spacing: 11) {
					Image(systemName: "checkmark.circle")
						.foregroundStyle(NullSignStyle.cyan)
					Text("You already have all available featured sources.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.sourcePanel()
			} else {
				VStack(spacing: 0) {
					ForEach(_filteredRecommendedSourcesData.indices, id: \.self) { index in
						let item = _filteredRecommendedSourcesData[index]
						_featuredRow(url: item.url, source: item.data)
						if index < _filteredRecommendedSourcesData.count - 1 {
							Divider().overlay(NullSignStyle.hairline).padding(.leading, 70)
						}
					}
				}
				.sourcePanel(padding: 0)
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
				Image(systemName: icon)
					.font(.system(size: 17, weight: .medium))
					.foregroundStyle(NullSignStyle.cyan)
					.frame(width: 30)
				VStack(alignment: .leading, spacing: 2) {
					Text(title)
						.font(.subheadline.weight(.semibold))
					Text(subtitle)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}
				Spacer()
				Image(systemName: "chevron.right")
					.font(.caption.weight(.semibold))
					.foregroundStyle(.tertiary)
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
			_featuredIcon(source.currentIconURL)
			VStack(alignment: .leading, spacing: 3) {
				Text(source.name ?? .localized("Unknown"))
					.font(.subheadline.weight(.semibold))
					.lineLimit(1)
				Text(url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
				Text(.localized("%lld Apps", arguments: source.apps.count))
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
			Spacer(minLength: 8)
			Button {
				Storage.shared.addSource(url, repository: source) { _ in
					_refreshFilteredRecommendedSourcesData()
				}
			} label: {
				Text(.localized("Add"))
					.font(.caption.weight(.bold))
					.foregroundStyle(.black)
					.padding(.horizontal, 14)
					.frame(height: 32)
					.background(NullSignStyle.cyan)
					.clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
			}
			.buttonStyle(.plain)
		}
		.padding(12)
	}

	@ViewBuilder
	private func _featuredIcon(_ url: URL?) -> some View {
		if let url {
			LazyImage(url: url) { state in
				if let image = state.image {
					image.appIconStyle(size: 46, isCircle: false, background: NullSignStyle.raisedPanel)
				} else {
					_featuredPlaceholder
				}
			}
		} else {
			_featuredPlaceholder
		}
	}

	private var _featuredPlaceholder: some View {
		ZStack {
			RoundedRectangle(cornerRadius: 11, style: .continuous).fill(NullSignStyle.raisedPanel)
			Image(systemName: "shippingbox").foregroundStyle(NullSignStyle.cyan)
		}
		.frame(width: 46, height: 46)
	}

	private func _saveSource() {
		_isSaving = true
		FR.handleSource(
			_trimmedURL,
			competion: { dismiss() },
			failure: { _isSaving = false }
		)
	}

	private func _exportSources() {
		let urls = Storage.shared.getSources().compactMap(\.sourceURL)
		guard !urls.isEmpty else {
			UIAlertController.showAlertWithOk(title: .localized("Error"), message: .localized("No sources to export"))
			return
		}
		UIPasteboard.general.string = urls.map(\.absoluteString).joined(separator: "\n")
		UIAlertController.showAlertWithOk(
			title: .localized("Success"),
			message: .localized("Sources copied to clipboard")
		) { dismiss() }
	}

	private func _refreshFilteredRecommendedSourcesData() {
		_filteredRecommendedSourcesData = recommendedSourcesData
			.filter { url, data in !Storage.shared.sourceExists(data.id ?? url.absoluteString) }
			.sorted {
				($0.data.name ?? "").localizedCaseInsensitiveCompare($1.data.name ?? "") == .orderedAscending
			}
	}

	private func _fetchRecommendedRepositories() async {
		let fetched = await _concurrentFetchRepositories(from: recommendedSources)
		await MainActor.run {
			recommendedSourcesData = fetched
			_refreshFilteredRecommendedSourcesData()
			_isLoadingFeatured = false
		}
	}

	private func _fetchImportedRepositories(_ code: String?, competion: @escaping () -> Void) {
		guard let code else {
			_isImporting = false
			return
		}

		let repoUrls = ASDeobfuscator(with: code).decode().compactMap(URL.init(string:))
		guard !repoUrls.isEmpty else {
			_isImporting = false
			UIAlertController.showAlertWithOk(
				title: .localized("Nothing to Import"),
				message: "Copy a supported source list, then try again."
			)
			return
		}

		Task {
			let fetched = await _concurrentFetchRepositories(from: repoUrls)
			guard !fetched.isEmpty else {
				await MainActor.run {
					_isImporting = false
					UIAlertController.showAlertWithOk(
						title: .localized("Import Failed"),
						message: "None of the copied sources could be loaded."
					)
				}
				return
			}
			let dict = Dictionary(fetched, uniquingKeysWith: { first, _ in first })
			await MainActor.run {
				Storage.shared.addSources(repos: dict) { _ in competion() }
			}
		}
	}

	private func _concurrentFetchRepositories(from urls: [URL]) async -> [(url: URL, data: ASRepository)] {
		let dataService = _dataService

		return await withTaskGroup(
			of: Optional<(url: URL, data: ASRepository)>.self,
			returning: [(url: URL, data: ASRepository)].self
		) { group in
			for url in urls {
				group.addTask {
					await withCheckedContinuation { continuation in
						dataService.fetch<ASRepository>(from: url) { (result: RepositoryDataHandler) in
							switch result {
							case .success(let repo):
								continuation.resume(returning: (url: url, data: repo))
							case .failure(let error):
								Logger.misc.error("Failed to fetch \(url): \(error.localizedDescription)")
								continuation.resume(returning: nil)
							}
						}
					}
				}
			}

			var results: [(url: URL, data: ASRepository)] = []
			for await result in group {
				if let result { results.append(result) }
			}
			return results
		}
	}
}
