//
//  ContentView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import CoreData
import NimbleViews

// MARK: - View
struct LibraryView: View {
	@StateObject var downloadManager = DownloadManager.shared
	@StateObject var updateManager = UpdateManager.shared
	@Environment(\.scenePhase) private var _scenePhase

	@State private var _selectedInfoAppPresenting: AnyApp?
	@State private var _selectedSigningAppPresenting: AnyApp?
	@State private var _selectedInstallAppPresenting: AnyApp?
	@State private var _isImportingPresenting = false
	@State private var _isImportMenuPresenting = false
	@State private var _pendingImportDestination: ImportDestination?
	@State private var _isDownloadingPresenting = false
	@State private var _pendingDownloadURL: URL?
	@State private var _isUpdateCheckCompleteVisible = false
	@State private var _isCertificatesPresenting = false
	@State private var _isBulkDeleteConfirmationPresented = false
	@State private var _bulkDeleteAfterDismissal = false

	// Automatic re-checks are throttled so opening the tab doesn't hammer every added source.
	private let _autoUpdateCheckInterval: TimeInterval = 6 * 60 * 60

	// MARK: Selection State
	@State private var _selectedAppUUIDs: Set<String> = []
	@State private var _isSelecting = false

	@State private var _searchText = ""
	@State private var _selectedScope: Scope = .all

	@Namespace private var _namespace
	@Environment(\.accessibilityReduceMotion) private var _reduceMotion

	// horror
	private func filteredAndSortedApps<T>(from apps: FetchedResults<T>) -> [T] where T: NSManagedObject {
		apps.filter {
			_searchText.isEmpty ||
				(($0.value(forKey: "name") as? String)?.localizedCaseInsensitiveContains(_searchText) ?? false)
		}
	}

	private var _filteredSignedApps: [Signed] {
		filteredAndSortedApps(from: _signedApps)
	}

	private var _filteredImportedApps: [Imported] {
		filteredAndSortedApps(from: _importedApps)
	}

	private var _hasApps: Bool {
		!_signedApps.isEmpty || !_importedApps.isEmpty
	}

	// MARK: Fetch
	@FetchRequest(
		entity: Signed.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
		animation: .snappy
	) private var _signedApps: FetchedResults<Signed>

