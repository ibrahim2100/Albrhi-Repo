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
