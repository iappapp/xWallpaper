import SwiftUI

struct CategoryView: View {
    let categories: [Category]
    @AppStorage("selectedCategoryIds") private var selectedCategoryIdsString: String = ""
    let onSelectChange: (Set<String>) -> Void
    let onAddCategory: (String, String) -> Void
    let onDeleteCategory: (String) -> Void

    @State private var showingAddDialog = false
    @State private var newName = ""
    @State private var newQuery = ""
    @State private var pendingDeleteId: String?

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
    }

    private var gridSpacing: CGFloat {
        10
    }

    private var horizontalPadding: CGFloat {
        10
    }

    private var selectedCategoryIds: Set<String> {
        Set(selectedCategoryIdsString.split(separator: ",").map(String.init))
    }

    private func updateSelectedIds(_ ids: Set<String>) {
        selectedCategoryIdsString = ids.sorted().joined(separator: ",")
        onSelectChange(ids)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: gridSpacing) {
                ForEach(categories) { cat in
                    categoryCard(cat)
                }
                addCard
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: .infinity)
        .alert("New Category", isPresented: $showingAddDialog) {
            TextField("Name", text: $newName)
            TextField("Unsplash search query", text: $newQuery)
            Button("Add") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                let query = newQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, !query.isEmpty else { return }
                onAddCategory(name, query)
                newName = ""
                newQuery = ""
            }
            Button("Cancel", role: .cancel) {
                newName = ""
                newQuery = ""
            }
        } message: {
            Text("Enter a display name and an Unsplash search query for the thumbnail and wallpapers.")
        }
        .alert(
            pendingDeleteName.isEmpty ? "Delete category?" : "Delete \(pendingDeleteName)?",
            isPresented: Binding(
                get: { pendingDeleteId != nil },
                set: { if !$0 { pendingDeleteId = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeleteId {
                    onDeleteCategory(id)
                }
                pendingDeleteId = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteId = nil
            }
        } message: {
            Text("This category will be removed. Wallpapers already downloaded are kept.")
        }
    }

    private var pendingDeleteName: String {
        guard let id = pendingDeleteId else { return "" }
        return categories.first { $0.id == id }?.name ?? ""
    }

    private var addCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundColor(Color.gray.opacity(0.5))

            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 80, maxHeight: 80)
        .padding(.horizontal, 4)
        .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .onTapGesture {
            showingAddDialog = true
        }
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

            // Top-right delete button (always visible)
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)
                        .padding(.top, 6)
                        .padding(.trailing, 6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            pendingDeleteId = category.id
                        }
                }
                Spacer()
            }

            // Bottom-right selection checkmark
            if isSelected {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.bottom, 6)
                            .padding(.trailing, 6)
                    }
                }
            }

            Text(category.name)
                .font(.system(size: 13, weight: .semibold))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.leading, 8)
                .padding(.bottom, 8)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 80, maxHeight: 80)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .clipped()
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.95) : Color.clear, lineWidth: 1.2)
        )
        .padding(.horizontal, 4)
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
                    .scaledToFill()
                    .clipped()
            } else if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .frame(minWidth: 110, maxWidth: 120, minHeight: 80, maxHeight: 80)
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
    CategoryPreviewHost()
        .frame(width: 380, height: 320)
}
