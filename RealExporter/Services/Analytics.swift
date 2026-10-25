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
        Aptabase.shared.initialize(appKey: appKey, with: options)
        isInitialized = true
    }

    private static func track(_ event: String, props: [String: Value] = [:]) {
        guard isInitialized else { return }

        var allProps = props
        allProps["distribution"] = distribution
        Aptabase.shared.trackEvent(event, with: allProps)
    }

    static func appLaunched() {
        track("app_launched")
    }

    static func exportStarted(count: Int) {
        track("export_started", props: ["count": count])
    }

    static func exportCompleted(count: Int, imageStyle: String, folderStructure: String) {
        track("export_completed", props: [
            "count": count,
            "image_style": imageStyle,
            "folder_structure": folderStructure,
        ])
    }

    static func videoStarted(count: Int) {
        track("video_started", props: ["count": count])
    }

    static func videoCompleted(count: Int, imageContent: String, resolution: String, fps: Double) {
        track("video_completed", props: [
            "count": count,
            "image_content": imageContent,
            "resolution": resolution,
            "fps": fps,
        ])
    }
}
