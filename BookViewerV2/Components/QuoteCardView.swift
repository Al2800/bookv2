import SwiftUI

struct QuoteCardView: View {
    let text: String
    let note: String?
    let footer: String

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("“")
                    .font(.system(size: 42, weight: .medium, design: .serif))
                    .foregroundStyle(.inkMuted)

                Text(text)
                    .font(.body)
                    .foregroundStyle(.ink)
                    .lineSpacing(4)

                if let note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.inkSoft)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.sm)
                        .background(Color.wash.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Text(footer)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.inkMuted)
            }
        }
    }
}
