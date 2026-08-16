# Albrhi for YouTube — Changelog

**Tested on YouTube 21.30.5.** Nothing is pinned to a version number: every class the
tweak touches is looked up at runtime and skipped if it is not there.

## v1.14.0

Read from a modified YouTube IPA the developer supplied — eighteen bundled dylibs, none
carrying a licence file, so every one of them was read for architecture only, the same
cautious way YTLite already is. Two findings were concrete enough to build independently.

**Real, system Picture-in-Picture — unlocked, not built.** The app already carries the
whole thing: `AVPictureInPictureController` is linked, and the video model answers
`-isPlayableInPictureInPictureByUserSettings` sitting in the same property list, right next
to `-playableInBackground` — the same class this tweak's own background-playback hook
already touches. That one property is the account-plan gate; forcing it is the entire
feature, since the controller, the AVFoundation session and the system window are all
already there and already working. Deliberately not forced: `-isPlayableInPictureInPicture`,
the narrower per-video answer, which can be genuinely NO for a live stream or a restricted
upload and would open a PIP window on something that cannot actually play in it.

**Smoother motion on a ProMotion phone.** YouTube's own player caps its `CADisplayLink`
under the screen's real refresh ceiling; this raises the cap to `UIScreen`'s own
`maximumFramesPerSecond` rather than a hard-coded 120, so it does nothing (correctly) on a
60Hz phone. Only the redraw rate of an already-decoded frame changes — not what the video
decodes at.

## v1.13.0

Built after reading a modified YouTube IPA the developer supplied — eighteen dylibs, of
which the relevant references are **YTVideoOverlay, YouQuality and YouSpeed by PoomSmart,
all MIT** (licences verified, not assumed) and **YTLite, which publishes source but ships
no LICENSE file** and is therefore read for architecture only, the same cautious way
`carsurf` is in the CarPlay tweak. Nothing here is lifted from either.

**A save button inside YouTube's own player, and the time the video ends at.** Until now
the tweak had no presence on the layer over the video at all — a tab at the bottom and
buttons in Shorts — so saving meant leaving the player, which is the one moment nobody
wants to. The two classes that own those two places (`YTMainAppControlsOverlayView`,
`YTInlinePlayerBarContainerView`) are read from YTVideoOverlay's source, not from a class
dump of this build, so **both features default off**, every selector is behind
`-respondsToSelector:`, and the diagnostics report names which of the two attached — "no
button" is never two silent reasons at once.

**A cover section in the download sheet**, beside Video and Sound. A cover is deliberately
*not* a third `SCIYTJobKind`: that enum is read by the library, the queue, the list and the
player, and every one tests it as a two-way question, so a third value would have made four
files silently answer "video" for a thumbnail without failing to compile. Video and sound
produce a job; a cover is fetched and handed to Photos on the spot. The section appears only
when there is a video id, and that id is the same one the title is resolved from — so the
cover belongs to the video asked for rather than to whichever was captured last, which is
the Shorts mismatch already documented at that call site, in picture form.

**The saved-media player now reads as iOS's own.** The transport row sits on a frosted
capsule measured to its own height, the play and pause glyphs are the system's bare pair
rather than the filled circles Music uses, and the timecodes are legible against a bright
frame instead of 55% white over one.

**Two settings headers were rendering their raw key**, and had been for a long time.
`dl_quality_header` and `dl_sound_header` were never defined in either table; both sat inside
a ternary within `SCILocalized(...)`, which `check.py`'s rule 6 cannot parse, so nothing ever
checked them. Rewriting that ternary as plain calls is what exposed it.

Two things the review found that needed **no** code, recorded so they are not rebuilt:
per-network quality already exists in full (`nw_path_monitor`, separate Wi-Fi and cellular
ceilings, both exposed); and SponsorBlock markers already reach the feed and mini-player bars
— those three bar classes are generic. That second one is not a feature, it is a **latent
bug**: `sciSegments` is one global for the active video with nothing tying a bar to the video
it belongs to, so a feed video's bar can be drawn with another video's segments. Fixing it
needs a device to say which class owns which model, which is exactly what this project
refuses to guess at.

## v1.12.5

**The lock screen showed a different video from the one playing.** Reported from a
device, and worth saying plainly: **this is a change to test, not a confirmed fix.** The
mechanism below is read off the code rather than measured on a phone, and it is being
shipped so it can be tried.

Nothing in this tweak writes a lock-screen entry for an ordinary YouTube video — the only
code that touches the now-playing centre belongs to the saved-downloads player, and that
was ruled out first. What the tweak can do is change *which video the app itself treats as
the one playing*, and background playback is where: the whole feature is three getters
forced to YES, and the app's audio session, its playback controls and its lock-screen entry
all follow from that one answer.

They were forced for **every** instance, including videos the app was merely preloading. A
preloaded video answering "yes, I may carry on in the background" is a candidate for the
lock screen while something else is playing.

`MLVideo -playableInBackground` now answers for the video actually being watched and leaves
the rest to YouTube. Two deliberate limits:

- It never answers *no*. An unmatched video gets YouTube's own answer — the behaviour
  without this tweak — rather than an invented refusal.
- No video id yet is not treated as a mismatch. That is the ordinary state for the first
  video of a session, and refusing it would break the feature exactly where it is wanted.

The file's other two hooks (`YTIPlayabilityStatus`, `YTPlaybackData`) are **not** scoped,
because neither carries a video id to compare and attributing one would be guesswork. If
the lock screen still disagrees with the sound, those two are the next place to look — and
the quickest way to tell is to turn background playback off entirely and see whether the
mismatch goes with it.

## v1.12.4

- The tweak now states, in its own filter file, the YouTube version it was last verified
  against. Albrhi Panel reads that and shows it beside the version on your phone, so a
  mismatch is visible before it becomes a question.


## v1.12.3

- **The switch in Settings actually works now.** Same fix as the Instagram tweak: the
  setting is read directly instead of being asked for through a system service that
  answers a sandboxed app with nothing.

## v1.12.2

- Adds a line to Diagnostics that lists what is actually on screen after you change
  tabs. The page-sticking fault has now had three fixes and it is still there, and
  the last report showed that the parts already suspected are working correctly. This
  release changes no behaviour — it asks the phone the one question that separates
  the two remaining explanations, so the next fix is not another guess.

## v1.12.1

- Really fixes the app getting stuck on one page. The last attempt fixed a different
  fault with the same symptom and left this one behind. After playing something from
  Downloads, the tweak was still holding the name of the tab you had been on before
  opening Downloads, and handing it back to YouTube on your next tap — so YouTube
  worked out where to go from a tab you had already left, and when that happened to
  be the tab you tapped it decided there was nowhere to go. It now forgets that name
  the moment the Downloads page closes, however it closes.

## v1.12.0

- Removes "Ask for plain streams" from the player settings. It was tried every way it
  could be tried and it never once made a difference to what YouTube sent — and while
  it was on, saving worked less well than with it off. A switch that does nothing is
  worse than no switch, so it is gone rather than left turned off.

## v1.11.0

- Fixes the app getting stuck on one page. After playing something from Downloads,
  every tab you tapped showed the same screen. The Downloads page was staying in
  place while YouTube changed its pages behind it, so nothing you tapped could be
  seen. It now steps aside whatever takes you away from it, not only a tab tap.
- One more attempt at asking YouTube for plain video files, from a different angle.
  If it does nothing again the switch will be removed rather than left there.

## v1.10.2

- Diagnostics now says whether the "Ask for plain streams" switch is on, and which
  video the reading was taken on. Two reports came back the same and there was no way
  to tell whether the switch had been tried or the video had simply not been played
  again — a report that cannot answer that is not telling you anything.

## v1.10.1

- Fixes the build. 1.10.0 did not compile: one line asked a value for a number without
  having said what kind of values it held. Nothing about the release was wrong on the
  phone, because it never reached one.
- The checks that run before every build now catch that particular mistake in a second
  rather than five minutes into a compile.

## v1.10.0

- **The settings are a short list now.** They had become one long scroll of nine headings,
  and finding anything meant scrolling past everything. The first screen is nine names —
  Downloads, Quality, Ads, Hide things, Player, Screen, SponsorBlock, General, About — and
  each opens its own page. Every setting is exactly where it was, one tap further in.
- Nothing was removed and nothing moved between categories.
- Diagnostics now names each streaming gate separately instead of adding them up. The last
  report said they were asked four times and named only one of them, which left it unclear
  whether that meant both gates or one of them four times — and those need different
  answers.

## v1.9.0

- **The video can always go the way you want it in fullscreen.** YouTube decides which way
  round from how you are holding the phone, which is wrong every time you are lying on your
  side. Under Screen you can set a side, and it goes there whatever the phone thinks. The
  button and the swipe are set separately — the button is on purpose, the swipe often is not.
