# Issuing Albrhi licence keys

## Once, ever

```bash
python3 tools/licence.py keygen
```

Writes the private key to `~/.albrhi/licence-ec-private.pem` and prints the public half as a C
array. **The private key never goes in this repository, in a build, in CI, or in a message** —
anyone holding it can mint keys for every device forever. A new keypair invalidates every key
already issued, which is why `keygen` refuses to overwrite one.

The public half is already embedded in `shared/src/SCILicense.m`. Re-run `python3
tools/licence.py pubkey` and paste it there only if the keypair is ever deliberately replaced.

## The panel — the usual way

<https://ibrahim2100.github.io/albrhi-repo/licence-panel/>

Issue keys, keep a ledger of what has been issued, and build the revocation list, from a browser —
on a phone as readily as on the Mac. Load the signing key once:

```bash
python3 tools/licence.py export-web
```

and paste the result into the page's first box. WebCrypto cannot import the key file as it sits on
disk (it is SEC1; `importKey('pkcs8', …)` is the only EC import the API offers), which is the only
reason that command exists.

**The page is public and the key is not.** It is served beside the APT index and does nothing at
all until a key is loaded into it. Signing happens in the browser; there is exactly one network
call in the whole file and it is a read of the published revocation list. It is deliberately not
linked from the repository's landing page — there is nothing to protect, and nothing to advertise
either.

**"Remember the key in this browser" is off by default.** With it on the key sits in that
browser's localStorage: convenient, and worth exactly as much protection as the device. On a
shared or lost phone that is a signing key somebody else now holds.

Two guards worth knowing about, because both catch a mistake whose symptom would otherwise appear
days later on somebody else's phone:

- **The loaded key is proved against the public half compiled into the tweak**, by signing a probe
  and verifying it. A key from a *different* keypair mints licences no device on earth accepts;
  the page refuses to issue at all and says so.
- **Every issued key is verified before it is shown.** One that does not check out is not handed
  over — the alternative is finding out through a support thread.

## The request → approve flow

The buyer does not read a device code out any more. In **Settings › Albrhi › Licence** they tap
**Request a licence**, pick a duration, and get a short string:

```
ALBREQ1.eyJkYXlzIjoxODAsImRldiI6ImEzMWQ….b4de
```

They send it however they already talk to you. Paste it into the panel's **الطلبات الواردة** box —
several at once, one per line — and each becomes a row with the device, the name and the duration
asked for. **Approve fills the issue form rather than signing behind your back**: the duration and
the name are still yours to change before the key is minted.

The request is **not signed**, deliberately: there is nothing on a phone to sign it with, and
nothing in it worth forging — it is a question, and you answer it. The four characters on the end
are a *check*, for a typo picked up in a chat window, and they are called a check everywhere they
appear so nobody comes to read them as a signature.

## Short codes

For selling without a conversation: **ALB-4K7M-9QX2-P3RT**, twelve characters, typeable and
readable down a phone line.

Mint them in the panel — how many, how long the licence runs, and how long the code stays
redeemable — then copy `codes.json` and replace `licence/codes.json` in this repository. The
device hashes what was typed and looks that hash up. **The file holds hashes and never codes**, so
publishing it hands nobody a working code.

The alphabet has no I, L, O or U, and the device folds the confusable characters back in before
hashing — `ALB-OA82…` and `ALB-0A82…` are the same code, whichever way somebody heard it.

**The clock starts at redemption, not at minting.** A code sold in January and redeemed in March
runs a year from March; anything else quietly sells somebody two months less than they paid for.

**What cannot be engineered away without a server:** a code is not bound to a device until it is
redeemed, so one code works for everybody who gets hold of it until its hash is removed from the
file. Its two protections are the redemption window it carries and removal. That is the trade for
a code short enough to type, and it is why device-bound keys remain the better instrument for
anything that matters.

Redemption is the one moment in this whole layer that needs the network, and it needs it once.
"The list could not be read" is reported as exactly that and never as "no such code" — telling
somebody their code is wrong because a café's wifi asked them to sign in is the shape of support
message this design exists to avoid.

## Issuing from the terminal

The buyer opens **Settings › Albrhi › Licence** and sends the sixteen-character device code.

```bash
python3 tools/licence.py issue <device-code> --days 365 --name "who it is for"
```

The key goes to stdout; everything else — expiry, and the id to revoke it by — goes to stderr, so
`... | pbcopy` copies the key alone.

Keep the ids. They are the only way to withdraw a key later; the panel keeps them for you, the
terminal does not.

Both issuers produce the same format and were checked against each other and against the device's
own verifier — a key signed in the browser is accepted by the Objective-C code that runs on the
phone, and by `licence.py verify`, and the reverse.

## Checking one

```bash
python3 tools/licence.py verify <key>
```

Verifies with the public half alone, which is exactly what the device does — so the format is
exercised by the same rules on both sides.

## Withdrawing one

The device asks `https://ibrahim2100.github.io/albrhi-repo/licence/revoked.json` at most once
every six hours:

```json
{ "revoked": ["QlVwnd00Ztq8", "…"] }
```

The panel builds this file for you: mark a key withdrawn in the ledger and copy the result. Add
the id, commit, and the key stops working on every device that reaches the file. **Only a
200 with real JSON counts**: a timeout, a 500 or a captive portal's login page is never read as
"revoked", because that would take a paying user's features away over a coffee shop's wifi.

## What happens on the device

| state | what the tweaks do |
|---|---|
| enforcement off *(shipped default)* | everything, exactly as before the licence layer existed |
| valid key | everything |
| valid key, server unreachable for under a day | everything |
| valid key, server unreachable for over a day | tweaks stand down |
| no key / expired / wrong device / revoked | tweaks stand down |

"Stand down" means `SCIPanelAllowsThisApp()` answers NO, which every tweak already asks before
installing a single hook — so the app behaves as if Albrhi were not installed. Nothing crashes and
nothing is half-patched.

## Turning it on

**Enforcement is on as of Panel 0.9.27.** It shipped off for the two releases before that, which
was the point: introduce the layer, prove it end to end on a real device, then turn it on.
Introducing a gate and enforcing it in the same release would have stopped every existing install
on the next update, before a key existed to fix them with.

It can always be switched off again in Settings › Albrhi › Licence — that page is a Settings
bundle and never asks the gate, so nobody can be locked out of the screen that lets them back in.

A device with no licence does not fail silently: a row at the top of Settings › Albrhi says Albrhi
is not running and why, and taps through to Licence.

## What this is honest about

No check running on the user's own device can be made unbreakable. The tweak is a dylib on a
jailbroken phone; whoever holds the phone holds the file. What this buys is that most people do
not crack anything, that removing it is real work rather than one `if`, and — the part no
client-side trick provides — that a key which turns up on a forum can be withdrawn.
