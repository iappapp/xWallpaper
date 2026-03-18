import SwiftUI

struct HeaderBarView: View {
    @Binding var currentPage: MainMenuPage
    let headerHeight: CGFloat

    var body: some View {
        HStack(alignment: .center) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)

            Text("Unsplash Wallpapers")
                .font(.system(size: 14, weight: .semibold))
                .frame(maxHeight: .infinity, alignment: .center)
            Spacer()
            HStack(spacing: 5) {
                ForEach(MainMenuPage.allCases, id: \.self) { page in
                    Button {
                        currentPage = page
                    } label: {
                        Image(systemName: page.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(currentPage == page ? .white : .secondary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(currentPage == page ? Color.black : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .padding(.horizontal, 16)
        .frame(height: headerHeight)
    }
}

#Preview("Header") {
    HeaderPreviewHost()
        .frame(width: 380, height: 50)
}

