import SwiftUI

struct SettingsTabView: View {
    var body: some View {
        SettingsView()
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

#Preview("Settings Tab") {
    SettingsTabView()
        .frame(width: 380, height: 320)
}
