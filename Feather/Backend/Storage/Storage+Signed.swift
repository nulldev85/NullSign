//
//  Storage+Signed.swift
//  Feather
//
//  Created by samara on 17.04.2025.
//

import CoreData
import UIKit.UIImpactFeedbackGenerator

// MARK: - Class extension: Signed Apps
extension Storage {
	func addSigned(
		uuid: String,
		source: URL? = nil,
		certificate: CertificatePair? = nil,

		appName: String? = nil,
		appIdentifier: String? = nil,
		appVersion: String? = nil,
		appIcon: String? = nil,

		completion: @escaping (Error?) -> Void
	) {
		let generator = UIImpactFeedbackGenerator(style: .light)
		generator.prepare()

		// This is reached off the main thread at the end of signing, so the
		// insert + save is done on a private background context instead of
		// the main-queue viewContext: writing the SQLite store here would
		// otherwise force that disk I/O onto the main thread right as the
		// signing sheet is dismissing, causing a visible freeze.
		let certificateID = certificate?.objectID

		container.performBackgroundTask { backgroundContext in
			backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

			let new = Signed(context: backgroundContext)

			new.uuid = uuid
			new.source = source
			new.date = Date()
			// if nil, we assume adhoc or certificate was deleted afterwards
			if let certificateID {
				new.certificate = backgroundContext.object(with: certificateID) as? CertificatePair
			}
			// could possibly be nil, but thats fine.
			new.identifier = appIdentifier
			new.name = appName
			new.icon = appIcon
			new.version = appVersion

			try? backgroundContext.save()

			DispatchQueue.main.async {
				generator.impactOccurred()
				completion(nil)
			}
		}
	}
}
