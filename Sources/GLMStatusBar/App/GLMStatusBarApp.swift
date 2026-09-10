import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: no Dock icon, no main window.
        NSApp.setActivationPolicy(.accessory)
        statusItemController = StatusItemController(model: .shared)
    }
}

@main
struct GLMStatusBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    init() {
        PanelSnapshot.maybeRunSnapshotMode()
        SingleInstanceGuard.ensureSingleInstance()
    }

    var body: some Scene {
        // The real UI lives in the NSStatusItem popover (see StatusItemController).
        Settings {
            EmptyView()
        }
    }
}
