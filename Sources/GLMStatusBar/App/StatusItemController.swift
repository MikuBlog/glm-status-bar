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
        item.button?.action = #selector(togglePopover(_:))
        statusItem = item
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

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if let popover, popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(relativeTo: sender)
        }
    }

    private func showPopover(relativeTo sender: NSView) {
        let popover = popover ?? makePopover()
        self.popover = popover
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
