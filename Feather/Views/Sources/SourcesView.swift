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

	private var _subtitle: String {
		guard !_sources.isEmpty else { return "No sources yet" }
		let sources = _sources.count == 1 ? "1 source" : "\(_sources.count) sources"
		return "\(sources) · \(_loadedAppCount.formatted()) apps"
	}

	var body: some View {
		let filteredSources = _filteredSources

		NBNavigationView("", displayMode: .inline) {
			List {
				NullSignTitle(title: "Apps", subtitle: _subtitle)
					.nullSignListRow(top: 2, bottom: 14)

				if _sources.isEmpty {
					SourceEmptyState(
						icon: "square.grid.2x2",
						title: .localized("No Repositories"),
						message: "Add an AltStore-compatible source to browse apps and send them straight to your signer.",
						actionTitle: .localized("Add Source"),
						action: { _isAddingPresenting = true }
					)
					.nullSignListRow(top: 30, bottom: 30)
				} else {
					NullSignSearchField(prompt: .localized("Search repositories"), text: $_searchText)
						.nullSignListRow(bottom: 8)

					if _searchText.isEmpty {
						ZStack {
							NavigationLink {
								SourceAppsView(object: Array(_sources), viewModel: viewModel)
							} label: {
								EmptyView()
							}
							.opacity(0)

							_catalogHero
						}
						.nullSignListRow(top: 6, bottom: 8)
					}

					NullSignSectionLabel(title: .localized("Repositories"), count: filteredSources.count)
						.nullSignListRow(top: 14, bottom: 4, horizontal: 20)

					ForEach(filteredSources) { source in
						ZStack {
							NavigationLink {
								SourceAppsView(object: [source], viewModel: viewModel)
							} label: {
								EmptyView()
							}
							.opacity(0)

							SourcesCellView(
								source: source,
								repository: viewModel.sources[source],
								isFetching: viewModel.isFetching,
								didFail: source.sourceURL.map(viewModel.failedSourceURLs.contains) ?? false
							)
						}
						.nullSignListRow(top: 5, bottom: 5)
					}

					if filteredSources.isEmpty {
						VStack(spacing: 10) {
							Image(systemName: "magnifyingglass")
								.font(.system(size: 22, weight: .semibold))
								.foregroundStyle(NullSignStyle.faint)
							Text("No repository matches “\(_searchText)”")
								.font(.system(size: 15, weight: .semibold))
								.multilineTextAlignment(.center)
						}
						.frame(maxWidth: .infinity)
						.nullSignListRow(top: 24, bottom: 24)
					}
				}
			}
			.listStyle(.plain)
			// Section labels are short rows; don't pad them up to 44pt.
			.environment(\.defaultMinListRowHeight, 0)
			.scrollContentBackground(.hidden)
			.background(NullSignBackdrop())
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
		}
		.tint(.white)
		.task(id: Array(_sources)) {
			await viewModel.fetchSources(_sources)
		}
	}

	private var _catalogHero: some View {
		let iconURLs = _sources.compactMap { $0.iconURL ?? viewModel.sources[$0]?.currentIconURL }

		return VStack(alignment: .leading, spacing: 16) {
			HStack(alignment: .top) {
				NullSignChip(text: "Catalog", systemImage: "sparkles", tint: NullSignStyle.accentHighlight)
				Spacer()
				if !iconURLs.isEmpty {
					SourceIconStack(urls: iconURLs, size: 34)
				}
			}

			VStack(alignment: .leading, spacing: 5) {
				Text("Browse every app")
					.font(NullSignStyle.display(22, weight: .bold))
					.foregroundStyle(.white)
				Text(_catalogSummary)
					.font(NullSignStyle.mono(11, weight: .medium))
					.foregroundStyle(NullSignStyle.muted)
			}

			HStack {
				Text("Open catalog")
					.font(.system(size: 14, weight: .bold))
				Spacer()
				Image(systemName: "arrow.right")
					.font(.system(size: 14, weight: .bold))
			}
			.foregroundStyle(.white)
			.padding(.horizontal, 16)
			.frame(height: 44)
			.background(Capsule().fill(NullSignStyle.signal))
			.overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
			.shadow(color: NullSignStyle.accent.opacity(0.4), radius: 12, y: 5)
		}
		.padding(18)
		.background(
			ZStack {
				RadialGradient(
					colors: [NullSignStyle.accent.opacity(0.35), .clear],
					center: .topTrailing,
					startRadius: 2,
					endRadius: 260
				)
				RadialGradient(
					colors: [NullSignStyle.violet.opacity(0.18), .clear],
					center: .bottomLeading,
					startRadius: 2,
					endRadius: 220
				)
			}
		)
		.nullSignSurface(cornerRadius: 26)
		.contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
	}

	private var _catalogSummary: String {
		if viewModel.isFetching && _loadedAppCount == 0 {
			return .localized("Updating catalog…")
		}
		return "\(_loadedAppCount.formatted()) apps · \(_sources.count.formatted()) sources"
	}
}
