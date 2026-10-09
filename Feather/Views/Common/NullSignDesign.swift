import SwiftUI
import CoreData

// MARK: - Tokens

/// True black, neutral grays, and one red — the red of the tvOS tag. Red
/// marks primary actions, selection, and problems; it is never decorative.
enum NullSignStyle {
	static let accent = Color(red: 0.902, green: 0.098, blue: 0.267)
	static let crimson = accent
	static let danger = accent
	static let success = Color(red: 0.188, green: 0.820, blue: 0.345)
	static let warning = Color(red: 1.0, green: 0.624, blue: 0.039)
	static let ink = Color.black
	static let canvas = Color.black
	/// Cards and grouped rows.
	static let surface = Color(white: 0.09)
	/// Controls, tags and icon wells.
	static let fill = Color.white.opacity(0.1)
	static let muted = Color.white.opacity(0.6)
	static let faint = Color.white.opacity(0.35)
	static let hairline = Color.white.opacity(0.08)
	static let panel = Color.white.opacity(0.05)
	static let raisedPanel = Color.white.opacity(0.1)
}

// MARK: - Surfaces

struct NullSignSurfaceModifier: ViewModifier {
	var cornerRadius: CGFloat = 16
	var fill: Color = NullSignStyle.surface

	func body(content: Content) -> some View {
		let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
		return content
			.background(fill, in: shape)
			.overlay(shape.strokeBorder(NullSignStyle.hairline, lineWidth: 1))
	}
}

extension View {
	func nullSignSurface(cornerRadius: CGFloat = 16, fill: Color = NullSignStyle.surface) -> some View {
		modifier(NullSignSurfaceModifier(cornerRadius: cornerRadius, fill: fill))
	}

	/// A transparent, separator-free list row so cards sit directly on black.
	func nullSignListRow(top: CGFloat = 5, bottom: CGFloat = 5, horizontal: CGFloat = 16) -> some View {
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

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: 6) {
			Text(title)
				.font(prominent ? Font.title3.weight(.bold) : Font.subheadline.weight(.semibold))
				.foregroundStyle(prominent ? Color.white : NullSignStyle.muted)
			if let count {
				Text(verbatim: "\(count)")
					.font(prominent ? Font.title3.weight(.semibold) : Font.subheadline)
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
	var tint: Color = .white
	var size: CGFloat = 30

	var body: some View {
		Image(systemName: systemImage)
			.font(.system(size: size * 0.5, weight: .medium))
			.foregroundStyle(tint)
			.frame(width: size, height: size)
			.background(NullSignStyle.fill, in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
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
					.font(.system(size: 9, weight: .semibold))
			}
			Text(text)
				.font(.caption2.weight(.semibold))
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
	/// Off for buttons that stay disabled while their own work runs, so the
	/// in-progress state reads as active rather than unavailable.
	var dimsWhenDisabled = true

	func makeBody(configuration: Configuration) -> some View {
		PrimaryBody(configuration: configuration, height: height, dimsWhenDisabled: dimsWhenDisabled)
	}

	struct PrimaryBody: View {
		let configuration: ButtonStyleConfiguration
		let height: CGFloat
		let dimsWhenDisabled: Bool
		@Environment(\.isEnabled) private var isEnabled

		var body: some View {
			configuration.label
				.font(.system(size: height < 40 ? 15 : 17, weight: .semibold))
				.foregroundStyle(.white)
				.padding(.horizontal, height < 40 ? 14 : 20)
				.frame(minHeight: height)
				.background(NullSignStyle.accent, in: Capsule())
				.opacity(isEnabled || !dimsWhenDisabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
		}
	}
}

struct NullSignSecondaryButtonStyle: ButtonStyle {
	var height: CGFloat = 50
	var tint: Color = .white

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
				.font(.system(size: height < 40 ? 15 : 17, weight: .semibold))
				.foregroundStyle(tint)
				.padding(.horizontal, height < 40 ? 14 : 20)
				.frame(minHeight: height)
				.background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.1), in: Capsule())
				.opacity(isEnabled ? 1 : 0.4)
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
		.frame(height: 40)
		.background(NullSignStyle.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
							.foregroundStyle(isSelected ? Color.white : NullSignStyle.muted)
						if let value = count?(option) {
							Text(verbatim: "\(value)")
								.foregroundStyle(NullSignStyle.faint)
						}
					}
					.font(.subheadline.weight(.semibold))
					.lineLimit(1)
					.frame(maxWidth: .infinity)
					.frame(height: 32)
					.background {
						if isSelected {
							RoundedRectangle(cornerRadius: 9, style: .continuous)
								.fill(Color.white.opacity(0.16))
								.matchedGeometryEffect(id: "segment", in: _namespace)
						}
					}
					.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.accessibilityAddTraits(isSelected ? .isSelected : [])
			}
		}
		.padding(3)
		.background(NullSignStyle.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
				.font(.system(size: 40, weight: .regular))
				.foregroundStyle(NullSignStyle.faint)
				.accessibilityHidden(true)

			VStack(spacing: 6) {
				Text(title)
					.font(.title3.weight(.semibold))
					.multilineTextAlignment(.center)
				Text(message)
					.font(.subheadline)
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
					tint: validity.tint == NullSignStyle.success ? .white : validity.tint
				)
				VStack(spacing: -2) {
					Text(validity.value)
						.font(.system(size: 17, weight: .bold, design: .rounded))
						.monospacedDigit()
						.minimumScaleFactor(0.6)
						.lineLimit(1)
					if !validity.unit.isEmpty {
						Text(validity.unit)
							.font(.system(size: 10, weight: .medium))
							.foregroundStyle(NullSignStyle.muted)
					}
				}
				.frame(width: 44)
			}

			VStack(alignment: .leading, spacing: 3) {
				Text(_title)
					.font(.headline)
					.lineLimit(1)
				Text(_subtitle)
					.font(.subheadline)
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)
				HStack(spacing: 6) {
					Circle()
						.fill(validity.tint)
						.frame(width: 7, height: 7)
					Text(_statusLine(validity))
						.font(.subheadline)
						.foregroundStyle(NullSignStyle.muted)
						.lineLimit(1)
				}
			}

			Spacer(minLength: 0)

			if action != nil {
				Image(systemName: "chevron.right")
					.font(.footnote.weight(.semibold))
					.foregroundStyle(NullSignStyle.faint)
			}
		}
		.padding(16)
		.nullSignSurface()
		.contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
					.font(.title2.weight(.bold))
					.multilineTextAlignment(.center)
					.lineLimit(2)
				Text(app.identifier ?? "No bundle identifier")
					.font(.subheadline)
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
