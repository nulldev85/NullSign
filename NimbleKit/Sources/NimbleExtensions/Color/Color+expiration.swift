//
//  UIColor+expiration.swift
//  Feather
//
//  Created by samara on 16.04.2025.
//

import SwiftUI

extension Color {
	static public func expiration(days: Int) -> Color {
		switch days {
		// NullSign's danger, warning, yellow and success (NullSignStyle).
		case ..<14:
			return Color(red: 1, green: 0.23, blue: 0.28)
		case 14..<30:
			return Color(red: 1, green: 0.62, blue: 0.04)
		case 30..<60:
			return Color(red: 1, green: 0.9, blue: 0)
		default:
			return Color(red: 0.19, green: 0.82, blue: 0.35)
		}
	}
}
