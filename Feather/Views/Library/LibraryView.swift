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
	@State private var _updateCheckRotation = 0.0
	@State private var _isUpdateCheckCompleteVisible = false
	
	// MARK: Selection State
	@State private var _selectedAppUUIDs: Set<String> = []
	@State private var _editMode: EditMode = .inactive
	
	@State private var _searchText = ""
	@State private var _selectedScope: Scope = .all
	
	
	@Namespace private var _namespace
	
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

	private var _visibleAppsEmpty: Bool {
		switch _selectedScope {
		case .all: return _filteredSignedApps.isEmpty && _filteredImportedApps.isEmpty
		case .signed: return _filteredSignedApps.isEmpty
		case .imported: return _filteredImportedApps.isEmpty
		}
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
		NBNavigationView("Signer") {
			Group {
				if _hasApps {
					NBListAdaptable {
						NullSignLibrarySummary(
							signedCount: _signedApps.count,
							importedCount: _importedApps.count,
							hasCertificate: !_certificates.isEmpty
						)
						_libraryTools

						if
							!_filteredSignedApps.isEmpty,
							_selectedScope == .all || _selectedScope == .signed
						{
							NBSection(.localized("Signed"), secondary: _filteredSignedApps.count.description) {
								ForEach(_filteredSignedApps, id: \.uuid) { app in
									LibraryCellView(
										app: app,
										selectedInfoAppPresenting: $_selectedInfoAppPresenting,
										selectedSigningAppPresenting: $_selectedSigningAppPresenting,
										selectedInstallAppPresenting: $_selectedInstallAppPresenting,
										selectedAppUUIDs: $_selectedAppUUIDs
									)
									.compatMatchedTransitionSource(id: app.uuid ?? "", ns: _namespace)
								}
							}
						}

						if
							!_filteredImportedApps.isEmpty,
							_selectedScope == .all || _selectedScope == .imported
						{
							NBSection(.localized("Imported"), secondary: _filteredImportedApps.count.description) {
								ForEach(_filteredImportedApps, id: \.uuid) { app in
									LibraryCellView(
										app: app,
										selectedInfoAppPresenting: $_selectedInfoAppPresenting,
										selectedSigningAppPresenting: $_selectedSigningAppPresenting,
										selectedInstallAppPresenting: $_selectedInstallAppPresenting,
										selectedAppUUIDs: $_selectedAppUUIDs
									)
									.compatMatchedTransitionSource(id: app.uuid ?? "", ns: _namespace)
								}
							}
						}

						if _visibleAppsEmpty {
							VStack(spacing: 8) {
								Image(systemName: "line.3.horizontal.decrease.circle")
									.font(.system(size: 24, weight: .light))
									.foregroundStyle(NullSignStyle.cyan)
								Text(_searchText.isEmpty ? "Nothing in this group" : "No matching apps")
									.font(.system(size: 15, weight: .semibold))
								if !_searchText.isEmpty {
									Button("Clear search") { _searchText = "" }
										.font(.footnote.weight(.semibold))
								}
							}
							.frame(maxWidth: .infinity)
							.padding(.vertical, 26)
							.listRowBackground(Color.clear)
							.listRowSeparator(.hidden)
						}
					}
					.scrollContentBackground(.hidden)
					.background(Color.black)
					.scrollDismissesKeyboard(.interactively)
				} else {
					NullSignEmptySignerView(
						hasCertificate: !_certificates.isEmpty,
						importFile: { _isImportingPresenting = true },
						importURL: { _isDownloadingPresenting = true }
					)
				}
			}
			.toolbar {
				if _hasApps {
					ToolbarItem(placement: .topBarLeading) { EditButton() }
				}
				
				if _editMode.isEditing {
					NBToolbarButton(
						.localized("Delete"),
						systemImage: "trash",
						isDisabled: _selectedAppUUIDs.isEmpty
					) {
						_bulkDeleteSelectedApps()
					}
				} else if _hasApps {
					ToolbarItem(placement: .topBarTrailing) {
						Button {
							Task {
								await _checkForUpdates()
							}
						} label: {
							Image(systemName: _isUpdateCheckCompleteVisible ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
								.rotationEffect(.degrees(_updateCheckRotation))
								.animation(
									updateManager.isChecking
										? .linear(duration: 0.8).repeatForever(autoreverses: false)
										: .default,
									value: _updateCheckRotation
								)
						}
						.disabled(updateManager.isChecking)
						.accessibilityLabel(.localized("Check for Updates"))
					}
					
					NBToolbarMenu(
						systemImage: "plus",
						style: .icon,
						placement: .topBarTrailing
					) {
						_importActions()
					}
				}
			}
			.environment(\.editMode, $_editMode)
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
					if let url = URL(string: _alertDownloadString) {
						_ = downloadManager.startDownload(from: url, id: "FeatherManualDownload_\(UUID().uuidString)")
					}
				}
			}
			.onReceive(NotificationCenter.default.publisher(for: Notification.Name("Feather.installApp"))) { _ in
				if let latest = _signedApps.first {
					_selectedInstallAppPresenting = AnyApp(base: latest)
				}
			}
			.onChange(of: _editMode) { mode in
				if mode == .inactive {
					_selectedAppUUIDs.removeAll()
				}
			}
			.onChange(of: updateManager.isChecking) { isChecking in
				_handleUpdateCheckStateChange(isChecking)
			}
		}
	}
}