- **A screen darker than iOS lets you go.** For a dark room, where even the lowest brightness
  is too much. It lays a dark layer over the screen rather than turning the backlight down —
  there is no way to go below the system minimum — so on an OLED phone it looks the same and
  on an LCD the picture dims. Touch works straight through it, and it never reaches black.
- **And it can turn itself on at night.** Set an hour to start and an hour to stop, and it
  leaves the screen alone outside them. Across midnight works — ten at night until seven is
  the setting it starts with.
- The direction and the dimming both follow YTweaks by fosterbarnes, GPLv3, credited in
  About. The code is our own, and the fullscreen part reaches the app a different way: the
  two places YTweaks hooks no longer exist in this YouTube, and the pair that replaced them
  do.

## v1.8.0

- **You choose how far a double tap jumps.** YouTube fixes it at ten seconds, which is too
  little for a lecture and too much for a song. Five up to a minute, under Player. The number
  on the little bubble changes with it.
- **Speeds above 2× in the speed menu** — 2.25×, 2.5×, 3× and 4×. Off until you turn it on.
- **A new Interface page for hiding parts of YouTube.** The coloured glow behind the video,
  the grid of suggestions that covers the last seconds, the pop-out cards in the middle, the
  search, notifications, create and cast buttons at the top, and the promotion row in the
  share sheet. Everything on that page is off until you switch it on: these are pieces of
  YouTube that work, and which of them you want gone is your call and not ours.
- Nothing here hides anything after it is drawn. Each switch answers the question YouTube
  asks itself before building the thing, so it is never built — no gap left behind, and it
  does not come back when the page reloads.
- **A first look at why saving is slow.** YouTube sends video in pieces instead of as files,
  which is the reason a save takes ninety requests. There is a switch under Player asking it
  not to. It ships off, it may do nothing, and Diagnostics now says whether YouTube even
  asked the question — which is the point of this release. If the answer is no, the idea ends
  there and nothing that works was touched to find out.

## v1.7.0

- **Downloads carry on when you leave YouTube.** Until now a save only progressed while you
  were standing in the app watching it — switch apps, take a call, or lock the phone and it
  froze until you came back. The fetching is handed to the system now, so it keeps going with
  YouTube closed.
- **A notification tells you when one finishes**, since the moment it does is now a moment
  nobody is watching. Only when you are outside the app — inside it, the row already says so.
  Permission is asked for the first time there is something to tell you, not at launch.
- If YouTube is force-quit from the app switcher mid-download, that download is lost and the
  row says so. Surviving that is a different piece of work and this does not pretend to.

## v1.6.0

- **The picture on the lock screen is square now**, instead of a wide strip with black above
  and below it. YouTube's thumbnails are widescreen and that slot is a square, so every saved
  song and video has been letterboxed there since the beginning.
- The space around it is filled with the picture's own colours rather than black, and the
  picture itself is left whole — nothing is cropped away, because a thumbnail is composed for
  its own shape and taking the middle of one usually removes the point of it.

## v1.5.1

- **Dropping the player down to the mini bar no longer stops the sound.** The arrow was
  pausing on its way out, so it handed you a bar that was already silent and the only way on
  was to press play again. It now takes the screen away and leaves playback exactly as it
  was — mid-word, if that is where you were.
- The mini bar also keeps its play button honest when playback is changed from the lock
  screen, headphones or a car, which it could not hear before.

## v1.5.0

- **The Download Centre is redrawn.** Every row is a card carrying its own artwork, tinted a
  shade of that artwork's own colour, so a list of saves reads as a shelf of things rather
  than a settings screen with pictures in it.
- **Videos and songs finally look like what they are.** A video keeps its 16:9 still with the
  length printed on the corner, the way a thumbnail is everywhere else; a song shows its
  square cover. Neither is squeezed into the other's frame any more.
- **Progress runs the full width of the row** while something downloads, instead of a short
  stub on the right where nobody looks.
- Rows press in when you touch them, the row that is playing is marked, and the page sits on
  a single lit surface rather than a grey table on a darker grey.

## v1.4.1

- **Tabs work again after visiting Downloads.** Opening the Centre and then tapping You, or
  Shorts, or anything else, was taking you to Home instead — every time. The tab bar was left
  holding our tab's name as the one it had open, and since that names no page it knows, it had
  nowhere to move *from* and fell back to its default. It is handed its own answer back before
  it is asked to move.
- **Picture in picture only starts when you press the button.** Leaving a video was putting it
  in a floating window on its own.

## v1.4.0

- **Every song now colours its own screen.** The background is read out of the cover itself —
  a red album gives a red screen, a blue one a blue screen — and it fades from one to the next
  as the track changes. The scrubber and the play button take their colour from the same
  place, and the cover casts that colour behind it, so the artwork looks lit rather than
  pasted on.
- **The cover breathes.** It settles back a little when paused and returns when playing —
  four per cent, enough to feel and not enough to notice.
- **Saved songs show their covers in the list**, instead of forty identical music notes, with
  rounder corners than a video's still so you can tell the two lists apart at a glance.
- **The row that is playing is marked**, so scrolling a long list while listening tells you
  where you are.

## v1.3.0

- **Downloads are several times faster.** A video arrives in ninety-odd pieces, and they were
  being fetched strictly one after another — so most of the wait was not the video coming
  down, it was ninety separate trips to Google, each one waiting for the last to finish. Four
  are now in flight at once.
- The order cannot go wrong. Each piece is written under its own number the moment it is
  asked for, and the video is assembled by those numbers rather than by what arrived first —
  so there is no arrangement of arrivals that can produce a scrambled file.
- Each piece still gets its three attempts, and a failure still names which one.

## v1.2.0

- **Deleting a save now asks first**, and names what it is about to delete. A swipe is easy
  to make by accident on a list you are scrolling, and what it destroys took minutes to fetch
  and does not go to a bin.
- **Optionally remove a video from here once Photos has it.** Off by default — a video sent to
  Photos still stays in the Centre, because that is where it plays. Turn it on if you would
  rather not keep two copies.
- **Saving something you already have just says so**, instead of fetching all of it again and
  leaving you with a second copy. Video and audio count separately.
- **Leftovers are cleared.** A download the app did not survive left its working file behind,
  and iOS empties that folder on its own unhurried schedule — which after a few long videos is
  hundreds of megabytes nobody can see. They are removed at launch, and only ones older than
  an hour, so a download running right now is never touched.

## v1.1.0

- **A download no longer starts over because one piece failed.** A video arrives in ninety-odd
  pieces, and a single one that timed out threw away everything already fetched — on mobile
  data that is most of the reason a save fails at all. Each piece is now asked for up to three
  times, with a pause between, and only what is genuinely refused gives up.
- An address that has expired still fails immediately, because asking again three times just
  makes the same mistake more slowly.
- If it does fail, the message says which piece and how many had already arrived, instead of
  "the download failed".

## v1.0.0

The first release that is not a work in progress.

- **Dislike counts are gone.** They never once worked: the buttons on this build are not
  drawn the way that feature needed, every report said so, and it was carrying an outside
  service's data and licence for a number that never appeared on screen. Removed entirely —
  the code, the setting, the network calls and the credit.
- **The tweak is lighter.** Four unused methods removed, the accent colour written out in
  eight files reduced to one, sixteen unused pieces of text deleted, and the busiest hook in
  the tweak — the one that runs every time the progress bar lays itself out — now asks
  whether the feature is on before doing anything at all.
- **An About section** with the licence and the credits.
- Nothing you use has changed. This is the same tweak with less in it.

## v0.31.1

- **An About section**, at the bottom of the settings: who made it, which version, the
  licence, and what it borrows from others. Some of that the licence requires; the rest is
  there because a tweak that talks to outside services should say so where you can find it.
- Housekeeping with no visible effect: four unused methods removed, and the accent colour
  written out in eight separate files reduced to one.

## v0.31.0

- **A saved Short is named after itself.** The right clip was being fetched — that is proved
  from the link it used — and then filed under the *next* clip's title, so the Download
  Centre showed the wrong video's name on the right video's file. From the outside those
  look the same, which is why this took so long to separate.
- If a Short you saved has the wrong name, the file itself is very likely the right one.
  Play it and see. New saves get the correct name.

## v0.30.4

- **Saving a Short is getting the right clip.** The report you sent carried the proof: the
  name inside the address it fetched works out to exactly the Short on screen, and not to
  the one below it. So the part that has been wrong for nine releases is now right.
- The tweak can check that for itself now, and says so in Diagnostics either way. It never
  refuses on it — that mistake cost a release — it only prefers a link it can confirm.

## v0.30.3

