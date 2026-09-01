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
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(.primary)
                
				Spacer()
                
				if let date {
					Text(date.formatted(.relative(presentation: .named)))
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
            
			ExpandableText(text: description, lineLimit: 3)
				.font(.subheadline)
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
} 
