import SwiftUI
import CoreData
import UIKit

// MARK: - Tokens

/// Settings is the palette reference: charcoal pages/cards and colored accents.
enum NullSignStyle {
	static let accent = Color(red: 0, green: 0.58, blue: 1)
	/// Slightly deeper blues keep white button/header text readable.
	static let actionBlue = Color(red: 0, green: 0.44, blue: 0.88)
	static let danger = Color(red: 1, green: 0.23, blue: 0.28)
	static let crimson = danger
	static let success = Color(red: 0.19, green: 0.82, blue: 0.35)
	static let warning = Color(red: 1, green: 0.62, blue: 0.04)
	static let yellow = Color(red: 1, green: 0.9, blue: 0)
	static let teal = Color(red: 0.18, green: 0.85, blue: 0.69)
	static let purple = Color(red: 0.75, green: 0.35, blue: 0.95)
	static let canvas = Color(red: 0.11, green: 0.11, blue: 0.12)
	static let groupedSurface = Color(red: 0.17, green: 0.17, blue: 0.18)
	// Ordinary cards and Settings groups share one surface color.
	static let surface = groupedSurface
	static let cardRadius: CGFloat = 24
	static let fill = Color.white.opacity(0.08)
	static let muted = Color(white: 0.72)
	static let faint = Color(white: 0.58)
	static let hairline = Color.white.opacity(0.08)
	static let panel = groupedSurface
	static let raisedPanel = Color(white: 0.22)

	static func categoryColor(for symbol: String) -> Color {
		switch symbol {
		case "checkmark", "checkmark.seal", "checkmark.seal.fill", "checkmark.shield", "hand.raised", "lock.shield", "lock.fill", "shield", "key":
			return success
		case "signature", "pencil", "slider.horizontal.3", "doc.text", "list.bullet", "puzzlepiece.extension", "gamecontroller", "character.bubble", "character.cursor.ibeam", "circle.lefthalf.filled":
			return purple
		case "internaldrive", "folder", "folder.fill", "folder.badge.person.crop", "shippingbox", "shippingbox.fill":
			return warning
		case "waveform.path.ecg", "exclamationmark.triangle", "trash", "trash.fill", "music.note.list":
			return danger
		case "arrow.triangle.2.circlepath", "speedometer", "square.stack.3d.up":
			return teal
		case "gearshape", "gearshape.fill", "info.circle":
			return Color(white: 0.55)
		default:
			return accent
		}
	}
}

// MARK: - Surfaces

struct NullSignSurfaceModifier: ViewModifier {
	var cornerRadius: CGFloat = NullSignStyle.cardRadius
	var fill: Color = NullSignStyle.surface

	func body(content: Content) -> some View {
		let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
		return content
			.background(fill, in: shape)
			.clipShape(shape)
	}
}

extension View {
	/// Charcoal pages and navigation chrome, including pushed views and sheets.
	func nullSignPage() -> some View {
		self
			.background(NullSignStyle.canvas)
			.toolbarBackground(NullSignStyle.canvas, for: .navigationBar)
			.toolbarBackground(.visible, for: .navigationBar)
			.toolbarColorScheme(.dark, for: .navigationBar)
			.tint(NullSignStyle.accent)
			.nullSignTypography()
	}

	func nullSignSurface(cornerRadius: CGFloat = NullSignStyle.cardRadius, fill: Color = NullSignStyle.surface) -> some View {
		modifier(NullSignSurfaceModifier(cornerRadius: cornerRadius, fill: fill))
	}

	/// A transparent, separator-free list row so cards sit on the charcoal canvas.
	func nullSignListRow(top: CGFloat = 6, bottom: CGFloat = 6, horizontal: CGFloat = 20) -> some View {
		self
			.listRowInsets(EdgeInsets(top: top, leading: horizontal, bottom: bottom, trailing: horizontal))
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
	}
}

// MARK: - Type

/// Section heading. `prominent` is for the top-level lists (Signer, Apps);
/// everything else uses the quieter grouped-list style.
struct NullSignSectionLabel: View {
	let title: String
	var count: Int? = nil
	var prominent: Bool = false
	var systemImage: String? = nil

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: 6) {
			if let systemImage {
				Image(systemName: systemImage)
					.font(.roundedUI(size: 13, weight: .bold))
					.foregroundStyle(NullSignStyle.muted)
					.accessibilityHidden(true)
			}
			Text(title.uppercased())
				.font(.roundedUI(prominent ? .subheadline : .caption, weight: .heavy))
				.tracking(prominent ? 0.35 : 0.65)
				.foregroundStyle(NullSignStyle.muted)
			if let count {
				Text(verbatim: "\(count)")
					.font(.roundedUI(.caption, weight: .bold))
					.foregroundStyle(NullSignStyle.faint)
			}
			Spacer(minLength: 0)
		}
		.textCase(nil)
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(.isHeader)
	}
}