- **Fixes 0.30.2, which stopped Shorts saving anything at all.** That release refused any
  address that did not contain the video's id — and no address does. YouTube names a video
  one way when you ask for it and another way inside these links, so the check threw away
  every correct answer along with the wrong ones.
- Saving works again. It may still give you the neighbouring clip; that is the older problem,
  not a new one, and nothing here pretends otherwise.
- The report now prints the name the link itself uses, beside the one asked for. Those two
  side by side settle whether the link is the right video's, which is the last unknown left.

## v0.30.2

- **The address is now checked against the video it is meant to be for.** Every release so far
  has reasoned about *which* set of details to use; the last one reported picking the right
  set and still produced the wrong file. So the tweak now reads the video's name out of the
  address itself and refuses it if it belongs to something else.
- If it refuses, it says so and saves nothing. That is deliberate: a file that is quietly the
  wrong video is why this has taken eight tries to pin down — it looks like success until you
  open it.

## v0.30.1

- **The wrong-Short download.** The details of the right clip were being found and then asked
  for the address under a name they do not use — two parts of YouTube call the same thing by
  two different names, and this was only ever asking for one of them. So the lookup kept
  coming back empty, which looks exactly like having found nothing at all.
- That was in our own file the whole time, thirty lines below the code that got it wrong.

## v0.30.0

- **The wrong-Short download, from the answer rather than from guesswork.** The last release
  added a line to the report saying exactly what Shorts hands over, and it turned out to be
  a kind of message whose contents cannot be looked up anywhere — not in the app, not in its
  code. So instead of asking it for a field by name, the tweak now finds the video's address
  inside it by recognising the address itself.
- That is the seventh attempt at this, and the first one built on a measurement instead of
  an argument. It is also the first that could not have been made before now: the previous
  release existed to produce the fact this one needed.

## v0.29.2

- **Another attempt at the wrong Short, and a way to tell whether it worked.** What Shorts
  hands over is a wrapper around the video's details rather than the details themselves, so
  the tweak was looking one level too shallow and finding nothing — which looked exactly the
  same as never having looked. It now checks the places that wrapper keeps them.
- If it is still wrong, Settings, Diagnostics now has a "What the Shorts model handed over"
  section that says precisely what arrived and what shape it was in. That answers it either
  way, which the last report could not.

## v0.29.1

- **Saving a Short takes its details from the Short itself.** Last release stored the details
  of recent videos so the right one could be looked up — and in Shorts there were never any
  to store, because Shorts does not build the object every other part of the tweak reads. It
  now takes them from the clip's own data, which knows both what it is and which video it is.
- **Ads: 8 hidden in one sitting**, so that part is working.

## v0.29.0

- **Saving a Short saves the one on screen.** The tweak now keeps the stream details of the
  last few videos instead of only the newest, and looks up the one you asked for by name.
  Shorts loads the next clip while you are still watching the current one, so the newest
  details have always belonged to the wrong clip — four releases went into trying to detect
  that, when the answer was simply to keep both and ask for the right one.

## v0.28.1

- **Fixes 0.28.0, which broke saving in Shorts completely.** That release added a check that
  compares the video you asked for against the video the tweak has details for — and the
  second of those never got read, so the check decided every time that it had the wrong
  video and refused everything.
- It now only refuses when it can actually see a disagreement. If it cannot tell, it carries
  on the way it did before, because the wrong video is a bad download and no video is no
  feature at all.

## v0.28.0

- **Saving a Short saves the Short you are watching.** The report you sent had the answer in
  it: the button was reading the right video all along, and the download was checking that
  against the wrong thing — so it compared two numbers that agreed, concluded everything was
  fine, and fetched a third video's details. It now checks against the one that actually
  decides what gets downloaded.
- Diagnostics shows all three of those at once now. They are the same number on an ordinary
  video and different in Shorts, which is why this only ever went wrong there.

## v0.27.1

- **Ad cards on Home should go, and the ad picture with them.** The same marker turns up on
  Home and in Shorts, so it is one thing being removed in both places rather than two.
- The previous attempt at this never once worked — it was reading the wrong thing entirely,
  while the ad sat on screen perfectly visible. It now reads the label the view carries
  itself, which was there all along.
- **Diagnostics can finally answer the wrong-Short question.** Tapping save wrote down what
  it tried to save, and the next swipe erased it before you could ever read it, so every
  report came back without the one line that mattered. Tap save on a Short, open Settings,
  Diagnostics, and send the "Last Shorts save attempt" section.

## v0.27.0

- **The ad picture in Shorts is hidden.** Refusing the ad page was not enough — it gets built
  anyway — so the picture itself is refused where it is drawn. Its place stays and you swipe
  past it, but there is nothing in it.
- **Saving a Short no longer saves the wrong one silently.** It still gets it wrong sometimes,
  and until that is fixed it will now say so and save nothing rather than quietly hand you a
  different video. A wrong file that looks like a success is why this has taken three
  attempts — you only find out when you open it.
- The message says what the tweak could and could not see, so the answer arrives with the
  complaint instead of needing another release to ask for it.

## v0.26.1

- **Ads in Shorts no longer draw.** A Short that is an advertisement is a different kind of
  page from a Short that is a video, which makes it easy to refuse — the tweak now says no
  when that page asks to render.
- Be clear about what that means: the ad does not appear, but its place in the feed is still
  there and you swipe past it. Taking the slot out altogether means changing the list the
  Shorts feed is built from, and that has not been measured yet — guessing at it is what
  emptied the Home feed in 0.20.1.
- Diagnostics counts how many were refused, so "Shorts still has ads" says whether they are
  arriving some other way.

## v0.26.0

- **Sponsored rows on Home should finally go.** Every previous attempt used names taken from
  the app's own code, and none of them matched what is actually on screen. This one was
  identified by pointing at a real Sponsored row on a real phone and asking what it was.
- **And a brake, so this cannot empty your feed again.** If the filter would remove more than
  a third of the page in one go, it stops and removes nothing — because that is not an ad
  filter, that is a mistake, and it is exactly what happened in 0.20.1. Ads getting through
  is a complaint; a blank Home is a broken app.
- Diagnostics says when the brake stopped it, so "no ads gone" tells you which of the two
  problems you have.

## v0.25.1

- **Saving a Short really does save the one you are watching now.** Last release made the
  button name the right clip, and it changed nothing, because everything downstream took
  what the player was holding — and in Shorts that is the clip queued below. When the video
  asked for is not the one playing, the tweak now goes and fetches that video's own details
  instead of reading what happens to be loaded.

## v0.25.0

- **Saving a Short now saves the one you are watching.** It was saving the next one down.
  Shorts builds the following clip while you are still on the current one, so "what is
  playing" had already moved on — the button now asks the clip it is actually drawn on.
- **The save button sits above the like column**, instead of below it among the caption.
- **The lock screen controls stay put for music.** They are written again every couple of
  seconds while something plays, because YouTube writes to the same place and clears it when
  it thinks nothing is playing — which, since our player pauses YouTube's, it does.

## v0.24.1

- **Sound keeps playing with the screen off again**, and its controls come back on the lock
  screen. Video was fine and sound was not, and the only thing this tweak did differently
  between them was a sound profile added two releases ago. It is gone; both are treated the
  same way, which is the way that worked.
- **The Shorts save button appears even when the layout is not one the tweak recognises.** It
  was placing itself under the like column and giving up entirely if it could not find one.
  It now falls back to the edge, which is roughly right, instead of not appearing at all.

## v0.24.0

- **Writing the cover into saved songs is off now.** It shipped switched on and rewrote every
  song you had in order to tag it, and a rewrite that goes wrong loses the song. What it buys
  is a picture when you send a song to someone else. That is not worth the song, so it is a
  setting you turn on, not something the tweak does to your library on its own.
- **A song that will not open now says so** instead of sitting at "--:--" forever, and
  Settings, Diagnostics lists exactly what iPhone said was wrong with the file. That is the
  one thing no amount of looking at the tweak can answer.
- **A mini player along the bottom of the Centre.** Sound carries on while you look through
  your downloads, and tapping the strip puts the full screen back where it was. Closing the
  player used to stop the music, because they were the same thing.

**If your saved songs stopped playing:** they were damaged by 0.22.0 and cannot be repaired
— delete them and save them again. Fresh saves are not touched by anything now.

## v0.23.0

- **A save button in Shorts**, in the column with like and share. Shorts has no long press
  to spare — the whole screen is already a scrubber and a swipe — so there was no way at
  all to save one before this.
- **Songs play again.** Last release put the cover inside the sound file, and replaced the
  file the moment the writing reported success — which says the work ran, not that what came
  out can be read. A song now has to open and play before it is allowed to replace anything.
  **A song already broken by 0.22.0 stays broken: delete it and save it again.**
