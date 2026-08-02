#import "SCIYTLibrary.h"
#import "../../../SCILog.h"
#import "../../../Prefs.h"
#import "../../../Localization/SCILocalize.h"
#import "../../../Diagnostics/SCIYTDiagnostics.h"
#import <Photos/Photos.h>

NSNotificationName const SCIYTLibraryDidChangeNotification = @"SCIYTLibraryDidChange";

@interface SCIYTLibrary ()
@property (nonatomic, strong) NSMutableArray<SCIYTJob *> *store;
@end

@implementation SCIYTLibrary

+ (instancetype)shared {
    static SCIYTLibrary *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[SCIYTLibrary alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;

    _store = [NSMutableArray array];
    [self load];
    return self;
}

+ (NSURL *)folder {
    static NSURL *folder = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURL *documents = [[[NSFileManager defaultManager]
            URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
        folder = [documents URLByAppendingPathComponent:@"Albrhi Downloads" isDirectory:YES];

        [[NSFileManager defaultManager] createDirectoryAtURL:folder
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:nil];
    });
    return folder;
}

+ (NSURL *)indexFile {
    return [[self folder] URLByAppendingPathComponent:@"library.index"];
}

- (NSArray<SCIYTJob *> *)jobs { return [self.store copy]; }

// MARK: - Persistence

- (void)load {
    NSData *data = [NSData dataWithContentsOfURL:[SCIYTLibrary indexFile]];
    if (!data.length) return;

    NSError *error = nil;
    NSSet *classes = [NSSet setWithObjects:[NSArray class], [SCIYTJob class],
                                            [NSString class], [NSDate class], nil];
    NSArray *saved = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                          fromData:data
                                                             error:&error];
    if (![saved isKindOfClass:[NSArray class]]) {
        SCILogV(@"library: index unreadable — %@", error.localizedDescription);
        return;
    }

    // A row whose file is gone is dropped rather than shown greyed out. The folder is
    // reachable from the Files app, and someone who deleted a video there has already
    // said what they wanted to happen to it.
    for (SCIYTJob *job in saved) {
        if ([job isKindOfClass:[SCIYTJob class]] && [job fileURL]) [self.store addObject:job];
    }

    SCILogV(@"library: %lu downloads", (unsigned long)self.store.count);
}

- (void)save {
    NSMutableArray<SCIYTJob *> *finished = [NSMutableArray array];
    for (SCIYTJob *job in self.store) {
        if (job.state == SCIYTJobStateDone && job.fileName.length) [finished addObject:job];
    }

    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:finished
                                        requiringSecureCoding:YES
                                                        error:&error];
    if (!data) {
        SCILogV(@"library: could not write the index — %@", error.localizedDescription);
        return;
    }
    [data writeToURL:[SCIYTLibrary indexFile] atomically:YES];
}

- (void)changed {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SCIYTLibraryDidChangeNotification
                                                            object:self];
    });
}

// MARK: - Running one

- (SCIYTJob *)startVariant:(SCIHLSVariant *)variant
                      kind:(SCIYTJobKind)kind
                     title:(NSString *)title
                   videoID:(NSString *)videoID {

    NSString *quality = (kind == SCIYTJobKindAudio) ? SCILocalized(@"dl_kind_audio")
                                                     : [variant label];

    SCIYTJob *job = [SCIYTJob jobWithTitle:title quality:quality kind:kind videoID:videoID];
    [self.store insertObject:job atIndex:0];
    [self changed];

    // Progress is throttled to whole percents. A playlist of two hundred parts posts two
    // hundred notifications otherwise, each one reloading a table that has not changed
    // by anything a person can see.
    __block int lastShown = -1;

    void (^onProgress)(double) = ^(double fraction) {
        int percent = (int)(fraction * 100);
        job.progress = fraction;
        if (percent == lastShown) return;
        lastShown = percent;
        [self changed];
    };

    void (^onDone)(NSURL *, NSString *) = ^(NSURL *file, NSString *failure) {
        if (!file) {
            job.state = SCIYTJobStateFailed;
            job.failure = failure ?: SCILocalized(@"dl_failed");
            [self changed];
            return;
        }
        [self adopt:file for:job];
    };

    if (kind == SCIYTJobKindAudio) {
        [SCIYTHLS downloadAudioFor:variant progress:onProgress completion:onDone];
    } else {
        [SCIYTHLS downloadVariant:variant progress:onProgress completion:onDone];
    }

    return job;
}

