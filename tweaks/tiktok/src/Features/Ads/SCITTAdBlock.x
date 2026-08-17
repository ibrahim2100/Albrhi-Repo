#import "SCITTAdBlock.h"
#import "../../TikTokHeaders.h"
#import "../../Prefs.h"
#import "../../SCILog.h"
#import "../../Diagnostics/SCITTDiagnostics.h"

///
/// One gate, at the model's own construction, rather than a view hidden after the fact.
///
/// `-isAds` is the server's own mark for a promoted item — read from `AWEAwemeModel`
/// itself, confirmed present in TikTok 46.4.0's own binary rather than guessed. Refusing
/// the object at `-init`/`-initWithDictionary:error:` means an ad is never built into a
/// feed cell in the first place, which is sturdier than hiding a cell afterwards: nothing
/// downstream that reads the feed array ever sees a gap where an ad used to be, because
/// there was never anything there.
///
/// `%orig` still runs first in both hooks. Refusing the object *after* construction,
/// not by skipping construction, is deliberate: `-isAds` cannot be read before the
/// model has actually decoded the dictionary that sets it.
///

%group AdBlock

%hook AWEAwemeModel

- (instancetype)initWithDictionary:(NSDictionary *)dictionary error:(NSError **)error {
    id built = %orig;
    [SCITTDiagnostics recordModelsSeen:1 droppedAsAds:0];

    if (!SCIPrefEnabled(SCIPrefHideAds)) return built;
    if (!built || ![built respondsToSelector:@selector(isAds)]) return built;
    if (![(AWEAwemeModel *)built isAds]) return built;

    [SCITTDiagnostics recordModelsSeen:0 droppedAsAds:1];
    return nil;
}

- (instancetype)init {
    id built = %orig;

    if (!SCIPrefEnabled(SCIPrefHideAds)) return built;
    if (!built || ![built respondsToSelector:@selector(isAds)]) return built;
    if (![(AWEAwemeModel *)built isAds]) return built;

    [SCITTDiagnostics recordModelsSeen:0 droppedAsAds:1];
    return nil;
}

%end

%end


void SCITTInstallAdBlock(void) {
    if (!NSClassFromString(@"AWEAwemeModel")) {
        SCILogV(@"AWEAwemeModel is not in this build — no ad filter");
        return;
    }

    %init(AdBlock);
    SCILogV(@"ad filter attached to AWEAwemeModel");
}
