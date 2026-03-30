import SwiftUI

struct SettingsView: View {
  @StateObject private var settings = AppSettings.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Toggle("Show in Dock", isOn: $settings.showInDock)
        .toggleStyle(.switch)
      Text("When enabled, Bandwidther will show an icon in the Dock.")
        .font(.caption)
        .foregroundColor(.secondary)

      Divider()

      Toggle("Show in App Switcher", isOn: $settings.showInAppSwitcher)
        .toggleStyle(.switch)
      Text("When enabled, Bandwidther will appear in the Cmd-Tab app switcher.")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding()
    .frame(width: 360)
  }
}

#Preview {
  SettingsView()
}
