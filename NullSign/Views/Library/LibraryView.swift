//
//  ContentView.swift
//  NullSign
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import CoreData
import NimbleViews
import NimbleExtensions

// MARK: - View
/// NullSign's Signer tab: the library in NullSign's look (overview, signing
/// identity, search and scope, app cards), on NullSign's library behavior
/// (reordering, batch sign/install/delete, update routing, install queue).
struct LibraryView: View {
    @StateObject var downloadManager = DownloadManager.shared
    @ObservedObject private var tabSelection = TabSelectionObserver.shared
    @ObservedObject private var _updateChecker = AppUpdateChecker.shared
    @ObservedObject private var _sourcesViewModel = SourcesViewModel.shared
    @ObservedObject private var _selfUpdate = SelfUpdateManager.shared
    @State private var _selfUpdateNotes: SelfUpdateRelease?
    @AppStorage("RyukSign.libraryShowsUpdates") private var _showsUpdates = true
    @Environment(\.accessibilityReduceMotion) private var _reduceMotion
    @State private var _updateRoute: UpdateRoute?

    @State private var _selectedInfoAppPresenting: AnyApp?
    @State private var _selectedSigningAppPresenting: AnyApp?
    @State private var _isDownloadingPresenting = false
    @State private var _alertDownloadString: String = "" // for _isDownloadingPresenting
    @State private var _isCertificatesPresenting = false
    @State private var _isCheckingForUpdates = false

    // MARK: Selection State
    @State private var _selectedAppUUIDs: Set<String> = []
    @State private var _editMode: EditMode = .inactive
    @State private var _showDeleteConfirmation = false
    @State private var _batchRequest: BatchRequest?

    @State private var _searchText = ""
    @State private var _selectedScope: Scope = .all

    @State private var scrollProxy: ScrollViewProxy?

    @Namespace private var _namespace

