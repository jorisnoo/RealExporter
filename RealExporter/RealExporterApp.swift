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
                UpdateMenuCommands(updater: appDelegate.updater, checkForUpdates: appDelegate.checkForUpdates)
            }
            #endif
        }
    }
}

#if !APP_STORE
struct UpdateMenuCommands: View {
    @ObservedObject var updater: AppUpdater
    var checkForUpdates: () -> Void

    var body: some View {
        Button("Check for Updates...") {
            checkForUpdates()
        }

        if case .downloaded(_, _, let bundle) = updater.state {
            Button("Restart and Update") {
                Task {
                    try await updater.installThrowing(bundle)
                }
            }
        }
    }
}
#endif
