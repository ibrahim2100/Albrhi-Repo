#import "SCIYTRowCell.h"
#import "SCIYTThumbnails.h"
#import "SCIYTPalette.h"
#import "../../../Tweak.h"

/// The artwork's height. Everything else on the row is laid out around it, so this is the
/// one number the row's proportions come from.
static const CGFloat kSCIArt = 62;

/// The margin either side. Wider than a stock cell's, because a list of pictures needs air
/// around it far more than a list of text does.
static const CGFloat kSCIInset = 16;


@interface SCIYTRowCell ()
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIImageView *artwork;
@property (nonatomic, strong) UIView *artworkShade;
@property (nonatomic, strong) UILabel *badge;
@property (nonatomic, strong) UIView *badgeBacking;

@property (nonatomic, strong) UILabel *name;
@property (nonatomic, strong) UILabel *meta;
@property (nonatomic, strong) UIView *bars;          ///< the playing mark
@property (nonatomic, strong) UIView *progressTrack;
@property (nonatomic, strong) UIView *progressFill;
@property (nonatomic, strong) NSLayoutConstraint *progressWidth;
@property (nonatomic, strong) NSLayoutConstraint *artworkWidth;
@end


@implementation SCIYTRowCell

+ (CGFloat)heightForKind:(SCIYTJobKind)kind {
    // The same for both. A video's artwork is wider and a song's is square, but they are the
    // same height, so the rows are -- and a list that changes row height when you flip the
    // switch above it reads as two different screens rather than two views of one.
    return kSCIArt + 22;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if (!(self = [super initWithStyle:style reuseIdentifier:identifier])) return nil;

    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    // A card per row rather than separators between rows.
    //
    // Separators are a way of saying "these are the same kind of thing, in a list"; a card
    // says "this is one thing". For rows carrying artwork the second is the truer statement,
    // and it is what every list worth looking at on this platform now does.
    self.card = [[UIView alloc] init];
    self.card.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    self.card.layer.cornerRadius = 16;
    self.card.layer.cornerCurve = kCACornerCurveContinuous;
    self.card.layer.borderWidth = 0.5;
    self.card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.08].CGColor;
    self.card.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.card];

    self.artwork = [[UIImageView alloc] init];
    self.artwork.contentMode = UIViewContentModeScaleAspectFill;
    self.artwork.clipsToBounds = YES;
    self.artwork.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    self.artwork.layer.cornerRadius = 10;
    self.artwork.layer.cornerCurve = kCACornerCurveContinuous;
    self.artwork.translatesAutoresizingMaskIntoConstraints = NO;
    [self.card addSubview:self.artwork];

    // A darkening at the foot of the artwork, so a white badge is legible on a pale still.
    self.artworkShade = [[UIView alloc] init];
    self.artworkShade.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    self.artworkShade.translatesAutoresizingMaskIntoConstraints = NO;
    [self.artwork addSubview:self.artworkShade];

    self.badgeBacking = [[UIView alloc] init];
    self.badgeBacking.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    self.badgeBacking.layer.cornerRadius = 4;
    self.badgeBacking.translatesAutoresizingMaskIntoConstraints = NO;
    [self.artwork addSubview:self.badgeBacking];

    // The length, on the artwork, the way it is on a thumbnail everywhere else. It belongs
    // there rather than in the meta line because it is a property of the picture.
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
    [self.card addSubview:self.name];

    self.meta = [[UILabel alloc] init];
    self.meta.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    self.meta.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    self.meta.translatesAutoresizingMaskIntoConstraints = NO;
    [self.card addSubview:self.meta];

    self.bars = [self buildBars];
    self.bars.translatesAutoresizingMaskIntoConstraints = NO;
    [self.card addSubview:self.bars];

    // Progress along the foot of the card, edge to edge.
    //
    // A UIProgressView in the accessory slot was a 60-point stub on the right of the row,
    // which is where iOS puts a control rather than where a reader looks. A bar the width of
    // the thing it describes is readable from across the room.
    self.progressTrack = [[UIView alloc] init];
    self.progressTrack.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    self.progressTrack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.card addSubview:self.progressTrack];

    self.progressFill = [[UIView alloc] init];
    self.progressFill.backgroundColor = SCIAccent();
    self.progressFill.translatesAutoresizingMaskIntoConstraints = NO;
    [self.progressTrack addSubview:self.progressFill];

    self.progressWidth = [self.progressFill.widthAnchor constraintEqualToConstant:0];
    self.artworkWidth = [self.artwork.widthAnchor constraintEqualToConstant:kSCIArt];

    [NSLayoutConstraint activateConstraints:@[
        [self.card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5],
        [self.card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],
        [self.card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kSCIInset],
        [self.card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kSCIInset],

        [self.artwork.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:6],
        [self.artwork.centerYAnchor constraintEqualToAnchor:self.card.centerYAnchor],
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
        [self.name.bottomAnchor constraintEqualToAnchor:self.card.centerYAnchor constant:1],

        [self.meta.leadingAnchor constraintEqualToAnchor:self.name.leadingAnchor],
        [self.meta.trailingAnchor constraintEqualToAnchor:self.name.trailingAnchor],
        [self.meta.topAnchor constraintEqualToAnchor:self.name.bottomAnchor constant:3],

        [self.bars.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-14],
        [self.bars.centerYAnchor constraintEqualToAnchor:self.card.centerYAnchor],
        [self.bars.widthAnchor constraintEqualToConstant:16],
        [self.bars.heightAnchor constraintEqualToConstant:14],

        [self.progressTrack.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor],
        [self.progressTrack.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor],
        [self.progressTrack.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor],
        [self.progressTrack.heightAnchor constraintEqualToConstant:2.5],

        [self.progressFill.leadingAnchor constraintEqualToAnchor:self.progressTrack.leadingAnchor],
        [self.progressFill.topAnchor constraintEqualToAnchor:self.progressTrack.topAnchor],
        [self.progressFill.bottomAnchor constraintEqualToAnchor:self.progressTrack.bottomAnchor],
        self.progressWidth,
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

    // The shape, which is most of the difference between the three kinds of row. An
    // ordinary still is 16:9, a Short is 9:16 -- tall, the way every Short actually is --
    // and a cover is square. Stretching any of them into another's frame is the thing
    // that makes a media list look homemade, and it is exactly what a Short got before
    // this: the same landscape frame a video gets, with a vertical picture squashed
    // sideways to fill it.
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

    // The card takes a hint of the artwork's colour, which is what stops a list of cards
    // reading as a spreadsheet. Faint on purpose -- it should be felt at a glance and not
    // identifiable as a colour if you look straight at it.
    if (artwork) {
        UIColor *accent = [SCIYTPalette accentFor:artwork];
        self.card.backgroundColor = [accent colorWithAlphaComponent:0.10];
        self.card.layer.borderColor = [accent colorWithAlphaComponent:0.18].CGColor;
    } else {
        self.card.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
        self.card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.08].CGColor;
    }
}

/// Pressed state, since the stock selection style is off.
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];

    [UIView animateWithDuration:0.18 animations:^{
        self.card.transform = highlighted ? CGAffineTransformMakeScale(0.975, 0.975)
                                          : CGAffineTransformIdentity;
        self.card.alpha = highlighted ? 0.75 : 1;
    }];
}

@end
