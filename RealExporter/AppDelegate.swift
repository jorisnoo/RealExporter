import AppKit
#if !APP_STORE
import AppUpdater
#endif

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Clear archives left behind by a crash or force quit.
        DataLoader.removeExtractedArchives()
        #if !APP_STORE
        updates.start()
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        DataLoader.removeExtractedArchives()
    }

    #if !APP_STORE
    let updates = AppUpdateController(owner: "jorisnoo", repo: "RealExporter")

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        updates.applicationShouldTerminate(sender)
    }
    #endif
}