- **The lock screen stops coming and going.** Its entry was written when playback started
  and never put back if something overwrote it in between. It is written again every time
  you leave the app.
- Songs no longer get the processing meant for film dialogue, which was audible on music.

## v0.22.0

- **Saved videos keep playing with the screen off, and when you leave the app.** They were
  stopping the moment you locked the phone. The tweak asked for the sound once, when the
  player opened, and YouTube takes it back as soon as it decides nothing is playing — which,
  since our player pauses YouTube's, is immediately. It is asked for again every time you
  leave, which is when it matters.
- Playback also resumes properly after a phone call or an alarm, instead of staying silent.
- **The cover is written into the song itself now.** It showed everywhere inside the tweak
  before but was not part of the file, so sending a song to someone, or opening it on a
  computer, gave them something nameless. The title goes in with it.
- Nothing is re-encoded to do that — the sound is copied across untouched and only the tags
  are rewritten — and the original is only replaced once the new file is complete.

## v0.21.1

- Fixes 0.21.0, which did not build. Renaming worked; the method that offered it happened to
  share a name with one iPhone already defines, and on this version of iOS that is not
  allowed.

## v0.21.0

- **Two videos no longer play at once.** Opening something from Downloads now stops whatever
  YouTube was playing. They are both inside the same app, and an iPhone only sorts this out
  between separate apps — so YouTube's player had to be told, and was not.
- That is also why sound sometimes stopped when the phone locked: with two players running,
  the one being managed in the background was not always the one you were listening to.
- **Rename anything you have saved.** Swipe a row. The file is renamed on disk too, so it
  arrives with that name when you share it or send it to Photos.
- **A welcome screen on the first launch**, saying where saved videos go and how to reach
  the settings. Once, and never again.

## v0.20.2

- **The feed is back.** Last release widened what counts as an advertisement and it went too
  far — it was dropping ordinary videos along with the sponsored ones. That change is undone
  entirely; ad hiding is back to exactly what it was in 0.20.0, which worked.
- Sponsored rows on Home are therefore still there. They will be dealt with properly, from
  what the app actually reports rather than from a list written by hand.
- Diagnostics now really does show how much of the feed was checked and dropped. That line
  was supposed to ship last release and did not, which is why a change to what gets hidden
  went out with no way to see what it hid.

## v0.20.1

- **Sponsored rows on Home should go now.** The list of what counts as an advertisement was
  written by hand, so it only ever covered the kinds someone had thought of. It is taken
  from YouTube's own build this time — including the wrapper every feed advertisement
  arrives in, which catches the kinds nobody has seen yet.
- If any still get through, Settings → Diagnostics now says how much of the feed was checked
  and how much was dropped. That tells apart "it never looked" from "it looked and did not
  recognise it", which are different problems with the same complaint.
- Fixes the release itself failing to publish.

## v0.20.0

- **The Download Centre is a page now, not a window.** Tapping the tab changes what is on
  screen and leaves everything else where it was: the tab bar stays, the Downloads tab
  lights up like any other, and tapping Home or You takes you straight back. It opened as a
  panel sliding up over the whole app before, which is why it felt bolted on — because it
  was.
- **Video and sound are a switch at the top**, in the title bar, instead of a second row of
  tabs sitting just above YouTube's own. One page with two views of it.
- Opening it from settings still opens a panel, since there is nothing behind it to be part
  of — but it is the same page, so the two can no longer drift apart.

## v0.19.1

- **It remembers where you stopped.** Open something again and it carries on from where you
  left it — including after the app has been closed for days. Not for the first few seconds
  or the last few: those are not places anyone stopped in the middle of.
- **Playback speed**, from 0.75× to 2×.
- **A sleep timer** — five minutes to an hour, or simply when the current one ends. The moon
  fills in while it is set, so you can see at a glance whether one is.
- **AirPlay**, from the player itself.
- Fixes 0.19.0, which did not build.

## v0.19.0

- **Turn the phone and the video fills the screen.** It used to shrink into the middle of a
  black field, because the screen rotated and the layout did not. Landscape is now its own
  layout: picture edge to edge, controls floating over it.
- **The controls get out of the way.** They fade after a few seconds of watching and come
  back with a tap — and they stay put while paused, because a paused screen with no
  controls looks broken.
- **Double tap either side to jump ten seconds**, and there are ten-second buttons either
  side of play as well.
- **Picture in picture.** Send the video to a floating window and carry on using the phone.
- **Saved songs have a cover now.** It comes from the video's own picture, and the same one
  fills the player behind it, blurred — so a song looks like a song and not an empty file.
- **Next and previous are back on the lock screen.** Last release quietly replaced them with
  15-second jumps: iPhone shows one pair or the other and never both, and claiming the jumps
  took the other two away. Track buttons are the default now, and the jumps are a setting.
- The lock screen also says where you are in the queue.

## v0.18.1

- **The mark on the Downloads tab should appear now.** It was being written onto the wrong
  thing: a tab is drawn by a button, and the picture was being handed to an image view the
  button either had not made yet or replaced on its next pass. It goes to the button now,
  which also lets the tab fill in when it is the open one.
- It is also drawn again on each layout, so a tab that came up blank the first time fills
  itself in rather than staying blank until the app restarts.
- **Diagnostics now has a Downloads tab section.** Last release could not tell you whether
  a tab had even been built, which made "the icon did not appear" unanswerable. It now says
  what happened at each step.
- Diagnostics also says plainly when dislike counts are simply switched off, instead of the
  same sentence it shows when they are on and not working.

## v0.18.0

- **Dislike counts are back**, if you turn them on. YouTube stopped publishing that number
  in 2021, so it comes from the Return YouTube Dislike archive — an estimate built from
  what its users report, not YouTube's own figure. The setting says so, and it is off until
  you ask for it, because a number from somewhere else is your choice to make.
- **Nothing about what you watch is sent.** The tweak asks for a video's number and
  receives it. It does not report your viewing and it does not submit votes.
- **The Downloads tab has its own mark now**, drawn for this tweak rather than borrowed
  from Apple's symbols, with the label underneath it the way the other tabs have.
- If the number does not appear on the right button, Settings → Diagnostics now lists every
  like and dislike button it found and what each one said. That is the answer, not a guess.

## v0.17.0

- **A quality ceiling, separately for Wi-Fi and for mobile data.** Set mobile to 480p and
  a video on the road stays at 480p, without touching what you get at home. It is a
  ceiling and not a fixed quality — YouTube still drops lower on its own when the
  connection cannot keep up, because the choosing is still YouTube's.
- The tweak notices which connection you are on as it changes, so nothing has to be
  switched by hand when you leave the house.
- **The full quality list is back**, if you want it: every resolution when you tap
  quality, instead of the two-line shortcut newer builds show.

## v0.16.0

- **The Downloads button is a real tab now**, beside the others, instead of a red circle
  floating on top of them. It has a label, it lights up when it is the open one, it takes
  its share of the width, and it moves with the bar — because YouTube draws it, not us.
  Nothing of ours sits on the bar any more.
- If a future YouTube changes the tab bar enough that the tab cannot be added, the old
  round button comes back on its own. The way in never disappears.

## v0.15.0

- **The lock screen has the counter now, and it works.** It was showing the title and
  nothing else. The length was being sent the instant playback began, and at that instant
  the file has not been read far enough to know how long it is — so nothing was sent, and
  no length means no bar at all rather than a short one. It is sent as soon as it is known.
- **Drag it to move.** The scrubber on the lock screen and in Control Centre now seeks,
  instead of springing back where it was.
- **Fifteen seconds forward and back**, on the lock screen, from headphones, and from the
  car.
- The counter also keeps proper time when you pause, instead of carrying on without you.

## v0.14.1

- **The player now really closes.** It was staying alive after you shut it, holding its
  file open and still listening to the lock screen buttons. Open the Centre a second time
  and two players were listening at once: one press of next skipped two.
- Closing it also hands the sound back, so whatever was playing before — YouTube itself,
  usually — is allowed to carry on instead of being left muted.
- **A download landing at the same moment you swipe one away no longer crashes.** Rare,
  but it was a crash and not a glitch, and it got more likely the more you had saved.

## v0.14.0

- **A real player, not a file opener.** Previous, play, next, a scrubber and both times —
  and the list you opened it from is the queue, in the order you were looking at, so next
  means the next one down.
- **Video and sound each have their own tab.** They are not the same thing to look at: a
  saved video wants its own still beside it and a saved song does not, and one list sized
  for both would be sized for neither.
- **Every saved video shows a still of itself**, taken a second in — videos open on black
  or on a title card often enough that the first frame is the least useful picture in the
  file. How long each one runs is shown beside it.
