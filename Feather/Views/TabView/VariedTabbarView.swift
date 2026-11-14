//
//  VariedTabbarView.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI
import UIKit
import NimbleViews

/// The app's tabs, in the system tab bar. On iPhone Duo the system places it
/// with each screen's toolbar in one column on the side (the right, beside the
/// camera, when closed; along the app's outer edge in Split View) and keeps it
/// at the bottom where that pose has room. A custom bar can't join that
/// column, so NullSign uses the system one everywhere.
struct VariedTabbarView: View {
	@State private var selectedTab: TabEnum = .signer
	/// Bumped to rebuild a tab at its root when its item is tapped again.
	@State private var rootGeneration: [TabEnum: Int] = [:]
	@StateObject private var selfUpdate = SelfUpdateManager.shared
	@ObservedObject private var _updateManager = UpdateManager.shared

	init() {}

	var body: some View {
		TabView(selection: _selection) {
			ForEach(TabEnum.defaultTabs, id: \.self) { tab in
				TabEnum.view(for: tab)
					.readsVerticalBarLayout()
					.id("\(tab.rawValue)-\(rootGeneration[tab, default: 0])")
					// A title and a symbol, so the system can show either one
					// wherever it places the bar.
					.tabItem { Label(tab.title, systemImage: tab.icon) }
					.tag(tab)
					// Apps with updates, found when NullSign opens or by Check for
					// Updates, so they show from any tab. Zero shows no badge.
					.badge(tab == .signer ? _pendingUpdates : 0)
			}
		}
		.tint(NullSignStyle.accent)
		.background(NullSignStyle.canvas)
		// NullSign's own update installs from here, so it can be started from
		// About or the Library and still show whichever tab is open.
		.sheet(item: $selfUpdate.installingApp, onDismiss: { selfUpdate.installerDismissed() }) { app in
			InstallPreviewView(app: app.base)
				.presentationDetents([.height(300)])
		}
	}

	/// Selecting the open tab again returns it to its first screen, as the
	/// custom dock did.
	private var _selection: Binding<TabEnum> {
		Binding(
			get: { selectedTab },
			set: { tab in
				UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
				if tab == selectedTab {
					UIImpactFeedbackGenerator(style: .light).impactOccurred()
					var transaction = Transaction()
					transaction.disablesAnimations = true
					withTransaction(transaction) {
						rootGeneration[tab, default: 0] += 1
					}
				} else {
					selectedTab = tab
				}
			}
		)
	}

	/// Apps with an update, NullSign's own among them, each counted once.
	private var _pendingUpdates: Int {
		var identifiers = _updateManager.updatedBundleIdentifiers
		if selfUpdate.availableVersion != nil {
			identifiers.insert(SelfUpdateManager.sourceBundleIdentifier)
		}
		return identifiers.count
	}
}
