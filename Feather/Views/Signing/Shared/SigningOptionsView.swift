//
//  SigningOptionsSharedView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SigningOptionsView: View {
	@Binding var options: Options
	var temporaryOptions: Options?
	
	// MARK: Body
	var body: some View {
		if (temporaryOptions == nil) {
			Section {
				_toggle(
					.localized("PPQ Protection"),
					systemImage: "shield",
					isOn: $options.ppqProtection,
					temporaryValue: temporaryOptions?.ppqProtection
				)
			} header: {
				SigningSectionHeader(title: .localized("Protection"))
			} footer: {
				Text("PPQ protection appends a short random value to signed bundle identifiers. Signing-service certificates usually do not need it.")
			}
		}
		
		Section {
			Self.picker(
				.localized("Appearance"),
				systemImage: "circle.lefthalf.filled",
				selection: $options.appAppearance,
				values: Options.AppAppearance.allCases
			)
			
			Self.picker(
				.localized("Minimum Requirement"),
				systemImage: "ruler",
				selection: $options.minimumAppRequirement,
				values: Options.MinimumAppRequirement.allCases
			)
		} header: {
			SigningSectionHeader(title: .localized("App Output"))
		}
		
		Section {
			Self.picker(
				.localized("Signing Type"),
				systemImage: "signature",
				selection: $options.signingOption,
				values: Options.SigningOption.allCases
			)
		} header: {
			SigningSectionHeader(title: .localized("Signing Mode"))
		}
		
		if (temporaryOptions == nil) {
			Section {
				Self.picker(
					.localized("Load Path"),
					systemImage: "point.topleft.down.curvedto.point.bottomright.up",
					selection: $options.injectPath,
					values: Options.InjectPath.allCases
				)
				
				Self.picker(
					.localized("Destination"),
					systemImage: "folder",
					selection: $options.injectFolder,
					values: Options.InjectFolder.allCases
				)
				
				_toggle(
					.localized("Inject into Extensions"),
					systemImage: "puzzlepiece.extension",
					isOn: $options.injectIntoExtensions,
					temporaryValue: temporaryOptions?.injectIntoExtensions
				)
			} header: {
				SigningSectionHeader(title: .localized("Tweak Injection"))
			}
		}
		
		Section {
			_toggle(
				.localized("File Sharing"),
				systemImage: "folder.badge.person.crop",
				isOn: $options.fileSharing,
				temporaryValue: temporaryOptions?.fileSharing
			)
			
			_toggle(
				.localized("iTunes File Sharing"),
				systemImage: "music.note.list",
				isOn: $options.itunesFileSharing,
				temporaryValue: temporaryOptions?.itunesFileSharing
			)
			
			_toggle(
				.localized("Pro Motion"),
				systemImage: "speedometer",
				isOn: $options.proMotion,
				temporaryValue: temporaryOptions?.proMotion
			)
			
			_toggle(
				.localized("Game Mode"),
				systemImage: "gamecontroller",
				isOn: $options.gameMode,
				temporaryValue: temporaryOptions?.gameMode
			)
			
			_toggle(
				.localized("iPad Fullscreen"),
				systemImage: "ipad.landscape",
				isOn: $options.ipadFullscreen,
				temporaryValue: temporaryOptions?.ipadFullscreen
			)
		} header: {
			SigningSectionHeader(title: .localized("App Features"))
		}
		
		Section {
			_toggle(
				.localized("Remove URL Schemes"),
				systemImage: "link.badge.minus",
				isOn: $options.removeURLScheme,
				temporaryValue: temporaryOptions?.removeURLScheme
			)
			
			_toggle(
				.localized("Remove Provisioning Profile"),
				systemImage: "doc.badge.minus",
				isOn: $options.removeProvisioning,
				temporaryValue: temporaryOptions?.removeProvisioning
			)
		} header: {
			SigningSectionHeader(title: .localized("Package Cleanup"))
		} footer: {
			Text("Removing the provisioning profile can make the app impossible to install. Leave this off unless the target environment requires it.")
		}
		
		Section {
			_toggle(
				.localized("Force Localized Name"),
				systemImage: "character.bubble",
				isOn: $options.changeLanguageFilesForCustomDisplayName,
				temporaryValue: temporaryOptions?.changeLanguageFilesForCustomDisplayName
			)
		} header: {
			SigningSectionHeader(title: .localized("Display Name"))
		} footer: {
			Text("Rewrites localized display-name files so the custom name is used consistently.")
		}
		
		Section {
			_toggle(
				.localized("Install Automatically"),
				systemImage: "arrow.down.circle",
				isOn: $options.post_installAppAfterSigned,
				temporaryValue: temporaryOptions?.post_installAppAfterSigned
			)
			_toggle(
				.localized("Delete Imported Copy"),
				systemImage: "trash",
				isOn: $options.post_deleteAppAfterSigned,
				temporaryValue: temporaryOptions?.post_deleteAppAfterSigned
			)
		} header: {
			SigningSectionHeader(title: .localized("After Signing"))
		} footer: {
			Text("Deleting the imported copy after a successful sign reduces storage use.")
		}
		
		Section {
			_toggle(
				.localized("Replace Substrate with ElleKit"),
				systemImage: "pencil",
				isOn: $options.experiment_replaceSubstrateWithEllekit,
				temporaryValue: temporaryOptions?.experiment_replaceSubstrateWithEllekit
			)
			
			_toggle(
				.localized("Disable Liquid Glass"),
				systemImage: "18.circle",
				isOn: $options.experiment_disableLiquidGlass,
				temporaryValue: temporaryOptions?.experiment_disableLiquidGlass
			).disabled(options.experiment_supportLiquidGlass)
			
			_toggle(
				.localized("Enable Liquid Glass"),
				systemImage: "26.circle",
				isOn: $options.experiment_supportLiquidGlass,
				temporaryValue: temporaryOptions?.experiment_supportLiquidGlass
			).disabled(options.experiment_disableLiquidGlass)
		} header: {
			SigningSectionHeader(title: .localized("Compatibility"))
		} footer: {
			Text("These switches change appearance metadata for newer iOS releases and may not work with every app.")
		}
	}
	
	@ViewBuilder
	static func picker<T: Hashable & LocalizedDescribable>(
		_ title: String,
		systemImage: String,
		selection: Binding<T>,
		values: [T]
	) -> some View {
		HStack(spacing: 12) {
			SigningRowIcon(systemImage: systemImage)
			Text(title)
				.font(.body.weight(.medium))
			Spacer(minLength: 8)
			Picker(title, selection: selection) {
				ForEach(values, id: \.self) { value in
					Text(value.localizedDescription).tag(value)
				}
			}
			.labelsHidden()
			.tint(NullSignStyle.cyan)
		}
		.signingDestinationRow()
	}
	
	@ViewBuilder
	private func _toggle(
		_ title: String,
		systemImage: String,
		isOn: Binding<Bool>,
		temporaryValue: Bool? = nil
	) -> some View {
		Toggle(isOn: isOn) {
			HStack(spacing: 12) {
				SigningRowIcon(systemImage: systemImage)
				Text(title)
					.font(.body.weight(.medium))
				if let tempValue = temporaryValue, tempValue != isOn.wrappedValue {
					Text("Changed")
						.font(.caption2.weight(.semibold))
						.foregroundStyle(NullSignStyle.cyan)
				}
			}
		}
		.tint(NullSignStyle.cyan)
		.signingDestinationRow()
	}
}
