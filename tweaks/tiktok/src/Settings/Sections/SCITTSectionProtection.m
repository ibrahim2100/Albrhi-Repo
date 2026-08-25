//
//  SCITTSectionProtection.m
//  Albrhi for TikTok
//
//  Detection and what is answered for it.
//
//  **One section, one file, registered by itself.** It was a block inside a 220-line array
//  literal in SCITTStatus.m; adding a row meant editing the middle of that list and deleting
//  a feature meant counting braces. Nothing outside this file knows the section exists --
//  see SCITTSectionRegistry.h for why that is the point.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "../SCITTStatus.h"
#import "../SCITTReport.h"
#import "../SCITTBadge.h"
#import "../../UI/SCITTWelcome.h"
#import "../../Tweak.h"
#import "../../Prefs.h"
#import "../../Localization/SCILocalize.h"
#import <objc/runtime.h>
#import "../SCITTSectionRegistry.h"

@interface SCITTSectionProtection : NSObject
@end

@implementation SCITTSectionProtection

+ (void)load {
    SCITTRegisterSection(60, ^NSDictionary *{
        return @{
            kSCISectionIcon: @"lock.shield.fill",
            kSCISectionColor: [UIColor systemOrangeColor],
            kSCISectionTitle: SCILocalized(@"section_protection"),
            kSCISectionRows: @[
                @{
                    kSCIRowKind: kSCIKindSwitch,
                    kSCIRowPref: SCIPrefBypass,
                    kSCIRowTitle: SCILocalized(@"row_bypass"),
                    kSCIRowNote: SCILocalized(@"row_bypass_note"),
                    kSCIRowIcon: @"shield.lefthalf.filled",
                    kSCIRowColor: [UIColor systemIndigoColor],
                },
            ],
        };
    });
}

@end
