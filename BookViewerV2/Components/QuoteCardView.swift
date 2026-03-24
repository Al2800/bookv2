import SwiftUI

struct QuoteCardView: View {
    let text: String
    let note: String?
    let footer: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .top, spacing: Space.sm) {
                Text("“")
                    .font(.system(size: 34, weight: .medium, design: .serif))
                    .foregroundStyle(.accent)

                Text(text)
                    .font(.quoteBody)
                    .foregroundStyle(.ink)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let note, !note.isEmpty {
                HStack(alignment: .top, spacing: Space.sm) {
                    Image(systemName: "note.text")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.brand)

                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .background(Color.paperSecondary, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }

            Text(footer)
                .font(.appMeta)
                .foregroundStyle(.inkMuted)
        }
        .padding(Space.lg)
        .paperCard()
    }
}
