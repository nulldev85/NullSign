//
//  CertificateReader.swift
//  Feather
//
//  Created by samara on 16.04.2025.
//

import Foundation
import OSLog
import Zsign

class CertificateReader: NSObject {
	let file: URL?
	var decoded: Certificate?
	
	init(_ file: URL?) {
		self.file = file
		super.init()
		self.decoded = self._readAndDecode()
	}
	
	private func _readAndDecode() -> Certificate? {
		guard let file = file else { return nil }
		
		do {
			guard let profileData = provisioning_profile_content(file.path) else {
				Logger.misc.error("Provisioning profile content could not be decoded")
				return nil
			}
			
			let decoder = PropertyListDecoder()
			let data = try decoder.decode(Certificate.self, from: profileData)
			return data
		} catch {
			Logger.misc.error("Error extracting certificate: \(error.localizedDescription)")
			return nil
		}
	}
}
