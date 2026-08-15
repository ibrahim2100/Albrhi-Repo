# Albrhi for X — what changed

## v0.7.2

**Diagnostics now prints the view chain above the rail when no button is added.**

Two releases have been spent on `0 buttons added`, a sentence that names a symptom and no
cause: first the rail was the wrong class, then the right class answered `-status` where the
lookup asked for `-viewModel`. If it is still zero, one unknown is left, and it is the one
nobody here can see — **whether the walk upward from the rail passes `ImmersiveCardView` at
all.** The immersive player is built of plugin views, and if the rail's plugin is a *sibling*
of the card rather than a descendant, no upward walk will ever reach the model and the fix is
a different search, not a different getter.

So the report answers it. `immersive button: ImmersiveActionsStackView — 0 buttons added;
above it: A < B < C …` — the actual superview chain, recorded once rather than on every
layout pass, since that hook runs continuously while a video plays.

Nothing else changed. This is instrumentation, and it is here because guessing at a
hierarchy from a class dump has now been wrong twice in a row about this one surface.

## v0.7.1

**The rail was found and the button still never appeared.** A device report on X 12.15
said it in one line: `immersive button: ImmersiveActionsStackView — 0 buttons added`. The
class 0.7.0 identified is right and the hook attaches; every placement then bailed at the
first line of the media lookup.

`SCITWFirstSaveableInStatusView` starts by asking the view for `-viewModel`. Walking up
from the rail reaches `ImmersiveCardView`, and **that class has no `-viewModel`** — its
whole interface is `-status`, `-playerView`, `-playerSessionProducer` and gesture plumbing,
confirmed in the class dump rather than guessed. So the lookup returned nil before it read
anything, on a hierarchy that was carrying exactly the object it wanted.

A view that answers `-status` is now treated as its own model. Everything after that hop
already knew how to go from a status to entities to media; only the top step was missing.
Surfaces that do answer `-viewModel` are untouched — it is still tried first.

The same report is why this was findable at all: `0 buttons added` and "the class is not
here" are different sentences, and 0.7.0 made the report say which.

## v0.7.0

**The save button did not appear inside the video, and a class dump answered why in one
line: the class it was being added to is not in this build at all.**

`ImmersiveInlinePlaybackButtonsStackView` — the rail 0.6.0 was written against, and which
TWIGalaxy's binary still names — is gone. Its sibling `ImmersiveCardView` is present, so the
dump does carry Swift classes and the absence is real rather than an artefact of how it was
taken. Five releases had been spent on button placement and none of them could have worked,
because nothing was there to attach to.

X rebuilt the immersive player around plugin views — `ImmersiveEngagementActionsPluginView`,
`ImmersivePlayPauseButtonPluginView`, `ImmersiveTopRightActionsPluginsView` and thirty-odd
more — and the rail of action buttons is now **`ImmersiveActionsStackView`**, whose members
are `ImmersiveActionButton`. It is the same shape as the old one: a stack of buttons with
`-layoutSubviews`, `-hitTest:withEvent:` and `-initWithFrame:`. Only the name moved, so the
placement itself did not need rethinking — the button is still an *arranged* subview, which
is what puts it in the rail beside like and share instead of fighting layout as a floating
one.

**Both names are hooked.** A `%hook` on an absent class never attaches, so naming the old
one costs nothing and covers builds that still carry it. The diagnostics report now names
which rail attached rather than answering yes or no — after an X update the useful question
is not whether a button appeared but which surface is left.

## v0.6.2

**Diagnostics now says whether the button actually landed on the video, or on the tweet
as a fallback.** The placement logic already prefers the video view -- it searches for it
by name and size before falling back to the tweet's own view -- but that was a claim about
what the code intends, not a measurement of what happens on a real timeline. The report
now reads it from the live view hierarchy at the moment each button is shown: how many
buttons landed on the video itself, and how many fell back to the tweet.

## v0.6.1

**The timeline button showed on the first screenful of a scroll and nowhere after.** It
was placed the moment the video view first appeared in a window, which happens once for a
genuinely new view — and a timeline cell that scrolls out and back in is not a new view,
it is the same one reused with new content. So the button from the top of the feed stayed
exactly there while every recycled cell below it got nothing, and opening a tweet worked
only because that builds a fresh view. The reels-style player added in 0.6.0 never had
this problem and needs no change.