// MARK: - Glyphs & Tags

struct NullSignIconTile: View {
	let systemImage: String
	/// Category color is the default for every row, including toggles.
	var tint: Color? = nil
	var size: CGFloat = 30
	var filled: Bool = true

	var body: some View {
		let color = tint ?? NullSignStyle.categoryColor(for: systemImage)
		// A symbol unavailable on an older supported iOS must not leave a blank tile.
		let symbol = UIImage(systemName: systemImage) == nil ? "square.dashed" : systemImage

		Image(systemName: symbol)
			.symbolRenderingMode(.monochrome)
			.font(.roundedUI(size: size * 0.5, weight: .medium))
			.foregroundStyle(filled ? Color.white : color)
			.frame(width: size, height: size)
			.background(filled ? color : NullSignStyle.fill, in: RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
			.accessibilityHidden(true)
	}
}

/// A small label. Filled tags carry white text on their tint (the tvOS
/// tag); plain tags sit on gray with tinted text.
struct NullSignChip: View {
	let text: String
	var systemImage: String? = nil
	var tint: Color = .white
	var filled: Bool = false

	var body: some View {
		HStack(spacing: 3) {
			if let systemImage {
				Image(systemName: systemImage)
					.font(.roundedUI(size: 9, weight: .semibold))
			}
			Text(text)
				.font(.roundedUI(.caption2, weight: .bold))
				.lineLimit(1)
		}
		.foregroundStyle(filled ? Color.white : tint)
		.padding(.horizontal, 6)
		.padding(.vertical, 3)
		.background(filled ? tint : NullSignStyle.fill, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
		.fixedSize()
	}
}

// MARK: - Ring

struct NullSignRing: View {
	let progress: Double
	var size: CGFloat = 60
	var lineWidth: CGFloat = 5
	var tint: Color = .white

	var body: some View {
		let clamped = min(max(progress, 0), 1)

		ZStack {
			Circle()
				.stroke(NullSignStyle.fill, lineWidth: lineWidth)
			Circle()
				.trim(from: 0, to: clamped)
				.stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
				.rotationEffect(.degrees(-90))
		}
		.padding(lineWidth / 2)
		.frame(width: size, height: size)
	}
}

// MARK: - Buttons

struct NullSignPrimaryButtonStyle: ButtonStyle {
	var height: CGFloat = 50
	var tint: Color = NullSignStyle.actionBlue
	/// Off for buttons that stay disabled while their own work runs, so the
	/// in-progress state reads as active rather than unavailable.
	var dimsWhenDisabled = true

	func makeBody(configuration: Configuration) -> some View {
		PrimaryBody(configuration: configuration, height: height, tint: tint, dimsWhenDisabled: dimsWhenDisabled)
	}

	struct PrimaryBody: View {
		let configuration: ButtonStyleConfiguration
		let height: CGFloat
		let tint: Color
		let dimsWhenDisabled: Bool
		@Environment(\.isEnabled) private var isEnabled

		var body: some View {
			configuration.label
				.font(.roundedUI(size: height < 40 ? 15 : 17, weight: .bold))
				.foregroundStyle(.white)
				.padding(.horizontal, height < 40 ? 14 : 20)
				.frame(minHeight: height)
				.background(tint, in: Capsule())
				.opacity(isEnabled || !dimsWhenDisabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
				.frame(minHeight: 44)
				.contentShape(Rectangle())
		}
	}
}

struct NullSignSecondaryButtonStyle: ButtonStyle {
	var height: CGFloat = 50
	var tint: Color = NullSignStyle.accent

	func makeBody(configuration: Configuration) -> some View {
		SecondaryBody(configuration: configuration, height: height, tint: tint)
	}

	struct SecondaryBody: View {
		let configuration: ButtonStyleConfiguration
		let height: CGFloat
		let tint: Color
		@Environment(\.isEnabled) private var isEnabled

