#import "SCIYTRowCell.h"
#import "SCIYTThumbnails.h"
#import "../../../Tweak.h"

/// The artwork's height. Everything else on the row is laid out around it, so this is the
/// one number the row's proportions come from.
static const CGFloat kSCIArt = 68;

/// The margin either side. The app's own list rows sit flush with a modest inset, not the
/// wide gutter a floating card wants -- there is no card any more to hold away from the
/// edge.
static const CGFloat kSCIInset = 16;


@interface SCIYTRowCell ()
@property (nonatomic, strong) UIImageView *artwork;
@property (nonatomic, strong) UIView *artworkShade;
@property (nonatomic, strong) UILabel *badge;
@property (nonatomic, strong) UIView *badgeBacking;

@property (nonatomic, strong) UILabel *name;
@property (nonatomic, strong) UILabel *meta;
@property (nonatomic, strong) UIView *bars;          ///< the playing mark
@property (nonatomic, strong) UIView *progressTrack;
@property (nonatomic, strong) UIView *progressFill;
@property (nonatomic, strong) UIView *separator;
@property (nonatomic, strong) NSLayoutConstraint *progressWidth;
@property (nonatomic, strong) NSLayoutConstraint *artworkWidth;
@end


@implementation SCIYTRowCell

+ (CGFloat)heightForKind:(SCIYTJobKind)kind {
    // The same for every section. A video's artwork is wider, a Short's is taller and a
    // song's is square, but they share one row height -- a list that changes shape when
    // you switch chips reads as three different screens rather than three views of one.
    return kSCIArt + 22;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if (!(self = [super initWithStyle:style reuseIdentifier:identifier])) return nil;

    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    // A plain row on the app's own flat ground -- no card, no per-item colour, no border.
    // A colour-tinted card behind every thumbnail was reading as this tweak's own screen
    // rather than as a page inside the app; the app's own lists are exactly this: a
    // picture, two lines of text, and a hairline underneath the last one.

    self.artwork = [[UIImageView alloc] init];
    self.artwork.contentMode = UIViewContentModeScaleAspectFill;
    self.artwork.clipsToBounds = YES;
    self.artwork.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    self.artwork.layer.cornerRadius = 8;
    self.artwork.layer.cornerCurve = kCACornerCurveContinuous;
    self.artwork.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.artwork];

    // A darkening at the foot of the artwork, so a white badge is legible on a pale still.
    self.artworkShade = [[UIView alloc] init];
    self.artworkShade.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    self.artworkShade.translatesAutoresizingMaskIntoConstraints = NO;
    [self.artwork addSubview:self.artworkShade];

    self.badgeBacking = [[UIView alloc] init];
    self.badgeBacking.backgroundColor = [UIColor colorWithWhite:0 alpha:0.65];
    self.badgeBacking.layer.cornerRadius = 4;
    self.badgeBacking.translatesAutoresizingMaskIntoConstraints = NO;
    [self.artwork addSubview:self.badgeBacking];

    // The length, on the artwork, the way every duration badge in the app's own thumbnails
    // already sits -- bottom-trailing corner, dark chip, white monospaced digits.
    self.badge = [[UILabel alloc] init];
    self.badge.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightSemibold];
    self.badge.textColor = [UIColor whiteColor];
    self.badge.translatesAutoresizingMaskIntoConstraints = NO;
    [self.badgeBacking addSubview:self.badge];

    self.name = [[UILabel alloc] init];
    self.name.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.name.textColor = [UIColor whiteColor];
    self.name.numberOfLines = 2;
    self.name.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.name];

    self.meta = [[UILabel alloc] init];
    self.meta.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    self.meta.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    self.meta.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.meta];

    self.bars = [self buildBars];
    self.bars.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.bars];

    // Progress along the foot of the row, edge to edge under the text column -- not under
    // the artwork, which already has its own duration badge and does not need a second
    // read on how far along the file is.
    self.progressTrack = [[UIView alloc] init];
    self.progressTrack.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    self.progressTrack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.progressTrack];

    self.progressFill = [[UIView alloc] init];
    self.progressFill.backgroundColor = SCIAccent();
    self.progressFill.translatesAutoresizingMaskIntoConstraints = NO;
    [self.progressTrack addSubview:self.progressFill];

    // The one separator, a hairline rather than the system's -- drawn under the text
    // column only, the way a list that puts its picture flush left already does, so the
    // line reads as ending one row's text rather than crossing under the artwork too.
    self.separator = [[UIView alloc] init];
    self.separator.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    self.separator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.separator];

    self.progressWidth = [self.progressFill.widthAnchor constraintEqualToConstant:0];
    self.artworkWidth = [self.artwork.widthAnchor constraintEqualToConstant:kSCIArt];

    [NSLayoutConstraint activateConstraints:@[
        [self.artwork.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kSCIInset],
        [self.artwork.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.artwork.heightAnchor constraintEqualToConstant:kSCIArt],
        self.artworkWidth,

        [self.artworkShade.leadingAnchor constraintEqualToAnchor:self.artwork.leadingAnchor],
        [self.artworkShade.trailingAnchor constraintEqualToAnchor:self.artwork.trailingAnchor],
        [self.artworkShade.bottomAnchor constraintEqualToAnchor:self.artwork.bottomAnchor],
        [self.artworkShade.heightAnchor constraintEqualToConstant:18],

        [self.badgeBacking.trailingAnchor constraintEqualToAnchor:self.artwork.trailingAnchor constant:-4],
        [self.badgeBacking.bottomAnchor constraintEqualToAnchor:self.artwork.bottomAnchor constant:-4],

        [self.badge.topAnchor constraintEqualToAnchor:self.badgeBacking.topAnchor constant:1.5],
        [self.badge.bottomAnchor constraintEqualToAnchor:self.badgeBacking.bottomAnchor constant:-1.5],
        [self.badge.leadingAnchor constraintEqualToAnchor:self.badgeBacking.leadingAnchor constant:4],
        [self.badge.trailingAnchor constraintEqualToAnchor:self.badgeBacking.trailingAnchor constant:-4],

        [self.name.leadingAnchor constraintEqualToAnchor:self.artwork.trailingAnchor constant:12],
        [self.name.trailingAnchor constraintEqualToAnchor:self.bars.leadingAnchor constant:-8],
        [self.name.bottomAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:1],

        [self.meta.leadingAnchor constraintEqualToAnchor:self.name.leadingAnchor],
        [self.meta.trailingAnchor constraintEqualToAnchor:self.name.trailingAnchor],
        [self.meta.topAnchor constraintEqualToAnchor:self.name.bottomAnchor constant:3],

        [self.bars.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kSCIInset],
        [self.bars.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.bars.widthAnchor constraintEqualToConstant:16],
        [self.bars.heightAnchor constraintEqualToConstant:14],

        [self.progressTrack.leadingAnchor constraintEqualToAnchor:self.name.leadingAnchor],
        [self.progressTrack.trailingAnchor constraintEqualToAnchor:self.bars.leadingAnchor constant:-8],
        [self.progressTrack.topAnchor constraintEqualToAnchor:self.meta.bottomAnchor constant:5],
        [self.progressTrack.heightAnchor constraintEqualToConstant:2.5],

        [self.progressFill.leadingAnchor constraintEqualToAnchor:self.progressTrack.leadingAnchor],
        [self.progressFill.topAnchor constraintEqualToAnchor:self.progressTrack.topAnchor],
        [self.progressFill.bottomAnchor constraintEqualToAnchor:self.progressTrack.bottomAnchor],
        self.progressWidth,

        [self.separator.leadingAnchor constraintEqualToAnchor:self.name.leadingAnchor],
        [self.separator.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kSCIInset],
        [self.separator.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [self.separator.heightAnchor constraintEqualToConstant:0.5],
    ]];

    return self;
}

