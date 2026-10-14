import SwiftUI
import NimbleViews

struct ConfigurationView: View {
	@StateObject private var _optionsManager = OptionsManager.shared
	@State private var _isRandomAlertPresenting = false
	@State private var _randomString = ""
	@State private var _isPPQMenuPresenting = false
	@State private var _didCopyPPQ = false
	@State private var _editPPQAfterDismissal = false

	var body: some View {
		ScrollView {
			VStack(spacing: 22) {
				NullSignSettingsIntro(
					systemImage: "signature",
					title: "Signing Defaults",
					detail: "These values are applied to new signing sessions. You can still override app-specific options before signing."
				)

				NullSignSettingsSection(
					"Automatic Rules",
					detail: "Match an existing name or bundle identifier and replace it automatically."
				) {
					NavigationLink(destination: ConfigurationDictView(
						title: "Display Names",
						dataDict: $_optionsManager.options.displayNames
					)) {
						NullSignSettingsRow(
							title: "Display Names",
							detail: "Rename matching apps",
							systemImage: "character.cursor.ibeam",
							value: _optionsManager.options.displayNames.count.description
						)
					}
					.buttonStyle(.plain)

					NullSignSettingsDivider()

					NavigationLink(destination: ConfigurationDictView(
						title: "Identifiers",
						dataDict: $_optionsManager.options.identifiers
					)) {
						NullSignSettingsRow(
							title: "Bundle Identifiers",
							detail: "Replace matching identifiers",
							systemImage: "number",
							value: _optionsManager.options.identifiers.count.description
						)
					}
					.buttonStyle(.plain)
				}

				NullSignSettingsSection("App Output") {
					_picker(
						"Appearance",
						systemImage: "circle.lefthalf.filled",
						selection: $_optionsManager.options.appAppearance,
						values: Options.AppAppearance.allCases
					)
					NullSignSettingsDivider()
					_picker(
						"Minimum iOS",
						systemImage: "iphone",
						selection: $_optionsManager.options.minimumAppRequirement,
						values: Options.MinimumAppRequirement.allCases
					)
					NullSignSettingsDivider()
					_picker(
						"Signing Mode",
						systemImage: "signature",
						selection: $_optionsManager.options.signingOption,
						values: Options.SigningOption.allCases
					)
				}

				NullSignSettingsSection(
					"Protection",
					detail: "PPQ protection appends a short random value to signed bundle identifiers. Signing-service certificates usually do not need it."
				) {
					_toggle(
						"PPQ Protection",
						detail: "Reduce repeated identifier flags",
						systemImage: "shield",
						isOn: $_optionsManager.options.ppqProtection
					)
				}

				NullSignSettingsSection(
					"Tweak Injection",
					detail: "Advanced options only affect sessions where you explicitly add .deb or .dylib files."
				) {
					_picker(
						"Load Path",
						systemImage: "point.topleft.down.curvedto.point.bottomright.up",
						selection: $_optionsManager.options.injectPath,
						values: Options.InjectPath.allCases
					)
					NullSignSettingsDivider()
					_picker(
						"Destination",
						systemImage: "folder",
						selection: $_optionsManager.options.injectFolder,
						values: Options.InjectFolder.allCases
					)
					NullSignSettingsDivider()
					_toggle(
						"Inject into Extensions",
						detail: "Also patch embedded app extensions",
						systemImage: "puzzlepiece.extension",
						isOn: $_optionsManager.options.injectIntoExtensions
					)
					NullSignSettingsDivider()
					_toggle(
						"Replace Substrate with ElleKit",
						detail: "Convert compatible tweak dependencies",
						systemImage: "arrow.triangle.2.circlepath",
						isOn: $_optionsManager.options.experiment_replaceSubstrateWithEllekit
					)
				}

				NullSignSettingsSection("App Features") {
					_toggle("File Sharing", systemImage: "folder", isOn: $_optionsManager.options.fileSharing)
					NullSignSettingsDivider()
					_toggle("iTunes File Sharing", systemImage: "music.note.list", isOn: $_optionsManager.options.itunesFileSharing)
					NullSignSettingsDivider()
					_toggle("ProMotion", systemImage: "speedometer", isOn: $_optionsManager.options.proMotion)
					NullSignSettingsDivider()
					_toggle("Game Mode", systemImage: "gamecontroller", isOn: $_optionsManager.options.gameMode)
					NullSignSettingsDivider()
					_toggle("iPad Fullscreen", systemImage: "ipad.landscape", isOn: $_optionsManager.options.ipadFullscreen)
				}

				NullSignSettingsSection(
					"Package Cleanup",
					detail: "Removing provisioning data can break installation. Leave it off unless the target environment specifically requires it."
				) {
					_toggle("Remove URL Schemes", systemImage: "link.badge.minus", isOn: $_optionsManager.options.removeURLScheme)
					NullSignSettingsDivider()
					_toggle("Remove Provisioning Profile", systemImage: "doc.badge.minus", isOn: $_optionsManager.options.removeProvisioning)
					NullSignSettingsDivider()
					_toggle(
						"Force Localized Name",
						detail: "Rewrite localized display-name files",
						systemImage: "character.bubble",
						isOn: $_optionsManager.options.changeLanguageFilesForCustomDisplayName
					)
				}

				NullSignSettingsSection(
					"After Signing",
					detail: "Deleting the imported copy after a successful sign reduces storage use."
				) {
					_toggle("Install Automatically", systemImage: "arrow.down.app", isOn: $_optionsManager.options.post_installAppAfterSigned)
					NullSignSettingsDivider()
					_toggle("Delete Imported Copy", systemImage: "trash", isOn: $_optionsManager.options.post_deleteAppAfterSigned)
				}

				NullSignSettingsSection(
					"Compatibility",
					detail: "These switches modify appearance metadata for newer iOS releases and may not work with every app."
				) {
					_toggle("Disable Liquid Glass", systemImage: "18.circle", isOn: $_optionsManager.options.experiment_disableLiquidGlass)
						.disabled(_optionsManager.options.experiment_supportLiquidGlass)
					NullSignSettingsDivider()
					_toggle("Enable Liquid Glass", systemImage: "26.circle", isOn: $_optionsManager.options.experiment_supportLiquidGlass)
						.disabled(_optionsManager.options.experiment_disableLiquidGlass)
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 12)
			.padding(.bottom, 28)
		}
		.nullSignPage()
		.nullSignNavigationTitle("Signing Defaults")
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button {
					_didCopyPPQ = false
					_isPPQMenuPresenting = true
				} label: { Image(systemName: "number") }
				.accessibilityLabel("PPQ Suffix Options")
			}
		}
		.sheet(isPresented: $_isPPQMenuPresenting, onDismiss: _openPPQEditor) { _ppqMenu }
		.sheet(isPresented: $_isRandomAlertPresenting) {
			NullSignTextPrompt(
				title: "PPQ Suffix", detail: "This value is appended when PPQ Protection is enabled.",
				placeholder: "String", text: $_randomString
			) {
				let value = _randomString.trimmingCharacters(in: .whitespacesAndNewlines)
				if !value.isEmpty { _optionsManager.options.ppqString = value }
			}
		}
		.onChange(of: _optionsManager.options) { _ in
			_optionsManager.saveOptions()
		}
	}
}

