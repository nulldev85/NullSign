//
//  SourceAppsTableView.swift
//  Feather
//
//  Created by samara on 3.05.2025.
//

import SwiftUI
import AltSourceKit
import UIKit

// MARK: - Representable
struct SourceAppsTableRepresentableView: UIViewRepresentable {
	var sourceContexts: [SourceAppsView.SourceRepositoryContext]
	@Binding var searchText: String
	@Binding var sortOption: SourceAppsView.SortOption
	@Binding var sortAscending: Bool
	var onSelect: (SourceAppsView.SourceAppRoute) -> Void
	var onActions: (SourceAppsView.SourceAppRoute) -> Void
	
	func makeUIView(context: Context) -> UITableView {
		let tableView = UITableView(frame: .zero, style: .plain)
		tableView.delegate = context.coordinator
		tableView.dataSource = context.coordinator
		tableView.backgroundColor = .clear
		tableView.separatorStyle = .none
		tableView.showsVerticalScrollIndicator = false
		tableView.contentInset.bottom = 18
		tableView.sectionHeaderTopPadding = 0
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AppCell")
		tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
		
		tableView.allowsSelection = true
		tableView.addGestureRecognizer(UILongPressGestureRecognizer(
			target: context.coordinator, action: #selector(Coordinator.presentActions(_:))
		))
		
		if
			let firstSource = sourceContexts.first,
			sourceContexts.count == 1,
			let news = firstSource.repository.news,
			!news.isEmpty
		{
			let header = UIHostingController(rootView: SourceNewsView(news: news).nullSignTypography())
			context.coordinator.headerController = header
			header.view.translatesAutoresizingMaskIntoConstraints = true
			header.view.backgroundColor = .clear
			header.view.autoresizingMask = [.flexibleWidth]
			let fixedHeight: CGFloat = 178
			let width = UIScreen.main.bounds.width
			header.view.frame = CGRect(origin: .zero, size: CGSize(width: width, height: fixedHeight))
			tableView.tableHeaderView = header.view
		}
		
		return tableView
	}
	
	func updateUIView(_ tableView: UITableView, context: Context) {
		context.coordinator.uiTableView = tableView
		
		let sourcesChanged = context.coordinator.sourceContexts != sourceContexts
		let searchChanged = context.coordinator.searchText != searchText
		let sortOptionChanged = context.coordinator.sortOption != sortOption
		let sortDirectionChanged = context.coordinator.sortAscending != sortAscending
		
		context.coordinator.sourceContexts = sourceContexts
		context.coordinator.searchText = searchText
		context.coordinator.sortOption = sortOption
		context.coordinator.sortAscending = sortAscending
		context.coordinator.onSelect = onSelect
		context.coordinator.onActions = onActions
		
		if sourcesChanged || searchChanged || sortOptionChanged || sortDirectionChanged {
			context.coordinator.invalidateCache(
				animated: !searchChanged && (sortOptionChanged || sortDirectionChanged)
			)
		}
	}
	
	func makeCoordinator() -> Coordinator {
		Coordinator(
			sourceContexts: sourceContexts,
			searchText: searchText,
			sortOption: sortOption,
			sortAscending: sortAscending,
			onSelect: onSelect,
			onActions: onActions
		)
	}
}

// MARK: - Representable Extension: Coordinator
extension SourceAppsTableRepresentableView { class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
	var sourceContexts: [SourceAppsView.SourceRepositoryContext]
	var searchText: String
	var sortOption: SourceAppsView.SortOption
	var sortAscending: Bool
	var onSelect: (SourceAppsView.SourceAppRoute) -> Void
	var onActions: (SourceAppsView.SourceAppRoute) -> Void
	
	private var _groupedAppsByNameFirstLetter: [String: [SourceAppEntry]] = [:]
	private var _groupedAppsByDate: [String: [SourceAppEntry]] = [:]
	private var _sortedSectionTitles: [String] = []
	
	private var _cachedSortedApps: [SourceAppEntry] = []
	private var _isCacheValid = false
	weak var uiTableView: UITableView?
	var headerController: UIViewController?
	