		var body: some View {
			configuration.label
				.font(.roundedUI(size: height < 40 ? 15 : 17, weight: .bold))
				.foregroundStyle(tint)
				.padding(.horizontal, height < 40 ? 14 : 20)
				.frame(minHeight: height)
				.background(tint.opacity(configuration.isPressed ? 0.16 : 0.04), in: Capsule())
				.overlay(Capsule().strokeBorder(tint.opacity(isEnabled ? 0.85 : 0.35), lineWidth: 1.2))
				.opacity(isEnabled ? 1 : 0.4)
				.frame(minHeight: 44)
				.contentShape(Rectangle())
		}
	}
}

/// For cards that act as buttons: a plain highlight while pressed.
struct NullSignPressableStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.opacity(configuration.isPressed ? 0.7 : 1)
	}
}

// MARK: - Inputs

struct NullSignSearchField: View {
	let prompt: String
	@Binding var text: String

	var body: some View {
		HStack(spacing: 8) {
			Image(systemName: "magnifyingglass")
				.foregroundStyle(NullSignStyle.muted)
			TextField(prompt, text: $text)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
				.submitLabel(.search)
			if !text.isEmpty {
				Button {
					text = ""
				} label: {
					Image(systemName: "xmark.circle.fill")
						.foregroundStyle(NullSignStyle.faint)
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Clear search")
			}
		}
		.padding(.horizontal, 12)
		.frame(minHeight: 46)
		.background(NullSignStyle.groupedSurface, in: Capsule())
	}
}

struct NullSignSegmentedControl<Value: Hashable>: View {
	let options: [Value]
	@Binding var selection: Value
	let title: (Value) -> String
	var count: ((Value) -> Int?)? = nil
	@Namespace private var _namespace
	@Environment(\.accessibilityReduceMotion) private var _reduceMotion

	var body: some View {
		HStack(spacing: 0) {
			ForEach(options, id: \.self) { option in
				let isSelected = option == selection
				Button {
					guard !isSelected else { return }
					UISelectionFeedbackGenerator().selectionChanged()
					withAnimation(_reduceMotion ? nil : .easeInOut(duration: 0.2)) {
						selection = option
					}
				} label: {
					HStack(spacing: 5) {
						Text(title(option))
							.foregroundStyle(isSelected ? Color.white : NullSignStyle.accent)
						if let value = count?(option) {
							Text(verbatim: "\(value)")
								.foregroundStyle(isSelected ? Color.white : NullSignStyle.accent)
						}
					}
					.font(.roundedUI(.subheadline, weight: .bold))
					.lineLimit(1)
					.minimumScaleFactor(0.8)
					.frame(maxWidth: .infinity)
					.frame(minHeight: 36)
					.background {
						if isSelected {
							Capsule()
								.fill(NullSignStyle.actionBlue)
								.matchedGeometryEffect(id: "segment", in: _namespace)
						}
					}
					.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.accessibilityAddTraits(isSelected ? .isSelected : [])
			}
		}
		.padding(4)
		.background(NullSignStyle.accent.opacity(0.08), in: Capsule())
		.overlay(Capsule().strokeBorder(NullSignStyle.accent.opacity(0.45), lineWidth: 1))
	}
}

// MARK: - Empty State

struct NullSignEmptyState<Actions: View>: View {
	let systemImage: String
	let title: String
	let message: String
	let actions: Actions

	init(
		systemImage: String,
		title: String,
		message: String,
		@ViewBuilder actions: () -> Actions
	) {
		self.systemImage = systemImage
		self.title = title
		self.message = message
		self.actions = actions()
	}

	var body: some View {
		VStack(spacing: 16) {
			Image(systemName: systemImage)
				.font(.roundedUI(size: 40, weight: .regular))
				.foregroundStyle(NullSignStyle.accent)
				.accessibilityHidden(true)

			VStack(spacing: 6) {
				Text(title)
					.font(.roundedUI(.title3, weight: .heavy))
					.multilineTextAlignment(.center)
				Text(message)
					.font(.roundedUI(.subheadline))
					.foregroundStyle(NullSignStyle.muted)
					.multilineTextAlignment(.center)
					.fixedSize(horizontal: false, vertical: true)
			}

			actions
		}
		.frame(maxWidth: 340)
		.padding(.vertical, 20)
		.frame(maxWidth: .infinity)
	}
}

extension NullSignEmptyState where Actions == EmptyView {
	init(systemImage: String, title: String, message: String) {
		self.init(systemImage: systemImage, title: title, message: message) { EmptyView() }
	}
}

// MARK: - Identity

/// How long a signing identity has left.
struct NullSignValidity {
	let progress: Double
	let value: String
	let unit: String
	/// Short state, e.g. "Active", "Expires soon".
	let status: String
	/// Color for the ring and status dot.
	let tint: Color