- **Sound keeps playing when you leave.** Lock the phone, switch apps, and it carries on,
  with the title and the picture on the lock screen and its skip buttons wired to the same
  queue. Video does the same: iPhone will not play through a picture nobody is looking at,
  so the picture is put down while you are away and picked up when you come back — the
  sound never stops.

## v0.13.0

- **A Download Centre, with a button beside You.** Everything saved lives in one list,
  and tapping one plays it right there — the tweak has its own player now, so a saved
  video does not have to leave for another app to be watched.
- **Downloads stay yours.** They no longer go to Photos on their own. They are kept in
  the Centre, and sending one to Photos is a swipe when you want it — or a switch in
  settings for anyone who preferred the old ending. Sharing and deleting are swipes too.
- **Sound on its own.** Choose sound instead of video and only the soundtrack is
  fetched — a few megabytes instead of a few hundred, because YouTube keeps them apart.
- **Choosing is one screen now**, with sound or video at the top and the sizes below,
  each saying its bitrate. It replaces a list of eight identical rows that looked like a
  system warning rather than a choice.
- **The progress bar is out of your way.** It used to be a window that held YouTube
  still until the download finished. It is a row in the Centre now, so saving something
  costs you nothing — keep watching, and check on it whenever.

## v0.12.5

- **The sound is now read correctly and joined correctly.** Last release got iPhone to
  read the soundtrack — it reports one proper audio track — and the joining step then
  refused it without saying why. It was asking how long the sound was before anything had
  read it: a bare AAC file carries no index, so its length is not known until the file has
  been gone through, and a length that is not yet a number cannot be used to cut anything.
  Both files are asked to measure themselves first now.
- The two halves are also joined one at a time, so a refusal names which half it was.
  A single message covering both is what sent the last round to the wrong track.

## v0.12.4

- **The soundtrack is read by iPhone's own AAC parser now.** The device settled the last
  question itself: every frame of sound had been found, 7867 of them, adding up to exactly
  the length the video says it is. They were then being rebuilt into a track by our code —
  code no download had ever reached before, because until this month no sound ever got
  that far. It was building nothing.
- So it does not build anything. The marker tags scattered through the file are taken out,
  the frames are left exactly as they arrived, and what remains is an ordinary AAC file of
  the sort iPhone plays every day. Our own route stays as a second attempt if that ever
  fails, and the report says which one was taken.

## v0.12.3

- **The soundtrack is read, not handed over.** 0.12.2 identified it correctly and gave it
  a name iPhone would accept — but the file has a marker tag buried at the start of each
  of its twenty-six pieces, not only at the front, and nothing was obliged to make sense
  of that. It didn't, and said nothing. The tags are stepped over now and the sound is
  unpacked by the same code that already unpacks the picture. The frames were never the
  problem; only what was wrapped around them.
- **Every step that can lose the sound now says so in Diagnostics.** The joining stage
  had three ways to fail and reported none of them, which is what made this take a round
  longer than it should have.

## v0.12.2

- **The sound arrives.** 0.12.0 found where YouTube keeps it and fetched it; it was then
  thrown away at the door. The soundtrack is not wrapped the way the video is — it is bare
  audio, and joining the parts had given the file a name that said otherwise. iPhone
  refused it on the strength of the name alone. The bytes decide now, and it is read the
  way it actually is.
- The device said all of this itself: seven qualities, two soundtracks, and a video track
  carrying no sound in it. Three rounds of reading the report instead of guessing, and
  each round narrowed it to one thing.
- When something still cannot be read, the report now prints what it actually was rather
  than only that it failed.

## v0.12.1

- **YouTube no longer closes the moment a download finishes.** It was not the download.
  Photos answers on a thread of its own, and the reply was being used to close the
  progress window and show a message right there — screen work from the wrong place, which
  iOS does not forgive. Every reply now comes back where it belongs. This was happening
  long before saving ever got far enough to reach it.
- **And if the video cannot go to Photos, it is handed to you instead.** Permission to add
  to the photo library belongs to YouTube, not to this tweak, and YouTube need not have
  it. Rather than asking anyway — which ends the app instantly — that is checked first,
  and the finished video opens in the share sheet where **Save Video** works normally.
- A downloaded file is no longer deleted when saving fails. It used to be, so a download
  that had worked from beginning to end came to nothing.

## v0.12.0

- **Saved videos have their sound.** They were arriving silent, and the reason is that
  YouTube does not always keep the sound in the same place as the picture: a playlist can
  list its soundtracks separately and point the video at one of them. The download read
  only the video half, and the half it skipped was never asked for.
- Both halves are fetched now and joined into one file at the end. Nothing is re-encoded
  for it — the sound is copied in exactly as it arrived — and the sound is trimmed to the
  length of the picture, since a soundtrack often runs a fraction of a second longer and
  the video would otherwise end on a frozen frame.
- **A download that loses its sound now says so** in Diagnostics, along with what the
  video actually contained. A silent file that explains nothing is what made this take a
  release to find; that will not happen the same way twice.

## v0.11.0

- **Saving videos works.** The parts were downloading correctly all along — every one of
  them — and were being thrown away at the very last step, because they arrive wrapped in a
  format iPhone has never been able to open from a file. Nothing was wrong with the
  download. The wrapper was wrong.
- So the wrapper comes off. The video and the sound inside are already exactly what an
  .mp4 holds, so nothing is re-encoded and nothing loses quality — it is unpacked and
  repacked, and it is quick.
- Other tweaks solve this by carrying a whole video-conversion library, between 2 and 19
  megabytes of it. This one carries none. That is why the tweak is still small.
- If it does fail now, it says which part failed: no picture inside, or no room on the
  device. Not one sentence for three different problems.

## v0.10.3

- **The error now tells you what it found**, instead of pointing at a page that had
  already forgotten. Saving still fails on some videos, and 0.10.2 was supposed to record
  why — but the record was being wiped mid-download, because YouTube re-announces a video
  while one is being saved and that was treated as "a new video, start a fresh record".
- So the reason travels with the message. If it fails you will now see the shape of the
  playlist underneath: how many pieces, how many actual addresses, whether ranges are used,
  and what the pieces are named. Those four facts distinguish the three completely
  different problems that all produced the same sentence before.
- The record is cleared when you start a save, which is the moment that actually separates
  one attempt from the next.

## v0.10.2

- **0.10.1 downloaded the same file over and over.** The playlist, the qualities and the
  transfer all worked — and then the result would not open, for a reason that is
  embarrassing once seen.
- YouTube's playlists list each piece as *a range of bytes inside one file*, not as a file
  of its own. The line saying so was being skipped, so the same address was read as though
  it were a hundred separate pieces — the whole file fetched a hundred times and glued
  end to end. Of course nothing could read it.
- Now that line is understood, and it makes things simpler rather than harder: when the
  pieces are all ranges of one file, **that file is the video**. It is fetched once, and
  there is nothing to join at all.
- The report also says what shape the playlist turned out to have — how many entries, how
  many actual addresses, whether ranges are used. "The pieces would not join" describes a
  symptom and names none of the three things a playlist can be.

## v0.10.1

- Fixes the build of 0.10.0, which never shipped. Everything it describes is in this one.

## v0.10.0

- **Saving videos, at last.** Hold a video and the qualities appear; pick one and it goes
  to Photos, with a percentage while it works.

- What made it possible was the report from 0.9.2, and it is worth saying what it found:
  every individual quality on this build arrives without an address, but **the playlist
  that lists them has one**. Nine releases of measurement to be sure of that — through the
  media layer, the format details nested inside it, the player's own response, and four
  different ways of asking YouTube directly. All of them agreed.

- That is also where every other tweak that can save videos ends up. The difference is
  what they carry to do it: each of the four taken apart along the way bundles a media
  library of 2 to 19 megabytes for this one job.

- **This does not.** The pieces YouTube serves join end to end into a file iOS reads
  directly, so the last step is a copy rather than a conversion. If a video turns out to
  be served in the other form, it says so plainly instead of leaving something broken in
  your library.

- Qualities that would download and then refuse to play are filtered out before you are
  offered them, not after.

## v0.9.2

- Asks two more questions in the same place 0.9.1 started asking, because taking apart
  **YTLite** — whose downloading works — showed it reads exactly that one field and nothing
  else of the kind.
- Its 20 MB is 19 of them spent on a media library, which understands playlists natively.
  That is the whole trick: where individual qualities have no address, the playlist that
  lists them does.
- So the report now also says whether the video has playlist data at all, and how many
  entries it holds. Between those and 0.9.1's three addresses, the next report answers
  whether saving videos is possible on your build — and if it is, by which route.

## v0.9.1

- **0.9.0's change worked**: the search now reaches the video's real format list, all
  twenty of them, through the information YouTube hands over when a video starts. That
  part is solved and stays solved.
