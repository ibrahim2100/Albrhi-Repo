# Albrhi for Locket — what changed

## 0.2.0

**Save a moment.** A friend’s photo or video, kept to your Photos at full size — the one they
sent, not a screenshot.

- **Hold two fingers anywhere in Locket** and every moment it has loaded since you opened it
  is listed, newest first. Tap one to save it.
- **Full quality**, photo or video, worked out from what Locket actually downloaded rather
  than guessed.
- Because Locket is built in Swift, a moment is not something a normal tweak can read from
  the screen — so the list is built from what Locket fetches over the network, filtered to
  the moments a friend sent and away from the app’s own artwork. A clear button empties it.

It saves what is already on your phone and does not touch anything you would pay Locket for.
A tool that fakes a paid subscription was asked for and not built — that takes money from the
people who make the app.

## 0.1.0

The first release. It keeps Locket from reporting your phone as jailbroken.

- **Three companies stop being told.** Locket's analytics (OneSignal), its ad attribution
  (AppsFlyer) and its own code each run a jailbreak check and send the answer home. On a
  modified phone that answer can count against your account. All three now come back clean.
- **It answers only the jailbreak questions.** The checks ask the system a small fixed set —
  is this file here, can this app be opened, is this folder writable, is this library
  loaded. This sits underneath and answers only those, only for the handful of paths a
  check looks at. Everything else the app asks the system passes straight through.
- **Hold two fingers anywhere in Locket** for a small screen that shows how many checks were
  answered and which kind, so you can see it is working — Locket itself gives no sign.
- Arabic and English, and it appears in Settings › Albrhi with the rest.

It does not touch payments or subscriptions. A tool that unlocks paid features by faking a
subscription was reviewed and deliberately not built.
