#import "../../YouTubeHeaders.h"
#import "../../SCILog.h"
#import "../../Prefs.h"
#import "../../Diagnostics/SCIYTDiagnostics.h"

///
/// Ads, removed at three different points, because they arrive by three different
/// routes and stopping one does nothing about the others.
///
///   1. the request   — the client stops telling the server it wants ads
///   2. the feed      — promoted sections are dropped by the server's own identifier
///   3. the player    — pre-roll, mid-roll and stream-stitched ads are refused
///
/// Not one of these hooks touches a view. That is the whole reason to do it this way:
/// of the two tweaks measured against this exact binary, the one hooking view classes
/// had nineteen targets that no longer exist, and the one hooking the model layer had
/// none. A feed renderer's identifier comes from Google's servers, so it survives every
/// rebuild of the app.
///

// MARK: - 1. Never ask for ads

%hook YTAdsInnerTubeContextDecorator

- (void)decorateContext:(id)context {
    if (!SCIPrefEnabled(SCIPrefHideAds)) {
        %orig;
        return;
    }

    // Deliberately not calling through. This method is what attaches ad capabilities
    // and targeting to the request, so skipping it means the response comes back
    // without ads in it -- cheaper and quieter than receiving them and hiding them.
}

%end

%hook YTAccountScopedAdsInnerTubeContextDecorator

- (void)decorateContext:(id)context {
    if (!SCIPrefEnabled(SCIPrefHideAds)) {
        %orig;
        return;
    }
}

%end

%hook YTAdShieldUtils

// The fingerprint YouTube collects to detect ad blocking. Emptied rather than left
// alone: a client that reports no ads shown *and* a full signal set is a more
// interesting client than one that reports nothing.
+ (NSDictionary *)spamSignalsDictionary {
    if (!SCIPrefEnabled(SCIPrefHideAds)) {
        return %orig;
    }
    return @{};
}

+ (NSDictionary *)spamSignalsDictionaryWithoutIDFA {
    if (!SCIPrefEnabled(SCIPrefHideAds)) {
        return %orig;
    }
    return @{};
}

%end


// MARK: - 2. Drop promoted sections from the feed

///
/// The identifiers of promoted layouts, as the server itself labels them.
///
/// This is the durable part of ad hiding and the reason it is done by string. These
/// names travel down from Google inside the renderer, so they do not change when the
/// app is rebuilt, when a class is renamed, or when a view is rewritten in Swift --
/// which is exactly how the view-hooking approach ends up with dead features.
///
/// Grouped by what each one actually is, because a bare list invites someone to
/// "clean it up" later without knowing what they are deleting.
///
static NSArray<NSString *> *SCIPromotedIdentifiers(void) {
    static NSArray *identifiers = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        identifiers = @[
            // Outright ad slots.
            @"brand_promo",
            @"feed_ad_metadata",
            @"statement_banner",
            @"text_search_ad",

            // Shopping and product placement.
            @"product_carousel",
            @"product_item",
            @"product_engagement_panel",
            @"shopping_carousel",
            @"shopping_item_card_list",

            // The generic layouts promoted content is delivered in. These carry no
            // "ad" in the name and are the ones a hand-written list always misses.
            @"carousel_footered_layout",
            @"carousel_headered_layout",
            @"full_width_portrait_image_layout",
            @"full_width_square_image_layout",
            @"square_image_layout",
            @"landscape_image_wide_button_layout",
            @"text_image_button_layout",
            @"video_display_full_layout",
            @"video_display_full_buttoned_layout",

            // Community posts promoted into the feed.
            @"post_shelf",

        ];
    });
    return identifiers;
}

/// Whether a section renderer is promoted content.
///
/// Read from -description rather than by reaching into the protobuf: every YTI* class
/// is a GPBMessage, whose description prints the whole message tree including the
/// element identifier. That needs no field name to be known, and a field name is
/// precisely the kind of thing that changes between builds.
static BOOL SCISectionIsPromoted(id section) {
    if (!section) return NO;

    NSString *text = nil;

    @try {
        text = [section description];
    } @catch (NSException *exception) {
        // A section that cannot describe itself is left alone. Hiding something on the
        // strength of a failed read would be worse than showing an ad.
        SCILogV(@"ads: could not describe a section: %@", exception.reason);
        return NO;
    }

    if (!text.length) return NO;

    for (NSString *identifier in SCIPromotedIdentifiers()) {
        if ([text containsString:identifier]) {
            SCILogV(@"ads: dropping a section matching %@", identifier);
            return YES;
        }
    }

    return NO;
}

%hook YTInnerTubeCollectionViewController

- (void)addSectionsFromArray:(NSArray *)sections {
    if (!SCIPrefEnabled(SCIPrefHideAds) || !sections.count) {
        %orig;
        return;
    }

    NSMutableArray *kept = [NSMutableArray arrayWithCapacity:sections.count];
    for (id section in sections) {
        if (!SCISectionIsPromoted(section)) {
            [kept addObject:section];
        }
    }

    if (kept.count != sections.count) {
        SCILogV(@"ads: %lu of %lu sections kept",
                (unsigned long)kept.count, (unsigned long)sections.count);
    }

    // Counted so "Sponsored is still showing" has an answer. There are two completely
    // different reasons for it and the same complaint covers both: this hook never running
    // -- the feed being built somewhere else entirely -- or it running and not recognising
    // what it saw. A total of zero says the first; a total with nothing dropped says the
    // second, and the next step differs.
    [SCIYTDiagnostics recordFeedSections:sections.count dropped:sections.count - kept.count];

    // Filtered on the way in, so the sections are never built into views at all --
    // as opposed to hiding cells afterwards, which leaves gaps in the feed where the
    // cell used to be.
    sections = kept;
    %orig;
}

%end


// MARK: - 3. Refuse ads in the player

%hook YTIPlayerResponse

- (BOOL)isMonetized {
    if (!SCIPrefEnabled(SCIPrefHideAds)) {
        return %orig;
    }
    return NO;
}

- (id)adIntroRenderer {
    if (!SCIPrefEnabled(SCIPrefHideAds)) {
        return %orig;
    }
    return nil;
}

- (BOOL)hasAdLoggingData {
    if (!SCIPrefEnabled(SCIPrefHideAds)) {
        return %orig;
    }
    return NO;
}

// Mid-roll ads: the cuepoints are where the player is told it may interrupt.
- (BOOL)isCuepointAdsEnabled {
    if (!SCIPrefEnabled(SCIPrefHideAds)) {
        return %orig;
    }
    return NO;
}

// Dynamic ad insertion: ads stitched into the video stream itself by the server,
// which no feed filter and no view hook can reach. This gate is the only way to
// refuse them.
- (BOOL)isDAIEnabledPlayback {
    if (!SCIPrefEnabled(SCIPrefHideAds)) {
        return %orig;
    }
    return NO;
}

%end

%hook YTLocalPlaybackController

- (id)createAdsPlaybackCoordinator {
    if (!SCIPrefEnabled(SCIPrefHideAds)) {
        return %orig;
    }

    // The last line of defence, and the bluntest: with no coordinator there is nothing
    // to play an ad even if one arrived past all three checks above.
    return nil;
}

%end
