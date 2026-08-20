//
//  Prefs.swift
//  Albrhi for Spotify
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

import Foundation
import MachO   // _dyld_image_count / _dyld_get_image_name: where this dylib was loaded from

///
/// Every switch this tweak has, read the way a sandboxed app has to read them.
///
/// **The preferences daemon is not enough, and Albrhi Watch is what proved it.** The panel writes
/// this domain from inside Settings; Spotify is a sandboxed App Store app, and a sandboxed process
/// asking cfprefsd for another application's domain is answered with an absence rather than an
/// error. A tweak that reads that absence as "off" is a tweak whose switches do nothing, and one
/// that reads it as "on" is a tweak that cannot be switched off.
///
/// So the daemon is asked first — where it works it is cheaper, and it sees a value written but not
/// yet flushed — and then the plist is read directly, which a jailbroken device permits. The
/// jailbreak prefix is found from **this dylib's own loaded path**, which is the only thing that is
/// right on roothide, where the root is a differently-named random directory on every device.
///
enum AlbrhiPrefs {
    static let domain = "com.albrhi.spotify"

    /// The master. Off until somebody turns it on: an install is not a decision to change how
    /// another company's app behaves, which is the reading `com.albrhi` settled on.
    static let enabled = "spotify_enabled"

    /// Audio and display advertising, refused at the services that fetch it.
    static let blockAds = "spotify_block_ads"

    /// The "go Premium" popups. Separate from the ads because it is a different annoyance, and a
    /// person who wants one may not want the other.
    static let blockUpsell = "spotify_block_upsell"

    /// Where the last answer came from, so the settings page can say it rather than imply it.
    private(set) static var source = "nothing has been read yet"

    private static var jailbreakPrefix: String {
        for index in 0..<_dyld_image_count() {
            guard let raw = _dyld_get_image_name(index) else { continue }
            let path = String(cString: raw)
            guard path.hasSuffix("AlbrhiSpotify.dylib") else { continue }

            // <prefix>/Library/MobileSubstrate/DynamicLibraries/AlbrhiSpotify.dylib
            var url = URL(fileURLWithPath: path)
            for _ in 0..<4 { url = url.deletingLastPathComponent() }
            return url.path
        }
        return "/"
    }

    private static func rawValue(_ key: String) -> Any? {
        CFPreferencesAppSynchronize(domain as CFString)

        if let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString) {
            source = "preferences daemon"
            return value
        }

        let leaf = "var/mobile/Library/Preferences/\(domain).plist"
        var candidates = ["/" + leaf]

        let prefix = jailbreakPrefix
        if prefix.count > 1 { candidates.append((prefix as NSString).appendingPathComponent(leaf)) }

        for path in candidates {
            guard let plist = NSDictionary(contentsOfFile: path),
                  let stored = plist[key] else { continue }
            source = path
            return stored
        }

        // Its own answer rather than folded into the fallback: "never switched on" and "switched
        // on and unreadable" are the two things this whole lookup exists to separate.
        source = "nothing written (looked in \(candidates.count) place(s))"
        return nil
    }

    static func bool(_ key: String, fallback: Bool) -> Bool {
        (rawValue(key) as? NSNumber)?.boolValue ?? fallback
    }

    /// The master, then the feature's own. The features default *on* so one switch gives a working
    /// tweak; the master defaults off.
    static func on(_ key: String) -> Bool {
        guard bool(enabled, fallback: false) else { return false }
        return bool(key, fallback: true)
    }
}
