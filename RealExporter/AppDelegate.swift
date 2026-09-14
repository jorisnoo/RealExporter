import AppKit
#if !APP_STORE
import AppUpdater
#endif

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    #if !APP_STORE
    let updates = AppUpdateController(owner: "jorisnoo", repo: "RealExporter")

    func applicationDidFinishLaunching(_ notification: Notification) {
        updates.start()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        updates.applicationShouldTerminate(sender)
    }
    #endif
}