	@FetchRequest(
		entity: Imported.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Imported.date, ascending: false)],
		animation: .snappy
	) private var _importedApps: FetchedResults<Imported>

	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>

	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]
	) private var _certificates: FetchedResults<CertificatePair>

	// MARK: Body
	var body: some View {
		// Computed once per render (instead of once per call site below) so
		// the search filter doesn't re-scan the full signed/imported lists
		// several times on every keystroke or unrelated state change.
		let filteredSignedApps = _filteredSignedApps
		let filteredImportedApps = _filteredImportedApps
		let showsSigned = !filteredSignedApps.isEmpty && (_selectedScope == .all || _selectedScope == .signed)
		let showsImported = !filteredImportedApps.isEmpty && (_selectedScope == .all || _selectedScope == .imported)

		NBNavigationView("Signer", displayMode: .inline) {
			List {
				NullSignOverviewBanner(
					title: "On this device",
					value: (_signedApps.count + _importedApps.count).formatted(),
					detail: "\(_signedApps.count) signed · \(_importedApps.count) imported",
					systemImage: "checkmark.seal.fill"
				)
				.nullSignListRow(top: 0, bottom: 0, horizontal: 0)

				NullSignIdentityCard(certificate: NullSignIdentity.activeCertificate(in: _certificates)) {
					_isCertificatesPresenting = true
				}
				.nullSignListRow(top: 4, bottom: 6)

				if _hasApps {
					_libraryTools
						.nullSignListRow(top: 6, bottom: 4)

					if showsSigned {
						NullSignSectionLabel(title: .localized("Signed"), count: filteredSignedApps.count, prominent: true, systemImage: "checkmark.seal")
							.nullSignListRow(top: 20, bottom: 8, horizontal: 24)
						ForEach(filteredSignedApps, id: \.objectID) { app in
							_cell(for: app)
						}
					}

					if showsImported {
						NullSignSectionLabel(title: .localized("Imported"), count: filteredImportedApps.count, prominent: true, systemImage: "tray.and.arrow.down")
							.nullSignListRow(top: 20, bottom: 8, horizontal: 24)
						ForEach(filteredImportedApps, id: \.objectID) { app in
							_cell(for: app)
						}
					}

					if !showsSigned && !showsImported {
						_noResults
							.nullSignListRow(top: 28, bottom: 28)
					}
				} else {
					_emptyLibrary
						.nullSignListRow(top: 30, bottom: 30)
				}
			}
			.listStyle(.plain)
			// Section labels are short rows; don't pad them up to 44pt.
			.environment(\.defaultMinListRowHeight, 0)
			.scrollContentBackground(.hidden)
			.nullSignPage()
			.scrollDismissesKeyboard(.interactively)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					if _hasApps {
						Button {
							_setSelecting(!_isSelecting)
						} label: {
							Text(_isSelecting ? "Done" : "Select")
								.font(.roundedUI(size: 15, weight: .bold))
						}
					}
				}

				ToolbarItemGroup(placement: .topBarTrailing) {
					if _hasApps && !_isSelecting {
						Button {
							Task {
								await _checkForUpdates()
							}
						} label: {
							HStack(spacing: 6) {
								if updateManager.isChecking {
									ProgressView()
										.controlSize(.small)
								}
								Text(_updateCheckTitle)
									.font(.roundedUI(size: 15, weight: .bold))
									.lineLimit(1)
							}
						}
						.disabled(updateManager.isChecking)
					}

					if !_isSelecting {
						Button {
							_isImportMenuPresenting = true
						} label: {
							Image(systemName: "plus")
						}
						.accessibilityLabel(.localized("Import"))
					}
				}
			}
			.safeAreaInset(edge: .bottom, spacing: 0) {
				if _isSelecting {
					_selectionBar
						.transition(.move(edge: .bottom).combined(with: .opacity))
				}
			}
			.navigationDestination(isPresented: $_isCertificatesPresenting) {
				CertificatesView()
			}
			.sheet(item: $_selectedInfoAppPresenting) { app in
				LibraryInfoView(app: app.base)
			}
			.sheet(item: $_selectedInstallAppPresenting) { app in
				InstallPreviewView(app: app.base, isSharing: app.archive)
					.presentationDetents([.height(230)])
					.presentationDragIndicator(.visible)
			}
			.fullScreenCover(item: $_selectedSigningAppPresenting) { app in
				SigningView(app: app.base)
					.compatNavigationTransition(id: app.base.uuid ?? "", ns: _namespace)
			}
			.sheet(isPresented: $_isImportingPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes:  [.ipa, .tipa],
					allowsMultipleSelection: true,
					onDocumentsPicked: { urls in
						guard !urls.isEmpty else { return }

						for url in urls {
							let id = "FeatherManualDownload_\(UUID().uuidString)"
							let dl = downloadManager.startArchive(from: url, id: id)
							try? downloadManager.handlePachageFile(url: url, dl: dl)
						}
					}
				)
				.ignoresSafeArea()
			}
			.sheet(isPresented: $_isImportMenuPresenting, onDismiss: _openPendingImport) {
				NullSignMenuSheet(
					title: .localized("Import"), systemImage: "tray.and.arrow.down",
					detail: "Choose how to add an app to your signing library."
				) {
					NullSignSettingsCard {
						NullSignMenuAction(
							title: .localized("Import from Files"), systemImage: "folder.fill",
							detail: "Choose one or more IPA or TIPA files.", tint: NullSignStyle.warning
						) { _chooseImport(.files) }
						NullSignSettingsDivider()
						NullSignMenuAction(
							title: .localized("Import from URL"), systemImage: "link",
							detail: "Download an app from a direct link."
						) { _chooseImport(.url) }
					}
				}
			}
			.sheet(isPresented: $_isDownloadingPresenting, onDismiss: _startPendingURLDownload) {
				ImportURLView { url in
					_pendingDownloadURL = url
				}
			}
			.sheet(isPresented: $_isBulkDeleteConfirmationPresented, onDismiss: _deleteAfterConfirmation) {
				_bulkDeleteMenu
			}
			.onReceive(NotificationCenter.default.publisher(for: Notification.Name("Feather.installApp"))) { _ in
				if let latest = _signedApps.first {
					_selectedInstallAppPresenting = AnyApp(base: latest)
				}
			}
			.onChange(of: _hasApps) { hasApps in
				if !hasApps {
					_setSelecting(false)
				}
			}
			.onChange(of: updateManager.isChecking) { isChecking in
				_handleUpdateCheckStateChange(isChecking)
			}
			.task {
				await _autoCheckForUpdatesIfNeeded()
			}
			// Coming back to NullSign checks again once the last check is old
			// enough, so an app left open for days still hears about updates.
			.onChange(of: _scenePhase) { phase in
				guard phase == .active else { return }
				Task { await _autoCheckForUpdatesIfNeeded() }
			}
		}
		.tint(NullSignStyle.accent)
	}
}