	private var _allAppsWithSource: [SourceAppEntry] {
		sourceContexts.flatMap { context in
			context.repository.apps.map {
				SourceAppEntry(
					sourceURL: context.sourceURL,
					source: context.repository,
					app: $0
				)
			}
		}
	}
	
	private var _sortedApps: [SourceAppEntry] {
		if _isCacheValid {
			return _cachedSortedApps
		}
		_cachedSortedApps = _calculateSortedApps()
		_isCacheValid = true
		return _cachedSortedApps
	}
	
	init(
		sourceContexts: [SourceAppsView.SourceRepositoryContext],
		searchText: String,
		sortOption: SourceAppsView.SortOption,
		sortAscending: Bool,
		onSelect: @escaping (SourceAppsView.SourceAppRoute) -> Void,
		onActions: @escaping (SourceAppsView.SourceAppRoute) -> Void
	) {
		self.sourceContexts = sourceContexts
		self.searchText = searchText
		self.sortOption = sortOption
		self.sortAscending = sortAscending
		self.onSelect = onSelect
		self.onActions = onActions
		super.init()
		
		invalidateCache()
	}
	
	private func _calculateSortedApps() -> [SourceAppEntry] {
		let filtered = _allAppsWithSource.filter {
			searchText.isEmpty ||
			($0.app.id?.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US")) != nil) ||
				($0.app.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
				($0.app.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
				($0.app.subtitle?.localizedCaseInsensitiveContains(searchText) ?? false) ||
				($0.app.localizedDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
		}
		
		switch sortOption {
		case .default:
			_groupedAppsByDate = [:]
			_groupedAppsByNameFirstLetter = [:]
			_sortedSectionTitles = []
			return sortAscending ? filtered : filtered.reversed()
		case .date:
			let sorted = filtered.sorted {
				let d1 = $0.app.currentDate?.date ?? .distantPast
				let d2 = $1.app.currentDate?.date ?? .distantPast
				return sortAscending ? (d1 < d2) : (d1 > d2)
			}
			
			let formatter = DateFormatter()
			formatter.dateFormat = "MMMM d, yyyy"
			
			let grouped = Dictionary(grouping: sorted) {
				$0.app.currentDate?.date.stripTime() ?? .distantPast
			}
			
			let sortedDates = grouped.keys.sorted(by: { sortAscending ? $0 < $1 : $0 > $1 })
			
			_groupedAppsByDate = grouped.reduce(into: [:]) { result, pair in
				let key = formatter.string(from: pair.key)
				result[key] = pair.value
			}
			
			_sortedSectionTitles = sortedDates.map { formatter.string(from: $0) }
			return sorted
		case .name:
			let sorted = filtered.sorted {
				let n1 = $0.app.name ?? ""
				let n2 = $1.app.name ?? ""
				let comparison = n1.localizedCaseInsensitiveCompare(n2)
				return sortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
			}
			_groupedAppsByNameFirstLetter = Dictionary(grouping: sorted) {
				let first = $0.app.name?.trimmingCharacters(in: .whitespacesAndNewlines).first?.uppercased() ?? "#"
				return first.range(of: "[A-Z]", options: .regularExpression) != nil ? first : "#"
			}
			_sortedSectionTitles = _groupedAppsByNameFirstLetter.keys.sorted(by: {
				if $0 == "#" { return false }
				if $1 == "#" { return true }
				return sortAscending ? $0 < $1 : $0 > $1
			})
			return sorted
		}
	}
	
	func invalidateCache(animated: Bool = false) {
		_isCacheValid = false
		_cachedSortedApps = _calculateSortedApps()
		_isCacheValid = true
		if let tableView = uiTableView {
			if animated && !UIAccessibility.isReduceMotionEnabled {
				UIView.transition(
					with: tableView,
					duration: 0.18,
					options: [.transitionCrossDissolve, .beginFromCurrentState],
					animations: tableView.reloadData
				)
			} else {
				UIView.performWithoutAnimation(tableView.reloadData)
			}
		}
	}
	
	// MARK: TableView
	
	func numberOfSections(in tableView: UITableView) -> Int {
		switch sortOption {
		case .default: 1
		case .name, .date: _sortedSectionTitles.count
		}
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch sortOption {
		case .default: _sortedApps.count
		case .name: _groupedAppsByNameFirstLetter[_sortedSectionTitles[section]]?.count ?? 0
		case .date: _groupedAppsByDate[_sortedSectionTitles[section]]?.count ?? 0
		}
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "AppCell", for: indexPath)
		let entry: SourceAppEntry
		switch sortOption {
		case .default: entry = _sortedApps[indexPath.row]
		case .name: entry = _groupedAppsByNameFirstLetter[_sortedSectionTitles[indexPath.section]]?[indexPath.row] ?? _sortedApps[indexPath.row]
		case .date: entry = _groupedAppsByDate[_sortedSectionTitles[indexPath.section]]?[indexPath.row] ?? _sortedApps[indexPath.row]
		}

		cell.backgroundColor = .clear
		cell.selectionStyle = .none
		cell.contentConfiguration = UIHostingConfiguration {
			SourceAppsCellView(sourceURL: entry.sourceURL, source: entry.source, app: entry.app)
				.nullSignTypography()
				.accessibilityAction(named: Text(.localized("App Actions"))) {
					self.onActions(SourceAppsView.SourceAppRoute(sourceURL: entry.sourceURL, source: entry.source, app: entry.app))
				}
		}
		.margins(.all, 0)
		.background(Color.clear)
		return cell
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)

		let entry: SourceAppEntry
		switch sortOption {
		case .default: entry = _sortedApps[indexPath.row]
		case .name: entry = _groupedAppsByNameFirstLetter[_sortedSectionTitles[indexPath.section]]?[indexPath.row] ?? _sortedApps[indexPath.row]
		case .date: entry = _groupedAppsByDate[_sortedSectionTitles[indexPath.section]]?[indexPath.row] ?? _sortedApps[indexPath.row]
		}

		onSelect(SourceAppsView.SourceAppRoute(sourceURL: entry.sourceURL, source: entry.source, app: entry.app))
	}
	
	func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader")
		let title: String
		
		switch sortOption {
		case .default: title = .localized("%lld Apps", arguments: _sortedApps.count)
		case .name, .date: title = _sortedSectionTitles[section]
		}
		
		// Sticky headers float over the cards, so they get a frosted backing.
		let backing = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
		backing.backgroundColor = UIColor(NullSignStyle.canvas).withAlphaComponent(0.85)
		headerView?.backgroundView = backing
		headerView?.contentConfiguration = UIHostingConfiguration {
			SourceSectionLabel(title: title, prominent: false)
				.nullSignTypography()
				.padding(.horizontal, 20)
				.padding(.vertical, 8)
		}
		.margins(.all, 0)
		.background(Color.clear)
		
		return headerView
	}
	
	func sectionIndexTitles(for tableView: UITableView) -> [String]? {
		sortOption == .name ? _sortedSectionTitles : nil
	}
	
	func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
		_sortedSectionTitles.firstIndex(of: title) ?? 0
	}
	
