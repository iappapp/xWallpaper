import SwiftUI

struct CategoryTabView: View {
    let categories: [Category]
    let onSelectChange: (Set<String>) -> Void

    var body: some View {
        VStack(spacing: 0) {
            CategoryView(categories: categories, onSelectChange: onSelectChange)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
    }
}

#Preview("Category Tab") {
    CategoryTabView(
        categories: PreviewData.categories,
        onSelectChange: { _ in }
    )
    .frame(width: 380, height: 320)
}
