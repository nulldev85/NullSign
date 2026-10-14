import CoreData
import AltSourceKit
import SwiftUI
import NimbleViews

struct SourcesView: View {
	@StateObject var viewModel = SourcesViewModel.shared
	@State private var _isAddingPresenting = false
	@State private var _selectedSource: AltSource?
	@State private var _searchText = ""

	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>

	private var _filteredSources: [AltSource] {
		_sources.filter { source in
			guard !_searchText.isEmpty else { return true }
			return (source.name?.localizedCaseInsensitiveContains(_searchText) ?? false) ||
				(source.sourceURL?.absoluteString.localizedCaseInsensitiveContains(_searchText) ?? false)
		}
	}

	private var _loadedAppCount: Int {
		_sources.compactMap { viewModel.sources[$0] }.reduce(0) { $0 + $1.apps.count }
	}

	var body: some View {
		let filteredSources = _filteredSources

		NBNavigationView("Apps", displayMode: .inline) {
			List {
				NullSignOverviewBanner(
					title: "Your catalog",
					value: viewModel.isFetching && _loadedAppCount == 0 ? "…" : _loadedAppCount.formatted(),
					detail: viewModel.isFetching && _loadedAppCount == 0
						? "Updating your repositories…"
						: "Apps from \(_sources.count) \(_sources.count == 1 ? "repository" : "repositories")",
					systemImage: "square.grid.2x2.fill"
				)
				.nullSignListRow(top: 0, bottom: 0, horizontal: 0)

				if _sources.isEmpty {
					SourceEmptyState(
						icon: "square.grid.2x2",
						title: .localized("No Repositories"),
						message: "Add an AltStore-compatible source to browse its apps and import them into NullSign.",
						actionTitle: .localized("Add Source"),
						action: { _isAddingPresenting = true }
					)
					.nullSignListRow(top: 40, bottom: 30)
				} else {
					NullSignSearchField(prompt: .localized("Search"), text: $_searchText)
						.nullSignListRow(top: 4, bottom: 6)

					if _searchText.isEmpty {
						ZStack {
							NavigationLink {
								SourceAppsView(object: Array(_sources), viewModel: viewModel)
							} label: {
								EmptyView()
							}
							.opacity(0)

							_allAppsRow
						}
						.nullSignListRow(top: 6, bottom: 4)
					}

					NullSignSectionLabel(title: .localized("Repositories"), prominent: true, systemImage: "externaldrive.connected.to.line.below")
						.nullSignListRow(top: 20, bottom: 8, horizontal: 24)

					ForEach(filteredSources) { source in
						SourcesCellView(
							source: source,
							repository: viewModel.sources[source],
							isFetching: viewModel.isFetching,
							didFail: source.sourceURL.map(viewModel.failedSourceURLs.contains) ?? false,
							onSelect: { _selectedSource = source }
						)
						.nullSignListRow()
					}

					if filteredSources.isEmpty {
						Text("No repositories match “\(_searchText)”.")
							.font(.roundedUI(.subheadline))
							.foregroundStyle(NullSignStyle.muted)
							.frame(maxWidth: .infinity)
							.nullSignListRow(top: 24, bottom: 24)
					}
				}
			}
			.listStyle(.plain)
			// Section labels are short rows; don't pad them up to 44pt.
			.environment(\.defaultMinListRowHeight, 0)
			.scrollContentBackground(.hidden)
			.nullSignPage()
			.scrollDismissesKeyboard(.interactively)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						_isAddingPresenting = true
					} label: {
						Image(systemName: "plus")
					}
					.accessibilityLabel(.localized("Add Source"))
				}
			}
			.refreshable {
				await viewModel.fetchSources(_sources, refresh: true)
			}
			.sheet(isPresented: $_isAddingPresenting) {
				SourcesAddView()
			}
			.navigationDestinationIfAvailable(item: $_selectedSource) { source in
				SourceAppsView(object: [source], viewModel: viewModel)
			}
		}
		.tint(NullSignStyle.accent)
		.task(id: Array(_sources)) {
			await viewModel.fetchSources(_sources)
		}
	}

	private var _allAppsRow: some View {
		let iconURLs = _sources.compactMap { source in
			SourceAssetURL.resolve(
				source.iconURL ?? viewModel.sources[source]?.currentIconURL,
				relativeTo: source.sourceURL
			)
		}

		return HStack(spacing: 14) {
			if iconURLs.isEmpty {
				NullSignIconTile(systemImage: "square.grid.2x2.fill", tint: NullSignStyle.accent, size: 48, filled: true)
			} else {
				SourceIconStack(urls: iconURLs, size: 40)
			}

			VStack(alignment: .leading, spacing: 2) {
				Text("All Apps")
					.font(.roundedUI(.headline))
					.foregroundStyle(.white)
				Text(_catalogSummary)
					.font(.roundedUI(.subheadline))
					.foregroundStyle(NullSignStyle.muted)
			}

			Spacer(minLength: 8)

			Image(systemName: "chevron.right")
				.font(.roundedUI(.footnote, weight: .semibold))
				.foregroundStyle(NullSignStyle.faint)
		}
		.padding(14)
		.nullSignSurface()
		.contentShape(RoundedRectangle(cornerRadius: NullSignStyle.cardRadius, style: .continuous))
	}

	private var _catalogSummary: String {
		if viewModel.isFetching && _loadedAppCount == 0 {
			return .localized("Updating…")
		}
		let sources = _sources.count == 1 ? "1 source" : "\(_sources.count.formatted()) sources"
		return "\(_loadedAppCount.formatted()) apps from \(sources)"
	}
}
