import SwiftUI

enum Space {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 36
}

enum Radius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum StrokeWidth {
    static let hairline: CGFloat = 1
}

extension Color {
    static let brand = Color(red: 0.17, green: 0.24, blue: 0.31)
    static let brandLight = Color(red: 0.27, green: 0.34, blue: 0.42)
    static let accent = Color(red: 0.83, green: 0.65, blue: 0.46)
    static let accentSoft = Color(red: 0.96, green: 0.91, blue: 0.83)

    static let paper = Color(red: 0.98, green: 0.98, blue: 0.97)
    static let paperSecondary = Color(red: 0.95, green: 0.95, blue: 0.92)
    static let paperTertiary = Color(red: 0.91, green: 0.91, blue: 0.88)
    static let card = Color.white

    static let ink = Color(red: 0.10, green: 0.10, blue: 0.10)
    static let inkSoft = Color(red: 0.42, green: 0.42, blue: 0.42)
    static let inkMuted = Color(red: 0.60, green: 0.60, blue: 0.60)

    static let success = Color(red: 0.29, green: 0.49, blue: 0.35)
    static let warning = Color(red: 0.79, green: 0.64, blue: 0.15)
    static let quoteBorder = Color(red: 0.90, green: 0.90, blue: 0.86)

    static let wash = paperSecondary
    static let line = quoteBorder.opacity(0.8)
}

extension ShapeStyle where Self == Color {
    static var brand: Color { .brand }
    static var brandLight: Color { .brandLight }
    static var accent: Color { .accent }
    static var accentSoft: Color { .accentSoft }
    static var paper: Color { .paper }
    static var paperSecondary: Color { .paperSecondary }
    static var paperTertiary: Color { .paperTertiary }
    static var card: Color { .card }
    static var ink: Color { .ink }
    static var inkSoft: Color { .inkSoft }
    static var inkMuted: Color { .inkMuted }
    static var wash: Color { .wash }
    static var line: Color { .line }
    static var success: Color { .success }
}

extension Font {
    static let appHero = Font.system(size: 34, weight: .semibold, design: .serif)
    static let appTitle = Font.system(.title3, design: .serif).weight(.semibold)
    static let appSection = Font.system(.headline, design: .rounded).weight(.semibold)
    static let appBody = Font.system(.body, design: .rounded)
    static let appMeta = Font.system(.caption, design: .rounded).weight(.medium)
    static let quoteBody = Font.system(.body, design: .serif)
}

extension Animation {
    static var smoothSpring: Animation {
        .spring(response: 0.35, dampingFraction: 0.82)
    }

    static var quickSpring: Animation {
        .spring(response: 0.22, dampingFraction: 0.78)
    }
}

extension View {
    func appContentColumn(maxWidth: CGFloat = 760) -> some View {
        frame(maxWidth: maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    func appScreenBackground() -> some View {
        background(
            LinearGradient(
                colors: [Color.paper, Color.paperSecondary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    func paperCard(cornerRadius: CGFloat = Radius.lg) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.card)
                .overlay {
                    LinearGradient(
                        colors: [Color.white.opacity(0.65), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.quoteBorder.opacity(0.8), lineWidth: StrokeWidth.hairline)
                }
        }
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
    }

    func fieldChrome(minHeight: CGFloat? = nil) -> some View {
        padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.paperSecondary)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(Color.quoteBorder.opacity(0.9), lineWidth: StrokeWidth.hairline)
            }
    }
}

struct CapsuleTag: View {
    enum Tone {
        case neutral
        case brand
        case accent
        case success
    }

    let label: String
    var tone: Tone = .neutral

    var body: some View {
        Text(label)
            .font(.appMeta)
            .foregroundStyle(foregroundColor)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(backgroundColor, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(borderColor, lineWidth: StrokeWidth.hairline)
            }
    }

    private var backgroundColor: Color {
        switch tone {
        case .neutral:
            return .paperSecondary
        case .brand:
            return .brand.opacity(0.12)
        case .accent:
            return .accentSoft
        case .success:
            return .success.opacity(0.12)
        }
    }

    private var foregroundColor: Color {
        switch tone {
        case .neutral:
            return .ink
        case .brand:
            return .brand
        case .accent:
            return .brand
        case .success:
            return .success
        }
    }

    private var borderColor: Color {
        switch tone {
        case .neutral:
            return .quoteBorder
        case .brand:
            return .brand.opacity(0.18)
        case .accent:
            return .accent.opacity(0.35)
        case .success:
            return .success.opacity(0.20)
        }
    }
}

struct SummaryPill: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))

            Text(text)
                .font(.appMeta)
        }
        .foregroundStyle(.ink)
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(Color.paperSecondary, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.quoteBorder.opacity(0.9), lineWidth: StrokeWidth.hairline)
        }
    }
}

struct SectionIntro: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?

    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.inkMuted)
            }

            Text(title)
                .font(.appTitle)
                .foregroundStyle(.ink)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct CoverArtworkView: View {
    let title: String
    let author: String

    var body: some View {
        let palette = CoverPalette.palette(for: title)

        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            .fill(
                LinearGradient(
                    colors: palette,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: StrokeWidth.hairline)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.footnote, design: .serif).weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.96))
                        .lineLimit(4)

                    Text(author)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(2)
                }
                .padding(Space.md)
            }
            .shadow(color: palette.last?.opacity(0.18) ?? Color.black.opacity(0.12), radius: 10, y: 4)
    }
}

private enum CoverPalette {
    private static let palettes: [[Color]] = [
        [.brand, .brandLight],
        [Color(red: 0.35, green: 0.29, blue: 0.52), Color(red: 0.20, green: 0.19, blue: 0.37)],
        [Color(red: 0.55, green: 0.31, blue: 0.27), Color(red: 0.31, green: 0.20, blue: 0.17)],
        [Color(red: 0.37, green: 0.48, blue: 0.34), Color(red: 0.22, green: 0.31, blue: 0.22)],
        [Color(red: 0.64, green: 0.49, blue: 0.26), Color(red: 0.32, green: 0.24, blue: 0.15)]
    ]

    static func palette(for title: String) -> [Color] {
        let seed = title.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palettes[seed % palettes.count]
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.brand, Color.brandLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.quickSpring, value: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.ink)
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(Color.paperSecondary)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(Color.quoteBorder.opacity(0.9), lineWidth: StrokeWidth.hairline)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.quickSpring, value: configuration.isPressed)
    }
}
