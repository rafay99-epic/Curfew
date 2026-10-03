# Curfew agent API

Plain HTTP with JSON on the LAN, port **787** (dry-run: 8787). Nothing is encrypted; every
message is authenticated with HMAC-SHA256 and a per-phone 32-byte key. Three endpoints.

`mac(key, a, b, ...)` below means: HMAC-SHA256 with `key` over the parts joined by `\n` (UTF-8),
written as lowercase hex.

## Finding the agent

mDNS service `_curfew._tcp` (IPv4), TXT record `id=<agent id>`. Clients remember the last
address and prefer a discovered one whose `id` matches.

## GET /v1/hello

No authentication. Returns the identity and a fresh one-time number.

```json
{"app": "curfew", "proto": 1, "id": "0b825f00961665a4", "name": "kids-laptop", "nonce": "<32 hex>"}
```

A nonce is valid once and for 60 seconds. Every POST needs a fresh one (this is what stops
replays without relying on clocks).

## POST /v1/pair

`sudo curfew pair` creates a 16-character code (80 bits, valid 2 minutes, single use, cancelled
after 5 wrong attempts). The code is shown in a QR code as
`curfew://pair?a=<ip>:<port>&i=<agent id>&c=<code>` and never travels over the network.

Request (`payload` is a JSON **string**, `cnonce` is 8-64 letters/digits chosen by the client):

```json
{"snonce": "<nonce from hello>", "cnonce": "...", "payload": "{\"name\": \"Dad's phone\"}",
 "mac": mac(code, "pair", snonce, cnonce, payload)}
```

Success (HTTP 200):

```json
{"phone": "<phone id>", "payload": "{\"ok\": true, \"id\": ..., \"name\": ..., \"phone_name\": ...}",
 "mac": mac(key, "res", phone, snonce, cnonce, payload)}
```

Both sides compute `key = HMAC-SHA256(code, "key\n" + snonce + "\n" + cnonce + "\n" + phone)` (raw 32 bytes).
The client must verify `mac`: only an agent that knows the code can produce it.
Errors (HTTP 403/409): `{"error": "bad_code" | "no_pairing" | "bad_nonce"}`.

## POST /v1/call

```json
{"phone": "<phone id>", "snonce": "...", "cnonce": "...", "payload": "{\"op\": \"status\"}",
 "mac": mac(key, "req", phone, snonce, cnonce, payload)}
```

Authenticated answer (HTTP 200); verify `mac` before trusting it:

```json
{"payload": "{\"ok\": true, ...}", "mac": mac(key, "res", phone, snonce, cnonce, payload)}
```

Unauthenticated refusals (HTTP 4xx, treat as hints only): `unknown_phone`, `bad_mac`,
`bad_nonce` (get a new nonce and retry once), `bad_request`.

### Operations (the `op` field of the payload)

| op | extra fields | answer |
|---|---|---|
| `status` | | `id`, `name`, `os`, `caps`, `users: [{name, full, admin, state, net, net_timer?}]`, `timer: null \| {remaining, warn}`, `wake?` |
| `apps` | `user` | `apps: [{name, detail, age, terminal}]`, newest first, at most 15 |
| `poweroff`, `reboot` | | |
| `timer_set` | `seconds` (10-86400) or `minutes` (1-1440), `warn` (bool) | `timer` |
| `timer_cancel` | | `timer: null` |
| `lock`, `logout` | `user` | |
| `login` | `user` | `how`: `unlocked` (an open session was brought to the screen and unlocked) or `approved` (the login screen lets this account in once, within `seconds`) |
| `net_set` | `user`, `seconds` (0 = now, or 10-86400), `warn` | internet off for that account, now or after the countdown |
| `net_clear` | `user` | internet back on, countdown cancelled |
| `forget` | | removes the calling phone |

`caps` lists what this agent can do: `seconds` (timers in seconds), `net` (iptables is present),
`login` (the login screen is set up to ask the agent). An agent without `caps` is the first version.

`os` is a name for people, shown by the app as it is: `Ubuntu 24.04.1 LTS` from the Ubuntu agent,
`macOS 27.0` from the macOS agent. Clients that need to know the platform check whether it starts
with `macOS`; anything else is treated as Linux.

`protocol/vectors.json` holds fixed inputs with the expected key derivation and signatures. Every
implementation (the Python agent, the macOS agent, the Android app) tests against it.
`net` is `on` or `off`; `net_timer` is `{remaining, warn}` while a countdown runs. Admin accounts are
always `on`.

`state` is `none`, `logged_in`, `locked` or `active`. `remaining` and `age` are seconds, so
clients never compare clocks. Failures are authenticated too: `{"ok": false, "error": ...}` with
`bad_op`, `bad_user`, `bad_args`, `not_logged_in`, `is_admin`, `no_password`, `unsupported`, `failed`, or **`unpaired`**: the phone was
removed with `sudo curfew unpair`; it is signed with the old key so the client can trust it and
drop the computer.

## macOS agent

The macOS agent answers the same operations, with these differences:

- `caps` is `seconds` and `net`, plus `login` while "Log in from the phone" is turned on in the Curfew app on the Mac.
- `wake` is the hardware address of the network interface the agent answers on, as `aa:bb:cc:dd:ee:ff`. A
  client that cannot reach the computer may send a Wake-on-LAN packet to it (UDP port 9, to the broadcast
  address), then try again. It only works when "Wake for the phone" is on, and over Wi-Fi only with an
  Apple TV or HomePod at home.
- `login` always answers `how: approved`. For an account that is not logged in, choose it on the login
  screen and press Enter with the password field empty. For a locked screen, press Enter on it with the
  password field empty. Either works once, within `seconds`. The Mac fills in the password that was last
  typed at its login screen, so an account whose password was never typed there since Curfew was set up
  gets `no_password`.
- `lock` on an account that is logged in but not on the screen does nothing and answers `ok`: switching
  back to it already asks for its password.
- `net_set` blocks TCP and UDP from that account's programs with pf. Apple services that act for the
  account from their own processes can still get through.

## Flood limits

The agent serves at most 8 connections per source address at a time and keeps at most 32 unused
nonces per source address, so a flood from one place (an account on the same computer, say) cannot
lock a phone out.

## Notes for a second client (web page for an iPhone)

- A page served over plain HTTP has no `crypto.subtle`, so it needs a small JavaScript
  HMAC-SHA256 (about 100 lines) and must keep its key in `localStorage`.
- Pairing would be the typed code, or the QR link opened in the browser.
- The agent would serve the page from a fourth, static endpoint; nothing above changes.
