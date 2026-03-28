import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  var statusItem: NSStatusItem!
  var popover: NSPopover!

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    if let button = statusItem.button {
      button.image = NSImage(
        systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: "Bandwidther")
      button.action = #selector(togglePopover)
      button.target = self
    }

    let popover = NSPopover()
    popover.contentSize = NSSize(width: 900, height: 750)
    popover.behavior = .transient
    popover.contentViewController = NSHostingController(rootView: ContentView())
    self.popover = popover

    NSApp.setActivationPolicy(.accessory)
  }

  @objc func togglePopover() {
    guard let button = statusItem.button else { return }
    if popover.isShown {
      popover.performClose(nil)
    } else {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      NSApp.activate(ignoringOtherApps: true)
      popover.contentViewController?.view.window?.makeKey()
    }
  }
}
