#import "SCIDownloadJob.h"
#import "../../Localization/SCILocalize.h"

@implementation SCIDownloadJob

+ (instancetype)jobWithURL:(NSURL *)url
             fileExtension:(NSString *)fileExtension
               displayName:(NSString *)displayName
               sourceLabel:(NSString *)sourceLabel {
    SCIDownloadJob *job = [[SCIDownloadJob alloc] init];
    if (!job) return nil;

    job->_identifier = [[NSUUID UUID] UUIDString];
    job->_remoteURL = [url copy];
    job->_createdAt = [NSDate date];

    NSString *ext = [fileExtension length] >= 3 ? fileExtension : [url pathExtension];
    job->_fileExtension = [([ext length] >= 3 ? ext : @"jpg") lowercaseString];
    job->_mediaKind = [self kindForExtension:job->_fileExtension];

    job.displayName = [displayName length] ? displayName : [self defaultNameForKind:job->_mediaKind];
    job.sourceLabel = sourceLabel;
    job.state = SCIDownloadStateQueued;
    job.bytesExpected = NSURLSessionTransferSizeUnknown;

    return job;
}

+ (SCIDownloadMediaKind)kindForExtension:(NSString *)ext {
    static NSDictionary<NSString *, NSNumber *> *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"mp4": @(SCIDownloadMediaKindVideo),
            @"mov": @(SCIDownloadMediaKindVideo),
            @"m4v": @(SCIDownloadMediaKindVideo),
            @"jpg": @(SCIDownloadMediaKindPhoto),
            @"jpeg": @(SCIDownloadMediaKindPhoto),
            @"png": @(SCIDownloadMediaKindPhoto),
            @"heic": @(SCIDownloadMediaKindPhoto),
            @"webp": @(SCIDownloadMediaKindPhoto),
            @"m4a": @(SCIDownloadMediaKindAudio),
            @"mp3": @(SCIDownloadMediaKindAudio),
            @"aac": @(SCIDownloadMediaKindAudio)
        };
    });

    NSNumber *kind = map[ext ?: @""];
    return kind ? (SCIDownloadMediaKind)[kind integerValue] : SCIDownloadMediaKindUnknown;
}

+ (NSString *)defaultNameForKind:(SCIDownloadMediaKind)kind {
    switch (kind) {
        case SCIDownloadMediaKindVideo: return SCILocalized(@"dl_kind_video");
        case SCIDownloadMediaKindPhoto: return SCILocalized(@"dl_kind_photo");
        case SCIDownloadMediaKindAudio: return SCILocalized(@"dl_kind_audio");
        default: return SCILocalized(@"dl_kind_file");
    }
}

// MARK: - Presentation

- (NSString *)symbolName {
    switch (self.mediaKind) {
        case SCIDownloadMediaKindVideo: return @"film";
        case SCIDownloadMediaKindPhoto: return @"photo";
        case SCIDownloadMediaKindAudio: return @"waveform";
        default: return @"doc";
    }
}

- (BOOL)isActive {
    return self.state == SCIDownloadStateQueued
        || self.state == SCIDownloadStateDownloading
        || self.state == SCIDownloadStatePaused;
}

- (BOOL)isFinished {
    return !self.isActive;
}

- (NSString *)statusDescription {
    switch (self.state) {
        case SCIDownloadStateQueued:
            return SCILocalized(@"dl_state_queued");

        case SCIDownloadStateDownloading: {
            NSString *received = [self humanSize:self.bytesReceived];

            NSString *sizePart = (self.bytesExpected > 0)
                ? [NSString stringWithFormat:SCILocalized(@"dl_size_of"), received, [self humanSize:self.bytesExpected]]
                : received;

            if (self.bytesPerSecond > 1024.0) {
                return [NSString stringWithFormat:@"%@ · %@/s", sizePart, [self humanSize:(int64_t)self.bytesPerSecond]];
            }

            return sizePart;
        }

        case SCIDownloadStatePaused:
            return [NSString stringWithFormat:@"%@ · %@",
                    SCILocalized(@"dl_state_paused"), [self humanSize:self.bytesReceived]];

        case SCIDownloadStateCompleted:
            return [NSString stringWithFormat:@"%@ · %@",
                    [self humanSize:self.bytesReceived], [self relativeFinishedTime]];

        case SCIDownloadStateFailed:
            return [self.failureReason length]
                ? [NSString stringWithFormat:@"%@ — %@", SCILocalized(@"dl_state_failed"), self.failureReason]
                : SCILocalized(@"dl_state_failed");

        case SCIDownloadStateCancelled:
            return SCILocalized(@"dl_state_cancelled");
    }
}

