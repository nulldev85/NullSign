import SwiftUI
import CoreData

// MARK: - Tokens

/// NullSign's visual language is built from its mark: a white form on true
/// black, punctuated by a single crimson dot. Crimson is the "signal" — it
/// marks what is active, what needs attention, and the primary action.
enum NullSignStyle {
	static let accent = Color(red: 0.902, green: 0.098, blue: 0.267)
	static let accentHighlight = Color(red: 1.0, green: 0.380, blue: 0.478)
	static let accentDeep = Color(red: 0.420, green: 0.035, blue: 0.122)
	static let crimson = accent
	static let violet = Color(red: 0.494, green: 0.376, blue: 1.0)
	static let success = Color(red: 0.204, green: 0.851, blue: 0.592)
	static let warning = Color(red: 1.0, green: 0.690, blue: 0.231)
	static let danger = accent
	static let ink = Color.black
	static let canvas = Color.black
	static let muted = Color.white.opacity(0.62)
	static let faint = Color.white.opacity(0.36)
	static let panel = Color.white.opacity(0.05)
	static let raisedPanel = Color.white.opacity(0.09)
	static let hairline = Color.white.opacity(0.09)

	/// Light catches the top-left edge of every surface.
	static let edge = LinearGradient(
		colors: [Color.white.opacity(0.17), Color.white.opacity(0.05), Color.white.opacity(0.03)],
		startPoint: .topLeading,
		endPoint: .bottomTrailing
	)
	static let cardFill = LinearGradient(
		colors: [Color.white.opacity(0.075), Color.white.opacity(0.032)],
		startPoint: .top,
		endPoint: .bottom
	)
	static let signal = LinearGradient(
		colors: [accentHighlight, accent],
		startPoint: .topLeading,
		endPoint: .bottomTrailing
	)

	static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
		.system(size: size, weight: weight).width(.expanded)
	}

	static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
		.system(size: size, weight: weight, design: .monospaced)
	}
}

// MARK: - Backdrop

/// Fixed ambient light behind every main screen: a crimson bloom from the
/// top-left and a faint violet counter-light, both fading into true black.
struct NullSignBackdrop: View {
	var intensity: Double = 1

	var body: some View {
		ZStack {
			NullSignStyle.canvas
			RadialGradient(
				colors: [NullSignStyle.accent.opacity(0.24 * intensity), .clear],
				center: UnitPoint(x: 0.05, y: -0.04),
				startRadius: 4,
				endRadius: 400
			)
			RadialGradient(
				colors: [NullSignStyle.violet.opacity(0.12 * intensity), .clear],
				center: UnitPoint(x: 1.0, y: 0.02),
				startRadius: 4,
				endRadius: 320
			)
		}
		.ignoresSafeArea()
		.allowsHitTesting(false)
	}
}

// MARK: - Surfaces

struct NullSignSurfaceModifier: ViewModifier {
	var cornerRadius: CGFloat = 20
	var fill: Color? = nil

	func body(content: Content) -> some View {
		let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
		return content
			.background {
				if let fill {
					shape.fill(fill)
				} else {
					shape.fill(NullSignStyle.cardFill)
				}
			}
			.overlay {
				shape.strokeBorder(NullSignStyle.edge, lineWidth: 1)
			}
			.clipShape(shape)
	}
}

extension View {
	func nullSignSurface(cornerRadius: CGFloat = 20, fill: Color? = nil) -> some View {
		modifier(NullSignSurfaceModifier(cornerRadius: cornerRadius, fill: fill))
	}

	/// A transparent, separator-free list row so cards float on the backdrop.
	func nullSignListRow(top: CGFloat = 6, bottom: CGFloat = 6, horizontal: CGFloat = 16) -> some View {
		self
			.listRowInsets(EdgeInsets(top: top, leading: horizontal, bottom: bottom, trailing: horizontal))
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
	}
}

// MARK: - Type

/// Screen title in the NullSign voice: wide, heavy, ending on the crimson dot.
struct NullSignTitle: View {
	let title: String
	var subtitle: String? = nil

