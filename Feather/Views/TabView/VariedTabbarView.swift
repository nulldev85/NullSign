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

	init() {}
	
	var body: some View {
		ZStack {
			ForEach(TabEnum.defaultTabs.filter { visitedTabs.contains($0) }, id: \.self) { tab in
				TabEnum.view(for: tab)
					.opacity(selectedTab == tab ? 1 : 0)
					.allowsHitTesting(selectedTab == tab)
					.accessibilityHidden(selectedTab != tab)
			}
		}
		.background(Color.black)
		.safeAreaInset(edge: .bottom, spacing: 0) {
			NullSignTabBar(selection: Binding(
				get: { selectedTab },
				set: { tab in
					visitedTabs.insert(tab)
					selectedTab = tab
					UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
				}
			))
		}
	}
}

private struct NullSignTabBar: View {
	@Binding var selection: TabEnum
	@Namespace private var _indicator

	var body: some View {
		HStack(spacing: 0) {
			ForEach(TabEnum.defaultTabs, id: \.self) { tab in
				_tabButton(for: tab)
			}
		}
		.padding(.horizontal, 12)
		.padding(.top, 8)
		.background {
			NBVariableBlurView()
				.rotationEffect(.degrees(180))
				.ignoresSafeArea(edges: .bottom)
		}
	}

	private func _tabButton(for tab: TabEnum) -> some View {
		let isSelected = selection == tab

		return Button {
			guard !isSelected else { return }
			UISelectionFeedbackGenerator().selectionChanged()
			withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
				selection = tab
			}
		} label: {
			VStack(spacing: 3) {
				ZStack {
					if isSelected {
						Capsule()
							.fill(NullSignStyle.raisedPanel)
							.frame(width: 44, height: 28)
							.matchedGeometryEffect(id: "tabIndicator", in: _indicator)
					}
					Image(systemName: tab.icon)
						.font(.system(size: 19, weight: isSelected ? .semibold : .regular))
						.symbolVariant(isSelected ? .fill : .none)
				}
				.frame(height: 28)
				Text(tab.title)
					.font(.system(size: 10, weight: isSelected ? .semibold : .medium))
			}
			.foregroundStyle(isSelected ? NullSignStyle.accent : NullSignStyle.muted)
			.frame(maxWidth: .infinity)
			.padding(.vertical, 6)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.accessibilityLabel(tab.title)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}
}