- And it answered the question that has been open since the beginning, definitively:
  **twelve of those formats are in codecs iOS cannot play, and the other eight carry no
  download link.** Not one. This build of YouTube fetches video in pieces and never
  receives a plain link for anything — which is why nothing found anywhere in the app has
  ever had one.
- So this release looks one level up, at the three addresses the video's stream list holds
  for *itself* rather than for each quality. One of them is a playlist of ordinary
  segments — the kind iOS knows how to download natively — and another is the piecewise
  protocol's own endpoint, which would mean the opposite. **Which one is present decides
  whether saving videos is a week of work or a different project entirely**, and nothing
  has ever looked.
- Also fixed: a whole second source was quietly finding nothing, because it was reaching
  for the video through something that does not hold one. It goes through the right object
  now.

## v0.9.0

- **The trace from 0.8.4 found it, and it was an argument being thrown away.**

- When a video starts, YouTube tells the tweak three things: which controller, which video,
  and the *playback data*. The first two have been used since the beginning. The third was
  ignored — and it is the one that carries both halves of what saving a video needs: the
  video's format list, and the session number the links are signed against.

- That number is what every stream in the report was showing as a bare `?cpn=…`. Not a
  broken link, but a pointer at where the real one is kept. Six releases were spent reading
  the fragment as though it were the answer.

- 0.8.4's trace also explained the other failure plainly: the controller it had held on to
  was alive but had gone quiet — YouTube builds one of those per surface, and the one that
  last announced a video is not the one still playing it by the time you hold the video
  down. Nothing found through it could have worked. The playback data is handed over at the
  moment it is true, so nothing has to be searched for or kept fresh.

- The session number is now used for the links rather than a fresh one made up on the
  spot. YouTube's server has never seen a made-up one.

## v0.8.4

- Includes the crash fix from 0.8.3, which never had a chance to be installed.
- **Looks for the video's formats in five more places.** Comparing against DLEasy — whose
  downloading works — showed it reaching them by different names than the two tweaks
  looked at before it. None of the names is guaranteed to be the right one on your build,
  so all of them are tried, and the report says which one actually answered.
- That is the useful part: rather than another guess, the next report will name the exact
  step where the search succeeds or stops.

**What is now known for certain**, from the fixed measurement in 0.8.2 and 0.8.3:

- The streams the app keeps for *playback* carry no download link. Not under any name, and
  not in the format details nested inside them. That question is closed.
- Asking YouTube directly over the network is refused: two identities rejected outright,
  two others answered properly and said the video was unavailable to them.
- Which leaves the player's own response — the one place that has never yet been reached
  without something failing first. This release is about reaching it.

## v0.8.3

- **Fixes the crash in 0.8.2.** Install this over it. Holding a video to save it took
  YouTube down, and that was a mistake I introduced in the previous release.
- Reading a format's number — its quality id, its height, its bitrate — went down a path
  that only works for text. The number came back as though it were an object, and the very
  next step treated it as one. It happened on the first field of the first format, so it
  crashed every time.
- The previous code read these correctly. Changing it was an optimisation nothing had
  asked for, applied where the answer's type is not known in advance.
- **And the search can no longer take the app down at all**, whatever goes wrong in it —
  the same rule the settings screen has followed since 0.1.4. A tool whose job is to
  explain what is happening must not be the reason the app stops.
- One thing the fixed report did settle: the streams the app holds for playback really do
  carry no download link, under any name. That was previously a guess from a broken
  measurement; it is now measured. What remains is the other place, which the crash
  prevented from ever being reached.

## v0.8.2

- **The diagnostics page has been misleading me for four releases, and this fixes it.**

- When it listed what each stream offered, it asked for the link under eleven different
  names — and stopped at the first one that answered anything at all. The first name
  answers with `?cpn=…`, a fragment rather than a link, so it printed that and **never
  tried the other ten, not once**. "There is no link anywhere in the app" was a conclusion
  drawn from a list of one name.

- Everything since 0.7.0 followed from that: asking YouTube over the network, four
  borrowed client identities, and all of it refused. None of that work was wrong, but it
  was answering a question that had never actually been asked properly.

- So: the report now lists **every** name that answers, and the search for something to
  download reads every name too, plus the format nested inside — taking the first that is
  genuinely a link rather than the first that replies.

- The source written off as a dead end in 0.8.0 is back in the search, for the same
  reason: it was written off on the strength of that same one-name probe.

- Comparing against **YouMod** by Tonwalter888 is what surfaced this. It reads exactly the
  same places this tweak does — it makes no network request at all — and the only
  difference was that it falls through to the next name where this one stopped.

## v0.8.1

- **The report now says what happened when it looked inside the app**, which 0.8.0 left
  out entirely. It recorded that path only when it worked, so a failure left no line at
  all and the report jumped straight to the network attempts — reading as though the app
  had never been asked.
- Three completely different outcomes were indistinguishable: the search stopping early,
  the app holding formats with no links, and it holding formats in codecs iOS cannot play.
  Each step is now named with what it actually returned.
- **A third place to look**, at no cost: the player response the video overlay is handed,
  which this tweak has been holding for the report since its first release and never read
  when searching for something to download.
- The four attempts in 0.7.3 all came back refused, and their messages are now specific
  enough to be worth reading: two were rejected outright, and two answered properly but
  said the video was unavailable *to them*. That is the request being understood and
  declined, which is different from it being malformed — the headers added in 0.7.3 did
  their job.

## v0.8.0

- **The links were in the app the whole time, in a place nobody had looked.**

- Everything so far read one source: the media layer's streaming data, whose streams
  answer with `?cpn=…` instead of a link because that layer fetches byte ranges rather
  than files. That is a genuine dead end — there is nothing in it to find, which is why
  every probe came back empty and why 0.7.0 went looking on the network instead.

- But the app holds a *second* set of streams for the same video. The player keeps its own
  player response, and inside it the formats do carry links. Same app, same video, a
  different object graph, and seven releases went past it.

- So the player is asked first now. When it has the formats, **nothing is asked of YouTube
  at all** — no request, no borrowed client identity, nothing that can stop working when
  Google changes something. The network path stays as a fallback for when it does not.

- The `HTTP 403` and `HTTP 400` from 0.7.3 are still worth having fixed, and that work
  stays: better headers, four client identities, and the server's own error message in the
  report rather than a bare status code. It is just no longer the first thing tried.

- Found by reading **YouMod** by Tonwalter888 (GPLv3, as this is), which reads both sources
  and takes whichever answers. Every selector was then checked against a real 21.30.5
  binary before being used — the credit is in the code and in the package description too.

## v0.7.3

- **Asking for the video id was fixed in 0.7.2 and it worked** — the request now goes out
  for the video actually on screen. YouTube refused it anyway, with two different errors,
  and 0.7.2 reported only the numbers: `HTTP 403` and `HTTP 400`.
- **The report now shows what the server said**, not just the status. YouTube explains a
  refusal in the reply, and throwing that away meant a report that said the wall was hit
  without saying which wall.
- The request was also missing headers YouTube expects. It declared which client it was
  in the body but not in the headers, and the server checks both — which is what an
  `HTTP 400` on an otherwise well-formed request means.
- **Two more client identities to fall back on**, both embedded-player ones. Those tend to
  outlive the rest, because a page embedding a video has to be served something. The two
  in 0.7.2 came from a tweak whose build predates whatever changed at YouTube's end.
- The report lists one round of attempts instead of every press stacked up.

**Being straight about this:** downloading from YouTube is an arms race, and this release
is a move in it, not a settlement. If these four are refused too, the report will now say
precisely why — and the answer may be that this route is closed and the one worth taking
is YouTube's own download machinery, which is already on the device and already knows how
to fetch these streams.

## v0.7.2

- Fixes the build of 0.7.1, which never shipped: the diagnostics header promised three
  things the code behind it did not have. Everything 0.7.1 describes is in this one.

## v0.7.1

- **The download was asking YouTube about the wrong video.** A report made it plain:
  SponsorBlock was working on one video id while the diagnostics page reported a different
  one as the last played. The download used the second — so it asked YouTube for a video
  nobody was watching, and reported back that it was private or blocked. It was neither.
- The cause: YouTube builds a video object for each clip it *preloads*, not only the one
  on screen, so "the last one made" is not "the one playing". The download now uses the
  video the player actually started, which is the same one SponsorBlock has been using
  correctly all along.
- The diagnostics page prints both ids when they disagree, so this cannot hide again.
- And it now lists every attempt to fetch formats — which client was asked, and what it
  answered. "No downloadable formats" covered a client being refused, a client answering
  without links, and a client never replying; those need different fixes and now they read
  differently.

## v0.7.0

- **Downloading works.** This is the release the last six were leading to.

