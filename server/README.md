# Albrhi licence server

Cloudflare Worker + one KV namespace. It issues short-lived signed licences, takes requests from
devices, and mints redeemable codes.

## Why the tokens are short-lived

A device holds a licence signed for **seven days** and renews it in the background. That is the
whole of the live-control design, and it buys two things a long key cannot:

- **Revocation actually revokes.** Withdraw a licence in the panel and the device stops within a
  week, without the device having to consult a list it might never reach.
- **Nobody is stranded by a flat tyre.** A phone in airplane mode, on a flight, or on a coffee
  shop's captive portal keeps working — it has six days of slack before anything is noticed.

The alternative, asking the server on every launch, gives faster revocation and makes every
customer's tweaks dead the minute Cloudflare has a bad minute. That is not a trade worth taking
for software somebody paid for.

## Setup

```bash
cd server
npm i -D wrangler                         # or use npx wrangler directly

npx wrangler kv namespace create DB       # put the printed id into wrangler.toml
npx wrangler secret put SIGNING_KEY       # python3 ../tools/licence.py export-web
npx wrangler secret put ADMIN_TOKEN       # openssl rand -hex 32
npx wrangler deploy
```

`SIGNING_KEY` is the PKCS#8 PEM. **It is the signing key itself** — anyone holding it can mint a
licence for every device forever. In a Worker Secret it is not readable back, not in the dashboard
and not by `wrangler`; that is the point of putting it there rather than in a `.env` or a file.

## The device API

No authentication: a device has no credential to present, and nothing here is worth protecting by
one — every response is either a licence that device is already entitled to, or a refusal.

| | |
|---|---|
| `POST /v1/hello` | `{dev}` → the current licence for that device, as a fresh seven-day token. This is the renew call. |
| `POST /v1/request` | `{dev, days, note}` → records a request. Appears in the panel. |
| `POST /v1/redeem` | `{dev, code}` → binds a short code to the device and returns a token. |
| `GET /v1/pubkey` | The public point, hex. For checking which keypair a deployment signs with. |

## The admin API

`Authorization: Bearer <ADMIN_TOKEN>` on every one.

| | |
|---|---|
| `GET /admin/state` | requests, licences and codes in one call |
| `POST /admin/approve` | `{dev, days, note}` — issues or extends |
| `POST /admin/decline` | `{dev}` — drops a request |
| `POST /admin/revoke` | `{dev}` — the device stops within seven days |
| `POST /admin/codes` | `{count, days, window, tier}` — mints codes, returns them once |

**Codes are returned once and stored as hashes.** The server cannot show a code again after
minting, which is deliberate: a store of live codes is a store worth stealing.

## What this does not change

The offline path still works. A key issued by `tools/licence.py` on the Mac verifies on the device
with no server involved at all — which is the way back in if this Worker is ever unreachable.