	init(certificate: CertificatePair?, profile: Certificate? = nil, now: Date = Date()) {
		guard let certificate else {
			self.init(progress: 0, value: "–", unit: "", status: "Not set up", tint: NullSignStyle.faint)
			return
		}

		if certificate.revoked {
			self.init(progress: 0, value: "0", unit: "days", status: "Revoked", tint: NullSignStyle.danger)
			return
		}

		guard let expiration = certificate.expiration else {
			self.init(progress: 1, value: "–", unit: "", status: "Active", tint: NullSignStyle.success)
			return
		}

		let remaining = expiration.timeIntervalSince(now)
		guard remaining > 0 else {
			self.init(progress: 0, value: "0", unit: "days", status: "Expired", tint: NullSignStyle.danger)
			return
		}

		var lifetime: TimeInterval = 365 * 86_400
		if let profile {
			let profileLifetime = profile.ExpirationDate.timeIntervalSince(profile.CreationDate)
			if profileLifetime > 0 { lifetime = profileLifetime }
		}

		let days = Int(remaining / 86_400)
		let progress = min(max(remaining / lifetime, 0.02), 1)

		let value: String
		let unit: String
		if days >= 1 {
			value = "\(days)"
			unit = days == 1 ? "day" : "days"
		} else {
			value = "\(max(1, Int(remaining / 3_600)))"
			unit = "hrs"
		}

		switch days {
		case ..<7:
			self.init(progress: progress, value: value, unit: unit, status: "Expires soon", tint: NullSignStyle.danger)
		case 7..<30:
			self.init(progress: progress, value: value, unit: unit, status: "Expiring", tint: NullSignStyle.warning)
		default:
			self.init(progress: progress, value: value, unit: unit, status: "Active", tint: NullSignStyle.success)
		}
	}

	private init(progress: Double, value: String, unit: String, status: String, tint: Color) {
		self.progress = progress
		self.value = value
		self.unit = unit
		self.status = status
		self.tint = tint
	}

	/// Remaining time as text, e.g. "106 days left", "5 hours left", "Expired".
	/// The tint stays neutral until expiry is close.
	static func shortLabel(for expiration: Date, now: Date = Date()) -> (text: String, tint: Color) {
		let remaining = expiration.timeIntervalSince(now)
		guard remaining > 0 else { return ("Expired", NullSignStyle.danger) }
		let days = Int(remaining / 86_400)
		if days < 1 {
			let hours = max(1, Int(remaining / 3_600))
			return (hours == 1 ? "1 hour left" : "\(hours) hours left", NullSignStyle.danger)
		}
		let text = days == 1 ? "1 day left" : "\(days) days left"
		let tint: Color = days < 7 ? NullSignStyle.danger : (days < 30 ? NullSignStyle.warning : NullSignStyle.muted)
		return (text, tint)
	}
}

enum NullSignIdentity {
	/// The certificate the signer would preselect for an iPhone app: the one
	/// it last remembered, else the legacy selected index, else the newest.
	/// Display only — this never changes which certificate is used to sign.
	static func activeCertificate<C: RandomAccessCollection>(in certificates: C) -> CertificatePair?
	where C.Element == CertificatePair, C.Index == Int {
		let defaults = UserDefaults.standard
		if
			let uuid = defaults.string(forKey: "feather.selectedCert.iOS"),
			let match = certificates.first(where: { $0.uuid == uuid })
		{
			return match
		}
		let legacy = defaults.integer(forKey: "feather.selectedCert")
		if certificates.indices.contains(legacy) {
			return certificates[legacy]
		}
		return certificates.first
	}
}

/// A decoded profile is immutable once read, so it can cross from the
/// background decode back to the main actor.
extension Certificate: @unchecked Sendable {}

/// Decoded provisioning profiles, read off the main thread once per
/// certificate instead of on every render.
@MainActor
final class ProvisioningProfileCache {
	static let shared = ProvisioningProfileCache()
	private var _profiles: [String: Certificate] = [:]

