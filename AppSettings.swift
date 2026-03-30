import AppKit
import Foundation

@MainActor
class AppSettings: ObservableObject {
  static let shared = AppSettings()

  @Published var showInAppSwitcher: Bool {
    didSet {
      UserDefaults.standard.set(showInAppSwitcher, forKey: "showInAppSwitcher")
      applyActivationPolicy()
    }
  }

  @Published var showInDock: Bool {
    didSet {
      UserDefaults.standard.set(showInDock, forKey: "showInDock")
      applyActivationPolicy()
    }
  }

  private init() {
    self.showInAppSwitcher = UserDefaults.standard.object(forKey: "showInAppSwitcher") as? Bool ?? true
    self.showInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? true
  }

  private func applyActivationPolicy() {
    if showInDock || showInAppSwitcher {
      NSApp.setActivationPolicy(.regular)
    } else {
      NSApp.setActivationPolicy(.accessory)
    }
  }
}
