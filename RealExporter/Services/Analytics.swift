//
//  Analytics.swift
//  RealExporter
//

import Aptabase
import Foundation

enum Analytics {
    private static var isInitialized = false

    private static var distribution: String {
        #if APP_STORE
        "app_store"
        #else
        "direct"
        #endif
    }

    static func initialize() {
        guard let appKey = Bundle.main.infoDictionary?["AptabaseAppKey"] as? String,
              !appKey.isEmpty
        else { return }

        let host = Bundle.main.infoDictionary?["AptabaseHost"] as? String
        let options = InitOptions(host: host)
        Aptabase.shared.initialize(appKey: appKey, options: options)
        isInitialized = true
    }

    private static func track(_ event: String, props: [String: EventValue] = [:]) {
        guard isInitialized else { return }

        var allProps = props
        allProps["distribution"] = .string(distribution)
        Aptabase.shared.trackEvent(event, with: allProps)
    }

    static func appLaunched() {
        track("app_launched")
    }

    static func exportStarted(count: Int) {
        track("export_started", props: ["count": .integer(count)])
    }

    static func exportCompleted(count: Int, imageStyle: String, folderStructure: String) {
        track("export_completed", props: [
            "count": .integer(count),
            "image_style": .string(imageStyle),
            "folder_structure": .string(folderStructure),
        ])
    }
}
