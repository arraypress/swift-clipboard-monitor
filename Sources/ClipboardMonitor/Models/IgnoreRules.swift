//
//  IgnoreRules.swift
//  ClipboardMonitor
//
//  Created by David Sherlock on 10/7/25.
//

import Foundation

/// Configuration for which apps/data to ignore
public struct IgnoreRules: Sendable {
    
    /// Bundle IDs of apps to ignore (e.g., password managers)
    public var blockedAppBundleIds: Set<String> = []
    
    /// Ignore transient/concealed clipboard data (recommended for security)
    public var ignoreTransientData: Bool = true
    
    /// Ignore clipboard changes from the same app making the request
    public var ignoreSelfPastes: Bool = false
    
    /// Default rules with common password managers blocked
    public static var passwordManagersSafe: Self {
        var rules = Self()
        rules.blockedAppBundleIds = [
            "com.agilebits.onepassword7",           // 1Password 7
            "com.1password.1password",              // 1Password 8
            "com.lastpass.LastPass",                // LastPass
            "com.dashlane.dashlanephonefinal",      // Dashlane
            "com.bitwarden.desktop",                // Bitwarden
            "com.keepersecurity.Keeper",            // Keeper
            "com.todesktop.230313mzl4w4u92",        // Bitwarden (alternate)
            "com.c3.macpass",                       // MacPass
            "com.keepassx.keepassxc",               // KeePassXC
            "com.enpass.Enpass-Desktop",            // Enpass
            "com.nordpass.desktop",                 // NordPass
            "com.roboform.roboform-mac",            // RoboForm
            "com.logmeininc.lastpass.safari",       // LastPass Safari extension
            "com.apple.password-manager",           // Apple Passwords (if it has a separate ID)
        ]
        rules.ignoreTransientData = true
        return rules
    }
    
    public init() {}
    
}
