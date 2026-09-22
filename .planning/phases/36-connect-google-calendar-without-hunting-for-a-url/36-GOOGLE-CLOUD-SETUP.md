# Phase 36 — Google Cloud setup (Dan's part, ~10 minutes)

> **Revised 2026-09-22 — the hold is lifted and Step 4 changed.**
> The original version had you create a **Web application** client. That was wrong: Google's
> Web-application client is a *confidential* client and will not complete a secret-free exchange, and
> a browser page cannot hold a secret. **You ruled: build it native.**
>
> So this is now an **iOS** client, which is genuinely simpler — Google's own docs:
> *"The `client_secret` is **not applicable** to requests from clients registered as Android, iOS, or
> Chrome applications"* and *"refresh tokens are **always** returned for installed applications."*
> That is exactly the "sign in and stay signed in" behaviour you described.
>
> **If you already did Steps 1–3, none of it is wasted** — they are unchanged. If you created a Web
> application client, just ignore it (or delete it); it is harmless.

---

## What you are creating

A Google Cloud project with an **iOS** OAuth client that can ask *you* for read-only access to *your*
calendar. Single-user, stays unpublished. **No client secret exists anywhere in this flow.**

---

## Step 1 — Project

1. <https://console.cloud.google.com/>
2. Project picker → **New Project** → name it e.g. `canopy-calendar`. No organisation needed.
3. Make sure the picker shows that project before continuing.

## Step 2 — Enable the Calendar API

1. **APIs & Services → Library**
2. Search **Google Calendar API** → **Enable**

Skip this and auth will succeed while every calendar call fails with a confusing 403.

## Step 3 — OAuth consent screen

1. **APIs & Services → OAuth consent screen**
2. User type: **External** (Internal is Workspace-only; a personal gmail can't use it)
3. App name `Canopy`; support + developer email: your own.
4. **Scopes** → *Add or remove scopes* → add **only**:

   ```
   https://www.googleapis.com/auth/calendar.readonly
   ```

   If you find yourself adding anything with write access, stop — CAL-03 says Canopy never writes to
   your calendar, and the point of the read-only scope is that **Google** enforces that rather than us
   promising it.

5. **Test users** → add your own Google address. Required, or sign-in returns `access_blocked`.
6. Publishing status stays **Testing**. Do not submit for verification.

> ### ⚠ The 7-day thing — still applies, and it is about publishing status, not client type
> In **Testing**, Google expires refresh tokens after **7 days**. You'll press reconnect roughly
> weekly. You ruled on this knowingly. The app is being built so it degrades *visibly* — it tells you
> the calendar went stale and offers one-tap reconnect, rather than quietly serving a week-old
> schedule (CALAUTH-03).

## Step 4 — The iOS OAuth client ← **this is the part that changed**

1. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
2. Application type: **iOS** *(not "Web application")*
3. Name: `canopy-ios`
4. **Bundle ID** — this is the only field that matters, and see the note below before you fill it:

   ```
   com.example.canopy
   ```

5. **Create.** Copy the **Client ID** (ends in `.apps.googleusercontent.com`).

**There is no redirect URI to enter, no JavaScript origins, and no client secret.** Google derives the
redirect from the client ID automatically (reversed form,
`com.googleusercontent.apps.<id>:/oauth2redirect`), and the app registers that as a URL scheme. This
is why the tailnet HTTPS origin from the previous draft is no longer relevant at all.

> ### 🤔 One decision worth 30 seconds — your bundle ID is still a placeholder
> The app currently ships as **`com.example.canopy`** (`ios/Runner.xcodeproj`, line 480), which
> `STATE.md` already flags as blocking any future App Store distribution. `com.example.*` is Apple's
> sample-code placeholder.
>
> **The OAuth client is bound to whatever bundle ID you enter here.** If you register
> `com.example.canopy` now and later change the bundle ID for real distribution, this client stops
> matching and you re-do Step 4.
>
> - **Fine to use `com.example.canopy`** if you just want it working now — re-registering later is
>   five minutes.
> - **Or pick your real one now** (e.g. `com.danjjohnson.canopy`) and tell me — I'll change it in the
>   Xcode project as part of this phase so it only happens once.
>
> Either is defensible. Not deciding it silently.

## Step 5 — Give the client ID to the app

```bash
cd ~/CodeProjects/canopy
echo '1234567890-abcdefg.apps.googleusercontent.com' > .google-client-id
chmod 600 .google-client-id
```

Gitignored. A client ID isn't a secret — for a native PKCE client it's expected to be visible in the
app bundle — but it identifies *your* project and this repo is public, so it's injected at build time
rather than committed.

---

## What you will and won't be able to see

**Be clear on this before you're surprised by it:** this is a **native iOS** flow. It will **not**
appear in the hosted browser build at `danserver:8161`, because a web page cannot do this without a
backend holding a secret — which is the whole reason the plan moved native.

- **On your MacBook / iPhone:** the real "Sign in with Google" button.
- **In the browser:** unchanged — the `.ics` feed path from Phase 35 still works and is still how you
  test everything else.

I can write and unit-test all the logic here on danserver. **The button itself is only observable on
your device**, same as Phase 35's device gate — no Xcode on this box, and there never will be.

## If something goes wrong

| Symptom | Almost certainly |
|---|---|
| `access_blocked` / "app not verified" | you're not in **Test users** (step 3.5) |
| `invalid_client` / nothing happens on tap | **bundle ID mismatch** — the client's bundle ID must equal the app's `CFBundleIdentifier` exactly |
| Auth works, calendar empty or 403 | **Calendar API not enabled** (step 2) |
| Worked last week, broken today | the **7-day expiry**. Press reconnect. Expected, not a bug. |
