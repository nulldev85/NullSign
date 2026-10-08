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

	init() {}

	var body: some View {
		ZStack {
			ForEach(TabEnum.defaultTabs.filter { visitedTabs.contains($0) }, id: \.self) { tab in
				TabEnum.view(for: tab)
					.id("\(tab.rawValue)-\(rootGeneration[tab, default: 0])")
					.opacity(selectedTab == tab ? 1 : 0)
					.allowsHitTesting(selectedTab == tab)
					.accessibilityHidden(selectedTab != tab)
			}
		}
		.background(Color.black)
		.safeAreaInset(edge: .bottom, spacing: 0) {
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
				.transition(.move(edge: .bottom).combined(with: .opacity))
			}
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

/// A floating glass dock. The active tab expands into a crimson pill that
/// carries its label; the others stay as quiet glyphs.
private struct NullSignDock: View {
	@Binding var selection: TabEnum
	let onReselect: (TabEnum) -> Void
	@Namespace private var _pill
	@Environment(\.accessibilityReduceMotion) private var _reduceMotion

	var body: some View {
		HStack(spacing: 4) {
			ForEach(TabEnum.defaultTabs, id: \.self) { tab in
				_item(for: tab)
			}
		}
		.padding(6)
		.modifier(NullSignDockChrome())
		.frame(maxWidth: 400)
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
			withAnimation(_reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.78)) {
				selection = tab
			}
		} label: {
			HStack(spacing: 7) {
				Image(systemName: tab.icon)
					.font(.system(size: 17, weight: .semibold))
					.symbolVariant(isSelected ? .fill : .none)
				if isSelected {
					Text(tab.title)
						.font(.system(size: 14, weight: .bold).width(.expanded))
						.lineLimit(1)
						.fixedSize()
						.transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .leading)))
				}
			}
			.foregroundStyle(isSelected ? Color.white : NullSignStyle.muted)
			.frame(maxWidth: isSelected ? .infinity : 62)
			.frame(height: 48)
			.background {
				if isSelected {
					Capsule()
						.fill(NullSignStyle.signal)
						.overlay(
							Capsule().fill(
								LinearGradient(
									colors: [Color.white.opacity(0.22), Color.clear],
									startPoint: .top,
									endPoint: .center
								)
							)
						)
						.shadow(color: NullSignStyle.accent.opacity(0.55), radius: 12, y: 3)
						.matchedGeometryEffect(id: "pill", in: _pill)
				}
			}
			.contentShape(Capsule())
		}
		.buttonStyle(.plain)
		.accessibilityLabel(tab.title)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}
}

/// Liquid Glass where the system has it; frosted dark glass before that.
private struct NullSignDockChrome: ViewModifier {
	@ViewBuilder
	func body(content: Content) -> some View {
		if #available(iOS 26.0, *) {
			content
				.glassEffect(in: Capsule())
				.shadow(color: .black.opacity(0.45), radius: 18, y: 8)
		} else {
			content
				.background(Capsule().fill(.ultraThinMaterial))
				.background(Capsule().fill(Color.black.opacity(0.45)))
				.overlay(Capsule().strokeBorder(NullSignStyle.edge, lineWidth: 1))
				.shadow(color: .black.opacity(0.6), radius: 18, y: 8)
		}
	}
}
