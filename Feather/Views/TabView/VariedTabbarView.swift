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
				.transition(.opacity)
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

/// A floating dock. The active tab becomes a red pill carrying its label;
/// the others stay as glyphs.
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
		.padding(5)
		.modifier(NullSignDockChrome())
		.frame(maxWidth: 360)
		.padding(.horizontal, 24)
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
			HStack(spacing: 6) {
				Image(systemName: tab.icon)
					.font(.system(size: 17, weight: .semibold))
					.symbolVariant(isSelected ? .fill : .none)
				if isSelected {
					Text(tab.title)
						.font(.system(size: 15, weight: .semibold))
						.lineLimit(1)
						.fixedSize()
						.transition(.opacity)
				}
			}
			.foregroundStyle(isSelected ? Color.white : NullSignStyle.muted)
			.frame(maxWidth: isSelected ? .infinity : 56)
			.frame(height: 44)
			.background {
				if isSelected {
					Capsule()
						.fill(NullSignStyle.accent)
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

/// Liquid Glass where the system has it; dark frosted glass before that.
private struct NullSignDockChrome: ViewModifier {
	@ViewBuilder
	func body(content: Content) -> some View {
		if #available(iOS 26.0, *) {
			content
				.glassEffect(in: Capsule())
		} else {
			content
				.background(.ultraThinMaterial, in: Capsule())
				.background(Color.black.opacity(0.5), in: Capsule())
				.overlay(Capsule().strokeBorder(NullSignStyle.hairline, lineWidth: 1))
		}
	}
}
