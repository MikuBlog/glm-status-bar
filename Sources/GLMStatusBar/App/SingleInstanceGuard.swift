import AppKit
import Darwin

/// Ensures only one instance of the app runs, regardless of how it was
/// launched (double-click, `open`, `swift run`, or direct binary execution).
/// Uses an advisory `flock` on a per-user lock file; the lock is released
/// automatically by the kernel when the owning process dies.
enum SingleInstanceGuard {
    private static var lockFD: Int32 = -1

    static func ensureSingleInstance() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = caches.appendingPathComponent("cn.bigmodel.glm-status-bar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("singleton.lock").path

        let fd = open(path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return } // fail-open: prefer a duplicate over blocking launch
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            activateExistingInstance()
            exit(0)
        }
        lockFD = fd // intentionally never closed; released on process exit
    }

    private static func activateExistingInstance() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        where app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }
}
