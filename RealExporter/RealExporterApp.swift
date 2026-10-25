//
//  RealExporterApp.swift
//  RealExporter
//

import SwiftUI
#if !APP_STORE
import AppUpdater
#endif

@main
struct RealExporterApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #else
    init() {
        // iOS gives no reliable quit hook, so clear archives from the last run here.
        DataLoader.removeExtractedArchives()
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    Analytics.initialize()
                    Analytics.appLaunched()
                }
        }
        #if os(macOS)
        .defaultSize(width: 500, height: 500)
        .windowResizability(.contentSize)
        #endif
        #if !APP_STORE
        .commands {
            CommandGroup(after: .appInfo) {
                AppUpdateMenu(controller: appDelegate.updates)
            }
        }
        #endif
    }
}