	// The native UIMenu cannot share the app's rounded fonts and card palette.
	@objc func presentActions(_ gesture: UILongPressGestureRecognizer) {
		guard gesture.state == .began,
			let tableView = gesture.view as? UITableView,
			let indexPath = tableView.indexPathForRow(at: gesture.location(in: tableView)),
			let entry = entry(at: indexPath)
		else { return }
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
		onActions(SourceAppsView.SourceAppRoute(sourceURL: entry.sourceURL, source: entry.source, app: entry.app))
	}

	/// A refresh/search can change sections while a long press is in progress.
	private func entry(at indexPath: IndexPath) -> SourceAppEntry? {
		let apps: [SourceAppEntry]
		switch sortOption {
		case .default: apps = _sortedApps
		case .name, .date:
			guard _sortedSectionTitles.indices.contains(indexPath.section) else { return nil }
			let section = _sortedSectionTitles[indexPath.section]
			apps = sortOption == .name
				? (_groupedAppsByNameFirstLetter[section] ?? [])
				: (_groupedAppsByDate[section] ?? [])
		}
		guard apps.indices.contains(indexPath.row) else { return nil }
		return apps[indexPath.row]
	}
}}

private struct SourceAppEntry {
	let sourceURL: URL?
	let source: ASRepository
	let app: ASRepository.App
}
