//
//  SigningView.swift
//  Feather
//
//  Created by samara on 14.04.2025.
//

import SwiftUI
import PhotosUI
import NimbleViews

// MARK: - View
struct SigningView: View {
	@Environment(\.dismiss) var dismiss
	@Environment(\.accessibilityReduceMotion) private var _reduceMotion
	@StateObject private var _optionsManager = OptionsManager.shared
	
	@State private var _temporaryOptions: Options = OptionsManager.shared.options
	@State private var _temporaryCertificate: Int
	@State private var _isAltPickerPresenting = false
	@State private var _isFilePickerPresenting = false
	@State private var _isImagePickerPresenting = false
	@State private var _isSigning = false
	@State private var _selectedPhoto: PhotosPickerItem? = nil
	@State var appIcon: UIImage?
	
	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var certificates: FetchedResults<CertificatePair>
	
	private func _selectedCert() -> CertificatePair? {
		guard certificates.indices.contains(_temporaryCertificate) else { return nil }
		let certificate = certificates[_temporaryCertificate]
		return Storage.shared.certificate(certificate, supports: app.platform) ? certificate : nil
	}
	
	var app: AppInfoPresentable
	
	init(app: AppInfoPresentable) {
		self.app = app
		let storedCert = Storage.shared.preferredCertificateIndex(for: app.platform) ?? -1
		__temporaryCertificate = State(initialValue: storedCert)
	}
		
	// MARK: Body
	var body: some View {
		NBNavigationView("", displayMode: .inline) {
			Form {
				NullSignSigningHeader(app: app) {
					_iconMenu(for: app)
				}
				_customizationOptions(for: app)
					.listRowBackground(NullSignStyle.panel)
				_cert()
					.listRowBackground(NullSignStyle.panel)
				_tweaks()
					.listRowBackground(NullSignStyle.panel)
				_customizationProperties(for: app)
					.listRowBackground(NullSignStyle.panel)
			}
			.scrollContentBackground(.hidden)
			.background(NullSignBackdrop())
			.tint(NullSignStyle.accent)
			.safeAreaInset(edge: .bottom, spacing: 0) {
				Button {
					_start()
				} label: {
					HStack(spacing: 10) {
						Image(systemName: "signature")
							.font(.system(size: 16, weight: .bold))
						Text(_isSigning ? .localized("Signing…") : .localized("Sign App"))
						Spacer()
						if _isSigning {
							ProgressView()
								.tint(.white)
						} else {
							Image(systemName: "arrow.right")
								.font(.system(size: 15, weight: .bold))
						}
					}
					.padding(.horizontal, 4)
				}
				.buttonStyle(NullSignPrimaryButtonStyle(height: 56, dimsWhenDisabled: false))
				.animation(_reduceMotion ? nil : .easeInOut(duration: 0.2), value: _isSigning)
				.padding(.horizontal, 16)
				.padding(.top, 14)
				.padding(.bottom, 8)
				.background(
					LinearGradient(
						colors: [Color.black.opacity(0), Color.black.opacity(0.85), Color.black],
						startPoint: .top,
						endPoint: .bottom
					)
					.ignoresSafeArea()
				)
			}

			.toolbar {
				NBToolbarButton(role: .dismiss)
				ToolbarItem(placement: .principal) {
					Text("Sign App")
						.font(.headline)
				}
				NBToolbarButton(
					.localized("Reset"),
					style: .text,
					placement: .topBarTrailing
				) {
					_temporaryOptions = OptionsManager.shared.options
					appIcon = nil
				}
			}
			.sheet(isPresented: $_isAltPickerPresenting) { SigningAlternativeIconView(app: app, appIcon: $appIcon, isModifing: .constant(true)) }
			.sheet(isPresented: $_isFilePickerPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes:  [.image],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self.appIcon = UIImage.fromFile(selectedFileURL)?.resizeToSquare()
					}
				)
				.ignoresSafeArea()
			}
			.photosPicker(isPresented: $_isImagePickerPresenting, selection: $_selectedPhoto)
			.onChange(of: _selectedPhoto) { newValue in
				guard let newValue else { return }
				
				Task {
					if let data = try? await newValue.loadTransferable(type: Data.self),
					   let image = UIImage(data: data)?.resizeToSquare() {
						appIcon = image
					}
				}
			}
			.disabled(_isSigning)
		}
		.onAppear {
			// ppq protection
			if
				_optionsManager.options.ppqProtection,
				let identifier = app.identifier,
				let cert = _selectedCert(),
				cert.ppQCheck
			{
				_temporaryOptions.appIdentifier = "\(identifier).\(_optionsManager.options.ppqString)"
			}
			
			if
				let currentBundleId = app.identifier,
				let newBundleId = _temporaryOptions.identifiers[currentBundleId]
			{
				_temporaryOptions.appIdentifier = newBundleId
			}
			
			if
				let currentName = app.name,
				let newName = _temporaryOptions.displayNames[currentName]
			{
				_temporaryOptions.appName = newName
			}
		}
		.onChange(of: _temporaryCertificate) { _ in
			if let certificate = _selectedCert() {
				Storage.shared.rememberCertificate(certificate, for: app.platform)
			}
		}
	}
}

