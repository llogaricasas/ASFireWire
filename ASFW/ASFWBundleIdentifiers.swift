//
//  ASFWBundleIdentifiers.swift
//  ASFW
//
//  Single source of truth for the driver extension's bundle identifier on the
//  app side. The dext's PRODUCT_BUNDLE_IDENTIFIER is
//  "$(ASFW_BUNDLE_PREFIX).ASFW.ASFWDriver" (see project.yml), i.e. the app's
//  own bundle identifier plus ".ASFWDriver", so derive it at runtime instead of
//  hard-coding a prefix that differs between forks / signing teams.
//

import Foundation

enum ASFWBundleIdentifiers {
    /// The host app's bundle identifier ("<prefix>.ASFW").
    static let app: String = Bundle.main.bundleIdentifier ?? "net.mrmidi.ASFW"

    /// The DriverKit extension's bundle identifier ("<prefix>.ASFW.ASFWDriver").
    /// Also the dext's IOUserServerName (Info.plist: $(PRODUCT_BUNDLE_IDENTIFIER)).
    static let driverExtension: String = app + ".ASFWDriver"
}
