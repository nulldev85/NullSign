import Foundation

struct AppImportFailure: LocalizedError {
	enum Stage: Equatable, Sendable { case reading, unpacking, addingToLibrary }
	let stage: Stage
	let underlying: Error

	var errorDescription: String? {
		let detail: String
		switch stage {
		case .reading: detail = "Couldn't read the selected file. Make sure it is downloaded in Files, then choose it again."
		case .unpacking: detail = "Couldn't unpack the IPA. The archive may be incomplete or unsupported."
		case .addingToLibrary: detail = "Couldn't add this app to the library."
		}
		return detail + " " + underlying.localizedDescription
	}
}

enum AppImportOperation {
	static func run(file: URL, download: Download? = nil, sourceProvenance: SourceAppProvenance? = nil) async throws {
		let handler = AppFileHandler(file: file, download: download, sourceProvenance: sourceProvenance)
		var stage = AppImportFailure.Stage.reading
		do {
			try await handler.copy()
			stage = .unpacking
			try await handler.extract()
			stage = .addingToLibrary
			try await handler.move()
			try await handler.addToDatabase()
			await MainActor.run { download?.importCompleted = true }
			try? await handler.clean()
		} catch {
			try? await handler.clean()
			throw AppImportFailure(stage: stage, underlying: error)
		}
	}
}
