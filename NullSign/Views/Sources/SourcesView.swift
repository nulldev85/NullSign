//
//  SourcesView.swift
//  NullSign
//
//  Created by samara on 10.04.2025.
//
import CoreData
import AltSourceKit
import SwiftUI
import NimbleViews
import NimbleExtensions

// MARK: - View
/// NullSign's Apps tab: the catalog in NullSign's look (overview, search, All
/// Apps, repository cards) on NullSign's sources (favorites, sorting,
/// selecting to delete, hiding from All, app links).
struct SourcesView: View {
	@Environment(\.scenePhase) private var scenePhase
	@Environment(\.accessibilityReduceMotion) private var _reduceMotion
	@StateObject var viewModel = SourcesViewModel.shared
	@State private var _isAddingPresenting = false
	@State private var _addingSourceLoading = false
	@State private var _searchText = ""
	@State private var _shouldNavigateToAllRepos = false
	@State private var _activeIndividualSource: AltSource? = nil
	@State private var _isEditMode = false
	@State private var _selectedSources: Set<AltSource> = []
	@State private var _showDeleteConfirmation = false

	@AppStorage("Feather.sourcesTabShowAllReposDirectly")
	private var _sourcesTabShowAllReposDirectly: Bool = false
	@AppStorage("RyukSign.sourcesSort") private var _sort: SourceSort = .name
	@AppStorage("RyukSign.sourcesSortAscending") private var _sortAscending = true
	@ObservedObject private var _favorites = SourceFavorites.shared

	/// Sources not excluded from "All Repositories"
	private var _nonExcludedSources: [AltSource] {
		_sources.filter { source in
			let id = source.identifier ?? source.sourceURL?.absoluteString ?? ""
			return !SourceExclusions.isExcluded(id)
		}
	}

	@ObservedObject var appNavigationManager = AppNavigationManager.shared

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

