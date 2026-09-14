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
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    Analytics.initialize()
                    Analytics.appLaunched()
                }
        }
        .defaultSize(width: 500, height: 500)
        .windowResizability(.contentSize)
        .commands {
            #if !APP_STORE
            CommandGroup(after: .appInfo) {
                AppUpdateMenu(controller: appDelegate.updates)
            }
            #endif
        }
    }
}
