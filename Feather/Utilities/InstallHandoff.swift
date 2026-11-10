import Foundation

enum InstallHandoff {
	/// Encode each URL layer separately so names, identifiers and payload URLs
	/// containing spaces, ampersands or Unicode survive the system handoff.
	static func externalManifestURL(identifier: String, name: String, version: String, payload: URL) -> URL {
		var components = URLComponents(string: "https://api.palera.in/genPlist")!
		components.queryItems = [
			URLQueryItem(name: "bundleid", value: identifier),
			URLQueryItem(name: "name", value: name),
			URLQueryItem(name: "version", value: version),
			URLQueryItem(name: "fetchurl", value: payload.absoluteString)
		]
		components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
		return components.url!
	}

	static func installURL(manifest: URL) -> URL {
		var components = URLComponents()
		components.scheme = "itms-services"
		components.host = ""
		components.queryItems = [
			URLQueryItem(name: "action", value: "download-manifest"),
			URLQueryItem(name: "url", value: manifest.absoluteString)
		]
		components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
		return components.url!
	}

	static func progress(afterSigning: Bool, installerProgress: Double, succeeded: Bool) -> Double {
		if succeeded { return 1 }
		let measured = min(0.99, max(0, installerProgress))
		return afterSigning ? 0.30 + measured * 0.70 : measured
	}
}
