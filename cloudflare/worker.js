// ════════════════════════════════════════════════════════════════════════════
// Chill Zone — free push backend (Cloudflare Worker). No Blaze, no billing.
//
// The app POSTs here when a friend request / challenge / chat message is sent.
// This Worker:
//   1) verifies the caller's Firebase ID token (so randoms can't spam),
//   2) reads the recipient's FCM token from RTDB (admin, via service account),
//   3) sends the push through FCM HTTP v1.
// FCM delivery is free & unlimited; Cloudflare Workers free tier = 100k req/day.
//
// Setup: see README.md in this folder. The only SECRET you add is
// SERVICE_ACCOUNT (the Firebase service-account JSON). Everything else below is
// already public (same values shipped in the app).
// ════════════════════════════════════════════════════════════════════════════

const PROJECT_ID = "gridwar-9a1b0";
const DB_URL = "https://gridwar-9a1b0-default-rtdb.firebaseio.com";
const WEB_API_KEY = "AIzaSyCqnHFGaz8YvX1eLiZ9XVrump8W0um89Ec";

// In-memory cache of the service-account OAuth token (per worker instance).
let _tok = { value: null, exp: 0 };

function b64url(buf) {
  let s = typeof buf === "string" ? btoa(buf) : btoa(String.fromCharCode(...new Uint8Array(buf)));
  return s.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function getAccessToken(env) {
  const now = Math.floor(Date.now() / 1000);
  if (_tok.value && _tok.exp - 60 > now) return _tok.value;

  const sa = JSON.parse(env.SERVICE_ACCOUNT);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = b64url(
    JSON.stringify({
      iss: sa.client_email,
      scope:
        "https://www.googleapis.com/auth/firebase.messaging " +
        "https://www.googleapis.com/auth/firebase.database " +
        "https://www.googleapis.com/auth/userinfo.email",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    })
  );
  const unsigned = `${header}.${claim}`;

  // Import the PKCS8 private key and sign.
  const pem = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned)
  );
  const jwt = `${unsigned}.${b64url(sig)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body:
      "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=" + jwt,
  });
  const data = await res.json();
  if (!data.access_token) throw new Error("token: " + JSON.stringify(data));
  _tok = { value: data.access_token, exp: now + (data.expires_in || 3600) };
  return _tok.value;
}

// Verify a Firebase ID token by asking Identity Toolkit to look it up.
async function verifyIdToken(idToken) {
  const r = await fetch(
    "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=" + WEB_API_KEY,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ idToken }),
    }
  );
  if (!r.ok) return null;
  const d = await r.json();
  const u = d.users && d.users[0];
  return u ? u.localId : null;
}

// Access token goes in the Authorization header (NOT the query string, which
// Google's RTDB access logs would capture).
async function dbGet(path, accessToken) {
  const r = await fetch(`${DB_URL}/${path}.json`, {
    headers: { Authorization: "Bearer " + accessToken },
  });
  if (!r.ok) return null;
  return r.json();
}

async function dbDelete(path, accessToken) {
  await fetch(`${DB_URL}/${path}.json`, {
    method: "DELETE",
    headers: { Authorization: "Bearer " + accessToken },
  });
}

// Firebase UIDs are short alphanumeric strings. Reject anything else so a
// caller can't smuggle path traversal (e.g. "../users/victim") into a DB path.
const UID_RE = /^[A-Za-z0-9]{1,128}$/;

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return new Response("ok", { status: 200 });
    }
    try {
      const auth = request.headers.get("authorization") || "";
      const idToken = auth.replace(/^Bearer\s+/i, "").trim();
      if (!idToken) return new Response("no token", { status: 401 });

      const senderUid = await verifyIdToken(idToken);
      if (!senderUid) return new Response("bad token", { status: 401 });

      const body = await request.json();
      const toUid = body.toUid;
      const type = body.type || "generic";
      // Strict validation BEFORE toUid is ever used in a DB path.
      if (typeof toUid !== "string" || !UID_RE.test(toUid) || toUid === senderUid) {
        return new Response("ok", { status: 200 });
      }

      const accessToken = await getAccessToken(env);

      // Recipient's device token.
      const fcmToken = await dbGet(`fcmTokens/${toUid}`, accessToken);
      if (!fcmToken || typeof fcmToken !== "string") {
        return new Response("no recipient token", { status: 200 });
      }

      // Sender's display name (for the title / message body).
      const senderName =
        (await dbGet(`users/${senderUid}/username`, accessToken)) || "Someone";

      let title = body.title;
      let text = body.body;
      if (type === "friend_request") {
        title = title || "New friend request";
        text = text || `${senderName} sent you a friend request`;
      } else if (type === "challenge") {
        title = title || "Game challenge";
        text = text || `${senderName} challenged you to a game!`;
      } else if (type === "chat") {
        title = title || senderName;
        text = text || "Sent you a message";
      } else {
        title = title || "Chill Zone";
        text = text || "";
      }
      if (text.length > 120) text = text.slice(0, 117) + "…";

      // Drop FCM-reserved keys so a caller can't force INVALID_ARGUMENT against
      // a victim's valid token (which we'd otherwise misread as "dead token").
      const RESERVED = /^(from|notification|message_type|google|gcm)/i;
      const data = {};
      for (const [k, v] of Object.entries(body.data || {})) {
        if (k === "type" || k === "fromUid" || RESERVED.test(k)) continue;
        data[String(k)] = String(v);
      }
      data.type = type;
      data.fromUid = senderUid;

      const message = {
        message: {
          token: fcmToken,
          notification: { title, body: text },
          data,
          android: {
            priority: "high",
            notification: { channel_id: "chillzone_high", sound: "default" },
          },
          apns: { payload: { aps: { sound: "default", badge: 1 } } },
        },
      };

      const fcmRes = await fetch(
        `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: "Bearer " + accessToken,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(message),
        }
      );

      if (!fcmRes.ok) {
        // Parse the structured error; only a genuine UNREGISTERED means the
        // token is dead. Never delete based on a substring of the raw text.
        let errCode = "";
        try {
          const ej = await fcmRes.json();
          const det =
            ej.error && ej.error.details
              ? ej.error.details.find((d) => d.errorCode)
              : null;
          errCode = (det && det.errorCode) || (ej.error && ej.error.status) || "";
        } catch (_) {}
        if (errCode === "UNREGISTERED") {
          await dbDelete(`fcmTokens/${toUid}`, accessToken);
        }
        return new Response("fcm error: " + errCode, { status: 200 });
      }
      return new Response("sent", { status: 200 });
    } catch (e) {
      return new Response("error: " + (e && e.message), { status: 200 });
    }
  },
};
