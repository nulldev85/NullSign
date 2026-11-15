//
//  InstallationView.swift
//  RyukSign
//
//  Created by samara on 3.06.2025.
//

import SwiftUI
import NimbleViews
import IDeviceSwift

// MARK: - View
struct InstallationView: View {
	@AppStorage("Feather.installationMethod") private var _installationMethod: Int = 0
	@ObservedObject private var _appleTV = AppleTVManager.shared
	@State private var _showMethodChangedAlert = false

	private let _installationMethods: [String] = [
		.localized("Server"),
		.localized("idevice")
	]
	
	// MARK: Body
    var body: some View {
		NBList(.localized("Installation")) {
			Section {
				Picker(.localized("Installation Type"), systemImage: "arrow.down.app", selection: $_installationMethod) {
					ForEach(_installationMethods.indices, id: \.description) { index in
						Text(_installationMethods[index]).tag(index)
					}
				}
			} footer: {
				Text(.localized("Server (Recommended):\nUses a locally hosted server and itms-services:// to install applications.\n\nIDevice (advanced):\nUses a VPN and a pairing file. Writes to AFC and manually calls installd, while monitoring install progress by using a callback\nAdvantage: It is very reliable, does not need SSL certificates or a externally hosted server. Rather, works similarly to a computer."))
			}
			.listRowBackground(NullSignStyle.groupedSurface)

			Section {
				NavigationLink {
					AppleTVPairingView()
				} label: {
					HStack {
						Label(.localized("Apple TV"), systemImage: "appletv.fill")
						Spacer()
						Text(_appleTV.pairedDevice?.name ?? String.localized("Not Paired"))
							.foregroundStyle(.secondary)
					}
				}
			} footer: {
				Text(.localized("tvOS apps always install on your paired Apple TV over Wi-Fi, whichever installation type iPhone apps use."))
			}
			.listRowBackground(NullSignStyle.groupedSurface)
			
			if _installationMethod == 0 {
				ServerView()
			} else if _installationMethod == 1 {
				TunnelView()
			}
		}
		.onChange(of: _installationMethod) { newValue in
			guard newValue == 1 else { return }
			_showMethodChangedAlert = true
		}
		.alert(.localized("Advanced Installation Method"), isPresented: $_showMethodChangedAlert) {
			Button(.localized("Switch Back"), role: .destructive) {
				_installationMethod = 0
			}
			Button(.localized("OK"), role: .cancel) {}
		} message: {
			Text(.localized(
				"This installation method is intended for advanced users only!\n\nIt requires a VPN and a pairing file from a PC.\n\nIts recommended you go back to the server installation method."
			))
		}
		.animation(.default, value: _installationMethod)
    }
}
