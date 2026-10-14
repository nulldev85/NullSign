import SwiftUI
import NimbleViews

struct CertificatesView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0

	@State private var _isAddingPresenting = false
	@State private var _isRenamingPresenting = false
	@State private var _isSelectedInfoPresenting: CertificatePair?
	@State private var _certToRename: CertificatePair?
	@State private var _newNickname = ""
	@State private var _actionCertificate: CertificatePair?
	@State private var _pendingCertificateAction: (CertificatePair, CertificateAction)?

	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>

	private var _bindingSelectedCert: Binding<Int>?
	private var _platform: AppPlatform?
	private var _selectedCertBinding: Binding<Int> {
		_bindingSelectedCert ?? $_storedSelectedCert
	}

	init(selectedCert: Binding<Int>? = nil, platform: AppPlatform? = nil) {
		self._bindingSelectedCert = selectedCert
		self._platform = platform
	}

	var body: some View {
		ScrollView {
			LazyVStack(spacing: 12) {
				_header

				if _certificates.isEmpty {
					NullSignEmptyState(
						systemImage: "checkmark.seal",
						title: "No Certificates",
						message: "Import your .p12 and its provisioning profile. Certificate files and passwords never leave this device."
					) {
						Button {
							_isAddingPresenting = true
						} label: {
							Text("Import Certificate")
								.frame(minWidth: 160)
						}
						.buttonStyle(NullSignPrimaryButtonStyle())
						.padding(.top, 4)
					}
					.padding(.top, 20)
				} else {
					NullSignSectionLabel(title: "Saved", count: _certificates.count)
						.padding(.horizontal, 4)
						.padding(.top, 10)

					ForEach(Array(_certificates.enumerated()), id: \.element.objectID) { index, cert in
						_cellButton(for: cert, at: index)
					}
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 12)
			.padding(.bottom, 24)
		}
		.nullSignPage()
		.nullSignNavigationTitle("Certificates")
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button {
					_isAddingPresenting = true
				} label: {
					Image(systemName: "plus")
						.foregroundStyle(NullSignStyle.accent)
				}
				.accessibilityLabel("Import Certificate")
			}
		}
		.sheet(item: $_isSelectedInfoPresenting) { cert in
			CertificatesInfoView(cert: cert)
		}
		.sheet(isPresented: $_isAddingPresenting) {
			CertificatesAddView()
				.presentationDetents([.medium, .large])
		}
		.sheet(item: $_actionCertificate, onDismiss: _performCertificateAction) { cert in _certificateMenu(cert) }
		.sheet(isPresented: $_isRenamingPresenting) { _renamePrompt }
	}
}

extension CertificatesView {
	private enum CertificateAction { case info, rename, revoke, delete }

	private func _chooseCertificateAction(_ action: CertificateAction, for cert: CertificatePair) {
		_pendingCertificateAction = (cert, action)
		_actionCertificate = nil
	}

	private func _performCertificateAction() {
		guard let (cert, action) = _pendingCertificateAction else { return }
		_pendingCertificateAction = nil
		guard cert.managedObjectContext != nil, !cert.isDeleted else { return }
		switch action {
		case .info: _isSelectedInfoPresenting = cert
		case .rename:
			_newNickname = cert.nickname ?? ""
			_certToRename = cert
			_isRenamingPresenting = true
		case .revoke: Storage.shared.revokagedCertificate(for: cert)
		case .delete: if cert.isDefault != true { _delete(cert) }
		}
	}

	private func _certificateMenu(_ cert: CertificatePair) -> some View {
		NullSignMenuSheet(title: cert.nickname ?? "Certificate", systemImage: "checkmark.seal", detail: "Manage this local signing identity.") {
			NullSignSettingsCard {
				NullSignMenuAction(title: "Get Info", systemImage: "info.circle") { _chooseCertificateAction(.info, for: cert) }
				NullSignSettingsDivider()
				NullSignMenuAction(title: "Rename", systemImage: "pencil", tint: NullSignStyle.purple) { _chooseCertificateAction(.rename, for: cert) }
				NullSignSettingsDivider()
				NullSignMenuAction(title: "Check Revocation", systemImage: "checkmark.shield", tint: NullSignStyle.success) { _chooseCertificateAction(.revoke, for: cert) }
				if cert.isDefault != true {
					NullSignSettingsDivider()
					NullSignMenuAction(title: "Delete", systemImage: "trash", isDestructive: true) { _chooseCertificateAction(.delete, for: cert) }
				}
			}
		}
	}

	@ViewBuilder
	private var _renamePrompt: some View {
		if let cert = _certToRename {
			NullSignTextPrompt(
				title: "Rename Certificate", detail: "Set a nickname, or leave it empty to use the original certificate name.",
				placeholder: "Nickname", text: $_newNickname, allowsEmpty: true
			) {
				guard cert.managedObjectContext != nil, !cert.isDeleted else { return }
				let value = _newNickname.trimmingCharacters(in: .whitespacesAndNewlines)
				cert.nickname = value.isEmpty ? nil : value
				Storage.shared.saveContext()
			}
		}
	}

	private var _header: some View {
		NullSignSettingsIntro(
			systemImage: "checkmark.seal",
			title: "Signing Certificates",
			detail: _platform == .tvOS
				? "Choose a certificate whose provisioning profile includes tvOS."
				: "Each certificate is a .p12 paired with its provisioning profile."
		)
	}

	@ViewBuilder
	private func _cellButton(for cert: CertificatePair, at index: Int) -> some View {
		let isSelected = _selectedCertBinding.wrappedValue == index
		let isCompatible = _platform.map { Storage.shared.certificate(cert, supports: $0) } ?? true
		let shape = RoundedRectangle(cornerRadius: NullSignStyle.cardRadius, style: .continuous)

		HStack(spacing: 0) {
			Button {
				if isCompatible {
					UISelectionFeedbackGenerator().selectionChanged()
					_selectedCertBinding.wrappedValue = index
				}
			} label: {
				CertificatesCellView(cert: cert, isSelected: isSelected)
					.padding(.vertical, 14)
					.padding(.leading, 14)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			.buttonStyle(.plain)
			.disabled(!isCompatible)
			.opacity(isCompatible ? 1 : 0.4)

			Button {
				_actionCertificate = cert
			} label: {
				Image(systemName: "ellipsis")
					.font(.roundedUI(size: 15, weight: .bold))
					.foregroundStyle(NullSignStyle.accent)
					.frame(width: 46, height: 52)
					.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.accessibilityLabel("Certificate actions")
		}
		.nullSignSurface(fill: NullSignStyle.groupedSurface)
		.overlay {
			if isSelected {
				shape.strokeBorder(NullSignStyle.accent, lineWidth: 2)
			}
		}
		.transaction { $0.animation = nil }
	}


	private func _delete(_ cert: CertificatePair) {
		let selectedIndex = _selectedCertBinding.wrappedValue
		let selectedUUID = _certificates.indices.contains(selectedIndex)
			? _certificates[selectedIndex].uuid
			: nil
		let deletedUUID = cert.uuid

		Storage.shared.deleteCertificate(for: cert)
		let remaining = Storage.shared.getAllCertificates()

		if let selectedUUID,
		   selectedUUID != deletedUUID,
		   let preservedIndex = remaining.firstIndex(where: { $0.uuid == selectedUUID }) {
			_selectedCertBinding.wrappedValue = preservedIndex
		} else {
			_selectedCertBinding.wrappedValue = min(selectedIndex, max(remaining.count - 1, 0))
		}
	}
}
