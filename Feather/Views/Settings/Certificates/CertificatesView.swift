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
	private var _selectedCertBinding: Binding<Int> {
		_bindingSelectedCert ?? $_storedSelectedCert
	}

	init(selectedCert: Binding<Int>? = nil) {
		self._bindingSelectedCert = selectedCert
	}

	var body: some View {
		ScrollView {
			LazyVStack(spacing: 12) {
				_header

				if _certificates.isEmpty {
					_emptyState
				} else {
					ForEach(Array(_certificates.enumerated()), id: \.element.uuid) { index, cert in
						_cellButton(for: cert, at: index)
					}
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 12)
			.padding(.bottom, 24)
		}
		.background(Color.black.ignoresSafeArea())
		.navigationTitle("Certificates")
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
		NullSignSettingsCard {
			HStack(spacing: 14) {
				VStack(alignment: .leading, spacing: 4) {
					Text("Signing identities")
						.font(.headline)
					Text(_certificates.isEmpty
						 ? "A .p12 and matching provisioning profile are required."
						 : "\(_certificates.count) saved on this iPhone")
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}

				Spacer(minLength: 8)

				Button {
					_isAddingPresenting = true
				} label: {
					Label("Import", systemImage: "plus")
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(.black)
						.padding(.horizontal, 12)
						.frame(height: 36)
						.background(NullSignStyle.cyan)
						.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
				}
				.buttonStyle(.plain)
			}
		}
	}

	private var _emptyState: some View {
		VStack(spacing: 11) {
			Image(systemName: "checkmark.seal")
				.font(.system(size: 25, weight: .medium))
				.foregroundStyle(NullSignStyle.cyan)
			Text("No certificates yet")
				.font(.headline)
			Text("Use Import above to add your signing identity. Certificate files and passwords remain on this device.")
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 38)
		.padding(.horizontal, 24)
		.background(NullSignStyle.panel)
		.overlay {
			RoundedRectangle(cornerRadius: 18, style: .continuous)
				.stroke(NullSignStyle.hairline, lineWidth: 1)
		}
		.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
	}

	@ViewBuilder
	private func _cellButton(for cert: CertificatePair, at index: Int) -> some View {
		let isSelected = _selectedCertBinding.wrappedValue == index

		HStack(spacing: 0) {
			Button {
				_selectedCertBinding.wrappedValue = index
			} label: {
				CertificatesCellView(cert: cert, isSelected: isSelected)
					.padding(.vertical, 14)
					.padding(.leading, 16)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			.buttonStyle(.plain)

			Menu {
				_contextActions(for: cert)
				if cert.isDefault != true {
					Divider()
					_actions(for: cert)
				}
			} label: {
				Image(systemName: "ellipsis")
					.font(.body.weight(.semibold))
					.foregroundStyle(.secondary)
					.frame(width: 48, height: 48)
					.contentShape(Rectangle())
			}
			.accessibilityLabel("Certificate actions")
		}
		.background(NullSignStyle.panel)
		.overlay(alignment: .leading) {
			Capsule()
				.fill(isSelected ? NullSignStyle.cyan : Color.clear)
				.frame(width: 3)
				.padding(.vertical, 12)
		}
		.overlay {
			RoundedRectangle(cornerRadius: 18, style: .continuous)
				.stroke(isSelected ? NullSignStyle.cyan.opacity(0.5) : NullSignStyle.hairline, lineWidth: 1)
		}
		.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

		Storage.shared.deleteCertificate(for: cert)
		let remaining = Storage.shared.getAllCertificates()

		if let selectedUUID,
		   selectedUUID != cert.uuid,
		   let preservedIndex = remaining.firstIndex(where: { $0.uuid == selectedUUID }) {
			_selectedCertBinding.wrappedValue = preservedIndex
		} else {
			_selectedCertBinding.wrappedValue = min(selectedIndex, max(remaining.count - 1, 0))
		}
	}
}
