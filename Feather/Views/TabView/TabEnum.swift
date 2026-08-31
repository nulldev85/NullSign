//
//  TabEnum.swift
//  feather
//
//  Created by samara on 22.03.2025.
//

import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
	case signer
	case apps
	case settings
	
	var title: String {
		switch self {
		case .signer:     	return "Signer"
		case .apps: 		return "Apps"
		case .settings: 	return .localized("Settings")
		}
	}
	
	var icon: String {
		switch self {
		case .signer: 		return "signature"
		case .apps: 		return "square.grid.2x2"
		case .settings: 	return "gearshape.2"
		}
	}
	
	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
		case .signer: LibraryView()
		case .apps: SourcesView()
		case .settings: SettingsView()
		}
	}
	
	static var defaultTabs: [TabEnum] {
		return [
			.signer,
			.apps,
			.settings
		]
	}
	
	static var customizableTabs: [TabEnum] {
		return []
	}
}
