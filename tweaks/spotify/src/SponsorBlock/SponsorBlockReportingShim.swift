//
//  SponsorBlockReportingShim.swift
//  Albrhi for Spotify
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

import UIKit

///
/// The segment-reporting interface, left out — and why the ported files still call it.
///
/// **SwiftUI cannot be compiled against the SDK this repository pins.** `iPhoneOS16.2.sdk` carries
/// a SwiftUI `.swiftinterface` built by Swift 5.7.1, and the toolchain on this machine is 6.3.3,
/// which refuses to rebuild the module from it. That is a fact about the SDK, not about the code:
/// the four upstream files that draw the submit-and-report screens are the only SwiftUI in the
/// port, and they are the part that *contributes* segments to SponsorBlock rather than the part
/// that skips them.
///
/// So the skipping is here in full and the reporting screens are not. This shim keeps their three
/// entry points under the names the ported files call, **so those files stay byte-for-byte
/// diffable against upstream** — the same decision Albrhi NextUp made about its own copy, and the
/// reason a fix landing there can be read against ours instead of hunted for.
///
/// What a person loses: the buttons for voting a segment up or down, submitting a new one, and
/// undoing a skip. What they keep: the segments being skipped, and being told that one was.
///
enum SponsorBlockReportingUI {

    /// Upstream: a sheet of actions for the segment under the playhead. Here: nothing, because
    /// every action on it is a submission to the SponsorBlock database.
    static func presentSegmentActions(uuid: String, anchor: UIView) {
        NSLog("[AlbrhiSpotify] segment actions are not built (uuid %@)", uuid)
    }

    /// Upstream: the screen for submitting a new segment.
    static func presentSubmissionActions(currentPlayheadSec: Double, anchor: UIView) {
        NSLog("[AlbrhiSpotify] segment submission is not built")
    }

    ///
    /// Upstream: a toast with undo and vote buttons. Here: the toast alone.
    ///
    /// **The message still appears, and that is deliberate rather than incidental.** A segment
    /// skipped silently is indistinguishable from a track that jumped on its own, which is the
    /// same complaint this project already answered in the TikTok tweak — a save with no indicator
    /// reads as a button that does nothing.
    ///
    static func presentSkipFeedback(segment: SponsorBlockSegment, onUndo: @escaping () -> Void) {
        SponsorBlockToast.shared.show(
            String(format: "%@ · %ds", segment.category, Int(segment.duration)))
    }
}
