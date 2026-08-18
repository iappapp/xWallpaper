import SwiftUI

struct CategoryTabView: View {
    let categories: [Category]
    let onSelectChange: (Set<String>) -> Void
    let onCategoriesChange: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            CategoryView(
                categories: categories,
                onSelectChange: onSelectChange,
                onAddCategory: { name, query in
                    _ = CategoryManager.shared.addCategory(name: name, query: query)
                    onCategoriesChange()
                },
                onDeleteCategory: { id in
                    CategoryManager.shared.removeCategory(id: id)
                    onCategoriesChange()
                }
            )
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
    }
}

#Preview("Category Tab") {
    CategoryTabView(
        categories: PreviewData.categories,
        onSelectChange: { _ in },
        onCategoriesChange: {}
    )
    .frame(width: 380, height: 320)
}