// MARK: - Extension: View
extension LibraryView {
	private func _cell(for app: AppInfoPresentable) -> some View {
		LibraryCellView(
			app: app,
			isSelecting: _isSelecting,
			selectedInfoAppPresenting: $_selectedInfoAppPresenting,
			selectedSigningAppPresenting: $_selectedSigningAppPresenting,
			selectedInstallAppPresenting: $_selectedInstallAppPresenting,
			selectedAppUUIDs: $_selectedAppUUIDs
		)
		.compatMatchedTransitionSource(id: app.uuid ?? "", ns: _namespace)
		.nullSignListRow(top: 5, bottom: 5)
	}

	private var _libraryTools: some View {
		VStack(spacing: 10) {
			NullSignSearchField(prompt: "Search", text: $_searchText)
			NullSignSegmentedControl(
				options: Scope.allCases,
				selection: $_selectedScope,
				title: \.displayName,
				count: { scope in
					switch scope {
					case .all: return nil
					case .signed: return _signedApps.count
					case .imported: return _importedApps.count
					}
				}
			)
		}
	}

	private var _emptyLibrary: some View {
		NullSignEmptyState(
			systemImage: "shippingbox",
			title: "No Apps Yet",
			message: _certificates.isEmpty
				? "Import an IPA to get started. You'll also need a certificate, which you can add in Settings."
				: "Import an IPA from Files or a link to sign it."
		) {
			VStack(spacing: 10) {
				Button {
					_isImportingPresenting = true
				} label: {
					Text("Import from Files")
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(NullSignPrimaryButtonStyle())

				Button {
					_isDownloadingPresenting = true
				} label: {
					Text("Import from URL")
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(NullSignSecondaryButtonStyle())
			}
			// Size the stack to its widest label so both buttons hug their
			// text and still match each other.
			.fixedSize(horizontal: true, vertical: false)
			.padding(.top, 4)
		}
	}

	private var _noResults: some View {
		VStack(spacing: 8) {
			Text(_searchText.isEmpty ? "Nothing here yet" : "No Results")
				.font(.roundedUI(.headline))
			if !_searchText.isEmpty {
				Text("No apps match “\(_searchText)”.")
					.font(.roundedUI(.subheadline))
					.foregroundStyle(NullSignStyle.muted)
			}
		}
		.frame(maxWidth: .infinity)
	}

	private var _selectionBar: some View {
		HStack(spacing: 10) {
			Text(_selectedAppUUIDs.isEmpty ? "Select apps" : "\(_selectedAppUUIDs.count) selected")
				.font(.roundedUI(.headline))
				.monospacedDigit()
			Spacer(minLength: 8)
			Button {
				_toggleSelectAllVisible()
			} label: {
				Text(_allVisibleSelected ? "Deselect All" : "Select All")
			}
			.buttonStyle(NullSignSecondaryButtonStyle(height: 36))

			Button {
				_isBulkDeleteConfirmationPresented = true
			} label: {
				Text(.localized("Delete"))
			}
			.buttonStyle(NullSignPrimaryButtonStyle(height: 36, tint: NullSignStyle.danger))
			.disabled(_selectedAppUUIDs.isEmpty)
		}
		.padding(.leading, 18)
		.padding(.trailing, 8)
		.padding(.vertical, 8)
		.background(.ultraThinMaterial, in: Capsule())
		.background(NullSignStyle.groupedSurface.opacity(0.85), in: Capsule())
		.overlay(Capsule().strokeBorder(NullSignStyle.hairline, lineWidth: 1))
		.padding(.horizontal, 16)
		.padding(.bottom, 8)
	}

	private enum ImportDestination {
		case files, url
	}

	private func _chooseImport(_ destination: ImportDestination) {
		_pendingImportDestination = destination
		_isImportMenuPresenting = false
	}

	/// Present the next sheet only after the choices panel has finished dismissing.
	private func _openPendingImport() {
		guard let destination = _pendingImportDestination else { return }
		_pendingImportDestination = nil
		switch destination {
		case .files: _isImportingPresenting = true
		case .url: _isDownloadingPresenting = true
		}
	}

	private func _startPendingURLDownload() {
		guard let url = _pendingDownloadURL else { return }
		_pendingDownloadURL = nil
		_ = downloadManager.startDownload(from: url, id: "FeatherManualDownload_\(UUID().uuidString)")
	}
}

// MARK: - Extension: Selection & Bulk Delete
extension LibraryView {
	private var _bulkDeleteTitle: String {
		_selectedAppUUIDs.count == 1 ? "Delete 1 app?" : "Delete \(_selectedAppUUIDs.count) apps?"
	}

	private var _bulkDeleteMenu: some View {
		NullSignMenuSheet(title: _bulkDeleteTitle, systemImage: "trash", detail: "The selected app files will be removed from this device. This cannot be undone.") {
			NullSignSettingsCard {
				NullSignMenuAction(title: "Delete Selected Apps", systemImage: "trash", isDestructive: true, isDisabled: _selectedAppUUIDs.isEmpty) {
					_bulkDeleteAfterDismissal = true
					_isBulkDeleteConfirmationPresented = false
				}
			}
			Button("Cancel") { _isBulkDeleteConfirmationPresented = false }
				.font(.roundedUI(.body, weight: .bold))
				.frame(maxWidth: .infinity, minHeight: 44)
		}
	}

	private func _deleteAfterConfirmation() {
		guard _bulkDeleteAfterDismissal else { return }
		_bulkDeleteAfterDismissal = false
		_bulkDeleteSelectedApps()
	}

	private var _allVisibleSelected: Bool {
		let visible = Set(_getAllApps().compactMap { $0.uuid })
		return !visible.isEmpty && visible.isSubset(of: _selectedAppUUIDs)
	}

	private func _setSelecting(_ selecting: Bool) {
		withAnimation(_reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.85)) {
			_isSelecting = selecting
			if !selecting {
				_selectedAppUUIDs.removeAll()
			}
		}
	}

	private func _toggleSelectAllVisible() {
		let visible = Set(_getAllApps().compactMap { $0.uuid })
		if _allVisibleSelected {
			_selectedAppUUIDs.subtract(visible)
		} else {
			_selectedAppUUIDs.formUnion(visible)
		}
	}

	private func _bulkDeleteSelectedApps() {
		let selectedApps = (_signedApps.map { $0 as AppInfoPresentable } + _importedApps.map { $0 as AppInfoPresentable })
			.filter { app in
				guard let uuid = app.uuid else { return false }
				return _selectedAppUUIDs.contains(uuid)
			}

		UINotificationFeedbackGenerator().notificationOccurred(.success)
		Storage.shared.deleteApps(selectedApps)
		_setSelecting(false)
	}

	private func _getAllApps() -> [AppInfoPresentable] {
		var allApps: [AppInfoPresentable] = []

		if _selectedScope == .all || _selectedScope == .signed {
			allApps.append(contentsOf: _filteredSignedApps)
		}

		if _selectedScope == .all || _selectedScope == .imported {
			allApps.append(contentsOf: _filteredImportedApps)
		}

		return allApps
	}
}

// MARK: - Extension: Updates
extension LibraryView {
	private func _checkForUpdates() async {
		let localApps = _signedApps.map { $0 as AppInfoPresentable } + _importedApps.map { $0 as AppInfoPresentable }
		await updateManager.checkForUpdates(
			sources: Array(_sources),
			localApps: localApps
		)
	}

