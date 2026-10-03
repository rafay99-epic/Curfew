#!/usr/bin/env python3
"""Talks to a Curfew agent the way the Android app does (see android/.../Proto.kt) and
prints one line per step, so two agents can be compared with diff.

    python3 tools/interop/client.py 127.0.0.1:8787 ABCD-EFGH-JKLM-NPQR [--user gaming]

Pairs with the code, then runs status, timer_set, timer_cancel and apps, plus the
refusals a client must handle. Every 200 answer has its MAC checked; a bad one aborts.
Values that differ on every run (ids, nonces, keys) are replaced by placeholders."""
import argparse
import hashlib
import hmac
import http.client
import json
import re
import secrets
import sys


def mac(key, *parts):
    return hmac.new(key, "\n".join(parts).encode(), hashlib.sha256).hexdigest()


def derive_key(code, snonce, cnonce, phone):
    return hmac.new(code.encode(), "\n".join(("key", snonce, cnonce, phone)).encode(), hashlib.sha256).digest()


def clean_code(text):
    return re.sub(r"[^A-Z0-9]", "", text.upper())


class Agent:
    def __init__(self, address):
        host, _, port = address.partition(":")
        self.host, self.port = host, int(port or 787)
        self.id = None

    def http(self, method, path, body=None, raw=None):
        conn = http.client.HTTPConnection(self.host, self.port, timeout=5)
        data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
        conn.request(method, path, body=data, headers={"Content-Type": "application/json"} if data else {})
        res = conn.getresponse()
        text = res.read()
        conn.close()
        try:
            return res.status, json.loads(text)
        except ValueError:
            return res.status, {"_raw": text.decode(errors="replace")}

    def hello(self):
        status, body = self.http("GET", "/v1/hello")
        if status != 200 or body.get("app") != "curfew" or not re.fullmatch(r"[0-9a-f]{32}", body.get("nonce", "")):
            raise SystemExit("not a Curfew agent: %r" % body)
        if self.id is not None and body["id"] != self.id:
            raise SystemExit("wrong computer: %s" % body["id"])
        self.id = body["id"]
        return body

    def pair(self, code, name):
        hello = self.hello()
        s, c = hello["nonce"], secrets.token_hex(16)
        payload = json.dumps({"name": name})
        status, r = self.http("POST", "/v1/pair", {"snonce": s, "cnonce": c, "payload": payload,
                                                   "mac": mac(code.encode(), "pair", s, c, payload)})
        if status != 200:
            return status, r, None
        key = derive_key(code, s, c, r["phone"])
        if not hmac.compare_digest(mac(key, "res", r["phone"], s, c, r["payload"]), r.get("mac", "")):
            raise SystemExit("FAKE: pair answer not signed with the derived key")
        return status, json.loads(r["payload"]), {"phone": r["phone"], "key": key}

    def envelope(self, phone, op, **args):
        s, c = self.hello()["nonce"], secrets.token_hex(16)
        payload = json.dumps(dict(op=op, **args))
        return {"phone": phone["phone"], "snonce": s, "cnonce": c, "payload": payload,
                "mac": mac(phone["key"], "req", phone["phone"], s, c, payload)}

    def send(self, phone, env):
        status, r = self.http("POST", "/v1/call", env)
        if status == 200:
            if not hmac.compare_digest(mac(phone["key"], "res", env["phone"], env["snonce"], env["cnonce"], r["payload"]),
                                       r.get("mac", "")):
                raise SystemExit("FAKE: answer not signed with our key")
            return status, json.loads(r["payload"])
        return status, r

    def call(self, phone, op, **args):
        return self.send(phone, self.envelope(phone, op, **args))


def scrub(value, agent_id):
    text = json.dumps(value, sort_keys=True)
    return text.replace(agent_id, "<agent-id>") if agent_id else text


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("address")
    ap.add_argument("code")
    ap.add_argument("--user", help="account for 'apps' (default: first standard account)")
    ap.add_argument("--name", default="Interop phone")
    a = ap.parse_args()
    agent, code = Agent(a.address), clean_code(a.code)
    if len(code) != 16:
        raise SystemExit("the code has 16 letters and digits")

    def show(step, status, body):
        print("%-24s %d %s" % (step, status, scrub(body, agent.id)), flush=True)

    hello = agent.hello()
    show("hello", 200, {k: hello[k] for k in ("app", "proto", "name")})
    wrong = "".join(reversed(code))
    st, body, _ = agent.pair(wrong, a.name)
    show("pair wrong code", st, body)
    st, body, phone = agent.pair(code, a.name)
    show("pair", st, body)
    if not phone:
        raise SystemExit("pairing failed")
    st, body, _ = agent.pair(code, a.name)
    show("pair code reused", st, body)

    st, status = agent.call(phone, "status")
    show("status", st, status)
    users = status.get("users", [])
    user = a.user or next((u["name"] for u in users if not u["admin"]), users[0]["name"] if users else "")
    st, body = agent.call(phone, "timer_set", seconds=600, warn=True)
    show("timer_set 600s warn", st, body)
    st, body = agent.call(phone, "status")
    t = body.get("timer") or {}
    show("status timer", st, {"timer_set": t.get("warn") is True and 595 <= t.get("remaining", -1) <= 600})
    show("timer_set minutes=2", *agent.call(phone, "timer_set", minutes=2))
    show("timer_set seconds=5", *agent.call(phone, "timer_set", seconds=5))
    show("timer_set seconds=true", *agent.call(phone, "timer_set", seconds=True))
    show("timer_cancel", *agent.call(phone, "timer_cancel"))
    st, body = agent.call(phone, "status")
    show("status after cancel", st, {"timer": body.get("timer")})
    show("apps " + user, *agent.call(phone, "apps", user=user))
    show("apps unknown user", *agent.call(phone, "apps", user="root"))
    show("unknown op", *agent.call(phone, "run", cmd="id"))
    show("op not a string", *agent.call(phone, ["status"]))

    env = agent.envelope(phone, "status")
    show("first use", agent.send(phone, env)[0], {})
    show("replay", *agent.http("POST", "/v1/call", env))
    env = agent.envelope(phone, "status")
    env["payload"] = json.dumps({"op": "poweroff"})
    show("tampered", *agent.http("POST", "/v1/call", env))
    show("bad key", *agent.http("POST", "/v1/call", agent.envelope(dict(phone, key=b"\0" * 32), "status")))
    show("unknown phone", *agent.http("POST", "/v1/call", agent.envelope(dict(phone, phone="deadbeefdeadbeef"), "status")))
    show("malformed json", *agent.http("POST", "/v1/call", raw=b"{not json"))
    show("missing fields", *agent.http("POST", "/v1/call", {"phone": "x"}))
    show("not an object", *agent.http("POST", "/v1/call", [1, 2]))
    show("oversized", *agent.http("POST", "/v1/call", raw=b"x" * 20000))
    show("unknown path", *agent.http("GET", "/etc/passwd"))
    show("forget", *agent.call(phone, "forget"))
    show("after forget", *agent.http("POST", "/v1/call", agent.envelope(phone, "status")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
