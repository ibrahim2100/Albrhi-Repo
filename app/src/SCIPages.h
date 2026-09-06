//
//  SCIPages.h
//  Albrhi Licences
//

#import "SCIPage.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCIRequestsPage : SCIPage @end
@interface SCILicencesPage : SCIPage
/// Shows one of the filters from outside — the summary card that counted those rows opens them.
- (void)applyScope:(NSInteger)scope;
@end
@interface SCIDevicesPage  : SCIPage @end
@interface SCIStoresPage   : SCIPage @end
@interface SCICodesPage    : SCIPage @end
@interface SCITrialsPage   : SCIPage @end
@interface SCIMessagesPage : SCIPage @end
@interface SCISummaryPage  : SCIPage @end
@interface SCISettingsPage : SCIPage @end

/// What a licence's `tier` covers, in words.
///
/// `lifetime` appears because an older server wrote the *term* into that field; it meant
/// everything, which is what `suite` means. An unknown value is shown as it is rather than
/// renamed — a panel that renames what it does not understand hides a server newer than itself.
NSString *SCIScopeName(id _Nullable tier);

NS_ASSUME_NONNULL_END