	var body: some View {
		VStack(alignment: .leading, spacing: 7) {
			HStack(alignment: .firstTextBaseline, spacing: 3) {
				Text(title)
					.font(NullSignStyle.display(33))
					.foregroundStyle(.white)
					.lineLimit(1)
					.minimumScaleFactor(0.7)
				Circle()
					.fill(NullSignStyle.accent)
					.frame(width: 9, height: 9)
					.shadow(color: NullSignStyle.accent.opacity(0.9), radius: 6)
			}
			if let subtitle {
				Text(subtitle.uppercased())
					.font(NullSignStyle.mono(11, weight: .semibold))
					.tracking(1.2)
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)
					.contentTransition(.numericText())
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(.isHeader)
	}
}

/// Small monospaced section marker: ● SIGNED  03
struct NullSignSectionLabel: View {
	let title: String
	var count: Int? = nil

	var body: some View {
		HStack(spacing: 8) {
			Circle()
				.fill(NullSignStyle.accent)
				.frame(width: 5, height: 5)
			Text(title.uppercased())
				.font(NullSignStyle.mono(11, weight: .bold))
				.tracking(1.4)
				.foregroundStyle(NullSignStyle.muted)
			if let count {
				Text(count < 10 ? "0\(count)" : "\(count)")
					.font(NullSignStyle.mono(11, weight: .bold))
					.foregroundStyle(NullSignStyle.faint)
					.contentTransition(.numericText())
			}
			Spacer(minLength: 0)
		}
		.textCase(nil)
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(.isHeader)
	}
}

// MARK: - Glyphs & Chips

struct NullSignIconTile: View {
	let systemImage: String
	var tint: Color = .white
	var size: CGFloat = 34

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
		Image(systemName: systemImage)
			.font(.system(size: size * 0.43, weight: .semibold))
			.symbolRenderingMode(.hierarchical)
			.foregroundStyle(tint)
			.frame(width: size, height: size)
			.background(
				shape.fill(
					LinearGradient(
						colors: [tint.opacity(0.22), tint.opacity(0.07)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)
			)
			.overlay(shape.strokeBorder(tint.opacity(0.18), lineWidth: 1))
	}
}

struct NullSignChip: View {
	let text: String
	var systemImage: String? = nil
	var tint: Color = .white
	var filled: Bool = false
	var uppercased: Bool = true

	var body: some View {
		HStack(spacing: 4) {
			if let systemImage {
				Image(systemName: systemImage)
					.font(.system(size: 8.5, weight: .heavy))
			}
			Text(uppercased ? text.uppercased() : text)
				.font(NullSignStyle.mono(9.5, weight: .bold))
				.tracking(0.5)
				.lineLimit(1)
		}
		.foregroundStyle(filled ? Color.white : tint)
		.padding(.horizontal, 7)
		.frame(height: 19)
		.background(Capsule().fill(filled ? tint : tint.opacity(0.13)))
		.overlay(Capsule().strokeBorder(tint.opacity(filled ? 0 : 0.26), lineWidth: 1))
		.fixedSize()
	}
}

// MARK: - Ring

/// A validity ring. Its leading end carries the crimson dot from the mark.
struct NullSignRing: View {
	let progress: Double
	var size: CGFloat = 72
	var lineWidth: CGFloat = 7
	var tint: Color = .white
	var showsSignalDot: Bool = true