	/// Runs the same check as the manual refresh button, but only when the tab appears and
	/// there's something to check, and no more often than `_autoUpdateCheckInterval`.
	private func _autoCheckForUpdatesIfNeeded() async {
		guard _hasApps, !_sources.isEmpty, !updateManager.isChecking else { return }

		if let lastChecked = updateManager.lastCheckedDate,
		   Date().timeIntervalSince(lastChecked) < _autoUpdateCheckInterval {
			return
		}

		await _checkForUpdates()
	}

	/// The update button says what it does, then for a moment what the check found.
	private var _updateCheckTitle: String {
		if updateManager.isChecking { return .localized("Checking…") }
		guard _isUpdateCheckCompleteVisible else { return .localized("Check for Updates") }
		switch updateManager.availableUpdateCount {
		case 0: return .localized("Up to Date")
		case 1: return .localized("1 Update Found")
		case let count: return .localized("%lld Updates Found", arguments: count)
		}
	}

	private func _handleUpdateCheckStateChange(_ isChecking: Bool) {
		if isChecking {
			_isUpdateCheckCompleteVisible = false
		} else {
			_isUpdateCheckCompleteVisible = true
			Task { @MainActor in
				try? await Task.sleep(nanoseconds: 2_500_000_000)
				if !updateManager.isChecking {
					_isUpdateCheckCompleteVisible = false
				}
			}
		}
	}
}

// MARK: - Extension: View (Sort)
extension LibraryView {
	enum Scope: CaseIterable {
		case all
		case signed
		case imported

		var displayName: String {
			switch self {
			case .all: return .localized("All")
			case .signed: return .localized("Signed")
			case .imported: return .localized("Imported")
			}
		}
	}
}