    // MARK: Fetch
    @FetchRequest(
        entity: Signed.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Signed.sortIndex, ascending: true)],
        animation: .snappy
    ) private var _signedApps: FetchedResults<Signed>

    @FetchRequest(
        entity: Imported.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Imported.sortIndex, ascending: true)],
        animation: .snappy
    ) private var _importedApps: FetchedResults<Imported>

    @FetchRequest(
        entity: CertificatePair.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
        animation: .snappy
    ) private var _certificates: FetchedResults<CertificatePair>

    // MARK: Computed Properties
    private var filteredSignedApps: [Signed] {
        _signedApps.filter(_matches)
    }

    private var filteredImportedApps: [Imported] {
        _importedApps.filter(_matches)
    }

    private func _matches(_ app: AppInfoPresentable) -> Bool {
        if _selectedScope == .updates, _update(for: app) == nil { return false }
        return _searchText.isEmpty || (app.name?.localizedCaseInsensitiveContains(_searchText) ?? false)
    }

    private func _update(for app: AppInfoPresentable) -> AppUpdate? {
        _updateChecker.update(for: app).flatMap { $0.libraryUUID == app.uuid ? $0 : nil }
    }

    private var shouldShowSignedSection: Bool {
        _selectedScope != .imported
    }

    private var shouldShowImportedSection: Bool {
        _selectedScope != .signed
    }

    private var _hasApps: Bool {
        !_signedApps.isEmpty || !_importedApps.isEmpty
    }

    private var _isEditing: Bool {
        _editMode.isEditing
    }

    private var _updateCount: Int {
        (_signedApps.map { $0 as AppInfoPresentable } + _importedApps.map { $0 as AppInfoPresentable })
            .filter { _update(for: $0) != nil }
            .count
    }

    // MARK: Body
    var body: some View {
        NBNavigationView(.localized("Signer"), displayMode: .inline) {
            mainContent
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if _hasApps {
                            Button {
                                _setEditing(!_isEditing)
                            } label: {
                                Text(_isEditing ? String.localized("Done") : String.localized("Select"))
                                    .font(.roundedUI(size: 15, weight: .bold))
                            }
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        if _hasApps && !_isEditing {
                            _updateCheckButton
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        if !_isEditing {
                            Menu {
                                importMenuActions
                            } label: {
                                Label(.localized("Import"), systemImage: "plus")
                            }
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if _isEditing {
                        selectionActionBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .environment(\.editMode, $_editMode)
                .navigationDestination(isPresented: $_isCertificatesPresenting) {
                    CertificatesView()
                }
                .sheet(item: $_selfUpdateNotes) { release in
                    SelfUpdateSheet(release: release)
                }
                .task {
                    // As in NullSign 1.x, opening the Signer looks for a newer
                    // NullSign (at most every six hours).
                    await _selfUpdate.checkIfNeeded()
                }
                .sheet(item: $_updateRoute) { route in
                    NavigationStack {
                        UpdatePickerView(route: route)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button(.localized("Done")) { _updateRoute = nil }
                                }
                            }
                    }
                    .nullSignPage()
                }
                .sheet(item: $_selectedInfoAppPresenting) { app in
                    LibraryInfoView(app: app.base)
                        .nullSignTypography()
                }
                .fullScreenCover(item: $_batchRequest, onDismiss: InstallCleanup.flush) { request in
                    BatchSignView(apps: request.apps, mode: request.mode)
                        .nullSignTypography()
                }
                .fullScreenCover(item: $_selectedSigningAppPresenting) { app in
                    SigningView(app: app.base)
                        .nullSignTypography()
                        .compatNavigationTransition(id: app.base.uuid ?? "", ns: _namespace)
                }
                .alert(.localized("Import from URL"), isPresented: $_isDownloadingPresenting) {
                    urlImportAlert
                }
                .onChange(of: _editMode) { mode in
                    if mode == .inactive {
                        _selectedAppUUIDs.removeAll()
                    }
                }
                .onChange(of: _hasApps) { hasApps in
                    if !hasApps { _setEditing(false) }
                }
                .onChange(of: _sourcesViewModel.isFinished) { finished in
                    if finished { _isCheckingForUpdates = false }
                }
                .alert(
                    deleteDialogTitle,
                    isPresented: $_showDeleteConfirmation
                ) {
                    Button(.localized("Delete"), role: .destructive) {
                        bulkDeleteSelectedApps()
                    }
                    Button(.localized("Cancel"), role: .cancel) {}
                } message: {
                    Text(.localized("The selected app files will be removed from this device. This cannot be undone."))
                }
        }
        .tint(NullSignStyle.accent)
    }

    private var deleteDialogTitle: String {
        let count = _selectedAppUUIDs.count
        return count == 1 ? "Delete 1 app?" : "Delete \(count) apps?"
    }

    // MARK: Main Content View
    private var mainContent: some View {
        ScrollViewReader { proxy in
            List {
                NullSignOverviewBanner(
                    title: "On this device",
                    value: (_signedApps.count + _importedApps.count).formatted(),
                    detail: "\(_signedApps.count) signed · \(_importedApps.count) imported",
                    systemImage: "checkmark.seal.fill"
                )
                .nullSignListRow(top: 0, bottom: 0, horizontal: 0)

                NullSignIdentityCard(certificate: NullSignIdentity.activeCertificate(in: Array(_certificates))) {
                    _isCertificatesPresenting = true
                }
                .nullSignListRow(top: 4, bottom: 6)

                if let release = _selfUpdate.available {
                    NullSignSelfUpdateBanner(selfUpdate: _selfUpdate, release: release) {
                        _selfUpdateNotes = release
                    }
                    .nullSignListRow(top: 4, bottom: 6)
                }

                if _hasApps {
                    _libraryTools
                        .nullSignListRow(top: 6, bottom: 4)

                    appsListContent

                    if !_showsSigned && !_showsImported {
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
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: tabSelection.highlightedAppUUID) { newUUID in
                if let uuid = newUUID {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(uuid, anchor: .center)
                    }
                }
            }
        }
    }

    private var _showsSigned: Bool {
        !filteredSignedApps.isEmpty && shouldShowSignedSection
    }

    private var _showsImported: Bool {
        !filteredImportedApps.isEmpty && shouldShowImportedSection
    }

    // MARK: Apps List Content
    @ViewBuilder
    private var appsListContent: some View {
        if _showsSigned {
            _sectionLabel(.localized("Signed"), apps: filteredSignedApps.map { $0 as AppInfoPresentable }, systemImage: "checkmark.seal")
            ForEach(filteredSignedApps, id: \.uuid) { app in
                _cell(for: app)
            }
            .onMove(perform: _searchText.isEmpty ? _moveSignedApps : nil)
        }

        if _showsImported {
            _sectionLabel(.localized("Imported"), apps: filteredImportedApps.map { $0 as AppInfoPresentable }, systemImage: "tray.and.arrow.down")
            ForEach(filteredImportedApps, id: \.uuid) { app in
                _cell(for: app)
            }
            .onMove(perform: _searchText.isEmpty ? _moveImportedApps : nil)
        }
    }

    /// While selecting, a section's count shows how many of its apps are selected.
    private func _sectionLabel(_ title: String, apps: [AppInfoPresentable], systemImage: String) -> some View {
        let selected = apps.filter { app in
            guard let uuid = app.uuid else { return false }
            return _selectedAppUUIDs.contains(uuid)
        }.count

        return NullSignSectionLabel(
            title: _isEditing && selected > 0 ? "\(title) · \(selected) selected" : title,
            count: apps.count,
            prominent: true,
            systemImage: systemImage
        )
        .nullSignListRow(top: 20, bottom: 8, horizontal: 24)
        .moveDisabled(true)
    }

    private func _cell(for app: AppInfoPresentable) -> some View {
        LibraryCellView(
            app: app,
            selectedInfoAppPresenting: $_selectedInfoAppPresenting,
            selectedSigningAppPresenting: $_selectedSigningAppPresenting,
            selectedAppUUIDs: $_selectedAppUUIDs,
            isHighlighted: app.uuid == tabSelection.highlightedAppUUID,
            update: _showsUpdates || _selectedScope == .updates ? _update(for: app) : nil,
            onUpdate: _startUpdate,
            onSelectMore: { _beginSelection(with: app) }
        )
        .compatMatchedTransitionSource(id: app.uuid ?? "", ns: _namespace)
        .id(app.uuid)
        .nullSignListRow(top: 5, bottom: 5)
    }

    private func _startUpdate(_ update: AppUpdate) {
        if !_updateChecker.autoUpdate(update) {
            _updateRoute = UpdateRoute(key: update.id, sourceIDs: nil)
        }
    }

    // MARK: Tools
    private var _libraryTools: some View {
        VStack(spacing: 10) {
            NullSignSearchField(prompt: .localized("Search"), text: $_searchText)
            NullSignSegmentedControl(
                options: Scope.allCases,
                selection: $_selectedScope,
                title: \.displayName,
                count: { scope in
                    switch scope {
                    case .all: return nil
                    case .signed: return _signedApps.count
                    case .imported: return _importedApps.count
                    case .updates: return _updateCount
                    }
                }
            )
        }
    }

    /// Refreshes every source; NullSign's update checker recomputes from them.
    private var _updateCheckButton: some View {
        Menu {
            Button(.localized("Check for Updates"), systemImage: "arrow.triangle.2.circlepath") {
                _checkForUpdates()
            }
            .disabled(_isCheckingForUpdates)
            Toggle(isOn: $_showsUpdates) {
                Label(.localized("Show Updates"), systemImage: "arrow.down.circle")
            }
        } label: {
            if _isCheckingForUpdates {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(_updateCheckTitle)
                    .font(.roundedUI(size: 15, weight: .bold))
                    .lineLimit(1)
            }
        } primaryAction: {
            _checkForUpdates()
        }
    }

    private var _updateCheckTitle: String {
        switch _updateCount {
        case 0: return .localized("Check for Updates")
        case 1: return .localized("1 Update")
        case let count: return "\(count) Updates"
        }
    }

    private func _checkForUpdates() {
        guard !_isCheckingForUpdates else { return }
        _isCheckingForUpdates = true
        Task {
            // NullSign's own update is checked alongside the library's.
            async let ownUpdate: Void = _selfUpdate.check()
            await _sourcesViewModel.fetchSources(Storage.shared.getSources(), refresh: true)
            await ownUpdate
            _isCheckingForUpdates = false
        }
    }

    // MARK: Empty States
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
                    _importFromFiles()
                } label: {
                    Text(.localized("Import from Files"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NullSignPrimaryButtonStyle())

                Button {
                    _isDownloadingPresenting = true
                } label: {
                    Text(.localized("Import from URL"))
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

    @ViewBuilder
    private var _noResults: some View {
        if _selectedScope == .updates && _searchText.isEmpty {
            NullSignEmptyState(
                systemImage: "checkmark.circle",
                title: .localized("Up to Date"),
                message: .localized("No newer version in your sources.")
            )
        } else {
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
    }

    // MARK: Selection Action Bar
    private var selectionActionBar: some View {
        let selection = selectedApps()
        let canSign = selection.contains { !$0.isSigned }
        let canInstall = !selection.isEmpty && selection.allSatisfy { $0.isSigned }

        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text(_selectedAppUUIDs.isEmpty ? "Select apps" : "\(_selectedAppUUIDs.count) selected")
                    .font(.roundedUI(.headline))
                    .monospacedDigit()
                Spacer(minLength: 8)
                Button {
                    selectAllApps()
                } label: {
                    Text(areAllAppsSelected ? "Deselect All" : "Select All")
                }
                .buttonStyle(NullSignSecondaryButtonStyle(height: 36))
            }

            HStack(spacing: 8) {
                if canInstall {
                    _actionButton(.localized("Install"), systemImage: "square.and.arrow.down") {
                        _startBatch(.install)
                    }
                } else {
                    _actionButton(.localized("Sign"), systemImage: "signature", isDisabled: !canSign) {
                        _startBatch(.sign)
                    }
                    _actionButton(.localized("Sign & Install"), systemImage: "square.and.arrow.down.on.square", isDisabled: !canSign) {
                        _startBatch(.signAndInstall)
                    }
                }

                Button {
                    _showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .accessibilityLabel(.localized("Delete"))
                }
                .buttonStyle(NullSignPrimaryButtonStyle(height: 36, tint: NullSignStyle.danger))
                .disabled(_selectedAppUUIDs.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NullSignStyle.cardRadius, style: .continuous))
        .background(NullSignStyle.groupedSurface.opacity(0.85), in: RoundedRectangle(cornerRadius: NullSignStyle.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NullSignStyle.cardRadius, style: .continuous).strokeBorder(NullSignStyle.hairline, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .reportsBottomBarHeight()
    }

    private func _actionButton(
        _ title: String,
        systemImage: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(NullSignPrimaryButtonStyle(height: 36))
        .disabled(isDisabled || _selectedAppUUIDs.isEmpty)
    }

    // MARK: Import
    @ViewBuilder
    private var importMenuActions: some View {
        Button(.localized("Import from Files"), systemImage: "folder") {
            _importFromFiles()
        }
        Button(.localized("Import from URL"), systemImage: "link") {
            Presentation.afterDismiss { _isDownloadingPresenting = true }
        }
    }

    private func _importFromFiles() {
        DocumentPicker.open([.ipa, .tipa], multiple: true, folder: .apps) { urls in
            for url in urls {
                downloadManager.startArchive(from: url, id: "FeatherManualDownload_\(UUID().uuidString)")
            }
        }
    }

    // MARK: URL Import Alert
    @ViewBuilder
    private var urlImportAlert: some View {
        TextField(.localized("URL"), text: $_alertDownloadString)
            .textInputAutocapitalization(.never)
        Button(.localized("Cancel"), role: .cancel) {
            _alertDownloadString = ""
        }
        Button(.localized("OK")) {
            if let url = URL(string: _alertDownloadString) {
                _ = downloadManager.startDownload(
                    from: url,
                    id: "FeatherManualDownload_\(UUID().uuidString)"
                )
            }
        }
    }
}

// MARK: - Extension: Batch
extension LibraryView {
    struct BatchRequest: Identifiable {
        let id = UUID()
        let apps: [AppInfoPresentable]
        let mode: BatchJobRunner.Mode
    }

    private func selectedApps() -> [AppInfoPresentable] {
        getAllApps().filter { app in
            guard let uuid = app.uuid else { return false }
            return _selectedAppUUIDs.contains(uuid)
        }
    }

    private func _setEditing(_ editing: Bool) {
        withAnimation(_reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.85)) {
            _editMode = editing ? .active : .inactive
            if !editing {
                _selectedAppUUIDs.removeAll()
            }
        }
    }

    private func _beginSelection(with app: AppInfoPresentable) {
        guard let uuid = app.uuid else { return }

        withAnimation {
            _editMode = .active
            _selectedAppUUIDs = [uuid]
        }
    }

    private func _startBatch(_ mode: BatchJobRunner.Mode) {
        let apps = selectedApps()
        guard !apps.isEmpty else { return }

        _batchRequest = BatchRequest(apps: apps, mode: mode)
        _selectedAppUUIDs.removeAll()
        _editMode = .inactive
    }
}

// MARK: - Extension: Reorder
extension LibraryView {
    private func _moveSignedApps(from source: IndexSet, to destination: Int) {
        var apps = filteredSignedApps
        apps.move(fromOffsets: source, toOffset: destination)

        for (index, app) in apps.enumerated() {
            app.sortIndex = Int32(index)
        }
        Storage.shared.saveContext()
    }

    private func _moveImportedApps(from source: IndexSet, to destination: Int) {
        var apps = filteredImportedApps
        apps.move(fromOffsets: source, toOffset: destination)

        for (index, app) in apps.enumerated() {
            app.sortIndex = Int32(index)
        }
        Storage.shared.saveContext()
    }
}

// MARK: - Extension: Bulk Delete
extension LibraryView {
    private func bulkDeleteSelectedApps() {
        for app in selectedApps() {
            Storage.shared.deleteApp(for: app)
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        _selectedAppUUIDs.removeAll()
        _editMode = .inactive
    }

    private func getAllApps() -> [AppInfoPresentable] {
        var allApps: [AppInfoPresentable] = []

        if shouldShowSignedSection {
            allApps.append(contentsOf: filteredSignedApps)
        }

        if shouldShowImportedSection {
            allApps.append(contentsOf: filteredImportedApps)
        }

        return allApps
    }

    private var areAllAppsSelected: Bool {
        let allApps = getAllApps()
        let allUUIDs = Set(allApps.compactMap { $0.uuid })
        return !allUUIDs.isEmpty && _selectedAppUUIDs == allUUIDs
    }

    private func selectAllApps() {
        if areAllAppsSelected {
            _selectedAppUUIDs.removeAll()
        } else {
            let allApps = getAllApps()
            _selectedAppUUIDs = Set(allApps.compactMap { $0.uuid })
        }
    }
}

// MARK: - Extension: View (Sort)
extension LibraryView {
    enum Scope: CaseIterable {
        case all
        case signed
        case imported
        case updates

        var displayName: String {
            switch self {
            case .all: return .localized("All")
            case .signed: return .localized("Signed")
            case .imported: return .localized("Imported")
            case .updates: return .localized("Updates")
            }
        }

        var systemImage: String {
            switch self {
            case .all: "square.grid.2x2"
            case .signed: "signature"
            case .imported: "square.and.arrow.down"
            case .updates: "arrow.down.circle"
            }
        }
    }
}
