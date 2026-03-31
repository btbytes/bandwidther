import AppKit
import Foundation
import ServiceManagement

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

  @Published var launchAtLogin: Bool {
    didSet {
      UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
      updateLoginItem()
    }
  }

  private init() {
    self.showInAppSwitcher = UserDefaults.standard.object(forKey: "showInAppSwitcher") as? Bool ?? true
    self.showInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? true
    self.launchAtLogin = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? false
  }

  private func applyActivationPolicy() {
    if showInDock || showInAppSwitcher {
      NSApp.setActivationPolicy(.regular)
    } else {
      NSApp.setActivationPolicy(.accessory)
    }
  }

  private func updateLoginItem() {
    do {
      if launchAtLogin {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      print("Failed to update login item: \(error)")
    }
  }
}