It is placed from the video's own bind point now, on the tweet's view and the video view
alike, which fires on first appearance and on every reuse — the same one Diagnostics had
already been counting correctly the whole time, from asking it the wrong question.

## v0.6.0

**The save button is inside the video now, in the full-screen player — the reels-style feed.**

The earlier button was on the wrong view. Reading the reference tweak's binary settled it:
the class the old button attached to does not exist in it at all, and the button it does
show inside a video goes into the row of playback controls in X's immersive, swipe-up video
player — as a real member of that row, not a floating badge. So the stack lays it out beside
like, reply and share on its own, which is exactly why it appears where the floating one
never did.

The two older buttons stay for now, and the report under the two-finger hold names which of
the three attached — so a phone can say plainly where the button is and is not, instead of
four silent reasons for the same blank.

## v0.5.3

**The save button lands inside the video now, every time — not just on a recycled cell.**

0.5.1 put the button on the video, but the search for the video ran too early: the
moment it looked, the timeline had not yet sized anything, so the search found nothing
and the button fell back to the corner of the tweet — the exact placement it was meant
to replace. The search now runs after layout, once the video has its real size, so it
lands in the frame and stays there while you swipe between videos, the same as
Instagram's reel download button.

## v0.5.2

Fixes the build. 0.5.1 did not compile.

# Albrhi for X — what changed

## v0.5.1

**The button is inside the video now, and stays there while you swipe between videos.**

X draws every video and photo in one kind of view — in the timeline, in a post you opened,
in the fullscreen viewer, in a quoted post, in a message — and the button goes on that view
rather than on the corner of a timeline cell. So it is inside the picture wherever the
picture is.

That view had a button of its own since the first release and it never appeared, and the
report from a phone said exactly why: it was asking the video for what to save, and the
video does not know. The post does. It now looks upward until something answers.

# Albrhi for X — what changed

## v0.5.0

**The save button has moved off the share button.** It was in the bottom corner of the
post, which is exactly where X puts share — two small targets in the same place, so some
taps saved and some shared. It now sits in the top corner of the video or photo itself,
where nothing of X's competes for the tap, and it is bigger.

The device report is what made that possible: it said the media view is there to be found,
and said the other button had seen twenty-five posts and found media in none of them. That
second one is why nothing appeared for so long.

**And the settings page has the tweak's own settings on it.** All three of them were
missing entirely — the save button, the feature switches, and the detailed log had no row
anywhere, on the only screen this tweak has, with no way to turn any of them off. They are
the first section now.

Status has moved down. It is four lines of information about what attached, and opening a
settings screen with a report puts the reading above everything anyone came to change.

# Albrhi for X — what changed

## v0.4.4

Fixes the build. 0.4.3 did not compile: the new button read a setting through a helper
that belongs to the YouTube and Locket tweaks and has never existed in this one.

# Albrhi for X — what changed

## v0.4.3

**A save button on the tweet itself, beside reply and like.** The owner said plainly that
the tweak they use has a button you press for video, and a long press that saves images —
so the binary was read to find out where that button lives. It is not on the video view at
all: it goes on the tweet's own view, and the class our first button hooks appears nowhere
in a tweak that works.

So there are two now, and Diagnostics says which one your build of X actually supports.
The new one is on three of X's status views, added when the tweet comes on screen rather
than during a layout pass, and it finds the video the way the working tweak does — through
the tweet's own entities.

It is grey like X's own buttons rather than red. A fifth button in a different colour, in a
row of four, reads as an advert.

# Albrhi for X — what changed

## v0.4.2

**The save button still did not appear, and the page could not say why.** Four different
things produce exactly that — the view class not being in this build of X, the hook not
attaching, the video never reaching it, or the button being placed and covered — and
Diagnostics reported none of them. It now says which: whether the class is there, whether
the hook attached, how many videos it saw, how many held saveable media, and how many
buttons it placed.

