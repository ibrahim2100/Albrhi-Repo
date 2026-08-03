#import "SCIYTArtwork.h"
#import "SCIYTJob.h"
#import "SCIYTThumbnails.h"
#import "../../../SCILog.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@implementation SCIYTArtwork

/// One tag, in the space iTunes and every player that reads an .m4a understands.
static AVMutableMetadataItem *SCITag(NSString *key, id value) {
    AVMutableMetadataItem *item = [[AVMutableMetadataItem alloc] init];
    item.keySpace = AVMetadataKeySpaceCommon;
    item.key = key;
    item.value = value;
    return item;
}

+ (void)embedInto:(SCIYTJob *)job completion:(void (^)(BOOL))completion {
    void (^finish)(BOOL) = ^(BOOL ok) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(ok); });
    };

    if (job.kind != SCIYTJobKindAudio) { finish(NO); return; }

    NSURL *file = [job fileURL];
    UIImage *cover = [SCIYTThumbnails cached:job];
    if (!file || !cover) { finish(NO); return; }

    NSData *jpeg = UIImageJPEGRepresentation(cover, 0.85);
    if (!jpeg.length) { finish(NO); return; }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:file options:nil];

        // Passthrough: the audio is copied byte for byte and only the container's tags are
        // written afresh. Any other preset would re-encode a file that is already exactly
        // what it should be.
        AVAssetExportSession *export =
            [[AVAssetExportSession alloc] initWithAsset:asset
                                             presetName:AVAssetExportPresetPassthrough];
        if (!export) { finish(NO); return; }

        NSURL *output = [NSURL fileURLWithPath:
            [NSTemporaryDirectory() stringByAppendingPathComponent:
                [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"m4a"]]];

        export.outputURL = output;
        export.outputFileType = AVFileTypeAppleM4A;
        export.metadata = @[
            SCITag(AVMetadataCommonKeyArtwork, jpeg),
            SCITag(AVMetadataCommonKeyTitle, job.title ?: @""),

            // Named as the source rather than as an artist we do not know. A song saved from
            // a video has no artist field to read, and inventing one would be worse than
            // leaving it to say where it came from.
            SCITag(AVMetadataCommonKeyArtist, @"YouTube"),
        ];

        [export exportAsynchronouslyWithCompletionHandler:^{
            if (export.status != AVAssetExportSessionStatusCompleted) {
                SCILogV(@"artwork: export refused — %@", export.error.localizedDescription);
                [[NSFileManager defaultManager] removeItemAtURL:output error:nil];
                finish(NO);
                return;
            }

            // Played before it is trusted.
            //
            // 0.22.0 replaced the song the moment the export said it had finished, and a
            // song that had played once then never played again -- which is what a report
            // described exactly. "Completed" means the export ran, not that what came out
            // is readable, and this is the one operation in the tweak that destroys the
            // original to produce its result.
            //
            // So the new file is opened and asked the two questions that matter: is there
            // sound in it, and does it know how long it is. A file failing either is thrown
            // away and the song is left exactly as it was.
            AVURLAsset *check = [AVURLAsset URLAssetWithURL:output options:nil];
            BOOL playable = [check tracksWithMediaType:AVMediaTypeAudio].count > 0
                         && CMTIME_IS_NUMERIC(check.duration)
                         && CMTimeGetSeconds(check.duration) > 0;

            if (!playable) {
                SCILogV(@"artwork: the tagged copy would not play — keeping the original");
                [[NSFileManager defaultManager] removeItemAtURL:output error:nil];
                finish(NO);
                return;
            }

            // Swapped only once the new file exists and is complete. Replacing in place
            // would mean a failure halfway through leaves the song destroyed to gain it a
            // picture, which is a terrible trade.
            NSError *error = nil;
            BOOL replaced = [[NSFileManager defaultManager] replaceItemAtURL:file
                                                               withItemAtURL:output
                                                              backupItemName:nil
                                                                     options:0
                                                            resultingItemURL:NULL
                                                                       error:&error];
            if (!replaced) {
                SCILogV(@"artwork: could not swap the file in — %@", error.localizedDescription);
                [[NSFileManager defaultManager] removeItemAtURL:output error:nil];
            }

            finish(replaced);
        }];
    });
}

@end
