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

	init() {}

	var body: some View {
		GeometryReader { geometry in
			VStack(spacing: 0) {
				ZStack {
					ForEach(TabEnum.defaultTabs.filter { visitedTabs.contains($0) }, id: \.self) { tab in
						TabEnum.view(for: tab)
							.id("\(tab.rawValue)-\(rootGeneration[tab, default: 0])")
							.opacity(selectedTab == tab ? 1 : 0)
							.allowsHitTesting(selectedTab == tab)
							.accessibilityHidden(selectedTab != tab)
					}
				}
				// Bound NavigationStack/List to the measured space above the dock.
				// A flexible sibling alone lets UIKit-backed List content draw below it.
				.frame(width: geometry.size.width, height: max(0, geometry.size.height - (isKeyboardVisible ? 0 : dockHeight)), alignment: .top)
				.clipped()

				if !isKeyboardVisible {
					NullSignDock(
						selection: Binding(
							get: { selectedTab },
							set: { tab in
								visitedTabs.insert(tab)
								selectedTab = tab
								UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
							}
						),
						onReselect: { tab in
							UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
							var transaction = Transaction()
							transaction.disablesAnimations = true
							withTransaction(transaction) {
								rootGeneration[tab, default: 0] += 1
							}
						}
					)
					.background {
						GeometryReader { dockGeometry in
							Color.clear.preference(key: NullSignDockHeightPreferenceKey.self, value: dockGeometry.size.height)
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
	let onReselect: (TabEnum) -> Void
	@Environment(\.accessibilityReduceMotion) private var _reduceMotion
	@ObservedObject private var _updateManager = UpdateManager.shared

	var body: some View {
		HStack(spacing: 2) {
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
						if tab == .signer, _updateManager.availableUpdateCount > 0 {
							_updateBadge(_updateManager.availableUpdateCount)
						}
					}
				Text(tab.title)
					.font(.roundedUI(.caption2, weight: .heavy))
					.lineLimit(1)
					.minimumScaleFactor(0.8)
			}
			.foregroundStyle(isSelected ? NullSignStyle.accent : Color.white)
			.frame(maxWidth: .infinity)
			.frame(minHeight: 52)
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

	private func _updatesValue(for tab: TabEnum) -> String {
		let count = _updateManager.availableUpdateCount
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