	var body: some View {
		let clamped = min(max(progress, 0), 1)
		let radius = (size - lineWidth) / 2
		let radians = (-90 + 360 * clamped) * .pi / 180

		ZStack {
			Circle()
				.stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
			Circle()
				.trim(from: 0, to: clamped)
				.stroke(
					AngularGradient(
						colors: [tint.opacity(0.3), tint],
						center: .center,
						startAngle: .degrees(0),
						endAngle: .degrees(360 * max(clamped, 0.001))
					),
					style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
				)
				.rotationEffect(.degrees(-90))
			if showsSignalDot && clamped > 0 {
				Circle()
					.fill(NullSignStyle.accent)
					.frame(width: lineWidth + 3, height: lineWidth + 3)
					.overlay(Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 1))
					.shadow(color: NullSignStyle.accent.opacity(0.9), radius: 5)
					.offset(x: radius * CGFloat(cos(radians)), y: radius * CGFloat(sin(radians)))
			}
		}
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
				.font(.system(size: height < 40 ? 13 : 15, weight: .bold))
				.foregroundStyle(.white)
				.padding(.horizontal, height < 40 ? 14 : 20)
				.frame(minHeight: height)
				.background {
					Capsule()
						.fill(NullSignStyle.signal)
						.overlay(
							Capsule().fill(
								LinearGradient(
									colors: [Color.white.opacity(0.24), Color.clear],
									startPoint: .top,
									endPoint: .center
								)
							)
						)
				}
				.overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
				.shadow(
					color: NullSignStyle.accent.opacity(isEnabled ? (configuration.isPressed ? 0.25 : 0.45) : 0),
					radius: configuration.isPressed ? 6 : 14,
					y: 5
				)
				.opacity(isEnabled || !dimsWhenDisabled ? 1 : 0.4)
				.scaleEffect(configuration.isPressed ? 0.97 : 1)
				.animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
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
				.font(.system(size: height < 40 ? 13 : 15, weight: .semibold))
				.foregroundStyle(tint)
				.padding(.horizontal, height < 40 ? 14 : 20)
				.frame(minHeight: height)
				.background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.08)))
				.overlay(Capsule().strokeBorder(NullSignStyle.edge, lineWidth: 1))
				.opacity(isEnabled ? 1 : 0.4)
				.scaleEffect(configuration.isPressed ? 0.97 : 1)
				.animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
		}
	}
}

/// For cards that act as buttons: a soft press-in, no chrome.
struct NullSignPressableStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.scaleEffect(configuration.isPressed ? 0.98 : 1)
			.opacity(configuration.isPressed ? 0.85 : 1)
			.animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
	}
}

// MARK: - Inputs

struct NullSignSearchField: View {
	let prompt: String
	@Binding var text: String
	@FocusState private var _isFocused: Bool

	var body: some View {
		HStack(spacing: 10) {
			Image(systemName: "magnifyingglass")
				.font(.system(size: 15, weight: .semibold))
				.foregroundStyle(_isFocused ? NullSignStyle.accent : NullSignStyle.muted)
			TextField(prompt, text: $text)
				.focused($_isFocused)
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
		.padding(.horizontal, 15)
		.frame(height: 46)
		.background(Capsule().fill(Color.white.opacity(0.06)))
		.overlay(
			Capsule().strokeBorder(
				_isFocused ? AnyShapeStyle(NullSignStyle.accent.opacity(0.65)) : AnyShapeStyle(NullSignStyle.edge),
				lineWidth: 1
			)
		)
		.animation(.easeOut(duration: 0.15), value: _isFocused)
	}
}

struct NullSignSegmentedControl<Value: Hashable>: View {
	let options: [Value]
	@Binding var selection: Value
	let title: (Value) -> String
	@Namespace private var _namespace
	@Environment(\.accessibilityReduceMotion) private var _reduceMotion

