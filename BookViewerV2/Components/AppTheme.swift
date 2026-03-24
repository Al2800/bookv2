import SwiftUI

enum Space {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
}

enum Radius {
    static let sm: CGFloat = 14
    static let md: CGFloat = 18
    static let lg: CGFloat = 24
}

extension Color {
    static let paper = Color(red: 0.97, green: 0.95, blue: 0.92)
    static let wash = Color(red: 0.93, green: 0.90, blue: 0.85)
    static let card = Color(red: 1.0, green: 0.99, blue: 0.98)
    static let ink = Color(red: 0.16, green: 0.17, blue: 0.20)
    static let inkSoft = Color(red: 0.31, green: 0.33, blue: 0.37)
    static let inkMuted = Color(red: 0.47, green: 0.49, blue: 0.52)
    static let line = Color.white.opacity(0.72)
}

extension ShapeStyle where Self == Color {
    static var paper: Color { Color.paper }
    static var wash: Color { Color.wash }
    static var card: Color { Color.card }
    static var ink: Color { Color.ink }
    static var inkSoft: Color { Color.inkSoft }
    static var inkMuted: Color { Color.inkMuted }
    static var line: Color { Color.line }
}

extension View {
    func appContentColumn() -> some View {
        frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct CapsuleTag: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.wash, in: Capsule())
    }
}
