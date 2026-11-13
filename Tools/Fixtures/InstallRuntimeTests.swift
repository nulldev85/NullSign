import Foundation

// Controlled Launch Services boundary, with real Objective-C dispatch and
// Apple Foundation Progress objects. No UIKit or private iPhone APIs are faked.
final class WorkspaceFixture: NSObject {
	weak var observer: NSObject?
	var added = 0
	var removed = 0
	@objc func addObserver(_ observer: NSObject) { self.observer = observer; added += 1 }
	@objc func removeObserver(_ observer: NSObject) { self.observer = nil; removed += 1 }
	var identifier: String?
	var synchronous: Bool?
	let progress = Progress(totalUnitCount: 100)
	var installed = false
	@objc(applicationIsInstalled:)
	func applicationIsInstalled(_ identifier: NSString) -> Bool { installed }
	@objc(installProgressForBundleID:makeSynchronous:)
	func installProgress(_ identifier: NSString, synchronous: Bool) -> Progress {
		self.identifier = identifier as String
		self.synchronous = synchronous
		return progress
	}
}

final class AppProxyFixture: NSObject {
	var identifier = "fixture.app"
	@objc func applicationIdentifier() -> NSString { identifier as NSString }
	var installed = true
	var placeholder = false
	@objc func isInstalled() -> Bool { installed }
	@objc func isPlaceholder() -> Bool { placeholder }
	@objc func bundleURL() -> NSURL { NSURL(fileURLWithPath: "/Applications/Fixture.app") }
	@objc func shortVersionString() -> NSString { "2.0" }
	@objc func bundleVersion() -> NSString { "20" }
	@objc func registeredDate() -> NSDate { NSDate(timeIntervalSince1970: 1234) }
}

@main struct InstallRuntimeTests {
	static func main() {
		let workspace = WorkspaceFixture()
		workspace.progress.completedUnitCount = 40
		let first = SystemInstallRuntime.progress(workspace: workspace, identifier: "fixture.app", synchronous: false)
		precondition(workspace.identifier == "fixture.app" && workspace.synchronous == false)
		precondition(first?.fractionCompleted == 0.4 && first?.totalUnitCount == 100 && first?.isFinished == false)
		_ = SystemInstallRuntime.progress(workspace: workspace, identifier: "other.app", synchronous: true)
		precondition(workspace.identifier == "other.app" && workspace.synchronous == true)
		workspace.progress.completedUnitCount = 100
		precondition(SystemInstallRuntime.progress(workspace: workspace, identifier: "fixture.app", synchronous: false)?.isFinished == true)
		workspace.progress.cancel()
		precondition(SystemInstallRuntime.progress(workspace: workspace, identifier: "fixture.app", synchronous: false)?.isCancelled == true)
		print("PASS production bridge passes real Objective-C BOOL false/true and reads Foundation Progress terminal/cancelled state")

		precondition(SystemInstallRuntime.progress(workspace: NSObject(), identifier: "fixture.app", synchronous: false) == nil)
		precondition(!SystemInstallRuntime.appState(proxy: NSObject()).isAvailable)
		precondition(SystemInstallRuntime.applicationIsInstalled(workspace: NSObject(), identifier: "fixture.app") == nil)
		precondition(SystemInstallRuntime.applicationIsInstalled(workspace: workspace, identifier: "fixture.app") == false)
		workspace.installed = true
		precondition(SystemInstallRuntime.applicationIsInstalled(workspace: workspace, identifier: "fixture.app") == true)
		let proxy = AppProxyFixture()
		let record = SystemInstallRuntime.appState(proxy: proxy).app
		precondition(record?.bundlePath == "/Applications/Fixture.app")
		precondition(record?.version == "2.0" && record?.build == "20" && record?.registeredAt == 1234)
		proxy.placeholder = true
		precondition(SystemInstallRuntime.appState(proxy: proxy).isAvailable && SystemInstallRuntime.appState(proxy: proxy).app == nil)
		proxy.placeholder = false
		proxy.installed = false
		precondition(SystemInstallRuntime.appState(proxy: proxy).isAvailable && SystemInstallRuntime.appState(proxy: proxy).app == nil)
		print("PASS missing selectors, placeholders and uninstalled records cannot become installation evidence")

		guard let observer = SystemInstallRuntime.observeInstallation(workspace: workspace, identifier: "fixture.app", version: "2.0") else { preconditionFailure("Observer did not register") }
		precondition(workspace.added == 1 && workspace.observer === observer)
		proxy.installed = true
		observer.applicationsDidInstall([proxy] as NSArray)
		precondition(!observer.didInstall, "An event before this attempt's payload must not complete it")
		observer.arm()
		proxy.identifier = "other.app"
		observer.applicationsDidInstall([proxy] as NSArray)
		precondition(!observer.didInstall)
		proxy.identifier = "fixture.app"
		proxy.placeholder = true
		observer.applicationsDidInstall([proxy] as NSArray)
		precondition(!observer.didInstall)
		proxy.placeholder = false
		observer.applicationsDidInstall([proxy] as NSArray)
		precondition(observer.didInstall)
		observer.stop()
		observer.stop()
		precondition(workspace.removed == 1 && workspace.observer == nil)
		precondition(SystemInstallRuntime.observeInstallation(workspace: NSObject(), identifier: "fixture.app", version: nil) == nil)
		print("PASS real Objective-C observer registration, armed matching install callback, filtering and idempotent teardown")
	}
}