// MARK: - Extension: View
extension SigningView {
	/// The header icon doubles as the icon picker.
	private func _iconMenu(for app: AppInfoPresentable) -> some View {
		Menu {
			Button(.localized("Select Alternative Icon"), systemImage: "app.dashed") { _isAltPickerPresenting = true }
			Button(.localized("Choose from Files"), systemImage: "folder") { _isFilePickerPresenting = true }
			Button(.localized("Choose from Photos"), systemImage: "photo") { _isImagePickerPresenting = true }
		} label: {
			Group {
				if let icon = appIcon {
					Image(uiImage: icon)
						.appIconStyle(size: 88)
				} else {
					FRAppIconView(app: app, size: 88, glow: true)
				}
			}
			.overlay(alignment: .bottomTrailing) {
				Image(systemName: "pencil")
					.font(.system(size: 11, weight: .heavy))
					.foregroundStyle(.white)
					.frame(width: 26, height: 26)
					.background(Circle().fill(NullSignStyle.signal))
					.overlay(Circle().strokeBorder(Color.black, lineWidth: 2))
					.offset(x: 6, y: 6)
			}
		}
		.accessibilityLabel("Change app icon")
	}

	@ViewBuilder
	private func _customizationOptions(for app: AppInfoPresentable) -> some View {
		Section {
			_infoCell(.localized("Name"), desc: _temporaryOptions.appName ?? app.name) {
				SigningPropertiesView(
					title: .localized("Name"),
					initialValue: _temporaryOptions.appName ?? (app.name ?? ""),
					bindingValue: $_temporaryOptions.appName
				)
			}
			_infoCell(.localized("Identifier"), desc: _temporaryOptions.appIdentifier ?? app.identifier) {
				SigningPropertiesView(
					title: .localized("Identifier"),
					initialValue: _temporaryOptions.appIdentifier ?? (app.identifier ?? ""),
					bindingValue: $_temporaryOptions.appIdentifier
				)
			}
			_infoCell(.localized("Version"), desc: _temporaryOptions.appVersion ?? app.version) {
				SigningPropertiesView(
					title: .localized("Version"),
					initialValue: _temporaryOptions.appVersion ?? (app.version ?? ""),
					bindingValue: $_temporaryOptions.appVersion
				)
			}
		} header: {
			SigningSectionHeader(title: .localized("Customization"))
		}
	}

	@ViewBuilder
	private func _cert() -> some View {
		Section {
			if let cert = _selectedCert() {
				NavigationLink {
					CertificatesView(selectedCert: $_temporaryCertificate, platform: app.platform)
				} label: {
					CertificatesCellView(
						cert: cert
					)
				}
			} else {
				NavigationLink {
					CertificatesView(selectedCert: $_temporaryCertificate, platform: app.platform)
				} label: {
					HStack(spacing: 12) {
						SigningRowIcon(systemImage: "checkmark.seal", tint: NullSignStyle.warning)
						VStack(alignment: .leading, spacing: 2) {
							Text(.localized("Choose Certificate"))
								.font(.system(size: 16, weight: .semibold))
							Text("No compatible certificate selected")
								.font(.caption)
								.foregroundStyle(NullSignStyle.muted)
						}
					}
				}
			}
		} header: {
			SigningSectionHeader(title: .localized("Signing"))
		}
	}

