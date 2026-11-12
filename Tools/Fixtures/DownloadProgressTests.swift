import Foundation
import Combine

// Provenance is an unrelated storage boundary; the observable Download and its
// completion/progress behavior below are the production implementation.
struct SourceAppProvenance {}

@main struct DownloadProgressTests {
	@MainActor static func main() {
		for onlyArchiving in [true, false] {
			let download = Download(id: "fixture", url: URL(fileURLWithPath: "/Fixture.ipa"), onlyArchiving: onlyArchiving)
			precondition(download.overallProgress == 0)
			download.progress = 1
			download.unpackageProgress = 1
			precondition(download.overallProgress == 0.99,
				"Unpacking alone must not complete the task before metadata/database saving")
			download.failure = "Could not save the imported app."
			precondition(download.overallProgress < 1 && !download.importCompleted)
			download.failure = nil
			download.importCompleted = true
			precondition(download.overallProgress == 1)
		}
		let download = Download(id: "fixture", url: URL(fileURLWithPath: "/Fixture.ipa"))
		for value in [Double.nan, .infinity, -.infinity] {
			download.progress = value
			precondition(download.overallProgress == 0)
		}
		print("PASS real Download model cannot finish at extraction or on save failure; only committed import reaches100 percent")
	}
}
