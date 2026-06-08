# Chill Zone — Free push backend (Cloudflare Worker)

WhatsApp-style background push **without Blaze / without any card**. FCM delivery
is free & unlimited; Cloudflare Workers free tier = 100,000 requests/day (way
more than this app needs).

You only do this **once**. After it's live, give the Worker URL to your dev and
the app will start sending pushes.

---

## Step 1 — Get the Firebase service-account key (the only secret)

1. Open: https://console.firebase.google.com/project/gridwar-9a1b0/settings/serviceaccounts/adminsdk
2. Click **Generate new private key** → **Generate key**.
3. A `.json` file downloads. Open it in a text editor and **copy the whole
   contents** (you'll paste it in Step 3). Keep this file private.

## Step 2 — Create the Worker (free Cloudflare account)

1. Sign up / log in (free): https://dash.cloudflare.com/sign-up
2. Left menu → **Workers & Pages** → **Create** → **Create Worker**.
3. Name it `chillzone-push` → **Deploy** (the default hello-world is fine for now).
4. Click **Edit code**. Delete everything in the editor, then paste the entire
   contents of [`worker.js`](worker.js). Click **Deploy**.

## Step 3 — Add the secret

1. Still in the Worker → **Settings** → **Variables and Secrets** (or
   "Variables").
2. **Add variable** → switch the type to **Secret** (encrypted).
   - **Name:** `SERVICE_ACCOUNT`
   - **Value:** paste the **entire JSON** from Step 1.
3. **Save and deploy**.

## Step 4 — Copy the URL

At the top of the Worker page you'll see a URL like:

```
https://chillzone-push.<your-subdomain>.workers.dev
```

**Send that URL to your dev.** It gets pasted into the app
(`lib/functions/push_sender.dart` → `kPushEndpoint`), then the app is rebuilt and
pushes go live.

---

### Test it (optional)
Visiting the URL in a browser shows `ok` (GET). Real pushes only fire on POST
from the app with a valid login, so you'll see them by sending a friend
request / challenge / message from one phone to another.

### Notes
- `PROJECT_ID`, `DB_URL`, `WEB_API_KEY` are hard-coded in `worker.js` — these are
  already public (they ship inside the app), so they're safe there. The **only**
  secret is `SERVICE_ACCOUNT`, which lives encrypted on Cloudflare and never in
  the app.
- The Worker verifies each caller's Firebase login token, so strangers can't use
  your URL to spam notifications.