	@ViewBuilder
	private func _tweaks() -> some View {
		Section {
			NavigationLink {
				SigningTweaksView(options: $_temporaryOptions)
			} label: {
				LabeledContent {
					Text(_temporaryOptions.injectionFiles.count.description)
						.font(NullSignStyle.mono(14, weight: .bold))
						.foregroundStyle(NullSignStyle.muted)
				} label: {
					HStack(spacing: 12) {
						SigningRowIcon(systemImage: "shippingbox.and.arrow.backward")
						Text("Add .deb or .dylib")
							.font(.system(size: 16, weight: .semibold))
					}
				}
			}

			Toggle(isOn: $_temporaryOptions.experiment_replaceSubstrateWithEllekit) {
				HStack(spacing: 12) {
					SigningRowIcon(systemImage: "arrow.triangle.2.circlepath")
					Text("Replace Substrate with ElleKit")
						.font(.system(size: 16, weight: .semibold))
				}
			}
		} header: {
			SigningSectionHeader(title: "Tweaks & Injection")
		} footer: {
			Text("NullSign adds ElleKit when an imported tweak needs a hooking runtime. Enable replacement only when the app already contains Cydia Substrate and you want to swap it for ElleKit.")
				.font(.caption)
				.foregroundStyle(NullSignStyle.muted)
		}
	}

	@ViewBuilder
	private func _customizationProperties(for app: AppInfoPresentable) -> some View {
		Section {
			DisclosureGroup(.localized("Modify")) {
				NavigationLink(.localized("Existing Dylibs")) {
					SigningDylibView(
						app: app,
						options: $_temporaryOptions.optional()
					)
				}
				
				NavigationLink(.localized("Frameworks & PlugIns")) {
					SigningFrameworksView(
						app: app,
						options: $_temporaryOptions.optional()
					)
				}
				#if NIGHTLY || DEBUG
					NavigationLink(.localized("Entitlements") + " (BETA)") {
						SigningEntitlementsView(
							bindingValue: $_temporaryOptions.appEntitlementsFile
						)
					}
				#endif
			}
			
			NavigationLink(.localized("Properties")) {
				Form { SigningOptionsView(
					options: $_temporaryOptions,
					temporaryOptions: _optionsManager.options
				)}
				.scrollContentBackground(.hidden)
				.background(NullSignBackdrop(intensity: 0.6))
				.navigationTitle(.localized("Properties"))
			}
		} header: {
			SigningSectionHeader(title: .localized("Advanced"))
		}
	}

	@ViewBuilder
	private func _infoCell<V: View>(_ title: String, desc: String?, @ViewBuilder destination: () -> V) -> some View {
		NavigationLink {
			destination()
		} label: {
			LabeledContent {
				Text(desc ?? .localized("Unknown"))
					.font(NullSignStyle.mono(13, weight: .medium))
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)
					.truncationMode(.middle)
			} label: {
				Text(title)
					.font(.system(size: 16, weight: .semibold))
			}
		}
	}
}

// MARK: - Extension: View (import)
extension SigningView {
	private func _start() {
		guard
			_selectedCert() != nil || _temporaryOptions.signingOption != .default
		else {
			UIAlertController.showAlertWithOk(
				title: .localized("No Certificate"),
				message: .localized("Please go to settings and import a valid certificate"),
				isCancel: true
			)
			return
		}

		let generator = UIImpactFeedbackGenerator(style: .light)
		generator.impactOccurred()
		if let certificate = _selectedCert() {
			Storage.shared.rememberCertificate(certificate, for: app.platform)
		}
		_isSigning = true
		
		FR.signPackageFile(
			app,
			using: _temporaryOptions,
			icon: appIcon,
			certificate: _selectedCert()
		) { error in
			// FR normally completes on MainActor. Keep the interaction state
			// explicit here so an error never leaves the entire screen locked.
			_isSigning = false
			if let error {
				let ok = UIAlertAction(title: .localized("Dismiss"), style: .cancel) { _ in
					dismiss()
				}
				
				UIAlertController.showAlert(
					title: "Error",
					message: error.localizedDescription,
					actions: [ok]
				)
			} else {
				if
					_temporaryOptions.post_deleteAppAfterSigned,
					!app.isSigned
				{
					Storage.shared.deleteApp(for: app)
				}
				
				if _temporaryOptions.post_installAppAfterSigned {
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
						NotificationCenter.default.post(name: Notification.Name("Feather.installApp"), object: nil)
					}
				}
				dismiss()
			}
		}
	}
}
