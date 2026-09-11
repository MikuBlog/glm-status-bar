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
final class StatusItemController: NSObject, NSMenuDelegate, NSPopoverDelegate {
    private let model: AppModel
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellable: AnyCancellable?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastBadgeKey: String?

    init(model: AppModel) {
        self.model = model
        super.init()
        setupStatusItem()
        renderBadge(force: true)
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
        // Only re-render when the visible content changes (state, text, or
        // color level) — avoids needless SwiftUI/ImageRenderer work on every
        // 3-second poll.
        let key = "\(model.stateKind)-\(model.menuBarText)-\(QuotaFormat.level(for: model.menuBarPercentage))"
        guard key != lastBadgeKey else { return }
        lastBadgeKey = key
        guard let button = statusItem?.button else { return }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let renderer = ImageRenderer(content: MenuBarBadge(model: model))
        renderer.scale = scale
        guard let image = renderer.nsImage else { return }
        image.isTemplate = false // keep the gradient colors
        button.image = image
        button.imagePosition = .imageOnly
    }

    private func renderBadge(force: Bool) {
        if force { lastBadgeKey = nil }
        renderBadge()
    }

    // MARK: - Popover

    /// Left-click toggles the panel; right-click opens a context menu.
    @objc private func handleStatusClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu(for: sender)
            return
        }
        if let popover, popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(relativeTo: sender)
        }
    }

    // MARK: - Right-click context menu

    private func showContextMenu(for button: NSStatusBarButton) {
        closePopoverIfNeeded()

        let menu = NSMenu()
        menu.delegate = self

        let refresh = NSMenuItem(title: "立即刷新", action: #selector(refreshAction), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let web = NSMenuItem(title: "打开网页版", action: #selector(openWebAction), keyEquivalent: "")
        web.target = self
        menu.addItem(web)

        menu.addItem(.separator())

        for tool in CodingTool.all {
            let item = NSMenuItem(
                title: tool.menuItemTitle,
                action: #selector(openToolAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = tool
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let logout = NSMenuItem(title: "退出登录 / 切换账号", action: #selector(logoutAction), keyEquivalent: "")
        logout.target = self
        menu.addItem(logout)

        let quit = NSMenuItem(title: "退出 GLM StatusBar", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        // Present the menu anchored to the status item.
        statusItem?.menu = menu
        button.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        // Restore normal button behavior after the menu dismisses.
        statusItem?.menu = nil
    }

    @objc private func refreshAction() {
        model.refreshNow()
    }

    @objc private func openWebAction() {
        NSWorkspace.shared.open(AppModel.overviewURL)
    }

    @objc private func openToolAction(_ sender: NSMenuItem) {
        guard let tool = sender.representedObject as? CodingTool else { return }
        tool.openOrVisitWebsite()
    }

    @objc private func logoutAction() {
        model.logout()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    private func showPopover(relativeTo sender: NSView) {
        closePopoverIfNeeded()
        // Fresh popover per open: releasing the hosting controller when closed
        // tears down the SwiftUI view tree, stopping all animations instead of
        // letting repeatForever effects burn CPU while hidden.
        let popover = makePopover()
        self.popover = popover
        popover.delegate = self
        if globalMonitor == nil { startDismissMonitoring() }
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makePopover() -> NSPopover {
        // Scroll only kicks in when content exceeds 3/4 of the visible screen.
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 900
        let maxContentHeight = max(360, screenHeight * 0.75 - 110)
        let hosting = NSHostingController(
            rootView: PanelView(maxContentHeight: maxContentHeight)
                .environmentObject(model)
                .frame(width: 440)
        )
        hosting.sizingOptions = .preferredContentSize

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .vibrantDark)
        popover.contentViewController = hosting
        return popover
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        popover?.contentViewController = nil
        popover = nil
    }
}
