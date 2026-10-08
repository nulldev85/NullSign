//
//  Storage+Imported.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import CoreData
import UIKit.UIImpactFeedbackGenerator

// MARK: - Class extension: Imported Apps
extension Storage {
	/// Imports finish on a background task, so the insert is moved onto the
	/// main context's own queue instead of mutating it from that thread.
	func addImported(
		uuid: String,
		source: URL? = nil,

		appName: String? = nil,
		appIdentifier: String? = nil,
		appVersion: String? = nil,
		appIcon: String? = nil,

		completion: @escaping (Error?) -> Void
	) {
		context.perform {
			let generator = UIImpactFeedbackGenerator(style: .light)

			let new = Imported(context: self.context)

			new.uuid = uuid
			new.source = source
			new.date = Date()
			// name, identifier and version are required by the model; an empty
			// value keeps a malformed bundle from failing every later save.
			new.identifier = appIdentifier ?? ""
			new.name = (appName?.isEmpty == false ? appName : nil) ?? appIdentifier ?? "Unknown"
			new.icon = appIcon
			new.version = appVersion ?? ""

			self.saveContextNow()
			generator.impactOccurred()
			completion(nil)
		}
	}
}
