//
//  Tweak.x.swift
//  Albrhi for Spotify
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

import Orion
import Foundation

///
/// Albrhi for Spotify — advertising refused, and nothing else.
///
/// **The ad blocking is EeveeSpotify's**, carried over under GPLv3: the same licence this
/// repository ships under, which is what makes carrying code over lawful here rather than merely
/// possible. See CHANGELOG.md and the notice inside the package.
///
/// **The Premium unlock is deliberately not here.** That tweak's own package description offers a
/// paid subscription for free; this project refused the same shape of thing once already, by name,
/// when Locket's `Check0verPlus` was reviewed and left alone. Nothing here asks what the account
/// is, reports it as anything, or changes what it may do — which is also **why these three files
/// could be taken and the rest could not**: upstream, the ad blocking never consulted the
/// subscription state either. That was measured before a line was copied.
///
/// The gate is this tweak's own master switch, not Albrhi Panel's per-app switch. The panel draws
/// that switch on an app's own row, and this tweak is collapsed into one grouped row instead — so
/// asking it means asking a question nobody can answer, which is exactly how Albrhi Watch shipped
/// a build where nothing installed at all.
///
struct AlbrhiSpotify: Tweak {
    init() {
        NSLog("[AlbrhiSpotify] %@ loaded", SCIVersionString)

        guard AlbrhiPrefs.bool(AlbrhiPrefs.enabled, fallback: false) else {
            NSLog("[AlbrhiSpotify] master switch is off (read via %@)", AlbrhiPrefs.source)
            return
        }

        //
        // **Gated at activation, not inside each hook.** A group that is never activated is a hook
        // that was never placed, which is the only stop that cannot leave half of an interception
        // in force — the same reason every other tweak here calls `%init` behind its gate rather
        // than checking a preference inside `%orig`.
        //
        if AlbrhiPrefs.on(AlbrhiPrefs.blockAds) {
            activateEeveeAdBlockerExtended()
            AdBlockerGroup().activate()
            NSLog("[AlbrhiSpotify] ad blocking active")
        }

        if AlbrhiPrefs.on(AlbrhiPrefs.blockUpsell) {
            activateUpsellPopupBlocker()
            NSLog("[AlbrhiSpotify] upsell popups blocked")
        }

        //
        // **Two switches for one feature is one switch too many, so Albrhi's is the one that
        // decides.**
        //
        // SponsorBlock keeps its own `enabled` flag inside its options, defaulting off, because
        // upstream drives it from a settings screen of its own that this port does not carry.
        // Left alone, the group would activate and skip nothing — a switch that moves and changes
        // nothing, which is the failure this project keeps writing rules about. So the option is
        // written from Albrhi's switch rather than read beside it.
        //
        if AlbrhiPrefs.on(AlbrhiPrefs.sponsorBlock) {
            var options = UserDefaults.sponsorBlockOptions
            options.enabled = true
            UserDefaults.sponsorBlockOptions = options

            activateSponsorBlock()
            NSLog("[AlbrhiSpotify] SponsorBlock active")
        }

    }
}
