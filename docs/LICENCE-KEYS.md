# Albrhi licences

Two paths, and both are real:

- **The server** — a Cloudflare Worker. Requests arrive by themselves, licences renew every seven
  days, and revocation actually stops a device. This is the normal way.
- **Offline** — `tools/licence.py` on the Mac issues a key that needs no server at all. This is
  the way back in when the Worker is unreachable, and the reason a server holding the only signing
  key is a decision with a stated cost rather than an oversight.

The device verifies both the same way: `ALB1.<payload>.<signature>`, ECDSA P-256, checked against a
public key compiled into the tweak. **The server decides; it is never trusted to be reachable,
correct, or even the right server** — a token that does not verify locally is dropped, so pointing
the address at something hostile gains nothing but a refusal.

## Standing it up

```bash
cd server
npx wrangler kv namespace create DB       # put the printed id into wrangler.toml
npx wrangler secret put SIGNING_KEY       # python3 ../tools/licence.py export-web
npx wrangler secret put ADMIN_TOKEN       # openssl rand -hex 32
npx wrangler deploy
```

`SIGNING_KEY` is the signing key itself. In a Worker Secret it is not readable back — not from the
dashboard, not by `wrangler` — which is the whole reason it goes there rather than into a file.

Then, once per phone: **Settings › Albrhi › Licence › Set the server**, paste the `workers.dev`
address. It must be https; the device refuses anything else, because a licence arriving over plain
http could be swapped in flight and the signature would still check out.

## The day-to-day

<https://ibrahim2100.github.io/albrhi-repo/licence-panel/> — paste the address and the admin
token once and it remembers them.

**A request arrives on its own.** The buyer taps *Request a licence* in Settings, and it appears in
the panel with their device, the duration they asked for and their name. **Approve** issues it
immediately; the phone collects it on its next check, or straight away with *Check the server now*.

**Revoke** stops that device within seven days — the length of the signed licence it is carrying.
There is no list for it to fetch and no way for it to decline to look.

**Codes** are minted in the panel and shown **once**: the server keeps hashes, so it genuinely
cannot show them again. A code binds to the first device that redeems it and does nothing for
anybody else afterwards — which is the difference between this and the published-list scheme it
replaced, where a code worked for everyone who got hold of it.

## Why the token is short-lived

A device holds a licence signed for **seven days** and renews it in the background — every six
hours normally, every half hour once less than two days are left.

That is the whole of the live-control design, and it buys two things at once:

- **Revocation is real.** Withdraw a licence and the device stops within a week, on its own.
- **Nobody is stranded by a bad network.** A flight, a captive portal, a Cloudflare hiccup: there
  are six days of slack behind every renewal, and a failed check is reported as *nothing was
  decided* rather than as a licence problem.

Asking the server on every launch would revoke faster and make every customer's tweaks dead the
minute the network is. That is not a trade worth taking for software somebody paid for.

## Issuing offline

```bash
python3 tools/licence.py issue <device-code> --days 365 --name "who it is for"
python3 tools/licence.py verify <key>
```

The key goes to stdout and everything else to stderr, so `| pbcopy` copies the key alone. The buyer
enters it under *Enter a key*. No server is involved at any point.

## Once, ever

```bash
python3 tools/licence.py keygen
```

Writes the private key to `~/.albrhi/licence-ec-private.pem` and prints the public half as a C
array, already embedded in `shared/src/SCILicense.m`. **A new keypair invalidates every licence
already issued**, which is why `keygen` refuses to overwrite one.

## What happens on the device

| state | what the tweaks do |
|---|---|
| valid licence | everything |
| licence valid, server unreachable | everything, until the token's seven days run out |
| no licence / expired / revoked / wrong device | stand down |
| enforcement switched off in the panel | everything |

"Stand down" means `SCIPanelAllowsThisApp()` answers NO, which every tweak already asks before
installing a single hook — so the app behaves as if Albrhi were not installed. Nothing crashes and
nothing is half-patched. A device in that state is not left guessing: a row at the top of Settings ›
Albrhi says so and taps through to Licence.

## What this is honest about

No check running on the user's own device can be made unbreakable. The tweak is a dylib on a
jailbroken phone; whoever holds the phone holds the file. What this buys is that most people do not
crack anything, that removing it is real work rather than one `if`, and — the part no client-side
trick provides — that a licence can be withdrawn and will actually stop.
