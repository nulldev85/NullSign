import Foundation
import ZsignSwift

struct Options {
    var disInjectionFiles: [String] = []
    var appEntitlementsFile: URL?
    var removeProvisioning = false
}
final class OptionsManager {
    static let shared = OptionsManager()
    let options = Options()
}
struct CertificatePair { var password: String? }
enum CertificateFile { case provision, certificate }
final class Storage {
    static let shared = Storage()
    func getFile(_ kind: CertificateFile, from certificate: CertificatePair) -> URL? { nil }
}
enum SigningFileHandlerError: Error { case missingCertifcate, disinjectFailed, signFailed }

@main
struct HandlerTests {
    static func main() async throws {
        let handler = ZsignHandler(appUrl: URL(fileURLWithPath: "/fixture.app"), cert: CertificatePair())
        for adhoc in [false, true] {
            // Early native failures may return false without invoking completion.
            Zsign.succeeds = false
            Zsign.callbackError = nil
            Zsign.callsCompletion = false
            do {
                if adhoc { try await handler.adhocSign() } else { try await handler.sign() }
                fatalError("Native failure without a callback was accepted")
            } catch SigningFileHandlerError.signFailed { }

            let detail = NSError(domain: "resource-test", code: 413)
            Zsign.callsCompletion = true
            Zsign.callbackError = detail
            do {
                if adhoc { try await handler.adhocSign() } else { try await handler.sign() }
                fatalError("Native failure with a detailed error was accepted")
            } catch {
                precondition((error as NSError) == detail, "Lost native error detail")
            }

            // Existing non-strict failures must still reach SigningHandler's
            // existing hadError check, even when the native return is true.
            Zsign.succeeds = true
            if adhoc { try await handler.adhocSign() } else { try await handler.sign() }
            precondition((handler.hadError as NSError?) == detail)

            Zsign.callbackError = nil
            Zsign.callsCompletion = false
            if adhoc { try await handler.adhocSign() } else { try await handler.sign() }
            precondition(handler.hadError == nil, "A successful retry retained stale failure state")
        }
        print("Signing handler passed 8 native-result/callback/retry boundary cases.")
    }
}
