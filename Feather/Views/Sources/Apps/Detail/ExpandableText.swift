//
//  ExpandableText.swift
//  Feather
//
//  Created by samsam on 7/26/25.
//


import SwiftUI

struct ExpandableText: View {
	let text: String
	let lineLimit: Int

	@State private var expanded: Bool = false
	@State private var truncated: Bool = false
	@State private var collapsedHeight: CGFloat = 0
	@State private var fullHeight: CGFloat = 0

	var body: some View {
		VStack(alignment: .leading, spacing: 7) {
			Text(text)
				.lineLimit(expanded ? nil : lineLimit)
				.background(
					GeometryReader { proxy in
						Color.clear
							.onAppear { _recordCollapsedHeight(proxy.size.height) }
							.onChange(of: proxy.size.height) { _recordCollapsedHeight($0) }
					}
				)
				.background(
					Text(text)
						.lineLimit(nil)
						.fixedSize(horizontal: false, vertical: true)
						.hidden()
						.background(GeometryReader { proxy in
							Color.clear
								.onAppear { _recordFullHeight(proxy.size.height) }
								.onChange(of: proxy.size.height) { _recordFullHeight($0) }
						})
				)
				.onTapGesture {
					guard truncated else { return }
					withAnimation(.easeInOut(duration: 0.2)) {
						expanded.toggle()
					}
				}

			if truncated {
				Button(action: {
					withAnimation(.easeInOut(duration: 0.2)) {
						expanded.toggle()
					}
				}) {
					Text(expanded ? .localized("Less") : .localized("More"))
						.font(.caption.weight(.semibold))
						.foregroundStyle(NullSignStyle.cyan)
				}
			}
		}
	}

	private func _recordCollapsedHeight(_ height: CGFloat) {
		guard !expanded else { return }
		collapsedHeight = height
		truncated = fullHeight > height + 1
	}

	private func _recordFullHeight(_ height: CGFloat) {
		fullHeight = height
		truncated = height > collapsedHeight + 1
	}
}

