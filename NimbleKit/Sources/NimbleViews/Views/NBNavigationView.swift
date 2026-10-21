//
//  NavigationViewWrapper.swift
//  Stars
//
//  Created by samara on 7.04.2025.
//

import SwiftUI

public struct NBNavigationView<Content>: View where Content: View {
	private var _title: String
	private var _mode: NavigationBarItem.TitleDisplayMode
	private var _content: Content
	
	public init(
		_ title: String,
		displayMode: NavigationBarItem.TitleDisplayMode = .automatic,
		@ViewBuilder content: () -> Content
	) {
		self._title = title
		self._mode = displayMode
		self._content = content()
	}
	
	public var body: some View {
		NavigationStack {
			_content
				.navigationTitle(_title)
				.navigationBarTitleDisplayMode(_mode)
				.toolbar {
					if _usesInlineTitle && !_title.isEmpty {
						ToolbarItem(placement: .principal) {
							Text(_title)
								.font(.roundedUI(.headline, weight: .heavy))
								.lineLimit(1)
								.minimumScaleFactor(0.8)
						}
					}
				}
		}
		.environment(\.font, .roundedUI(.body))
		.modifier(NBRoundedFontDesign())
	}

	private var _usesInlineTitle: Bool {
		if case .inline = _mode { return true }
		return false
	}
}
