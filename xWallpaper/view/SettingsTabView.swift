import SwiftUI

struct SettingsTabView: View {
    var body: some View {
        SettingsView()
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct SettingsTabView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsTabView()
            .frame(width: 380, height: 320)
    }
}
