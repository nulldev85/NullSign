import CoreData
import AltSourceKit
import SwiftUI
import NimbleViews

struct SourcesView: View {
	@StateObject var viewModel = SourcesViewModel.shared
	@State private var _isAddingPresenting = false
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
		NBNavigationView("Apps") {
			List {
				if !_sources.isEmpty && _searchText.isEmpty {
					Section {
						NavigationLink {
							SourceAppsView(object: Array(_sources), viewModel: viewModel)
						} label: {
							_catalogRow
						}
						.buttonStyle(.plain)
						.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))
						.listRowBackground(Color.clear)
						.listRowSeparator(.hidden)
					}
				}

				if !_filteredSources.isEmpty {
					Section {
						ForEach(_filteredSources) { source in
							NavigationLink {
								SourceAppsView(object: [source], viewModel: viewModel)
							} label: {
								SourcesCellView(
									source: source,
									repository: viewModel.sources[source],
									isFetching: viewModel.isFetching,
									didFail: source.sourceURL.map(viewModel.failedSourceURLs.contains) ?? false
								)
							}
							.buttonStyle(.plain)
							.listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
							.listRowBackground(Color.black)
							.listRowSeparatorTint(NullSignStyle.hairline)
						}
					} header: {
						SourceSectionLabel(title: .localized("Repositories"), count: _filteredSources.count)
							.padding(.top, 6)
					}
				}
			}
			.listStyle(.plain)
			.scrollContentBackground(.hidden)
			.background(Color.black)
			.searchable(text: $_searchText, placement: .platform(), prompt: .localized("Search repositories"))
			.overlay {
				if _sources.isEmpty {
					SourceEmptyState(
						icon: "shippingbox",
						title: .localized("No Repositories"),
						message: "Add a source to browse apps and import them into your signing library.",
						actionTitle: .localized("Add Source"),
						action: { _isAddingPresenting = true }
					)
				} else if _filteredSources.isEmpty {
					SourceEmptyState(
						icon: "magnifyingglass",
						title: .localized("No Results"),
						message: "No repository matches “\(_searchText)”."
					)
				}
			}
			.toolbar {
				if !_sources.isEmpty {
					NBToolbarButton(
						systemImage: "plus",
						style: .icon,
						placement: .topBarTrailing
					) {
						_isAddingPresenting = true
					}
				}
			}
			.refreshable {
				await viewModel.fetchSources(_sources, refresh: true)
			}
			.sheet(isPresented: $_isAddingPresenting) {
				SourcesAddView()
			}
		}
		.tint(NullSignStyle.cyan)
		.task(id: Array(_sources)) {
			await viewModel.fetchSources(_sources)
		}
	}

	private var _catalogRow: some View {
		HStack(spacing: 14) {
			ZStack {
				RoundedRectangle(cornerRadius: 13, style: .continuous)
					.fill(NullSignStyle.raisedPanel)
				Image(systemName: "square.grid.2x2")
					.font(.system(size: 20, weight: .semibold))
					.foregroundStyle(NullSignStyle.cyan)
			}
			.frame(width: 50, height: 50)

			VStack(alignment: .leading, spacing: 4) {
				Text("Browse All Apps")
					.font(.body.weight(.semibold))
				Text(_catalogSummary)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			Spacer()
		}
		.sourcePanel(padding: 13)
	}

	private var _catalogSummary: String {
		if viewModel.isFetching && _loadedAppCount == 0 {
			return .localized("Updating catalog…")
		}
		return "\(_loadedAppCount.formatted()) apps across \(_sources.count.formatted()) sources"
	}
}
