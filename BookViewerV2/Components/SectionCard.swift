import SwiftUI

struct SectionCard<Content: View>: View {
    @ViewBuilder private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .paperCard()
    }
}