// MARK: - Extension: View
extension LibraryView {
	private var _libraryTools: some View {
		VStack(spacing: 10) {
			HStack(spacing: 10) {
				Image(systemName: "magnifyingglass")
					.foregroundStyle(NullSignStyle.muted)
				TextField("Search signed and imported apps", text: $_searchText)
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled()
				if !_searchText.isEmpty {
					Button { _searchText = "" } label: {
						Image(systemName: "xmark.circle.fill").foregroundStyle(NullSignStyle.muted)
					}
					.buttonStyle(.plain)
				}
			}
			.padding(.horizontal, 13)
			.frame(height: 42)
			.background(NullSignStyle.panel)
			.overlay {
				RoundedRectangle(cornerRadius: 11, style: .continuous)
					.stroke(NullSignStyle.hairline, lineWidth: 1)
			}
			.clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

			HStack(spacing: 6) {
				ForEach(Scope.allCases, id: \.displayName) { scope in
					Button {
						withAnimation(.easeOut(duration: 0.16)) { _selectedScope = scope }
					} label: {
						Text(scope.displayName)
							.font(.system(size: 12, weight: .semibold))
							.foregroundStyle(_selectedScope == scope ? .black : NullSignStyle.muted)
							.frame(maxWidth: .infinity)
							.frame(height: 30)
							.background(_selectedScope == scope ? NullSignStyle.cyan : Color.clear)
							.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
					}
					.buttonStyle(.plain)
				}
			}
			.padding(3)
			.background(NullSignStyle.panel)
			.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
		}
		.listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
		.listRowBackground(Color.clear)
		.listRowSeparator(.hidden)
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

// MARK: - Extension: Bulk Delete
extension LibraryView {
	private func _bulkDeleteSelectedApps() {
		let selectedApps = _getAllApps().filter { app in
			guard let uuid = app.uuid else { return false }
			return _selectedAppUUIDs.contains(uuid)
		}
		
		for app in selectedApps {
			Storage.shared.deleteApp(for: app)
		}
		
		_selectedAppUUIDs.removeAll()
		
		// _editMode = .inactive
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
	
	private func _checkForUpdates() async {
		let localApps = _signedApps.map { $0 as AppInfoPresentable } + _importedApps.map { $0 as AppInfoPresentable }
		await updateManager.checkForUpdates(
			sources: Array(_sources),
			localApps: localApps
		)
	}
	
	private func _handleUpdateCheckStateChange(_ isChecking: Bool) {
		if isChecking {
			_isUpdateCheckCompleteVisible = false
			_updateCheckRotation = 0
			withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
				_updateCheckRotation = 360
			}
		} else {
			withAnimation(.none) {
				_updateCheckRotation = 0
			}
			
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
