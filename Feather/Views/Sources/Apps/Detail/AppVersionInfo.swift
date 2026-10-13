//
//  AppVersionInfo.swift
//  Feather
//
//  Created by Nagata Asami on 27/7/25.
//

import SwiftUI

struct AppVersionInfo: View {
	let version: String
	let date: Date?
	let description: String
    
	init(
		version: String,
		date: Date? = nil,
		description: String
	) {
		self.version = version
		self.date = date
		self.description = description
	}
    
	var body: some View {
		VStack(alignment: .leading, spacing: 9) {
			HStack {
				Text("Version \(version)")
					.font(.roundedUI(.subheadline, weight: .bold))
					.foregroundStyle(.primary)
                
				Spacer()
                
				if let date {
					Text(date.formatted(.relative(presentation: .named)))
						.font(.roundedUI(.caption))
						.foregroundStyle(.secondary)
				}
			}
            
			ExpandableText(text: description, lineLimit: 3)
				.font(.roundedUI(.subheadline))
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
} 
