//
//  SettingsView.swift
//  RyukSign
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews
import UIKit
import Darwin
import IDeviceSwift

// MARK: - View
/// NullSign's Settings: the signing identity, then RyukSign's settings in
/// NullSign's card sections. RyukSign's donation card and its alternate app
/// icons (Feather and RyukSign artwork) aren't part of NullSign.
struct SettingsView: View {
    @ObservedObject private var _selfUpdate = SelfUpdateManager.shared
    @AppStorage("Feather.installationMethod") private var _installationMethod = 0
    @State private var _isCertificatesPresenting = false

    // MARK: Fetch
    @FetchRequest(
        entity: CertificatePair.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
        animation: .snappy
    ) private var _certificates: FetchedResults<CertificatePair>

    private let _githubUrl = "https://github.com/nulldev85/NullSign"

    private var _build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    // MARK: Body
    var body: some View {
        NBNavigationView(.localized("Settings"), displayMode: .inline) {
            ScrollView {
                VStack(spacing: 28) {
                    NullSignIdentityCard(certificate: NullSignIdentity.activeCertificate(in: Array(_certificates))) {
                        _isCertificatesPresenting = true
                    }

                    _signingSection
                    _appSection
                    _filesSection
                    _maintenanceSection
                    _aboutSection

                    Text("Apps are signed on this device. Certificates and passwords never leave it.")
                        .font(.roundedUI(.footnote))
                        .foregroundStyle(NullSignStyle.faint)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .nullSignPage()
            .navigationDestination(isPresented: $_isCertificatesPresenting) {
                CertificatesView()
            }
        }
        .tint(NullSignStyle.accent)
        .nullSignTypography()
    }
}

// MARK: - Sections
extension SettingsView {
    private var _signingSection: some View {
        NullSignSettingsSection(.localized("Signing")) {
            _link(.localized("Certificates"), systemImage: "checkmark.seal", value: _certificates.count.description) {
                CertificatesView()
            }
            NullSignSettingsDivider()
            _link(.localized("Signing Defaults"), systemImage: "signature") {
                ConfigurationView()
            }
            NullSignSettingsDivider()
            _link(.localized("Tweaks"), systemImage: "puzzlepiece.extension") {
                TweakLibraryList().navigationTitle(.localized("Tweaks"))
            }
            NullSignSettingsDivider()
            _link(
                .localized("Installation Method"),
                systemImage: "arrow.down.app",
                value: _installationMethod == 0 ? String.localized("Server") : String.localized("Pairing")
            ) {
                InstallationView()
            }
        }
    }

    private var _appSection: some View {
        NullSignSettingsSection(.localized("App")) {
            _link(.localized("Appearance"), systemImage: "circle.lefthalf.filled") {
                AppearanceView()
            }
            NullSignSettingsDivider()
            _link(.localized("Tab Bar"), systemImage: "square.stack.3d.up") {
                TabBarSettingsView()
            }
            NullSignSettingsDivider()
            _link(.localized("Sources"), systemImage: "externaldrive.connected.to.line.below") {
                SourcesSettingsView()
            }
            NullSignSettingsDivider()
            _link(.localized("Downloads"), systemImage: "arrow.down.circle") {
                DownloadsSettingsView()
            }
            NullSignSettingsDivider()
            _link(
                .localized("Updates"),
                systemImage: "arrow.triangle.2.circlepath",
                value: _selfUpdate.available != nil ? String.localized("Available") : nil
            ) {
                UpdatesSettingsView()
            }
        }
    }

    private var _filesSection: some View {
        NullSignSettingsSection(.localized("Files")) {
            _link(.localized("Files & Compression"), systemImage: "shippingbox") {
                FilesCompressionView()
            }
            NullSignSettingsDivider()
            _link(.localized("Web Manager"), systemImage: "externaldrive.badge.wifi") {
                WebManagerView()
            }
            NullSignSettingsDivider()
            Menu {
                Button(.localized("Open Documents"), systemImage: "folder") {
                    UIApplication.open(URL.documentsDirectory.toSharedDocumentsURL()!)
                }
                Button(.localized("Open Archives"), systemImage: "archivebox") {
                    UIApplication.open(FileManager.default.archives.toSharedDocumentsURL()!)
                }
                Button(.localized("Open Certificates"), systemImage: "checkmark.seal") {
                    UIApplication.open(FileManager.default.certificates.toSharedDocumentsURL()!)
                }
            } label: {
                NullSignSettingsRow(title: .localized("Open in Files"), detail: nil, systemImage: "folder")
            }
            .buttonStyle(.plain)
        }
    }

    private var _maintenanceSection: some View {
        NullSignSettingsSection(
            .localized("Maintenance"),
            detail: .localized("Check what is using space, back up your setup, or reset the app.")
        ) {
            _link(.localized("Storage"), systemImage: "internaldrive") {
                StorageView()
            }
            NullSignSettingsDivider()
            _link(.localized("Activity Logs"), systemImage: "list.bullet") {
                LogsHistoryView()
            }
            NullSignSettingsDivider()
            _link(.localized("Backup & Restore"), systemImage: "clock.arrow.circlepath") {
                BackupView()
            }
            NullSignSettingsDivider()
            _link(.localized("Reset"), systemImage: "trash") {
                ResetView()
            }
        }
    }

    private var _aboutSection: some View {
        NullSignSettingsSection(.localized("About")) {
            _link(
                .localized("About NullSign"),
                systemImage: "info.circle",
                value: "\(Bundle.main.version) (\(_build))"
            ) {
                AboutView()
            }
            NullSignSettingsDivider()
            Button {
                _submitFeedback()
            } label: {
                NullSignSettingsRow(title: .localized("Submit Feedback"), detail: nil, systemImage: "exclamationmark.bubble", showsChevron: false)
            }
            .buttonStyle(.plain)
            NullSignSettingsDivider()
            Button {
                UIApplication.open(_githubUrl)
            } label: {
                NullSignSettingsRow(title: .localized("GitHub Repository"), detail: nil, systemImage: "safari", showsChevron: false)
            }
            .buttonStyle(.plain)
        }
    }

    /// A settings row that opens a screen.
    private func _link<Destination: View>(
        _ title: String,
        systemImage: String,
        value: String? = nil,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
                .nullSignPage()
        } label: {
            NullSignSettingsRow(title: title, detail: nil, systemImage: systemImage, value: value)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feedback
extension SettingsView {
    private func _submitFeedback() {
        let bugAction: UIAlertAction = .init(title: .localized("Bug Report"), style: .default) { _ in
            UIApplication.open(_makeGitHubIssueURL(url: _githubUrl))
        }

        let chooseAction: UIAlertAction = .init(title: .localized("Other"), style: .default) { _ in
            UIApplication.open(URL(string: "\(_githubUrl)/issues/new/choose")!)
        }

        UIAlertController.showAlertWithCancel(
            title: .localized("Submit Feedback"),
            message: nil,
            actions: [bugAction, chooseAction]
        )
    }

    private func _makeGitHubIssueURL(url: String) -> String {
        var configurationSection = "### App Configuration:\n"

        switch UserDefaults.standard.integer(forKey: "Feather.installationMethod") {
        case 0: // Server
            let serverMethod = UserDefaults.standard.integer(forKey: "Feather.serverMethod")
            let ipFix = UserDefaults.standard.bool(forKey: "Feather.ipFix")
            let serverType = (serverMethod == 0) ? "Fully Local" : "Semi Local"
            configurationSection += "- Install method: `Server`\n"
            configurationSection += "  - Server type: `\(serverType)`\n"
            configurationSection += "  - IP Fix: `\(ipFix)`\n"
        case 1: // idevice
            let pairingPath = HeartbeatManager.pairingFile()
            let pairingExists = FileManager.default.fileExists(atPath: pairingPath)
            let pairingStatus = pairingExists ? "`Present`" : "`Not Present`"
            configurationSection += "- Install method: `idevice`\n"
            configurationSection += "  - Pairing file: \(pairingStatus)\n"
        default:
            configurationSection += "- Install method: `Unknown`\n"
        }

        let body = """
		### Device Information
		- Device: `\(MobileGestalt().getStringForName("PhysicalHardwareNameString") ?? "Unknown")`
		- iOS Version: `\(UIDevice.current.systemVersion)`
		- App Version: `\(Bundle.main.version)`

		\(configurationSection)

		### Issue Description
		<!-- Describe your issue here -->

		### Steps to Reproduce
		1.
		2.
		3.

		### Expected Behavior

		### Actual Behavior
		"""
        let encodedTitle = "[Bug] replace this with a descriptive title "
			.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body
			.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "\(url)/issues/new?template=bug.yml&title=\(encodedTitle)&text=\(encodedBody)"
    }
}