/// Three bars, the middle one taller.
///
/// Drawn rather than an SF Symbol: the equaliser glyphs Apple ships look animated without
/// animating, which reads as broken rather than as still.
- (UIView *)buildBars {
    UIView *mark = [[UIView alloc] init];

    CGFloat heights[3] = {8, 14, 10};
    for (int i = 0; i < 3; i++) {
        UIView *bar = [[UIView alloc] initWithFrame:
            CGRectMake(i * 6, (14 - heights[i]) / 2, 3, heights[i])];
        bar.backgroundColor = SCIAccent();
        bar.layer.cornerRadius = 1.5;
        [mark addSubview:bar];
    }
    return mark;
}

- (void)fillWith:(SCIYTJob *)job artwork:(UIImage *)artwork playing:(BOOL)playing {
    BOOL isVideo = (job.kind == SCIYTJobKindVideo);

    // The shape, which is most of the difference between the three rows. An ordinary
    // still is 16:9, a Short is 9:16 -- tall, the way a Short actually is -- and a cover
    // is square. Forcing any of them into another's frame is what makes a media list
    // look homemade, and it is exactly what a Short got before this: stretched into the
    // same landscape box a video gets.
    self.artworkWidth.constant = job.isShort ? (kSCIArt * 9.0 / 16.0)
                                : isVideo ? (kSCIArt * 16.0 / 9.0)
                                : kSCIArt;
    self.artwork.image = artwork ?: [UIImage systemImageNamed:isVideo ? @"film" : @"music.note"];
    self.artwork.contentMode = artwork ? UIViewContentModeScaleAspectFill
                                       : UIViewContentModeCenter;
    if (!artwork) self.artwork.tintColor = [UIColor colorWithWhite:1 alpha:0.35];

    self.name.text = job.title;

    BOOL done = (job.state == SCIYTJobStateDone);
    BOOL failed = (job.state == SCIYTJobStateFailed);

    self.meta.text = [job statusLine];
    self.meta.textColor = failed ? [UIColor systemRedColor]
                                 : [UIColor colorWithWhite:1 alpha:0.5];

    // The length on the artwork, and only once it is known -- a badge reading 0:00 while a
    // download runs is worse than no badge.
    BOOL hasLength = done && job.duration > 0;
    self.badge.text = hasLength ? [SCIYTThumbnails clock:job.duration] : nil;
    self.badgeBacking.hidden = !hasLength;
    self.artworkShade.hidden = !hasLength;

    self.bars.hidden = !playing;
    self.name.textColor = playing ? SCIAccent() : [UIColor whiteColor];

    self.progressTrack.hidden = done || failed;
    if (!self.progressTrack.hidden) {
        // Laid out immediately: the fill is a fraction of a width that autolayout has not
        // resolved yet on a freshly dequeued cell, and a bar that appears a frame late
        // flickers on every scroll.
        [self layoutIfNeeded];
        self.progressWidth.constant = self.progressTrack.bounds.size.width * job.progress;
    }
}

/// Pressed state, since the stock selection style is off. A dim rather than a scale --
/// the app's own rows do not shrink under a touch, they just darken.
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];

    [UIView animateWithDuration:0.15 animations:^{
        self.contentView.alpha = highlighted ? 0.6 : 1;
    }];
}

@end