- The reason it did not work before is worth writing down. Every format the app was
  holding had no link on it — just `?cpn=…`, a fragment. Four of them were in H.264, which
  iOS plays perfectly well, so the codec was never the problem: YouTube 21.30.5 simply is
  not given file links any more. It streams in pieces, asking for ranges. Nothing this
  tweak could read out of the app was ever going to produce a downloadable file.

- So it asks YouTube directly instead, the same way every working YouTube downloader does:
  a fresh request for the video's formats, made as one of the clients that is still served
  plain links. Those come back ready to fetch, and the rest of the pipeline — pick a
  quality, fetch, join picture and sound, save — already worked.

- **What that means for privacy, plainly:** the video's id goes to YouTube. Not to anyone
  else, on the same connection, for the video it is already streaming to your phone a
  second earlier. That is a different thing from the SponsorBlock lookup, which is asked
  by fingerprint precisely so a *third party* cannot learn what you are watching.

- When YouTube refuses a video — private, age restricted, blocked in your country — the
  message now says which, in YouTube's own words rather than a guess.

- No extra weight. A well-known tweak does this by carrying a 25 MB media library to join
  the audio and video back together; this joins them with what iOS already has, which is
  possible because the formats are filtered to the codecs iOS can handle in the first
  place.

## v0.6.1

- **Holding the video works now.** In 0.6.0 the gesture was added and never fired once.
  A gesture added to a view in an app that already has its own does not simply share the
  screen with them — iOS lets one win, and YouTube's player is covered in them. Ours lost
  every time, silently, which looks exactly like a gesture that was never added.
- **The "nothing to save" message was misleading, and this is the important part.** A
  report showed twelve formats: eight in codecs iOS cannot play, and **four in H.264,
  which it can**. The message said "all in a codec iOS will not play", because eight is
  more than four. What was actually stopping the download is that those four carried no
  link to fetch.
- So the message now names the wall that blocks the formats that would otherwise work,
  not the one that happens to affect the most of them.
- The diagnostics page now also opens up what is nested inside each stream, which is the
  one place a link could still be hiding. If it is not there either, then this build of
  YouTube hands out no file links at all — and that is worth knowing for certain rather
  than assuming, because it decides whether downloading is a small feature or a different
  project entirely.

## v0.6.0

- **Hold the video to save it.** No need to open settings first. The settings row is
  still there, but nobody opens a settings screen to save the thing they are watching.
  One finger, a little over half a second, and the gesture never swallows a touch — tap
  to pause, scrubbing and YouTube's own hold-to-speed all keep working.

- **Audio on its own.** Last entry in the quality list. It saves to Files rather than
  Photos, because Photos refuses audio, and the share sheet opens on it so it can go
  into Files, Music or a message in one step.

- **"Nothing to download" now says why.** It stood for three completely different
  situations: no stream information yet, formats with no link to fetch, and formats in a
  codec iOS cannot play. Each gets its own sentence now, and the codec one names the
  format numbers — so a report of this actually says what to do about it.

- Fixes, all found reading the 0.5.0 code rather than on a device:
  - Every download that had to merge audio left **both source files behind** — tens of
    megabytes each, per download. Only the merged file was ever cleaned up.
  - **"Saved without sound" never appeared.** The message was built and then discarded,
    so a silent file was always reported as a clean save.
  - The **"Saving…" alert could stick on screen with no buttons**, needing YouTube to be
    force-quit. Dismissing an alert that is still animating in is ignored by iOS, and a
    link that would not parse triggered exactly that, every time.
  - A **failed merge was reported as success** — you got a silent video and were told it
    saved fine. Neither track insertion was checked at all.
  - The **SponsorBlock markers were rebuilt on every layout pass** of the player bar,
    which runs constantly during playback. They now redraw when something actually
    changes.

- **Next:** the download centre — a list of what you have saved, with the audio player
  and gallery inside the app. Deliberately after this release: a centre for a downloader
  that cannot yet produce a file on your build would be building the hard half first, and
  the message above is what tells us which half is hard.

## v0.5.0

- **Downloads.** Open the panel over a video and there is a row that saves it to Photos,
  at the quality you pick, up to 1080p60.

- **No button is added to YouTube.** Every other tweak that does this puts one in the
  player controls, which means hooking view classes that get renamed between releases —
  the survey behind 0.1.3 found nineteen dead class names in one such tweak. The row
  lives in our own panel, which cannot go stale, and it acts on the video the player is
  already holding.

- Above 360p YouTube sends picture and sound as separate files. Both are fetched and
  joined on the device with AVFoundation; because only H.264 and AAC are offered in the
  list, the join is a copy rather than a re-encode, and no FFmpeg is carried to do it.
  If the sound cannot be fetched, the silent file is still saved and the message says so
  rather than pretending.

- Only formats iOS can actually play are offered, chosen by itag rather than by MIME
  type: YouTube serves VP9 and AV1 in containers that download happily and then show a
  black frame.

- The diagnostics page gains a "Saveable" line, so a video that offers nothing says so
  before you try.

