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

## Issuing a key

The buyer opens **Settings › Albrhi › Licence** and sends the sixteen-character device code.

```bash
python3 tools/licence.py issue <device-code> --days 365 --name "who it is for"
```

The key goes to stdout; everything else — expiry, and the id to revoke it by — goes to stderr, so
`... | pbcopy` copies the key alone.

Keep the ids. They are the only way to withdraw a key later.

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

Add the id, commit, and the key stops working on every device that reaches the file. **Only a
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

**Enforcement ships off and stays off until someone turns it on** in Settings › Albrhi › Licence.
The source has been free for as long as it has existed, and a release that both introduced this
layer and enforced it would stop every install already out there on the next update, before a
single key had been issued to fix them with.

The order that works: issue keys → confirm a few devices report `licensed` → then switch it on.

## What this is honest about

No check running on the user's own device can be made unbreakable. The tweak is a dylib on a
jailbroken phone; whoever holds the phone holds the file. What this buys is that most people do
not crack anything, that removing it is real work rather than one `if`, and — the part no
client-side trick provides — that a key which turns up on a forum can be withdrawn.
