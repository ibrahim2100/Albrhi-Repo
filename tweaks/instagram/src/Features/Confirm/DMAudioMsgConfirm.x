#import "../../Utils.h"
#import "../../Compat/SCIResolve.h"

// Legacy hook (for non ai voices interface)
%hook IGDirectThreadViewController
- (void)voiceRecordViewController:(id)arg1 didRecordAudioClipWithURL:(id)arg2 waveform:(id)arg3 duration:(CGFloat)arg4 entryPoint:(NSInteger)arg5 {
    if ([SCIUtils getBoolPref:@"voice_message_confirm"]) {
        SCILogV(@"[SCInsta] DM audio message confirm triggered");

        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end

// Workaround until I can figure out how to stop long press recording from automatically sending
%group SCIgIGDirectComposer

%hook IGDirectComposer
- (void)_didLongPressVoiceMessage:(id)arg1 {
    if ([SCIUtils getBoolPref:@"voice_message_confirm"]) {
        return;
    } else {
        return %orig;
    }
}
%end

%end


// Demangled name: IGDirectAIVoiceUIKit.CompactBarContentView
%hook _TtC20IGDirectAIVoiceUIKitP33_5754F7617E0D924F9A84EFA352BBD29A21CompactBarContentView
- (void)didTapSend {
    if ([SCIUtils getBoolPref:@"voice_message_confirm"]) {
        SCILogV(@"[SCInsta] DM audio message confirm triggered");

        [SCIUtils showConfirmation:^(void) {
            %orig;
        }];
    } else {
        return %orig;
    }
}
%end

%ctor {
    // The hooks outside the groups below. Logos writes this call itself for
    // a file with no %ctor -- and stops the moment there is one, so leaving
    // it out would silence every hook this file did not need to convert.
    %init;

    Class directComposer = SCIResolveClass(@"IGDirectComposer");
    if (directComposer) %init(SCIgIGDirectComposer, IGDirectComposer = directComposer);
}
