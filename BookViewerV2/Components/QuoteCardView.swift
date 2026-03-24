import SwiftUI

struct QuoteCardView: View {
    let text: String
    let note: String?
    let footer: String

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: Space.md) {
                HStack(alignment: .top, spacing: Space.sm) {
                    Text("“")
                        .font(.system(size: 30, weight: .medium, design: .serif))
                        .foregroundStyle(.inkMuted)

                    Text(text)
                        .font(.body)
                        .foregroundStyle(.ink)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let note, !note.isEmpty {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.inkSoft)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.sm)
                        .background(Color.wash.opacity(0.82), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                }

                Text(footer)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.inkMuted)
            }
        }
    }
}
