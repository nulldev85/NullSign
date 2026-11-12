import Foundation

enum ArchiveFileAccess {
	/// Coordinate while the security scope is held. A provider may need to
	/// materialize the selected file before its bytes can be copied.
	static func copy(from source: URL, to destination: URL) throws {
		let access = source.startAccessingSecurityScopedResource()
		defer { if access { source.stopAccessingSecurityScopedResource() } }
		#if os(Linux)
		try FileManager.default.copyItem(at: source, to: destination)
		#else
		var coordinationError: NSError?
		var result: Result<Void, Error>?
		NSFileCoordinator().coordinate(readingItemAt: source, options: .withoutChanges, error: &coordinationError) { url in
			result = Result { try FileManager.default.copyItem(at: url, to: destination) }
		}
		if let coordinationError { throw coordinationError }
		guard let result else { throw CocoaError(.fileReadUnknown) }
		try result.get()
		#endif
	}
}
