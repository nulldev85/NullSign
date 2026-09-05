//
//  FRExpirationPillView.swift
//  Feather
//
//  Created by samara on 7.05.2025.
//

import SwiftUI

// MARK: - View
struct FRExpirationPillView: View {
	let title: String
	let revoked: Bool
	let expiration: Date.ExpirationInfo?
	
	var body: some View {
		let textLabel = revoked
			? .localized("Revoked")
			: expiration?.formatted ?? title
		
		let statusColor = revoked ? NullSignStyle.warning : NullSignStyle.accent

		HStack(spacing: 6) {
			Circle()
				.fill(statusColor)
				.frame(width: 6, height: 6)
			Text(textLabel.uppercased())
				.lineLimit(1)
		}
		.font(.system(size: 12, weight: .bold, design: .monospaced))
		.foregroundStyle(statusColor)
		.padding(.horizontal, 10)
		.padding(.vertical, 7)
		.background(NullSignStyle.raisedPanel)
		.overlay(Capsule().stroke(statusColor.opacity(0.35), lineWidth: 1))
		.clipShape(Capsule())
	}
}

