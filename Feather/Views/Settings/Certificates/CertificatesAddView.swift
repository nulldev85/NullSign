import SwiftUI
import NimbleViews
import UniformTypeIdentifiers

struct CertificatesAddView: View {
	@Environment(\.dismiss) private var dismiss

	@State private var _p12URL: URL?
	@State private var _provisionURL: URL?
	@State private var _p12Password = ""
	@State private var _certificateName = ""
	@State private var _isImportingP12Presenting = false
	@State private var _isImportingMobileProvisionPresenting = false
	@State private var _isSaving = false

	private var saveButtonDisabled: Bool {
		_p12URL == nil || _provisionURL == nil || _isSaving
	}

	var body: some View {
		NBNavigationView("Import Certificate", displayMode: .inline) {
			ScrollView {
				VStack(spacing: 22) {
					NullSignSettingsIntro(
						systemImage: "checkmark.seal",
						title: "Add a signing identity",
						detail: "Choose a .p12 private key and its matching .mobileprovision profile."
					)

					NullSignSettingsSection("Files") {
						_fileButton(
							title: "Certificate",
							file: _p12URL,
							systemImage: "key"
						) {
							_isImportingP12Presenting = true
						}

						NullSignSettingsDivider()

						_fileButton(
							title: "Provisioning Profile",
							file: _provisionURL,
							systemImage: "doc.text"
						) {
							_isImportingMobileProvisionPresenting = true
						}
					}

					NullSignSettingsSection(
						"Details",
						detail: "Leave the password empty only when the .p12 was exported without one."
					) {
						_inputField("Nickname (optional)", text: $_certificateName, secure: false)
						NullSignSettingsDivider()
						_inputField("Certificate password", text: $_p12Password, secure: true)
					}

					Label(
						"Certificate files and passwords are stored locally and are never uploaded by NullSign.",
						systemImage: "lock.fill"
					)
					.font(.footnote)
					.foregroundStyle(.secondary)
					.padding(.horizontal, 4)
				}
				.padding(.horizontal, 16)
				.padding(.top, 12)
				.padding(.bottom, 28)
			}
			.background(Color.black.ignoresSafeArea())
			.toolbar {
				NBToolbarButton(role: .cancel)
				NBToolbarButton(
					"Save",
					style: .text,
					placement: .confirmationAction,
					isDisabled: saveButtonDisabled
				) {
					_saveCertificate()
				}
			}
			.sheet(isPresented: $_isImportingP12Presenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.p12],
					onDocumentsPicked: { urls in
						_p12URL = urls.first
					}
				)
				.ignoresSafeArea()
			}
			.sheet(isPresented: $_isImportingMobileProvisionPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.mobileProvision],
					onDocumentsPicked: { urls in
						_provisionURL = urls.first
					}
				)
				.ignoresSafeArea()
			}
		}
	}
}

extension CertificatesAddView {
	private func _fileButton(
		title: String,
		file: URL?,
		systemImage: String,
		action: @escaping () -> Void
	) -> some View {
		Button(action: action) {
			HStack(spacing: 12) {
				Image(systemName: file == nil ? systemImage : "checkmark.circle.fill")
					.font(.system(size: 16, weight: .semibold))
					.foregroundStyle(NullSignStyle.cyan)
					.frame(width: 32, height: 32)
					.background(NullSignStyle.raisedPanel)
					.clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

				VStack(alignment: .leading, spacing: 2) {
					Text(title)
						.font(.body.weight(.medium))
					Text(file?.lastPathComponent ?? "Choose a file")
						.font(.caption)
						.foregroundStyle(file == nil ? Color.secondary : NullSignStyle.cyan)
						.lineLimit(1)
				}
				Spacer()
				Text(file == nil ? "Choose" : "Change")
					.font(.subheadline.weight(.medium))
					.foregroundStyle(NullSignStyle.cyan)
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}

	@ViewBuilder
	private func _inputField(_ placeholder: String, text: Binding<String>, secure: Bool) -> some View {
		if secure {
			SecureField(placeholder, text: text)
				.textContentType(.password)
		} else {
			TextField(placeholder, text: text)
		}
	}

	private func _saveCertificate() {
		guard !_isSaving else { return }
		_isSaving = true

		guard
			let p12URL = _p12URL,
			let provisionURL = _provisionURL,
			FR.checkPasswordForCertificate(for: p12URL, with: _p12Password, using: provisionURL)
		else {
			_isSaving = false
			UIAlertController.showAlertWithOk(
				title: "Unable to Open Certificate",
				message: "Check that the files match and that the certificate password is correct."
			)
			return
		}

		let certificatesBeforeImport = Storage.shared.getAllCertificates()
		let selectedIndex = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		let selectedUUID = certificatesBeforeImport.indices.contains(selectedIndex)
			? certificatesBeforeImport[selectedIndex].uuid
			: nil

		FR.handleCertificateFiles(
			p12URL: p12URL,
			provisionURL: provisionURL,
			p12Password: _p12Password,
			certificateName: _certificateName.trimmingCharacters(in: .whitespacesAndNewlines)
		) { error in
			_isSaving = false
			if let error {
				UIAlertController.showAlertWithOk(
					title: "Unable to Import Certificate",
					message: error.localizedDescription
				)
				return
			}

			if let selectedUUID,
			   let preservedIndex = Storage.shared.getAllCertificates().firstIndex(where: { $0.uuid == selectedUUID }) {
				UserDefaults.standard.set(preservedIndex, forKey: "feather.selectedCert")
			}
			dismiss()
		}
	}
}
