import Foundation

@main
enum TVIconSelectionTests {
	static func main() {
		// Matches the Info.plist inspected in Lineup 0.19.0 (71)'s actual IPA.
		let lineup: [String: Any] = [
			"CFBundleIdentifier": "com.nulldev85.NullSports",
			"CFBundleSupportedPlatforms": ["AppleTVOS"],
			"UIDeviceFamily": [3],
			"CFBundleIcons": ["CFBundlePrimaryIcon": "App Icon - Small"]
		]
		precondition(TVIconSelection.isTVApp(lineup))
		precondition(TVIconSelection.assetNames(in: lineup) == ["App Icon - Small"])
		precondition(!TVIconSelection.isTVApp(["CFBundleSupportedPlatforms": ["iPhoneOS"], "UIDeviceFamily": [1, 2]]))
		precondition(TVIconSelection.isTVApp(["UIDeviceFamily": [3]]))

		// Same app identifier, new artwork: never use an old/generic alternate.
		var updated = lineup
		let updatedIcons: [String: Any] = [
			"CFBundlePrimaryIcon": "Current Blue Icon",
			"CFBundleAlternateIcons": ["Old Purple Icon", "App Icon - Small"]
		]
		updated["CFBundleIcons"] = updatedIcons
		precondition(TVIconSelection.assetNames(in: updated) == ["Current Blue Icon"])
		let dictionaryPrimary: [String: Any] = [
			"CFBundleIconName": "Current", "CFBundleIconFiles": ["Small", "Large", "Current"]
		]
		precondition(TVIconSelection.assetNames(in: [
			"CFBundleIcons": ["CFBundlePrimaryIcon": dictionaryPrimary]
		]) == ["Current", "Large", "Small"])
		precondition(TVIconSelection.assetNames(in: ["CFBundleIconFile": "Legacy.png"]) == ["Legacy.png"])
		precondition(TVIconSelection.assetNames(in: [
			"CFBundleIcons": ["CFBundlePrimaryIcon": ""], "CFBundleIconName": "Root Icon"
		]) == ["Root Icon"])
		precondition(TVIconSelection.assetNames(in: [:]) == ["App Icon - Small", "App Icon - Large", "App Icon", "AppIcon"])
		precondition(TVIconSelection.looseFileNames(for: "Current.png") == ["Current@3x.png", "Current@2x.png", "Current.png"])
		precondition(TVIconSelection.looseFileNames(for: "Current") == TVIconSelection.looseFileNames(for: "Current.png"))
		print("tvOS primary-icon selection tests passed, including changed artwork for the same bundle identifier.")
	}
}