**And the crash is most likely gone.** The button was being given Auto Layout constraints
from inside the layout pass it was created in, inside a view that lays its own overlay out
with plain frames. Asking for a new layout while one is running asks for another, and the
button was the only participant a solver had in a view that does not use one. It is a
plain rectangle in the corner now — the same 30 points, no solver involved.

# Albrhi for X — what changed

## v0.4.1

**The save button now appears on videos.** It never did. The button is built when the view
lays itself out, and the video it belongs to is handed over earlier than that — so the
button did not exist yet at the moment it was told what to save, and by the time it was
built there was nothing left to tell it. It hid itself, correctly, on the strength of a
question asked too early.

What to save is now kept on the view rather than on the button, so it does not matter which
of the two happens first.


## 0.4.0

**A download button on the video itself.** In the corner beside play and mute — tap it and
the video is in Photos, at the best quality X offers. No opening a menu first.

The list under the two-finger hold stays, and the two cover each other: the button is on
one of X's views and could break the day X renames it, while the list saves from the model
and does not. If the button ever goes missing after an X update, the list is still there.

## 0.3.0

**Saving videos.** Hold two fingers in X and everything it has shown you since you opened
it is at the top of the screen, newest first. Tap one and it is in Photos.

- **Videos at the best quality X offers** — the choice is made by X's own picker, not by us
  guessing at a URL.
- **Photos at full size.** A timeline photo is a smaller copy; what gets saved is the one
  that was uploaded.
- **GIFs too**, saved as the video files X actually serves — which is what they have been
  for years.
- Progress while it downloads, and a plain answer if it fails.

**No button is added to X**, and that is on purpose. A button has to live inside one of X's
views, and those get renamed — this project has lost the same button twice on Instagram for
exactly that reason. The list is in our own screen, so it keeps working when X moves things
around.

A live broadcast is the one thing that cannot be saved: X offers a stream for those and not
a file, so they are left out of the list rather than listed and failing after the tap.

## 0.2.0

**The features are here, and they are named after what they do.** 0.1.0 watched your phone
and wrote down every switch X asked about. This release turns what it saw into seventeen
switches in plain language:

- **Hide ads** — promoted posts in the timeline, before videos, on profiles and in search,
  and X's own rules that keep an ad out of the first slot are switched on.
- **Hide the Promote button**, **Hide Grok**, **Hide Premium ads**.
- **Stop X translating by itself** — the busiest switch on the whole phone, asked 32,844
  times in one session. The Translate button stays exactly where it is.
- **Send less about me** — the usage reports about your scrolling, storage, connection and
  crashes, and two outside services X carries. How X verifies your device is deliberately
  left alone: that one can get an account locked.
- **Clean up the interface**, **Hide view counts**, **Hide Spaces**.
- **Show sensitive posts directly**, **Do not play GIFs by themselves**, **Zoom without
  opening**, **More gestures**, **More tabs**, **Keep my likes private**, **Open faster**,
  and speed tweaks X ships switched off.

**Your own answer still wins.** Set a switch by hand and it beats whatever a feature wants,
and each row in the list now says which feature is behind its value. One button undoes
everything — features included.

Every switch a feature touches is one a real phone reported: 341 switches over 345,902
questions on X 12.14. What each one *does* is read from its name, so if something looks
wrong, turn the feature off and X goes straight back to normal.

## 0.1.0

The first release. It shows you the switches X uses to decide what your app can do,
and lets you answer them yourself.

- **Hold two fingers anywhere in X** to open it.
- **The list is real.** Every switch on the screen is one your copy of X actually asked
  about while you were using it — nothing is written in advance and nothing is guessed.
  Use the app for a while and the list grows.
- **Tap a switch to answer it.** On, off, or hand the decision back to X. Your answers
  are kept, and there is one button to undo all of them.
- **Search**, and a filter that shows only the ones you changed.
- **Save a report** to the Files app, so a problem can be described with the actual
  numbers instead of from memory.
- Arabic and English, and it appears in Settings › Albrhi with the rest.

This release deliberately reports more than it changes. Which switches are worth turning
on by name is decided by what real phones report, not by reading a binary — and that is
what this one is for.
