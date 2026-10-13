//
//  ASFWBundleIdentifiers.swift
//  ASFW
//
//  Single source of truth for the driver extension's bundle identifier on the
//  app side. Forks build under their own App IDs (project.yml:
//  ASFW_BUNDLE_PREFIX), so nothing here is hard-coded: the dext ID is read from
//  the extension embedded in this very app bundle
//  (Contents/Library/SystemExtensions/<id>.dext/Info.plist), which is also what
//  OSSystemExtensionRequest will activate.
//

import Foundation

nonisolated enum ASFWBundleIdentifiers {
    /// The host app's bundle identifier.
    static let app: String = Bundle.main.bundleIdentifier ?? "net.asfw.app"

    /// The DriverKit extension's bundle identifier — also its IOUserServerName
    /// (Info.plist: $(PRODUCT_BUNDLE_IDENTIFIER)).
    static let driverExtension: String = embeddedDriverExtensionIdentifier() ?? "net.asfw.driver"

    private static func embeddedDriverExtensionIdentifier() -> String? {
        let dir = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/SystemExtensions", isDirectory: true)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return nil }
        for url in entries where url.pathExtension == "dext" {
            if let id = Bundle(url: url)?.bundleIdentifier, !id.isEmpty { return id }
        }
        return nil
    }
}
