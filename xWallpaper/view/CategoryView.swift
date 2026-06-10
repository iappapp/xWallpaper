import SwiftUI

struct CategoryView: View {
    let categories: [Category]
    @AppStorage("selectedCategoryIds") private var selectedCategoryIdsString: String = ""
    let onSelectChange: (Set<String>) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private var selectedCategoryIds: Set<String> {
        Set(selectedCategoryIdsString.split(separator: ",").map(String.init))
    }

    private func updateSelectedIds(_ ids: Set<String>) {
        selectedCategoryIdsString = ids.sorted().joined(separator: ",")
        onSelectChange(ids)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(categories) { cat in
                    categoryCard(cat)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: .infinity)
    }

    private func categoryCard(_ category: Category) -> some View {
        let isSelected = selectedCategoryIds.contains(category.id)

        return ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.gray.opacity(0.22))

            CategoryThumbnailImageView(category: category)

            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .center,
                endPoint: .bottom
            )

            if isSelected {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.top, 6)
                            .padding(.trailing, 6)
                    }
                    Spacer()
                }
            }

            Text(category.name)
                .font(.system(size: 13, weight: .semibold))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.leading, 8)
                .padding(.bottom, 8)
        }
        .frame(height: 80)
        .clipped()  // 添加 clipped 以确保内容不会溢出边界
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.95) : Color.clear, lineWidth: 1.2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .onTapGesture {
            var newIds = selectedCategoryIds
            if newIds.contains(category.id) {
                newIds.remove(category.id)
            } else {
                newIds.insert(category.id)
            }
            updateSelectedIds(newIds)
        }
    }
}

private struct CategoryThumbnailImageView: View {
    let category: Category

    @State private var localImage: NSImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let localImage {
                Image(nsImage: localImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .task(id: category.id) {
            isLoading = true
            if let cached = CategoryThumbCache.shared.cachedThumbnailURL(for: category) {
                localImage = NSImage(contentsOf: cached)
                isLoading = false
                return
            }

            CategoryThumbCache.shared.loadThumbnail(for: category) { url in
                DispatchQueue.main.async {
                    if let url {
                        localImage = NSImage(contentsOf: url)
                    }
                    isLoading = false
                }
            }
        }
    }
}

#Preview("Category Grid") {
    CategoryView(
        categories: PreviewData.categories,
        onSelectChange: { _ in }
    )
    .frame(width: 380, height: 320)
}