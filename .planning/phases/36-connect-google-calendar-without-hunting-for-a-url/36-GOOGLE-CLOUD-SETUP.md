# Phase 36 — Google Cloud setup (Dan's part, ~15 minutes)

> # ⛔ ON HOLD — 2026-09-22. Do not follow Step 4 yet.
>
> **Steps 1–3 are still correct and safe to do** (project, enable Calendar API, consent screen +
> read-only scope + add yourself as a test user). They are needed under every option below.
>
> **Step 4 — creating a "Web application" OAuth client — is on hold**, because research found that
> Google's Web-application client type is a *confidential* client: its token exchange is widely
> reported to reject a secret-free PKCE exchange with `400 client_secret is missing`, and Google's own
> docs say *"a JavaScript application does not require a secret, but a web server application does"*
> without documenting PKCE-as-substitute for this client type at all.
>
> That collides head-on with **decision 1 (no client secret)** and **CALAUTH-04**. A browser SPA
> cannot hold a secret — it ships in the JS bundle where anyone can read it.
>
> **This is an architecture fork, not a config tweak.** Awaiting the owner's ruling before Step 4
> is rewritten. See the conversation, and the "Finding B" section of `36-RESEARCH.md`.


> **Do this while the code is being built, not after.** You called it: the scaffolding is the slow
> part, and it is the part only you can do — it lives in your Google account, not in this repo.
> Everything here produces exactly **one value** the app needs: an OAuth **client ID**. There is no
> client secret, by design (PKCE public client — see decision 1 in the ROADMAP), which is why none of
> this ends up committed.

---

## What you are creating

A Google Cloud project with an OAuth client that can ask *you* for read-only access to *your*
calendar. It is single-user and stays unpublished.

---

## Step 1 — Project

1. Go to <https://console.cloud.google.com/>
2. Project picker (top bar) → **New Project**
3. Name it something you will recognise later, e.g. `canopy-calendar`. No organisation needed.
4. Create, then make sure the picker shows that project before continuing.

## Step 2 — Enable the Calendar API

1. **APIs & Services → Library**
2. Search **Google Calendar API** → **Enable**

Without this, auth will succeed and every calendar call will fail with a confusing 403 — so don't
skip it.

## Step 3 — OAuth consent screen

1. **APIs & Services → OAuth consent screen**
2. User type: **External** (Internal is Workspace-only; a personal gmail cannot use it)
3. App name: `Canopy`. User support email + developer email: your own.
4. **Scopes** → *Add or remove scopes* → filter for `calendar` and add:

   ```
   https://www.googleapis.com/auth/calendar.readonly
   ```

   **Only that one.** If you find yourself adding a scope with `events` write or `calendar` (full) in
   it, stop — CAL-03 says Canopy never writes to your calendar, and the whole point of the read-only
   scope is that Google enforces that rather than us promising it.

5. **Test users** → add your own Google address. This is required; without it you get
   `access_blocked` when you try to sign in.
6. Leave publishing status as **Testing**. Do not submit for verification.

> ### ⚠ The 7-day thing, restated here so it is not a surprise later
> While the app is in **Testing**, Google **expires your refresh token after 7 days**. You will have
> to press reconnect roughly weekly. You already ruled on this knowingly; the app is being built to
> make it *visible* — it will tell you the calendar went stale and offer a one-tap reconnect, rather
> than quietly serving you a week-old schedule (requirement CALAUTH-03).
>
> Publishing to remove the limit means submitting a personal single-user app to Google's verification
> review, because `calendar.readonly` is a *sensitive* scope. That option stays open; it is not being
> done now.

## Step 4 — The OAuth client

1. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
2. Application type: **Web application**
3. Name: `canopy-web`
4. **Authorised JavaScript origins** — add:

   ```
   https://danserver.tailc2efd2.ts.net:8446
   http://localhost:8161
   ```

5. **Authorised redirect URIs** — add:

   ```
   https://danserver.tailc2efd2.ts.net:8446/oauth-callback.html
   http://localhost:8161/oauth-callback.html
   ```

6. **Create.** Copy the **Client ID** (ends in `.apps.googleusercontent.com`). Ignore the client
   secret entirely — this build does not use one and must not.

### Why those two origins, and what to do if Google refuses one

- Google requires redirect URIs to be **HTTPS**, with `localhost` as the only exemption. Your current
  UAT origin `http://danserver:8161` is **plain HTTP and not localhost**, so it is disqualified — this
  is why UAT serving moves to the tailnet TLS origin for this phase.
- `danserver.tailc2efd2.ts.net` is a real public domain (Tailscale owns `ts.net`), so it *should* be
  accepted. **If Google rejects it**, that is a genuine finding, not something to work around
  silently — tell me and we fall back to the `localhost` entry, which you reach by port-forwarding
  rather than over the tailnet.
- The `localhost` pair is there as that fallback and for local debugging.

## Step 5 — Give the client ID to the app

```bash
cd ~/CodeProjects/canopy
echo '1234567890-abcdefg.apps.googleusercontent.com' > .google-client-id
chmod 600 .google-client-id
```

`.google-client-id` is gitignored. A client ID is not strictly a secret — for a PKCE public client it
is expected to be visible in the shipped bundle — but it identifies *your* project, and this repo is
public, so it stays out of commits and gets injected at build time instead.

---

## When you are done

Tell me, and I will wire it into the build and serve it on the HTTPS origin. You do **not** need to
do anything else — no secret, no JSON key file, no service account.

## If something goes wrong

| Symptom | Almost certainly |
|---|---|
| `access_blocked` / "app not verified" at sign-in | you are not in **Test users** (step 3.5) |
| `redirect_uri_mismatch` | the URI in step 4.5 does not match **exactly** — trailing slash, port, http vs https all count |
| Auth works, calendar list is empty or 403 | **Calendar API not enabled** (step 2) |
| Worked last week, broken today | the **7-day token expiry**. Press reconnect. This is expected, not a bug. |