_Method derived from [YouMod](https://github.com/Tonwalter888/YouMod) by Tonwalter888
(GPLv3): where the format list lives, that the real link hangs off the stream's nested
formatStream rather than the stream itself, the itag sets, and the query handling that
makes a link fetchable at full speed. Those cost that project real time to work out._

## v0.4.5

- **The streams section, asked properly this time.** 0.4.4 got the ladder — 22 formats,
  itags, resolutions up to 1080p60 — and then failed on the three things that matter
  next. It listed what a stream "offers" by reading only its own class, and the
  accessors are on the superclass, so it printed nothing at all. It printed the type as
  an address, because MIMEType is a wrapper rather than a string. And it reported the
  URL as `?cpn=…`, a query fragment, without saying which of the possible names that
  came from.

  All three are fixed: the class chain is walked, wrapped values are unwrapped, and
  eleven names a stream might keep a real link under are tried with the answering one
  printed beside it. Whether this build hands out fetchable links is the one question
  standing between here and downloads.

## v0.4.4

- **The diagnostics page opens.** 0.4.3 guessed at why it crashed and guessed wrong —
  it was not the size of the report. The copy button was held only by a weak reference,
  so nothing retained it and it was released before the next line ran; the layout then
  tried to pin the text view to an anchor that was gone, and the exception said so in
  a way that reads like nonsense until you know that. The guard added in 0.4.3 is what
  printed it. It is held properly now.

- **The streams section finally says something.** It printed `<MLStreamingData: 0x…>`
  and nothing else, because that class is not a protobuf and does not describe itself.
  Every format list it carries is now enumerated — itag, type, resolution, frame rate,
  bitrate, and whether there is a plain URL — and if none answers, the report lists what
  the object can be asked instead, from the runtime rather than from guesswork.

  This is the measurement the download feature has been waiting on since 0.1.0.

## v0.4.3

- **The diagnostics page no longer takes YouTube down when opened.** It printed the
  whole player response — a protobuf rendered as text, hundreds of kilobytes on a
  real video — into a single text view. The page now shows the first 40 KB and says
  where it stopped; the file on disk still holds all of it, and the copy button still
  copies the lot.

  The page is also wrapped now, the way the settings panel around it always was. It
  was the one part left unguarded, which is a poor place for the exception to be: a
  page whose job is to explain a failure must never be one.

  Worth saying plainly: this is why the download feature is still "being measured".
  The measurement was written to a page nobody could open.

## v0.4.2

- **The package page, actually readable this time.** 0.4.1 gave Sileo a page but
  filled its What's New tab with the changelog pasted in whole — and Sileo does not
  render headings, so it came out as a literal `## v0.4.1` on top of a wall of prose.
  Each version is now a heading of its own with its changes listed under it, one line
  each. The reasoning stays in this file, where there is room for it.

- The description is shorter and no longer drawn with block characters, which not
  every font has.

## v0.4.1

- **A proper package page.** Sileo had nothing to render but the raw description
  field — a wall of prose, where the Instagram package has a tabbed page with
  headings and a changelog. It has one of its own now: what each feature does, what
  it was tested against, and who is credited.

  Nothing in the tweak changed. The generator that writes Instagram's page simply
  had Instagram written into it, so this taught it the difference between the two
  rather than adding a second script to keep in sync with the first.

## v0.4.0

- **The coloured markers, which 0.3.0 said were not ready.** Each segment is now drawn
  on the progress bar in its SponsorBlock colour, so what is coming is visible before it
  arrives. Its own switch, under SponsorBlock.

  This is the only place the tweak hooks a view, and the reason it is safe now is not
  courage: the markers are laid out with **frames, never constraints**. The layout engine
  is what took 0.1.1 and 0.1.3 down, and a rectangle at start ÷ duration × width does not
  need it. Drawing is wrapped as well — a fault there costs the colours, never the video.

  All three bar classes are hooked, because which one a build renders cannot be read off
  the binary, and the diagnostics page now says which one was found.

- **Credit where it is owed.** The markers are derived from
  [iSponsorBlock](https://github.com/Galactic-Dev/iSponsorBlock) by Galactic Dev, which
  is GPLv3 as this is: the bar class names, the placement arithmetic, and the detail that
  they must be redrawn the moment segments arrive rather than only on layout — which is
  what makes them appear at all, and would have cost several builds to find by trial.
  Credited in the settings screen and the package description as the licence requires.

- Reading the video's identifier no longer depends on one accessor: the video object is
  asked first, then the player controller, which is where iSponsorBlock reads it.

## v0.3.1

- **Fixes skipping, which never once worked in 0.3.0.** The feature asked the video
  object for its identifier under four names, and the one this build actually uses was
  not among them — so every lookup came back empty and the tweak returned before it had
  asked SponsorBlock for anything. Nothing was broken downstream; nothing downstream
  ever ran.

  The right name was already in this repository: the diagnostics page has been reading
  it since 0.1.0, having measured it rather than assumed it. That is the whole lesson
  again, one level down — a class name copied from another project is a lead and not a
  fact, and so is an accessor name.

- **And the report now says which of the three it was.** "Nothing was skipped" looked
  identical whether the ID could not be read, no segments matched your categories, or a
  skip happened and you missed it. The SponsorBlock line names it.

## v0.3.0

- **Skips the sponsored parts.** Paid plugs, the creator's own promotion, and subscribe
  reminders are jumped over automatically, using segments other viewers submitted to
  SponsorBlock. A short line at the top names what was skipped and offers an undo, so a
  wrong segment costs one tap rather than a rewind.

- **Eight categories, each with its own switch.** Sponsor, self-promotion and subscribe
  reminders are on. Intros, endcards, recaps, tangents and non-music sections are off
  until you turn them on — somebody chose to make that content, and deciding for you
  that it is worthless is not this tweak's call.

- **Your video is never sent.** SponsorBlock offers two ways to ask, and this uses the
  one that sends only the first four characters of the video's fingerprint — so the
  reply covers many videos and the server cannot tell which one you are watching. The
  other way is simpler and would report every video you play to a third party, which for
  a tweak with a privacy half would have been a strange thing to do.

  The cost is paid here instead: that endpoint returns the raw submissions rather than
  the server's curated pick, so downvoted and non-skip segments are filtered on the
  phone.

- Nothing is requested at all when the feature is off, or when every category is off.
  Not requested and discarded — not requested.

- Segment data is from SponsorBlock (sponsor.ajay.app), licensed CC BY-NC-SA 4.0 and
  credited in the settings screen. That is a licence condition, not a courtesy.

- **Not yet:** the coloured markers on the progress bar. Those need a hook on a view
  rather than the player, and views are where this tweak's earlier crashes came from —
  it will come once it can be done without risking the skipping that already works.

## v0.2.0

- **No ads.** Blocked at three separate points, because ads arrive by three separate
  routes and stopping one does nothing about the others: the app stops asking YouTube
  for ads at all, promoted rows are dropped out of the feed, and the player refuses ads
  before a video, mid-video, and the kind stitched into the stream itself.

  The feed filter matches on the identifiers YouTube's own servers attach to promoted
  rows — including plain-sounding layouts with no "ad" in the name, which are the ones a
  hand-written list always misses.

- **Background playback.** Audio keeps going when you leave the app or lock the screen.

- **Silence the update prompt**, since updating YouTube replaces the app and removes
  this tweak. And optionally hide the paid-promotion banner — off by default, because
  it is a disclosure and removing one for everybody is not this tweak's call.

- **A real settings screen at last.** Hold two fingers anywhere in YouTube. Sections,
  switches, Arabic and English with right-to-left layout, and a card at the top that
  says whether everything actually attached to *your* build instead of leaving you to
  wonder.

  Built on a standard grouped table this time. Three releases in a row either failed to
  appear or crashed, the last one inside the layout engine while assembling a panel out
  of hand-written constraints. A table has almost none of that surface — the system does
  the layout.

- Ad hiding, background playback and the update prompt are **on by default**; they are
  why you would install this.

## v0.1.4

- **Fixes the crash when opening the panel in 0.1.3.** Install this over it.
- The cause was in the panel's own layout, and the honest version is that the crash
  report could not point at the exact line. So this release does not guess at one — it
  removes the room for the mistake instead. Each row now has a single fixed height set
  in one place, where three different things used to be sizing it at once.
- **And the panel can no longer take YouTube down at all.** Building it is now wrapped:
  if anything in it goes wrong, the panel simply does not open and the report says what
  happened, under "The panel could not be built". A tool whose job is to explain what is
  going on must never be the reason the app dies — that was true of 0.1.1 and 0.1.3 and
  it is now enforced rather than intended.
- Nothing else changed. The report still writes itself to
  `Documents/AlbrhiYT-report.txt` at launch and on every video, so it is readable whether
  or not the panel opens.

## v0.1.3

- **The panel is back, and it is ours.** Hold **two fingers anywhere in YouTube** for
  about half a second and it opens. Inside: verbose logging, and the diagnostics report.
- Why not inside YouTube's own settings, after two goes at it? Because the crash report
  from 0.1.1 named the exact reason, and it is not fixable by trying harder: putting a
  section there means satisfying a contract with tables the tweak has no access to. The
  tweak that this project studied for its hook points does not do it either — it carries
  its own panel. That is the right shape, not a workaround.
- A survey of that tweak's targets also found **nineteen class names it uses that do not
  exist in YouTube 21.30.5 at all** — including the obvious place to hang an entry point.
  So this one hangs off `UIWindow`, which is part of iOS and cannot go missing.
- **Two fingers, not one**, so it never fights YouTube's own long presses — on a video,
  in comments, on the player. And the gesture never swallows a touch: everything under
  it keeps working exactly as before.
- The report is still written to `Documents/AlbrhiYT-report.txt` as well, at launch and
  on every video. The panel is now a second way to reach it, not the only way.

## v0.1.2

- **Fixes the crash when opening YouTube's settings in 0.1.1.** Install this over it.
- The cause: 0.1.1 added a settings section of its own, and a section is not something
  a tweak can simply announce. YouTube looks the new entry up in its own tables for a
  title, an icon and a page identifier — and an entry those tables have never heard of
  is not an empty row, it is a crash.
- So the section is gone again for now, and will come back once the rest of what
  YouTube expects is known rather than assumed. A settings panel that stops the app
  opening its settings is worse than no panel.
- **The report is unaffected**, because it never depended on the panel: it is written
  to `Documents/AlbrhiYT-report.txt` inside YouTube's own folder, at launch and
  whenever a video plays. That is the whole purpose of these early versions and it
  still works.
- The report now also lists YouTube's settings groups with the number each one carries,
  which is exactly what the next attempt needs — measured from your build instead of
  guessed at twice more.

## v0.1.1

- **The Albrhi section now actually appears in YouTube's settings.** In 0.1.0 it did
  not, and the reason is worth writing down: YouTube 21.30.5 builds its settings screen
  out of *groups*, and the list 0.1.0 added itself to is a different, older list that
  the screen no longer reads. The category was added somewhere nobody looks.

  It is now added to the group list the screen is genuinely built from, and which group
  is decided by asking YouTube rather than by picking a number and hoping.

- **The report no longer hides inside the thing that can fail.** 0.1.0 put the only way
  of finding out what went wrong behind the settings section — so when that section did
  not appear, there was nothing to read. The report is now also written to a file inside
  YouTube's own folder (`Documents/AlbrhiYT-report.txt`), refreshed at launch and
  whenever a video plays, and the tweak logs one line at launch saying it loaded.

- The report also lists the settings groups YouTube built, with their names and numbers,
  so a future version that reorders them says so instead of quietly vanishing again.

## v0.1.0

- **First release, and deliberately small.** It adds an *Albrhi* section to YouTube's
  own settings, with two things in it: verbose logging, and a diagnostics page.
- **Nothing about YouTube changes.** No downloads, no ad removal, nothing touched in
  the player. Installing this and using YouTube should feel exactly as it did before —
  if it does not, that is a bug worth reporting.
- **The diagnostics page is the point.** Play a video, then open it: it prints
  everything YouTube told the app about that video — every quality, every format,
  every stream — and copies the lot with one tap.

  That report is what the download feature will be built on. Downloading from YouTube
  is not a matter of grabbing a link, and which of the possible routes is actually
  open cannot be read off the app from the outside. It has to be measured on a real
  phone, on a real video. Guessing instead is how the Instagram quality picker took
  three attempts.
