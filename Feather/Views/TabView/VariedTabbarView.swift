//
//  VariedTabbarView.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI
import UIKit
import NimbleViews

struct VariedTabbarView: View {
	@State private var selectedTab: TabEnum = .signer
	@State private var visitedTabs: Set<TabEnum> = [.signer]
	@State private var rootGeneration: [TabEnum: Int] = [:]
	@State private var isKeyboardVisible = false
	// The first pass uses the dock's current compact height; its measured height
	// replaces this value so larger accessibility text also gets a matching viewport.
	@State private var dockHeight: CGFloat = 72
	@StateObject private var selfUpdate = SelfUpdateManager.shared
	@Environment(\.horizontalSizeClass) private var _horizontalSizeClass
	@Environment(\.verticalSizeClass) private var _verticalSizeClass

	init() {}

	/// Regular in both directions, as on iPhone Duo's inner display or a
	/// full-screen iPad: the dock becomes a rail down the right edge, beside
	/// the content instead of under it. Folding iPhone Duo shut (compact
	/// width) brings the bottom dock back.
	private var _usesSideRail: Bool {
		_horizontalSizeClass == .regular && _verticalSizeClass == .regular
	}

	var body: some View {
		GeometryReader { geometry in
			let rail = _usesSideRail
			// One layout that switches axis, so folding or unfolding keeps every
			// tab's content (and its navigation) instead of rebuilding it.
			let layout = rail ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))

			layout {
				_tabContent
					// Bound NavigationStack/List to the measured space beside or above
					// the dock. A flexible sibling alone lets UIKit-backed List content
					// draw under it.
					.frame(
						width: rail ? nil : geometry.size.width,
						height: rail ? geometry.size.height : max(0, geometry.size.height - (isKeyboardVisible ? 0 : dockHeight)),
						alignment: .top
					)
					.frame(maxWidth: rail ? .infinity : nil)
					.clipped()

				// The rail sits beside the content, clear of the keyboard, so it
				// stays while typing; the bottom dock steps aside for it.
				if rail || !isKeyboardVisible {
					_dock(vertical: rail)
						.background {
							GeometryReader { dockGeometry in
								Color.clear.preference(key: NullSignDockHeightPreferenceKey.self, value: rail ? 0 : dockGeometry.size.height)
							}
						}
						.transition(.opacity)
				}
			}
			.frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(NullSignStyle.canvas)
		.onPreferenceChange(NullSignDockHeightPreferenceKey.self) { height in
			guard height > 0, abs(height - dockHeight) > 0.5 else { return }
			dockHeight = height
		}
		// The dock steps aside for the keyboard instead of riding on top of it.
		.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
			withAnimation(.easeOut(duration: 0.2)) { isKeyboardVisible = true }
		}
		.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
			withAnimation(.easeOut(duration: 0.2)) { isKeyboardVisible = false }
		}
		// NullSign's own update installs from here, so it can be started from
		// About or the Library and still show whichever tab is open.
		.sheet(item: $selfUpdate.installingApp, onDismiss: { selfUpdate.installerDismissed() }) { app in
			InstallPreviewView(app: app.base)
				.presentationDetents([.height(300)])
		}
	}
}

extension VariedTabbarView {
	private var _tabContent: some View {
		ZStack {
			ForEach(TabEnum.defaultTabs.filter { visitedTabs.contains($0) }, id: \.self) { tab in
				TabEnum.view(for: tab)
					.id("\(tab.rawValue)-\(rootGeneration[tab, default: 0])")
					.opacity(selectedTab == tab ? 1 : 0)
					.allowsHitTesting(selectedTab == tab)
					.accessibilityHidden(selectedTab != tab)
			}
		}
	}

	private func _dock(vertical: Bool) -> some View {
		NullSignDock(
			selection: Binding(
				get: { selectedTab },
				set: { tab in
					visitedTabs.insert(tab)
					selectedTab = tab
					UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
				}
			),
			vertical: vertical,
			onReselect: { tab in
				UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
				var transaction = Transaction()
				transaction.disablesAnimations = true
				withTransaction(transaction) {
					rootGeneration[tab, default: 0] += 1
				}
			}
		)
	}
}

private struct NullSignDockHeightPreferenceKey: PreferenceKey {
	static let defaultValue: CGFloat = 0

	static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
		let height = nextValue()
		if height > 0 { value = height }
	}
}