/// Moves a finished file into the library folder under a name a person can read.
- (void)adopt:(NSURL *)file for:(SCIYTJob *)job {
    NSString *extension = file.pathExtension.length ? file.pathExtension : @"mp4";

    // The characters a file name cannot hold, taken out rather than escaped. A title is
    // whatever the uploader typed, and on this project that has included newlines.
    NSMutableCharacterSet *illegal =
        [NSMutableCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>:"];
    [illegal formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
    [illegal formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];

    NSString *safe = [[job.title componentsSeparatedByCharactersInSet:illegal]
                      componentsJoinedByString:@" "];
    safe = [safe stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (safe.length > 80) safe = [safe substringToIndex:80];
    if (!safe.length) safe = SCILocalized(@"dl_untitled");

    NSString *name = [safe stringByAppendingPathExtension:extension];
    NSURL *destination = [[SCIYTLibrary folder] URLByAppendingPathComponent:name];

    NSUInteger attempt = 2;
    while ([[NSFileManager defaultManager] fileExistsAtPath:destination.path]) {
        name = [[NSString stringWithFormat:@"%@ (%lu)", safe, (unsigned long)attempt++]
                stringByAppendingPathExtension:extension];
        destination = [[SCIYTLibrary folder] URLByAppendingPathComponent:name];
    }

    NSError *error = nil;
    if (![[NSFileManager defaultManager] moveItemAtURL:file toURL:destination error:&error]) {
        SCILogV(@"library: could not keep it — %@", error.localizedDescription);
        job.state = SCIYTJobStateFailed;
        job.failure = SCILocalized(@"dl_failed");
        [self changed];
        return;
    }

    job.fileName = name;
    job.bytes = (long long)[[[NSFileManager defaultManager]
        attributesOfItemAtPath:destination.path error:nil][NSFileSize] longLongValue];
    job.progress = 1;
    job.state = SCIYTJobStateDone;

    [self save];
    [self changed];

    // Only if it was asked for. Saving to Photos used to be the one ending a download
    // could have, and that is what this whole screen exists to undo.
    if (SCIPrefEnabled(SCIPrefAutoPhotos)) {
        [self export:job completion:^(BOOL ok, NSString *detail) {
            if (!ok) SCILogV(@"library: automatic export refused — %@", detail);
        }];
    }
}

// MARK: - Afterwards

- (void)remove:(SCIYTJob *)job {
    NSURL *file = [job fileURL];
    if (file) [[NSFileManager defaultManager] removeItemAtURL:file error:nil];

    [self.store removeObject:job];
    [self save];
    [self changed];
}

- (void)export:(SCIYTJob *)job completion:(void (^)(BOOL, NSString *))completion {
    void (^done)(BOOL, NSString *) = ^(BOOL ok, NSString *detail) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(ok, detail); });
    };

    NSURL *file = [job fileURL];
    if (!file) { done(NO, SCILocalized(@"dl_failed")); return; }

    // Sound has no place in Photos: the library holds pictures and videos, and an
    // audio-only file is refused with an error that says nothing useful. Said here
    // instead, before the refusal.
    if (job.kind == SCIYTJobKindAudio) { done(NO, SCILocalized(@"dl_audio_not_photos")); return; }

    // The host app has to have declared a reason, and YouTube need not have. Asking
    // without one does not fail -- iOS ends the process. Established in 0.12.1.
    NSBundle *host = [NSBundle mainBundle];
    if (![host objectForInfoDictionaryKey:@"NSPhotoLibraryAddUsageDescription"] &&
        ![host objectForInfoDictionaryKey:@"NSPhotoLibraryUsageDescription"]) {
        done(NO, SCILocalized(@"dl_no_photos_access"));
        return;
    }

    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                               handler:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
            done(NO, SCILocalized(@"dl_no_permission"));
            return;
        }

        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:file];
        } completionHandler:^(BOOL success, NSError *error) {
            // Ours is not deleted. That is the difference: Photos gets a copy, and the
            // original stays where the user can still reach it.
            if (success) {
                job.exported = YES;
                [self save];
                [self changed];
            } else {
                SCILogV(@"library: Photos refused it — %@", error.localizedDescription);
            }
            done(success, success ? nil : SCILocalized(@"dl_failed"));
        }];
    }];
}

- (long long)totalBytes {
    long long total = 0;
    for (SCIYTJob *job in self.store) total += job.bytes;
    return total;
}

@end