extension ConfigurationView {
	private var _ppqMenu: some View {
		NullSignMenuSheet(title: "PPQ Suffix", systemImage: "number", detail: "Manage the suffix used by PPQ Protection.") {
			NullSignSettingsCard {
				NullSignMenuAction(title: "Change", systemImage: "pencil", tint: NullSignStyle.purple) {
					_editPPQAfterDismissal = true
					_isPPQMenuPresenting = false
				}
				NullSignSettingsDivider()
				NullSignMenuAction(title: _didCopyPPQ ? "Copied" : "Copy", systemImage: _didCopyPPQ ? "checkmark" : "doc.on.doc") {
					UIPasteboard.general.string = _optionsManager.options.ppqString
					_didCopyPPQ = true
				}
			}
		}
	}

	private func _openPPQEditor() {
		guard _editPPQAfterDismissal else { return }
		_editPPQAfterDismissal = false
		_randomString = _optionsManager.options.ppqString
		_isRandomAlertPresenting = true
	}

	private func _picker<T: Hashable & LocalizedDescribable>(
		_ title: String,
		systemImage: String,
		selection: Binding<T>,
		values: [T]
	) -> some View {
		NullSignChoiceRow(
			title: title, systemImage: systemImage, selection: selection,
			values: values, label: { $0.localizedDescription }
		)
	}

	private func _toggle(
		_ title: String,
		detail: String? = nil,
		systemImage: String,
		isOn: Binding<Bool>
	) -> some View {
		Toggle(isOn: isOn) {
			HStack(spacing: 12) {
				NullSignIconTile(systemImage: systemImage)
				VStack(alignment: .leading, spacing: detail == nil ? 0 : 2) {
					Text(title)
						.font(.roundedUI(size: 16, weight: .bold))
					if let detail {
						Text(detail)
							.font(.roundedUI(.caption))
							.foregroundStyle(NullSignStyle.muted)
					}
				}
			}
		}
		.tint(NullSignStyle.accent)
	}
}
