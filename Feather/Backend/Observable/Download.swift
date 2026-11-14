import Foundation
import Combine

final class Download: ObservableObject, Identifiable, @unchecked Sendable {
	@Published var progress: Double = 0.0
	@Published var bytesDownloaded: Int64 = 0
	@Published var totalBytes: Int64 = 0
	@Published var unpackageProgress: Double = 0.0
	@Published var importCompleted = false
	@Published var failure: String?

	var overallProgress: Double {
		if importCompleted { return 1 }
		let measured = onlyArchiving ? unpackageProgress : (0.3 * unpackageProgress) + (0.7 * progress)
		return measured.isFinite ? min(0.99, max(0, measured)) : 0
	}

	var task: URLSessionDownloadTask?
	var resumeData: Data?
	let id: String
	let url: URL
	let fileName: String
	let onlyArchiving: Bool
	var sourceProvenance: SourceAppProvenance?

	init(id: String, url: URL, onlyArchiving: Bool = false, sourceProvenance: SourceAppProvenance? = nil) {
		self.id = id
		self.url = url
		self.onlyArchiving = onlyArchiving
		self.sourceProvenance = sourceProvenance
		self.fileName = url.lastPathComponent
	}
}
