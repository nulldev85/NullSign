//
//  AppearanceView.swift
//  NullSign
//
//  Created by samara on 7.05.2025.
//
import SwiftUI
import NimbleViews
import UIKit
// MARK: - View
struct AppearanceView: View {
	@AppStorage("Feather.storeCellAppearance")
	private var _storeCellAppearance: Int = 0
	private let _storeCellAppearanceMethods: [(name: String, desc: String)] = [
		(.localized("Standard"), .localized("Default style for the app, only includes subtitle.")),
		(.localized("Big Description"), .localized("Adds the localized description of the app."))
	]
	
	@AppStorage("com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck")
	private var _ignoreSolariumLinkedOnCheck: Bool = false

	@AppStorage("Feather.sourcesTabShowAllReposDirectly")
	private var _sourcesTabShowAllReposDirectly: Bool = false

	@AppStorage("Feather.sourcesShowUpdatesAsTab")
	private var _sourcesShowUpdatesAsTab: Bool = false

	@AppStorage("Feather.showSourcesUpdateBadge")
	private var _showSourcesUpdateBadge: Bool = true

	@AppStorage("Feather.shouldTintIcons")
	private var _shouldTintIcons: Bool = false

	@AppStorage("Feather.shouldChangeIconsBasedOffStyle")
	private var _shouldChangeIconsBasedOffStyle: Bool = false

	// MARK: Body
	var body: some View {
		NBList(.localized("Appearance")) {
			// NullSign is always dark and always NullSign blue, so there's no
			// light/dark or accent color choice here.
			if #available(iOS 18.0, *) {
				NBSection(.localized("Library")) {
					Toggle(.localized("Dynamic Icons"), isOn: $_shouldChangeIconsBasedOffStyle)
					if #available(iOS 18.2, *) {
						Toggle(.localized("Tinted Icons"), isOn: $_shouldTintIcons)
					}
				}
			}

			NBSection(.localized("Sources")) {

				Picker(.localized("Store Cell Appearance"), selection: $_storeCellAppearance) {
					ForEach(0..<_storeCellAppearanceMethods.count, id: \.self) { index in
						let method = _storeCellAppearanceMethods[index]
						NBTitleWithSubtitleView(
							title: method.name,
							subtitle: method.desc
						)
						.tag(index)
					}
				}
				.labelsHidden()
				.pickerStyle(.inline)
				Toggle(.localized("Show All Repos by Default"), isOn: $_sourcesTabShowAllReposDirectly)
				Toggle(.localized("Show Updates as Tab"), isOn: $_sourcesShowUpdatesAsTab)
				Toggle(.localized("Update Count Badge"), isOn: $_showSourcesUpdateBadge)
			} footer: {
				Text(.localized("When enabled, the Apps tab shows all apps directly. Toggle off to manage repositories. The update count badge shows the number of available app updates on the Signer tab."))
			}
			
			if #available(iOS 19.0, *) {
				NBSection(.localized("Experiments")) {
					Toggle(.localized("Enable Liquid Glass"), isOn: $_ignoreSolariumLinkedOnCheck)
				} footer: {
					Text(.localized("This enables liquid glass for this app, this requires a restart of the app to take effect."))
				}
			}
		}
		.onChange(of: _ignoreSolariumLinkedOnCheck) { _ in
			UIApplication.shared.suspendAndReopen()
		}
	}
}