	private var _isLoadingCatalog: Bool {
		!viewModel.isFinished && _loadedAppCount == 0
	}

	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>

	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Apps"), displayMode: .inline) {
			mainContent
		}
		.tint(NullSignStyle.accent)
		.task(id: Array(_sources)) {
			await viewModel.fetchSources(_sources)
		}
		.onAppear {
			handlePendingNavigation(appNavigationManager.pendingAppNavigation)
		}
		.onChange(of: appNavigationManager.pendingAppNavigation) { pendingNavigation in
			handlePendingNavigation(pendingNavigation)
		}
		.onChange(of: _isEditMode) { isEditing in
			if !isEditing {
				_selectedSources.removeAll()
			}
		}
		.onChange(of: scenePhase) { newPhase in
			if newPhase == .active {
				Task {
					await viewModel.refreshStale(Array(_sources))
				}
			}
		}
	}

	@ViewBuilder
	private var mainContent: some View {
		if _sourcesTabShowAllReposDirectly && !_sources.isEmpty {
			allRepositoriesDirectView
		} else {
			sourcesListView
		}
	}

	@ViewBuilder
	private var allRepositoriesDirectView: some View {
		SourceAppsView(
			object: _nonExcludedSources,
			viewModel: viewModel,
			onRefresh: {
				await self.viewModel.fetchSources(self._sources, refresh: true)
			},
			isSourcesRoot: true
		)
		.nullSignPage()
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button {
					_isAddingPresenting = true
				} label: {
					Label(.localized("Add Source"), systemImage: "plus")
				}
				.disabled(_addingSourceLoading)
			}
		}
		.sheet(isPresented: $_isAddingPresenting) {
			SourcesAddView()
				.adaptiveSheetSizing()
		}
	}

	private var sourcesListView: some View {
		List {
			NullSignOverviewBanner(
				title: "Your catalog",
				value: _isLoadingCatalog ? "…" : _loadedAppCount.formatted(),
				detail: _isLoadingCatalog
					? "Updating your repositories…"
					: "Apps from \(_sources.count) \(_sources.count == 1 ? "repository" : "repositories")",
				systemImage: "square.grid.2x2.fill"
			)
			.nullSignListRow(top: 0, bottom: 0, horizontal: 0)

			if _sources.isEmpty {
				NoRepositoriesView { _isAddingPresenting = true }
					.nullSignListRow(top: 40, bottom: 30)
			} else {
				NullSignSearchField(prompt: .localized("Search"), text: $_searchText)
					.nullSignListRow(top: 4, bottom: 6)

				if _searchText.isEmpty && !_isEditMode {
					allRepositoriesRow
						.nullSignListRow(top: 6, bottom: 4)
				}

				repositoriesSection

				if _filteredSources.isEmpty {
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
			toolbarContent
		}
		.refreshable {
			await viewModel.fetchSources(_sources, refresh: true)
		}
		.sheet(isPresented: $_isAddingPresenting) {
			SourcesAddView()
				.adaptiveSheetSizing()
		}
		.alert(
			deleteDialogTitle,
			isPresented: $_showDeleteConfirmation
		) {
			Button(.localized("Delete"), role: .destructive) {
				deleteSelectedSources()
			}
			Button(.localized("Cancel"), role: .cancel) {}
		} message: {
			Text(.localized("This action cannot be undone."))
		}
	}

	private var deleteDialogTitle: String {
		let count = _selectedSources.count
		return "Delete \(count) \(count == 1 ? "repository" : "repositories")?"
	}

	// MARK: All Apps
	/// The whole catalog, from every repository not hidden from All.
	private var allRepositoriesRow: some View {
		ZStack {
			NavigationLink(isActive: $_shouldNavigateToAllRepos) {
				SourceAppsView(
					object: _nonExcludedSources,
					viewModel: viewModel,
					onRefresh: {
						await self.viewModel.fetchSources(self._sources, refresh: true)
					}
				)
				.nullSignPage()
			} label: {
				EmptyView()
			}
			.opacity(0)
			.onChange(of: _shouldNavigateToAllRepos) { isActive in
				if isActive {
					_activeIndividualSource = nil
				}
			}

			_allAppsCard
		}
	}

	private var _allAppsCard: some View {
		let iconURLs = _nonExcludedSources.compactMap { source in
			SourceAssetURL.resolve(
				viewModel.sources[source]?.currentIconURL ?? source.iconURL,
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
				Text(.localized("All Apps"))
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
		if _isLoadingCatalog {
			return .localized("Updating…")
		}
		let sources = _sources.count == 1 ? "1 source" : "\(_sources.count.formatted()) sources"
		return "\(_loadedAppCount.formatted()) apps from \(sources)"
	}

	// MARK: Repositories
	private var _sortedSources: [AltSource] {
		let sorted = _filteredSources.sorted { lhs, rhs in
			switch _sort {
			case .name:
				return (lhs.name ?? "").localizedCaseInsensitiveCompare(rhs.name ?? "") == .orderedAscending
			case .apps:
				return (viewModel.sources[lhs]?.apps.count ?? 0) > (viewModel.sources[rhs]?.apps.count ?? 0)
			case .added:
				return (lhs.date ?? .distantPast) > (rhs.date ?? .distantPast)
			}
		}
		return _sortAscending ? sorted : sorted.reversed()
	}

	@ViewBuilder
	private var repositoriesSection: some View {
		let sources = _sortedSources
		let favorites = sources.filter(_favorites.contains)
		let others = sources.filter { !_favorites.contains($0) }

		if !favorites.isEmpty {
			NullSignSectionLabel(title: .localized("Favorites"), count: favorites.count, prominent: true, systemImage: "star")
				.nullSignListRow(top: 20, bottom: 8, horizontal: 24)
			ForEach(favorites) { _row(for: $0) }
		}

		if !others.isEmpty {
			NullSignSectionLabel(
				title: _isEditMode && !_selectedSources.isEmpty
					? "\(String.localized("Repositories")) · \(_selectedSources.count) selected"
					: .localized("Repositories"),
				count: others.count,
				prominent: true,
				systemImage: "externaldrive.connected.to.line.below"
			)
			.nullSignListRow(top: 20, bottom: 8, horizontal: 24)
			ForEach(others) { _row(for: $0) }
		}
	}

	@ViewBuilder
	private func _row(for source: AltSource) -> some View {
		if _isEditMode {
			editModeRow(for: source)
				.nullSignListRow()
		} else {
			normalModeRow(for: source)
				.nullSignListRow()
		}
	}

	private func editModeRow(for source: AltSource) -> some View {
		let isSelected = _selectedSources.contains(source)
		return HStack(spacing: 12) {
			Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
				.font(.roundedUI(.title2, weight: .regular))
				.symbolRenderingMode(.palette)
				.foregroundStyle(isSelected ? Color.white : NullSignStyle.faint, isSelected ? NullSignStyle.accent : NullSignStyle.faint)
			SourcesCellView(source: source, isEditMode: true)
				.overlay {
					if isSelected {
						RoundedRectangle(cornerRadius: NullSignStyle.cardRadius, style: .continuous)
							.strokeBorder(NullSignStyle.accent, lineWidth: 2)
					}
				}
		}
		.contentShape(Rectangle())
		.onTapGesture {
			toggleSelection(for: source)
		}
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}

	private func normalModeRow(for source: AltSource) -> some View {
		let isActive = Binding(
			get: { _activeIndividualSource == source },
			set: { isActive in
				if isActive {
					_activeIndividualSource = source
					_shouldNavigateToAllRepos = false
				} else if _activeIndividualSource == source {
					_activeIndividualSource = nil
				}
			}
		)

		return ZStack {
			NavigationLink(isActive: isActive) {
				SourceAppsView(
					object: [source],
					viewModel: viewModel,
					onRefresh: {
						await self.viewModel.fetchSources(self._sources, refresh: true)
					}
				)
				.nullSignPage()
			} label: {
				EmptyView()
			}
			.opacity(0)

			SourcesCellView(source: source, isEditMode: false)
		}
	}

	// MARK: Toolbar
	@ToolbarContentBuilder
	private var toolbarContent: some ToolbarContent {
		ToolbarItem(placement: .topBarLeading) {
			if !_sources.isEmpty {
				Button {
					withAnimation(_reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.85)) {
						_isEditMode.toggle()
					}
				} label: {
					Text(_isEditMode ? String.localized("Done") : String.localized("Select"))
						.font(.roundedUI(size: 15, weight: .bold))
				}
			}
		}

		ToolbarItem(placement: .topBarTrailing) {
			if _isEditMode {
				Menu {
					Button(areAllSourcesSelected ? String.localized("Deselect All") : String.localized("Select All"), systemImage: "checkmark.circle") {
						selectAllSources()
					}
					Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
						if !_selectedSources.isEmpty {
							_showDeleteConfirmation = true
						}
					}
					.disabled(_selectedSources.isEmpty)
				} label: {
					Label(.localized("Selection"), systemImage: "ellipsis.circle")
				}
			} else {
				_sortMenu
			}
		}

		ToolbarItem(placement: .topBarTrailing) {
			if !_isEditMode {
				Button {
					_isAddingPresenting = true
				} label: {
					Label(.localized("Add Source"), systemImage: "plus")
				}
				.disabled(_addingSourceLoading)
			}
		}
	}

	private var _sortMenu: some View {
		Menu {
			Picker(.localized("Sort by"), selection: $_sort) {
				ForEach(SourceSort.allCases, id: \.self) { option in
					Label(option.title, systemImage: option.systemImage).tag(option)
				}
			}

			SortOrderPicker(ascending: $_sortAscending)

			Section {
				Toggle(isOn: $_sourcesTabShowAllReposDirectly) {
					Label(.localized("Show All Apps by Default"), systemImage: "square.stack")
				}
			}
		} label: {
			Label(.localized("Sort"), systemImage: "line.3.horizontal.decrease")
		}
	}

	// MARK: - Selection Methods
	private var _deletableSources: [AltSource] {
		_filteredSources
	}

	private func toggleSelection(for source: AltSource) {
		NBHaptic.selection()
		if _selectedSources.contains(source) {
			_selectedSources.remove(source)
		} else {
			_selectedSources.insert(source)
		}
	}

	private var areAllSourcesSelected: Bool {
		let all = Set(_deletableSources)
		return !all.isEmpty && _selectedSources == all
	}

	private func selectAllSources() {
		if areAllSourcesSelected {
			_selectedSources.removeAll()
		} else {
			_selectedSources = Set(_deletableSources)
		}
	}

	private func deleteSelectedSources() {
		withAnimation {
			for source in _selectedSources {
				Storage.shared.deleteSource(for: source)
			}
			_selectedSources.removeAll()
			_isEditMode = false
		}
	}

	// MARK: - Navigation Handler
	private func handlePendingNavigation(_ pendingNavigation: AppNavigationManager.PendingAppNavigation?) {
		guard let navigation = pendingNavigation else { return }

		if let activeSource = _activeIndividualSource {
			if let repository = viewModel.sources[activeSource],
			   appExistsInRepository(appId: navigation.appId, repository: repository) {
				// Already in the right source — let it handle scrolling.
				return
			} else {
				_activeIndividualSource = nil

				// Let the source close before opening All Repositories.
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
					self._shouldNavigateToAllRepos = true
				}
				return
			}
		}

		if !_shouldNavigateToAllRepos {
			_shouldNavigateToAllRepos = true
		}
	}

	private func appExistsInRepository(appId: String, repository: ASRepository) -> Bool {
		for app in repository.apps {
			if app.currentUniqueId == appId {
				return true
			}
		}
		return false
	}
}

/// No sources yet, in NullSign's empty-state style.
struct NoRepositoriesView: View {
	let onAdd: () -> Void

	var body: some View {
		SourceEmptyState(
			icon: "square.grid.2x2",
			title: .localized("No Repositories"),
			message: "Add an AltStore-compatible source to browse its apps and import them into NullSign.",
			actionTitle: .localized("Add Source"),
			action: onAdd
		)
	}
}

// MARK: - Sort
extension SourcesView {
	enum SourceSort: String, CaseIterable {
		case name, apps, added

		var title: String {
			switch self {
			case .name: .localized("Name")
			case .apps: .localized("App Count")
			case .added: .localized("Date Added")
			}
		}

		var systemImage: String {
			switch self {
			case .name: "textformat"
			case .apps: "number"
			case .added: "calendar"
			}
		}
	}
}
