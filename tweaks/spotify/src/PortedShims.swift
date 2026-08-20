//
//  PortedShims.swift
//  Albrhi for Spotify
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

import Foundation

///
/// The handful of names the ported files expect to find, kept here rather than edited into them.
///
/// **The copies stay diffable against upstream on purpose** — the same decision Albrhi NextUp made
/// about its own port, and the reason a later fix from that project can be read against ours
/// instead of hunted for. So where a ported file says `EeveeSpotify.version` or
/// `UserDefaults.cleanShareLinks`, the name is provided here rather than renamed there.
///
///
/// Upstream's debug logger, deliberately not a file.
///
/// **It wrote every message to a file in the app's temporary directory, forever.** Albrhi NextUp's
/// own port carried the same shape and this project switched it off for the same reason: a log that
/// records what somebody is listening to, growing without limit, from a tweak whose neighbours here
/// exist to stop watching being reported at all. `NSLog` is bounded by the system and reaches the
/// console when somebody is actually looking.
///
func writeDebugLog(_ message: String) {
    NSLog("[AlbrhiSpotify] %@", message)
}

enum EeveeSpotify {
    /// Sent to SponsorBlock's API as this client's version. **Ours, not theirs**: it identifies who
    /// is asking, and answering with a version this build is not would misreport a real service.
    static let version = SCIVersionString.replacingOccurrences(of: "v", with: "")
}

extension UserDefaults {
    /// Share links without the tracking parameters Spotify appends. Read through Albrhi's own gate
    /// rather than `standard`, which inside Spotify means Spotify's own preferences.
    static var cleanShareLinks: Bool {
        AlbrhiPrefs.on(AlbrhiPrefs.cleanLinks)
    }
}