	var body: some View {
		HStack(spacing: 4) {
			ForEach(options, id: \.self) { option in
				let isSelected = option == selection
				Button {
					guard !isSelected else { return }
					UISelectionFeedbackGenerator().selectionChanged()
					withAnimation(_reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.8)) {
						selection = option
					}
				} label: {
					Text(title(option))
						.font(.system(size: 13, weight: .semibold))
						.foregroundStyle(isSelected ? Color.white : NullSignStyle.muted)
						.lineLimit(1)
						.frame(maxWidth: .infinity)
						.frame(height: 34)
						.background {
							if isSelected {
								Capsule()
									.fill(Color.white.opacity(0.12))
									.overlay(Capsule().strokeBorder(NullSignStyle.edge, lineWidth: 1))
									.matchedGeometryEffect(id: "segment", in: _namespace)
							}
						}
						.contentShape(Capsule())
				}
				.buttonStyle(.plain)
				.accessibilityAddTraits(isSelected ? .isSelected : [])
			}
		}
		.padding(4)
		.background(Capsule().fill(Color.white.opacity(0.04)))
		.overlay(Capsule().strokeBorder(NullSignStyle.hairline, lineWidth: 1))
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
		VStack(spacing: 18) {
			ZStack {
				ForEach(0..<3) { ring in
					Circle()
						.strokeBorder(Color.white.opacity(0.08 - Double(ring) * 0.022), lineWidth: 1)
						.frame(width: 92 + CGFloat(ring) * 42, height: 92 + CGFloat(ring) * 42)
				}
				Circle()
					.fill(
						RadialGradient(
							colors: [NullSignStyle.accent.opacity(0.32), .clear],
							center: .center,
							startRadius: 0,
							endRadius: 72
						)
					)
					.frame(width: 150, height: 150)
				NullSignIconTile(systemImage: systemImage, tint: .white, size: 62)
			}
			.frame(height: 178)
			.accessibilityHidden(true)

			VStack(spacing: 8) {
				Text(title)
					.font(NullSignStyle.display(20, weight: .bold))
					.multilineTextAlignment(.center)
				Text(message)
					.font(.subheadline)
					.foregroundStyle(NullSignStyle.muted)
					.multilineTextAlignment(.center)
					.fixedSize(horizontal: false, vertical: true)
			}

			actions
		}
		.frame(maxWidth: 360)
		.padding(.horizontal, 20)
		.frame(maxWidth: .infinity)
	}
}

extension NullSignEmptyState where Actions == EmptyView {
	init(systemImage: String, title: String, message: String) {
		self.init(systemImage: systemImage, title: title, message: message) { EmptyView() }
	}
}

// MARK: - Identity

/// How long a signing identity has left, shaped for the validity ring.
struct NullSignValidity {
	let progress: Double
	let value: String
	let unit: String
	let status: String
	let tint: Color

	init(certificate: CertificatePair?, profile: Certificate? = nil, now: Date = Date()) {
		guard let certificate else {
			self.init(progress: 0, value: "—", unit: "NONE", status: "Setup needed", tint: NullSignStyle.faint)
			return
		}

		if certificate.revoked {
			self.init(progress: 0, value: "!", unit: "REVOKED", status: "Revoked", tint: NullSignStyle.danger)
			return
		}

		guard let expiration = certificate.expiration else {
			self.init(progress: 1, value: "∞", unit: "VALID", status: "Active", tint: .white)
			return
		}

		let remaining = expiration.timeIntervalSince(now)
		guard remaining > 0 else {
			self.init(progress: 0, value: "0", unit: "EXPIRED", status: "Expired", tint: NullSignStyle.danger)
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
			unit = days == 1 ? "DAY" : "DAYS"
		} else {
			value = "\(max(1, Int(remaining / 3_600)))"
			unit = "HRS"
		}

		switch days {
		case ..<7:
			self.init(progress: progress, value: value, unit: unit, status: "Expires soon", tint: NullSignStyle.danger)
		case 7..<30:
			self.init(progress: progress, value: value, unit: unit, status: "Expiring", tint: NullSignStyle.warning)
		default:
			self.init(progress: progress, value: value, unit: unit, status: "Active", tint: .white)
		}
	}

	private init(progress: Double, value: String, unit: String, status: String, tint: Color) {
		self.progress = progress
		self.value = value
		self.unit = unit
		self.status = status
		self.tint = tint
	}

