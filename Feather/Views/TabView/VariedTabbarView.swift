//
//  VariedTabbarView.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI
import UIKit

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

	var body: some View {
		HStack(spacing: 0) {
			ForEach(TabEnum.defaultTabs, id: \.self) { tab in
				Button {
					guard selection != tab else { return }
					UISelectionFeedbackGenerator().selectionChanged()
					selection = tab
				} label: {
					VStack(spacing: 4) {
						Image(systemName: tab.icon)
							.font(.system(size: 19, weight: selection == tab ? .medium : .regular))
						Text(tab.title)
							.font(.system(size: 10, weight: selection == tab ? .semibold : .medium))
					}
					.foregroundStyle(selection == tab ? NullSignStyle.cyan : NullSignStyle.muted)
					.frame(maxWidth: .infinity)
					.frame(height: 50)
					.padding(.horizontal, 5)
					.padding(.vertical, 5)
					.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.accessibilityLabel(tab.title)
				.accessibilityAddTraits(selection == tab ? .isSelected : [])
			}
		}
		.padding(.horizontal, 7)
		.background(NullSignStyle.panel.opacity(0.98))
		.overlay(alignment: .top) { Rectangle().fill(NullSignStyle.hairline).frame(height: 1) }
	}
}
