import SwiftUI
import AltSourceKit
import NimbleViews
import UIKit

extension SourceAppsView {
	enum SortOption: String, CaseIterable {
		case `default` = "default"
		case name
		case date

		var displayName: String {
			switch self {
			case .default: .localized("Default")
			case .name: .localized("Name")
			case .date: .localized("Date")
			}
		}
	}
}

struct SourceAppsView: View {
	@AppStorage("Feather.sortOptionRawValue") private var _sortOptionRawValue = SortOption.default.rawValue
	@AppStorage("Feather.sortAscending") private var _sortAscending = true

	@State private var _sortOption: SortOption = .default
	@State private var _selectedRoute: SourceAppRoute?
	@State private var _searchText = ""
	@State private var _sourceContexts: [SourceRepositoryContext]?
	@State private var _isRetrying = false

	var object: [AltSource]
	@ObservedObject var viewModel: SourcesViewModel

	private var _navigationTitle: String {
		object.count == 1 ? (object[0].name ?? .localized("Apps")) : .localized("All Apps")
	}

	private var _hasMatchingApps: Bool {
		guard let _sourceContexts else { return false }
		guard !_searchText.isEmpty else { return _sourceContexts.contains { !$0.repository.apps.isEmpty } }
		return _sourceContexts.flatMap(\.repository.apps).contains { app in
			(app.id?.localizedCaseInsensitiveContains(_searchText) ?? false) ||
				(app.name?.localizedCaseInsensitiveContains(_searchText) ?? false) ||
				(app.description?.localizedCaseInsensitiveContains(_searchText) ?? false) ||
				(app.subtitle?.localizedCaseInsensitiveContains(_searchText) ?? false) ||
				(app.localizedDescription?.localizedCaseInsensitiveContains(_searchText) ?? false)
		}
	}

	var body: some View {
		ZStack {
			Color.black.ignoresSafeArea()

			if let _sourceContexts, !_sourceContexts.isEmpty {
				SourceAppsTableRepresentableView(
					sourceContexts: _sourceContexts,
					searchText: $_searchText,
					sortOption: $_sortOption,
					sortAscending: $_sortAscending,
					onSelect: { _selectedRoute = $0 }
				)
				.ignoresSafeArea(edges: .bottom)

				if !_hasMatchingApps {
					SourceEmptyState(
						icon: _searchText.isEmpty ? "square.grid.2x2" : "magnifyingglass",
						title: _searchText.isEmpty ? .localized("No Apps") : .localized("No Results"),
						message: _searchText.isEmpty
							? "This repository does not currently list any apps."
							: "No app matches “\(_searchText)”."
					)
				}
			} else if viewModel.isFetching || _isRetrying || _sourceContexts == nil {
				SourceLoadingState(label: "Updating catalog")
			} else {
				SourceEmptyState(
					icon: "wifi.exclamationmark",
					title: .localized("Catalog Unavailable"),
					message: "NullSign could not load this source. Check your connection or try again.",
					actionTitle: .localized("Try Again"),
					action: _retry
				)
			}
		}
		.navigationTitle(_navigationTitle)
		.searchable(text: $_searchText, placement: .platform(), prompt: .localized("Search apps"))
		.toolbarTitleMenu {
			if let context = _sourceContexts?.first, _sourceContexts?.count == 1 {
				if let url = context.repository.website {
					Button(.localized("Visit Website"), systemImage: "globe") { UIApplication.open(url) }
				}
				Divider()
			}

			Button(.localized("Copy Source URL"), systemImage: "doc.on.doc") {
				_copySourceURLs()
			}
		}
		.toolbar {
			NBToolbarMenu(
				systemImage: "arrow.up.arrow.down",
				style: .icon,
				placement: .topBarTrailing
			) {
				_sortActions()
			}
		}
		.tint(NullSignStyle.accent)
		.onAppear {
			_sortOption = SortOption(rawValue: _sortOptionRawValue) ?? .default
			_load()
		}
		.onChange(of: viewModel.sources.count) { _ in _load() }
		.onChange(of: viewModel.isFetching) { _ in _load() }
		.onChange(of: _sortOption) { _sortOptionRawValue = $0.rawValue }
		.navigationDestinationIfAvailable(item: $_selectedRoute) { route in
			SourceAppsDetailView(sourceURL: route.sourceURL, source: route.source, app: route.app)
		}
	}

	private func _load() {
		let loaded = object.compactMap { source -> SourceRepositoryContext? in
			guard let repository = viewModel.sources[source] else { return nil }
			return SourceRepositoryContext(sourceURL: source.sourceURL, repository: repository)
		}
		if !loaded.isEmpty || !viewModel.isFetching {
			_sourceContexts = loaded
		}
	}

	private func _retry() {
		_isRetrying = true
		Task {
			await viewModel.fetchSources(object, refresh: true)
			await MainActor.run {
				_load()
				_isRetrying = false
			}
		}
	}

	private func _copySourceURLs() {
		let urls = object.compactMap(\.sourceURL)
		guard !urls.isEmpty else {
			UIAlertController.showAlertWithOk(title: .localized("Error"), message: .localized("No sources to copy"))
			return
		}
		UIPasteboard.general.string = urls.map(\.absoluteString).joined(separator: "\n")
		UIAlertController.showAlertWithOk(title: .localized("Copied"), message: .localized("Sources copied to clipboard"))
	}

	struct SourceRepositoryContext: Equatable {
		let sourceURL: URL?
		let repository: ASRepository

		static func == (lhs: Self, rhs: Self) -> Bool {
			lhs.sourceURL == rhs.sourceURL &&
			lhs.repository.id == rhs.repository.id &&
			lhs.repository.name == rhs.repository.name &&
			lhs.repository.apps.map { "\($0.currentUniqueId)|\($0.currentVersion ?? "")" } ==
			rhs.repository.apps.map { "\($0.currentUniqueId)|\($0.currentVersion ?? "")" }
		}
	}

	struct SourceAppRoute: Identifiable, Hashable {
		let sourceURL: URL?
		let source: ASRepository
		let app: ASRepository.App
		let id = UUID().uuidString
	}
}

extension SourceAppsView {
	@ViewBuilder
	private func _sortActions() -> some View {
		Section(.localized("Sort by")) {
			ForEach(SortOption.allCases, id: \.rawValue) { option in
				Button {
					if _sortOption == option {
						_sortAscending.toggle()
					} else {
						_sortOption = option
						_sortAscending = true
					}
				} label: {
					HStack {
						Text(option.displayName)
						Spacer()
						if _sortOption == option {
							Image(systemName: _sortAscending ? "chevron.up" : "chevron.down")
						}
					}
				}
			}
		}
	}
}

extension View {
	@ViewBuilder
	func navigationDestinationIfAvailable<Item: Identifiable & Hashable, Destination: View>(
		item: Binding<Item?>,
		@ViewBuilder destination: @escaping (Item) -> Destination
	) -> some View {
		if #available(iOS 17, *) {
			self.navigationDestination(item: item, destination: destination)
		} else {
			self.background {
				NavigationLink(
					isActive: Binding(
						get: { item.wrappedValue != nil },
						set: { if !$0 { item.wrappedValue = nil } }
					),
					destination: {
						if let value = item.wrappedValue {
							destination(value)
						}
					},
					label: { EmptyView() }
				)
				.hidden()
			}
		}
	}
}
