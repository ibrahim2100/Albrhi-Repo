# Albrhi for Locket — what changed

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