/// A labeled floating dock with a dark selected capsule and electric-blue emphasis.
private struct NullSignDock: View {
	@Binding var selection: TabEnum
	/// A rail down the right edge instead of a bar along the bottom.
	var vertical = false
	let onReselect: (TabEnum) -> Void
	@Environment(\.accessibilityReduceMotion) private var _reduceMotion
	@ObservedObject private var _updateManager = UpdateManager.shared
	@ObservedObject private var _selfUpdate = SelfUpdateManager.shared

	var body: some View {
		let layout = vertical ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 2))

		if vertical {
			layout {
				ForEach(TabEnum.defaultTabs, id: \.self) { tab in
					_item(for: tab)
				}
			}
			.padding(5)
			.modifier(NullSignDockChrome())
			.padding(.leading, 8)
			.padding(.trailing, 12)
			.padding(.vertical, 16)
			.frame(maxHeight: .infinity)
		} else {
			layout {
				ForEach(TabEnum.defaultTabs, id: \.self) { tab in
					_item(for: tab)
				}
			}
			.padding(5)
			.modifier(NullSignDockChrome())
			.frame(maxWidth: 420)
			.padding(.horizontal, 20)
			.padding(.top, 6)
			.padding(.bottom, 4)
		}
	}

	private func _item(for tab: TabEnum) -> some View {
		let isSelected = selection == tab

		return Button {
			if isSelected {
				UIImpactFeedbackGenerator(style: .light).impactOccurred()
				onReselect(tab)
				return
			}
			UISelectionFeedbackGenerator().selectionChanged()
			withAnimation(_reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
				selection = tab
			}
		} label: {
			VStack(spacing: 3) {
				Image(systemName: tab.icon)
					.font(.roundedUI(size: 22, weight: .semibold))
					.accessibilityHidden(true)
					.overlay(alignment: .topTrailing) {
						if tab == .signer, _pendingUpdates > 0 {
							_updateBadge(_pendingUpdates)
						}
					}
				Text(tab.title)
					.font(.roundedUI(.caption2, weight: .heavy))
					.lineLimit(1)
					.minimumScaleFactor(0.8)
			}
			.foregroundStyle(isSelected ? NullSignStyle.accent : Color.white)
			.frame(maxWidth: vertical ? nil : .infinity)
			.frame(width: vertical ? 76 : nil)
			.frame(minHeight: vertical ? 64 : 52)
			.background {
				if isSelected {
					Capsule().fill(Color.black.opacity(0.6))
				}
			}
			.contentShape(Capsule())
		}
		.buttonStyle(.plain)
		.accessibilityLabel(tab.title)
		.accessibilityValue(_updatesValue(for: tab))
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}

	/// The Library's tab carries a count of apps with updates, found when the
	/// app opens or by Check for Updates, so they show from any tab.
	private func _updateBadge(_ count: Int) -> some View {
		Text(count > 99 ? "99+" : "\(count)")
			.font(.roundedUI(size: 11, weight: .heavy))
			.foregroundStyle(.white)
			.padding(.horizontal, 5)
			.frame(minWidth: 18, minHeight: 18)
			.background(NullSignStyle.danger, in: Capsule())
			.overlay(Capsule().strokeBorder(Color.black.opacity(0.55), lineWidth: 1.5))
			.offset(x: 11, y: -7)
			.accessibilityHidden(true)
	}

	/// Apps with an update, NullSign's own among them, each counted once.
	private var _pendingUpdates: Int {
		var identifiers = _updateManager.updatedBundleIdentifiers
		if _selfUpdate.availableVersion != nil {
			identifiers.insert(SelfUpdateManager.sourceBundleIdentifier)
		}
		return identifiers.count
	}

	private func _updatesValue(for tab: TabEnum) -> String {
		let count = _pendingUpdates
		guard tab == .signer, count > 0 else { return "" }
		return count == 1 ? .localized("1 update available") : .localized("%lld updates available", arguments: count)
	}
}

/// Liquid Glass where the system has it; dark frosted glass before that.
private struct NullSignDockChrome: ViewModifier {
	@ViewBuilder
	func body(content: Content) -> some View {
		if #available(iOS 26.0, *) {
			content
				.glassEffect(in: Capsule())
				.overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
		} else {
			content
				.background(.ultraThinMaterial, in: Capsule())
				.background(NullSignStyle.groupedSurface.opacity(0.85), in: Capsule())
				.overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
		}
	}
}