	/// Compact label for chips, e.g. "6D", "11H", "EXPIRED".
	static func shortLabel(for expiration: Date, now: Date = Date()) -> (text: String, tint: Color) {
		let remaining = expiration.timeIntervalSince(now)
		guard remaining > 0 else { return ("Expired", NullSignStyle.danger) }
		let days = Int(remaining / 86_400)
		if days < 1 {
			return ("\(max(1, Int(remaining / 3_600)))H", NullSignStyle.danger)
		}
		let tint: Color = days < 7 ? NullSignStyle.danger : (days < 30 ? NullSignStyle.warning : NullSignStyle.success)
		return ("\(days)D", tint)
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

/// The hero card: the active signing identity and how long it has left.
struct NullSignIdentityCard: View {
	let certificate: CertificatePair?
	var action: (() -> Void)? = nil

	@State private var _profile: Certificate?

	private var _validity: NullSignValidity {
		NullSignValidity(certificate: certificate, profile: _profile)
	}

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
		let validity = _validity

		return HStack(spacing: 16) {
			ZStack {
				NullSignRing(
					progress: validity.progress,
					size: 76,
					lineWidth: 7,
					tint: validity.tint,
					showsSignalDot: certificate != nil
				)
				VStack(spacing: 0) {
					Text(validity.value)
						.font(.system(size: 21, weight: .heavy, design: .rounded))
						.minimumScaleFactor(0.6)
						.lineLimit(1)
						.contentTransition(.numericText())
					Text(validity.unit)
						.font(NullSignStyle.mono(7.5, weight: .bold))
						.tracking(0.8)
						.foregroundStyle(NullSignStyle.muted)
				}
				.frame(width: 54)
			}

			VStack(alignment: .leading, spacing: 6) {
				NullSignChip(
					text: validity.status,
					systemImage: certificate == nil ? "exclamationmark" : "checkmark.seal.fill",
					tint: certificate == nil ? NullSignStyle.warning : (validity.tint == .white ? NullSignStyle.success : validity.tint)
				)
				Text(_title)
					.font(.system(size: 18, weight: .bold))
					.lineLimit(1)
				Text(_subtitle)
					.font(NullSignStyle.mono(11, weight: .medium))
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)
			}

			Spacer(minLength: 0)

			if action != nil {
				Image(systemName: "chevron.right")
					.font(.system(size: 13, weight: .bold))
					.foregroundStyle(NullSignStyle.faint)
			}
		}
		.padding(18)
		.background {
			RoundedRectangle(cornerRadius: 26, style: .continuous)
				.fill(NullSignStyle.cardFill)
				.overlay(
					RadialGradient(
						colors: [validity.tint == .white ? NullSignStyle.accent.opacity(0.22) : validity.tint.opacity(0.22), .clear],
						center: UnitPoint(x: 0.12, y: 0.5),
						startRadius: 2,
						endRadius: 170
					)
				)
		}
		.overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(NullSignStyle.edge, lineWidth: 1))
		.clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
		.contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
		.accessibilityElement(children: .combine)
	}

	private var _title: String {
		guard let certificate else { return "No signing identity" }
		return certificate.nickname ?? _profile?.Name ?? "Signing certificate"
	}

	private var _subtitle: String {
		guard certificate != nil else { return "Import a .p12 and profile to sign" }
		guard let profile = _profile else { return "Reading profile…" }
		let platforms = profile.Platform.joined(separator: " · ")
		return platforms.isEmpty ? profile.TeamName : "\(profile.TeamName) · \(platforms)"
	}
}

// MARK: - Signing Header

/// Top of the signing session: the app being signed, centered and lit.
struct NullSignSigningHeader<IconMenu: View>: View {
	let app: AppInfoPresentable
	let iconMenu: IconMenu

	init(app: AppInfoPresentable, @ViewBuilder iconMenu: () -> IconMenu) {
		self.app = app
		self.iconMenu = iconMenu()
	}

	var body: some View {
		VStack(spacing: 14) {
			iconMenu

			VStack(spacing: 7) {
				Text(app.name ?? "Unknown App")
					.font(NullSignStyle.display(21, weight: .bold))
					.multilineTextAlignment(.center)
					.lineLimit(2)
				Text(app.identifier ?? "No bundle identifier")
					.font(NullSignStyle.mono(11, weight: .medium))
					.foregroundStyle(NullSignStyle.muted)
					.lineLimit(1)
					.truncationMode(.middle)
				HStack(spacing: 6) {
					PlatformBadge(platform: app.platform)
					if let version = app.version, !version.isEmpty {
						NullSignChip(text: "v\(version)", uppercased: false)
					}
					NullSignChip(
						text: app.isSigned ? "Re-sign" : "Unsigned",
						tint: app.isSigned ? NullSignStyle.success : NullSignStyle.warning
					)
				}
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 6)
		.nullSignListRow(top: 6, bottom: 12)
	}
}
