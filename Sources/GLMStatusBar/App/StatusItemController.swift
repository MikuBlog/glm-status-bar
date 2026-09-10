import AppKit
import Combine
import SwiftUI

/// Owns the native status item and the dropdown popover.
///
/// `MenuBarExtra` renders its label as a monochrome template image, which
/// strips our gradient colors — so we host a full-color badge through
/// `NSStatusItem` + `ImageRenderer` instead, and present the panel in an
/// `NSPopover`.
@MainActor
final class StatusItemController: NSObject {
    private let model: AppModel
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellable: AnyCancellable?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(model: AppModel) {
        self.model = model
        super.init()
        setupStatusItem()
        renderBadge()
        cancellable = model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.renderBadge()
            }
        }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(handleStatusClick(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    /// Click anywhere outside the panel (other apps, desktop, menu bar)
    /// dismisses it. `.transient` covers most cases; these monitors make it
    /// airtight across macOS event-delivery quirks.
    private func startDismissMonitoring() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePopoverIfNeeded()
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                guard let self,
                      let popover = self.popover, popover.isShown else { return }
                // Let clicks inside the popover panel pass through untouched;
                // clicks on the status icon are handled by its own action.
                if event.window === popover.contentViewController?.view.window { return }
                if let button = self.statusItem?.button,
                   event.window === button.window,
                   button.frame.contains(event.locationInWindow) { return }
                self.closePopoverIfNeeded()
            }
            return event
        }
    }

    private func closePopoverIfNeeded() {
        guard let popover, popover.isShown else { return }
        popover.performClose(nil)
    }

    private func renderBadge() {
        guard let button = statusItem?.button else { return }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let renderer = ImageRenderer(content: MenuBarBadge(model: model))
        renderer.scale = scale
        guard let image = renderer.nsImage else { return }
        image.isTemplate = false // keep the gradient colors
        button.image = image
        button.imagePosition = .imageOnly
    }

    // MARK: - Popover

    /// Left-click toggles the panel; right-click quits the app.
    @objc private func handleStatusClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            NSApp.terminate(nil)
            return
        }
        if let popover, popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(relativeTo: sender)
        }
    }

    private func showPopover(relativeTo sender: NSView) {
        let popover = popover ?? makePopover()
        self.popover = popover
        if globalMonitor == nil { startDismissMonitoring() }
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makePopover() -> NSPopover {
        let hosting = NSHostingController(
            rootView: PanelView()
                .environmentObject(model)
                .frame(width: 360)
        )
        hosting.sizingOptions = .preferredContentSize

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .vibrantDark)
        popover.contentViewController = hosting
        return popover
    }
}
