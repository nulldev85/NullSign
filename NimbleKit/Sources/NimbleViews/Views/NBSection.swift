//
//  SectionProminentHeaderWrapper.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI

public struct NBSection<Content, Footer>: View
where 	Content: View,
		Footer: View
{
	private var _headerText: String
	private var _headerTextSecondary: String?
	private var _systemName: String?
	private var _content: Content
	private var _footer: Footer
	
	public init(_ headerText: String,
		 secondary headerTextSecondary: String? = nil,
			systemName: String? = nil,
		 @ViewBuilder content: () -> Content,
		 @ViewBuilder footer: () -> Footer
	) {
		self._headerText = headerText
		self._headerTextSecondary = headerTextSecondary
		self._systemName = systemName
		self._content = content()
		self._footer = footer()
	}
	
	public init(_ headerText: String,
		 secondary headerTextSecondary: String? = nil,
		 systemName: String? = nil,
		 @ViewBuilder content: () -> Content
	) where Footer == EmptyView {
		self._headerText = headerText
		self._headerTextSecondary = headerTextSecondary
		self._systemName = systemName
		self._content = content()
		self._footer = EmptyView()
	}
	
	/// NullSign's grouped section: a quiet uppercase label with an optional
	/// symbol and count, rows on the charcoal surface, muted footer.
	public var body: some View {
		Section(
			header:
				HStack(alignment: .firstTextBaseline, spacing: 6) {
					if let _systemName {
						Image(systemName: _systemName)
							.font(.system(size: 13, weight: .bold, design: .rounded))
							.foregroundStyle(NBTheme.muted)
							.accessibilityHidden(true)
					}

					Text(_headerText.uppercased())
						.font(.system(.caption, design: .rounded).weight(.heavy))
						.tracking(0.65)
						.foregroundStyle(NBTheme.muted)

					if let _headerTextSecondary {
						Text(_headerTextSecondary)
							.font(.system(.caption, design: .rounded).weight(.bold))
							.foregroundStyle(NBTheme.faint)
							.contentTransition(.numericText())
					}

					Spacer(minLength: 0)
				}
				.textCase(nil)
				.accessibilityElement(children: .combine)
				.accessibilityAddTraits(.isHeader)
			,
			footer: _footer
				.font(.system(.caption, design: .rounded))
				.foregroundColor(NBTheme.faint)
		) {
			_content
				.listRowBackground(NBTheme.surface)
		}
	}
}
