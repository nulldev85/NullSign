import SwiftUI
import NimbleViews

struct CertificatesView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0

	@State private var _isAddingPresenting = false
	@State private var _isRenamingPresenting = false
	@State private var _isSelectedInfoPresenting: CertificatePair?
	@State private var _certToRename: CertificatePair?
	@State private var _newNickname = ""

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
		.background(Color.black)
		.navigationTitle("Certificates")
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button {
					_isAddingPresenting = true
				} label: {
					Image(systemName: "plus")
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
		.alert("Rename Certificate", isPresented: $_isRenamingPresenting, presenting: _certToRename) { cert in
			TextField("Nickname", text: $_newNickname)
			Button("Cancel", role: .cancel) { }
			Button("Save") {
				guard cert.managedObjectContext != nil, !cert.isDeleted else { return }
				cert.nickname = _newNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
					? nil
					: _newNickname.trimmingCharacters(in: .whitespacesAndNewlines)
				Storage.shared.saveContext()
			}
		}
	}
}

extension CertificatesView {
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
		let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

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

			Menu {
				_contextActions(for: cert)
				if cert.isDefault != true {
					Divider()
					_actions(for: cert)
				}
			} label: {
				Image(systemName: "ellipsis")
					.font(.system(size: 15, weight: .bold))
					.foregroundStyle(NullSignStyle.muted)
					.frame(width: 46, height: 52)
					.contentShape(Rectangle())
			}
			.accessibilityLabel("Certificate actions")
		}
		.nullSignSurface()
		.overlay {
			if isSelected {
				shape.strokeBorder(NullSignStyle.accent, lineWidth: 2)
			}
		}
		.transaction { $0.animation = nil }
	}

	@ViewBuilder
	private func _actions(for cert: CertificatePair) -> some View {
		Button("Delete", systemImage: "trash", role: .destructive) {
			_delete(cert)
		}
	}

	@ViewBuilder
	private func _contextActions(for cert: CertificatePair) -> some View {
		Button("Get Info", systemImage: "info.circle") {
			_isSelectedInfoPresenting = cert
		}
		Button("Rename", systemImage: "pencil") {
			_newNickname = cert.nickname ?? ""
			_certToRename = cert
			_isRenamingPresenting = true
		}
		Divider()
		Button("Check Revocation", systemImage: "checkmark.shield") {
			Storage.shared.revokagedCertificate(for: cert)
		}
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