- (NSString *)humanSize:(int64_t)bytes {
    if (bytes <= 0) return @"0 KB";

    static NSByteCountFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSByteCountFormatter alloc] init];
        formatter.countStyle = NSByteCountFormatterCountStyleFile;
        formatter.allowsNonnumericFormatting = NO;
    });

    return [formatter stringFromByteCount:bytes];
}

- (NSString *)relativeFinishedTime {
    if (!self.finishedAt) return @"";

    static NSRelativeDateTimeFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSRelativeDateTimeFormatter alloc] init];
        formatter.unitsStyle = NSRelativeDateTimeFormatterUnitsStyleShort;
    });

    formatter.locale = [NSLocale localeWithLocaleIdentifier:[SCILocalize activeLanguage]];

    return [formatter localizedStringForDate:self.finishedAt relativeToDate:[NSDate date]];
}

// MARK: - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.identifier forKey:@"identifier"];
    [coder encodeObject:self.remoteURL forKey:@"remoteURL"];
    [coder encodeObject:self.fileExtension forKey:@"fileExtension"];
    [coder encodeObject:self.displayName forKey:@"displayName"];
    [coder encodeObject:self.sourceLabel forKey:@"sourceLabel"];
    [coder encodeInteger:self.mediaKind forKey:@"mediaKind"];
    [coder encodeInteger:self.state forKey:@"state"];
    [coder encodeInt64:self.bytesReceived forKey:@"bytesReceived"];
    [coder encodeInt64:self.bytesExpected forKey:@"bytesExpected"];
    [coder encodeObject:self.createdAt forKey:@"createdAt"];
    [coder encodeObject:self.finishedAt forKey:@"finishedAt"];
    [coder encodeObject:self.localURL forKey:@"localURL"];
    [coder encodeObject:self.failureReason forKey:@"failureReason"];
    [coder encodeInteger:self.attemptCount forKey:@"attemptCount"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (!self) return nil;

    _identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"] ?: [[NSUUID UUID] UUIDString];
    _remoteURL = [coder decodeObjectOfClass:[NSURL class] forKey:@"remoteURL"];
    _fileExtension = [coder decodeObjectOfClass:[NSString class] forKey:@"fileExtension"] ?: @"jpg";
    _displayName = [coder decodeObjectOfClass:[NSString class] forKey:@"displayName"] ?: @"";
    _sourceLabel = [coder decodeObjectOfClass:[NSString class] forKey:@"sourceLabel"];
    _mediaKind = [coder decodeIntegerForKey:@"mediaKind"];
    _state = [coder decodeIntegerForKey:@"state"];
    _bytesReceived = [coder decodeInt64ForKey:@"bytesReceived"];
    _bytesExpected = [coder decodeInt64ForKey:@"bytesExpected"];
    _createdAt = [coder decodeObjectOfClass:[NSDate class] forKey:@"createdAt"] ?: [NSDate date];
    _finishedAt = [coder decodeObjectOfClass:[NSDate class] forKey:@"finishedAt"];
    _localURL = [coder decodeObjectOfClass:[NSURL class] forKey:@"localURL"];
    _failureReason = [coder decodeObjectOfClass:[NSString class] forKey:@"failureReason"];
    _attemptCount = [coder decodeIntegerForKey:@"attemptCount"];

    // A job persisted mid-flight can't still be running after a relaunch.
    if (_state == SCIDownloadStateDownloading || _state == SCIDownloadStateQueued) {
        _state = SCIDownloadStatePaused;
    }

    return self;
}

@end
