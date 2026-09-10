import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: no Dock icon, no main window.
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct GLMStatusBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    init() {
        PanelSnapshot.maybeRunSnapshotMode()
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environmentObject(model)
                .frame(width: 330)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.needle")
                Text(model.menuBarText)
                    .monospacedDigit()
            }
            .foregroundStyle(model.menuBarForeground)
        }
        .menuBarExtraStyle(.window)
    }
}