	func profile(for certificate: CertificatePair) async -> Certificate? {
		guard
			certificate.managedObjectContext != nil,
			let uuid = certificate.uuid
		else {
			return nil
		}

		if let cached = _profiles[uuid] {
			return cached
		}

		guard let url = Storage.shared.getFile(.provision, from: certificate) else {
			return nil
		}

		let decoded = await Task.detached(priority: .utility) {
			CertificateReader(url).decoded
		}.value

		if let decoded {
			_profiles[uuid] = decoded
		}
		return decoded
	}
}

/// The active signing identity and how long it has left.
struct NullSignIdentityCard: View {
	let certificate: CertificatePair?
	var action: (() -> Void)? = nil

	@State private var _profile: Certificate?

	var body: some View {
		Button {
			action?()
		} label: {
			_content
		}
		.buttonStyle(NullSignPressableStyle())
		.disabled(action == nil)
		.task(id: certificate?.objectID) {
			guard let certificate else {
				_profile = nil
				return
			}
			_profile = await ProvisioningProfileCache.shared.profile(for: certificate)
		}
	}

	private var _content: some View {
		let validity = NullSignValidity(certificate: certificate, profile: _profile)

		return HStack(spacing: 14) {
			ZStack {
				NullSignRing(
					progress: validity.progress,
					size: 58,
					lineWidth: 5,
					tint: validity.tint
				)
				VStack(spacing: -2) {
					Text(validity.value)
						.font(.roundedUI(size: 17, weight: .heavy))
						.monospacedDigit()
						.minimumScaleFactor(0.6)
						.lineLimit(1)
					if !validity.unit.isEmpty {
						Text(validity.unit)
							.font(.roundedUI(size: 10, weight: .regular))
							.foregroundStyle(NullSignStyle.muted)
					}
				}
				.frame(width: 44)
			}

			VStack(alignment: .leading, spacing: 3) {
				Text(_title)
					.font(.roundedUI(.headline))
					.lineLimit(1)
				Text(_subtitle)
					.font(.roundedUI(.subheadline))
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)
				HStack(spacing: 6) {
					Circle()
						.fill(validity.tint)
						.frame(width: 7, height: 7)
					Text(_statusLine(validity))
						.font(.roundedUI(.subheadline))
						.foregroundStyle(NullSignStyle.muted)
						.lineLimit(1)
				}
			}

			Spacer(minLength: 0)

			if action != nil {
				Image(systemName: "chevron.right")
					.font(.roundedUI(.footnote, weight: .semibold))
					.foregroundStyle(NullSignStyle.faint)
			}
		}
		.foregroundStyle(.white)
		.padding(18)
		.nullSignSurface(fill: NullSignStyle.groupedSurface)
		.contentShape(RoundedRectangle(cornerRadius: NullSignStyle.cardRadius, style: .continuous))
		.accessibilityElement(children: .combine)
	}

	private var _title: String {
		guard let certificate else { return "No certificate" }
		return certificate.nickname ?? _profile?.Name ?? "Signing certificate"
	}

	private var _subtitle: String {
		guard certificate != nil else { return "Import a .p12 and its profile to sign" }
		return _profile?.TeamName ?? " "
	}

	private func _statusLine(_ validity: NullSignValidity) -> String {
		guard let certificate else { return "Not set up" }
		if certificate.revoked { return "Revoked" }
		guard let expiration = certificate.expiration else { return validity.status }
		if expiration <= Date() { return "Expired" }
		return "\(validity.status) · Expires \(expiration.formatted(date: .abbreviated, time: .omitted))"
	}
}

// MARK: - Signing Header

/// Top of the signing session: the app being signed.
struct NullSignSigningHeader<IconMenu: View>: View {
	let app: AppInfoPresentable
	let iconMenu: IconMenu

	init(app: AppInfoPresentable, @ViewBuilder iconMenu: () -> IconMenu) {
		self.app = app
		self.iconMenu = iconMenu()
	}

	var body: some View {
		VStack(spacing: 12) {
			iconMenu

			VStack(spacing: 4) {
				Text(app.name ?? "Unknown App")
					.font(.roundedUI(.title2, weight: .heavy))
					.multilineTextAlignment(.center)
					.lineLimit(2)
				Text(app.identifier ?? "No bundle identifier")
					.font(.roundedUI(.subheadline))
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)
			}

			HStack(spacing: 6) {
				PlatformBadge(platform: app.platform)
				if let version = app.version, !version.isEmpty {
					NullSignChip(text: version)
				}
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 4)
		.nullSignListRow(top: 6, bottom: 12)
	}
}
