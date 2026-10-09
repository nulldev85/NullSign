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

	@State private var _selectedInfoAppPresenting: AnyApp?
	@State private var _selectedSigningAppPresenting: AnyApp?
	@State private var _selectedInstallAppPresenting: AnyApp?
	@State private var _isImportingPresenting = false
	@State private var _isDownloadingPresenting = false
	@State private var _alertDownloadString: String = "" // for _isDownloadingPresenting
	@State private var _isUpdateCheckCompleteVisible = false
	@State private var _isCertificatesPresenting = false
	@State private var _isBulkDeleteConfirmationPresented = false

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

	private var _subtitle: String {
		guard _hasApps else { return "No apps yet" }
		return "\(_signedApps.count) signed · \(_importedApps.count) imported"
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

		NBNavigationView("", displayMode: .inline) {
			List {
				NullSignTitle(title: "Signer", subtitle: _subtitle)
					.nullSignListRow(top: 2, bottom: 14)

				NullSignIdentityCard(certificate: NullSignIdentity.activeCertificate(in: _certificates)) {
					_isCertificatesPresenting = true
				}
				.nullSignListRow(bottom: 8)

				if _hasApps {
					_libraryTools
						.nullSignListRow(top: 8, bottom: 6)

					if showsSigned {
						NullSignSectionLabel(title: .localized("Signed"), count: filteredSignedApps.count)
							.nullSignListRow(top: 16, bottom: 4, horizontal: 20)
						ForEach(filteredSignedApps, id: \.objectID) { app in
							_cell(for: app)
						}
					}

					if showsImported {
						NullSignSectionLabel(title: .localized("Imported"), count: filteredImportedApps.count)
							.nullSignListRow(top: 16, bottom: 4, horizontal: 20)
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
			.background(NullSignBackdrop())
			.scrollDismissesKeyboard(.interactively)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					if _hasApps {
						Button {
							_setSelecting(!_isSelecting)
						} label: {
							Text(_isSelecting ? "Done" : "Select")
								.font(.system(size: 15, weight: .semibold))
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
							if updateManager.isChecking {
								ProgressView()
							} else {
								Image(systemName: _isUpdateCheckCompleteVisible ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
							}
						}
						.disabled(updateManager.isChecking)
						.accessibilityLabel(.localized("Check for Updates"))
					}

					if !_isSelecting {
						Menu {
							_importActions()
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
			.alert(.localized("Import from URL"), isPresented: $_isDownloadingPresenting) {
				TextField(.localized("URL"), text: $_alertDownloadString)
					.textInputAutocapitalization(.never)
				Button(.localized("Cancel"), role: .cancel) {
					_alertDownloadString = ""
				}
				Button(.localized("OK")) {
					let trimmed = _alertDownloadString.trimmingCharacters(in: .whitespacesAndNewlines)
					if let url = URL(string: trimmed), url.scheme != nil {
						_ = downloadManager.startDownload(from: url, id: "FeatherManualDownload_\(UUID().uuidString)")
					}
					_alertDownloadString = ""
				}
			}
			.confirmationDialog(
				_bulkDeleteTitle,
				isPresented: $_isBulkDeleteConfirmationPresented,
				titleVisibility: .visible
			) {
				Button(.localized("Delete"), role: .destructive) {
					_bulkDeleteSelectedApps()
				}
				Button(.localized("Cancel"), role: .cancel) {}
			} message: {
				Text("The app files are removed from this device.")
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
		}
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
			NullSignSearchField(prompt: "Search your library", text: $_searchText)
			NullSignSegmentedControl(
				options: Scope.allCases,
				selection: $_selectedScope,
				title: \.displayName
			)
		}
	}

	private var _emptyLibrary: some View {
		NullSignEmptyState(
			systemImage: "shippingbox",
			title: "Drop in an IPA",
			message: _certificates.isEmpty
				? "Import an app to start. You'll also need a certificate — add one from Settings."
				: "Import an app from Files or a link. NullSign checks every package before it signs."
		) {
			VStack(spacing: 10) {
				Button {
					_isImportingPresenting = true
				} label: {
					Label("Choose from Files", systemImage: "folder.fill")
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(NullSignPrimaryButtonStyle())

				Button {
					_isDownloadingPresenting = true
				} label: {
					Label("Import from a Link", systemImage: "link")
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(NullSignSecondaryButtonStyle())
			}
			.padding(.top, 6)
		}
	}

	private var _noResults: some View {
		VStack(spacing: 10) {
			Image(systemName: _searchText.isEmpty ? "line.3.horizontal.decrease" : "magnifyingglass")
				.font(.system(size: 22, weight: .semibold))
				.foregroundStyle(NullSignStyle.faint)
			Text(_searchText.isEmpty ? "Nothing in this group" : "No matching apps")
				.font(.system(size: 15, weight: .semibold))
			if !_searchText.isEmpty {
				Button("Clear Search") { _searchText = "" }
					.buttonStyle(NullSignSecondaryButtonStyle(height: 36))
			}
		}
		.frame(maxWidth: .infinity)
	}

	private var _selectionBar: some View {
		HStack(spacing: 10) {
			VStack(alignment: .leading, spacing: 2) {
				Text(_selectedAppUUIDs.isEmpty ? "Select apps" : "\(_selectedAppUUIDs.count) selected")
					.font(.system(size: 15, weight: .bold))
					.contentTransition(.numericText())
				Text("Tap cards to choose")
					.font(NullSignStyle.mono(10, weight: .medium))
					.foregroundStyle(NullSignStyle.muted)
			}
			Spacer(minLength: 8)
			Button {
				_toggleSelectAllVisible()
			} label: {
				Text(_allVisibleSelected ? "None" : "All")
			}
			.buttonStyle(NullSignSecondaryButtonStyle(height: 40))

			Button {
				_isBulkDeleteConfirmationPresented = true
			} label: {
				Label(.localized("Delete"), systemImage: "trash")
			}
			.buttonStyle(NullSignPrimaryButtonStyle(height: 40))
			.disabled(_selectedAppUUIDs.isEmpty)
		}
		.padding(.leading, 18)
		.padding(.trailing, 8)
		.padding(.vertical, 8)
		.background(Capsule().fill(.ultraThinMaterial))
		.background(Capsule().fill(Color.black.opacity(0.4)))
		.overlay(Capsule().strokeBorder(NullSignStyle.edge, lineWidth: 1))
		.padding(.horizontal, 16)
		.padding(.bottom, 8)
	}

	@ViewBuilder
	private func _importActions() -> some View {
		Button(.localized("Import from Files"), systemImage: "folder") {
			_isImportingPresenting = true
		}
		Button(.localized("Import from URL"), systemImage: "globe") {
			_isDownloadingPresenting = true
		}
	}
}

// MARK: - Extension: Selection & Bulk Delete
extension LibraryView {
	private var _bulkDeleteTitle: String {
		_selectedAppUUIDs.count == 1 ? "Delete 1 app?" : "Delete \(_selectedAppUUIDs.count) apps?"
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

	private func _handleUpdateCheckStateChange(_ isChecking: Bool) {
		if isChecking {
			_isUpdateCheckCompleteVisible = false
		} else {
			_isUpdateCheckCompleteVisible = true
			Task { @MainActor in
				try? await Task.sleep(nanoseconds: 900_000_000)
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
