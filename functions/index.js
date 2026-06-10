// ════════════════════════════════════════════════════════════════════════════
// Chill Zone — WhatsApp-style push notifications (Firebase Cloud Functions, v1).
//
// These triggers fire on the SERVER when a new row lands in Realtime Database,
// even if the recipient's app is closed. Each reads the recipient's saved FCM
// token (fcmTokens/{uid}) and asks FCM to deliver a notification to that phone.
//
//   friendRequests/{toUid}/{fromUid}  → "X sent you a friend request"
//   challenges/{toUid}/{cid}          → "X challenged you to a game!"  (also room invites)
//   chats/{chatId}/{msgId}            → "X: <message>"
//
// FCM delivery is free & unlimited. Only these function invocations use the
// Blaze free tier (2M/month free). Deploy:  firebase deploy --only functions
// ════════════════════════════════════════════════════════════════════════════

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.database();

// Send a single notification to one user's device token. Cleans up dead tokens.
async function sendToUser(uid, title, body, data) {
  if (!uid) return;
  const snap = await db.ref(`fcmTokens/${uid}`).get();
  const token = snap.val();
  if (!token || typeof token !== "string") return;

  const message = {
    token,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data || {}).map(([k, v]) => [k, String(v)])
    ),
    android: {
      priority: "high",
      notification: { channelId: "chillzone_high", sound: "default" },
    },
    apns: {
      payload: { aps: { sound: "default", badge: 1 } },
    },
  };

  try {
    await admin.messaging().send(message);
  } catch (e) {
    const code = e && e.errorInfo && e.errorInfo.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token" ||
      code === "messaging/invalid-argument"
    ) {
      // Token is dead — remove it so we stop trying.
      await db.ref(`fcmTokens/${uid}`).remove().catch(() => {});
    } else {
      console.error("FCM send failed:", code || e);
    }
  }
}

async function lookupName(uid) {
  if (!uid) return "Someone";
  try {
    const s = await db.ref(`users/${uid}/username`).get();
    return (s.val() && String(s.val())) || "Someone";
  } catch (_) {
    return "Someone";
  }
}

// ── Friend request ──────────────────────────────────────────────────────────
exports.onFriendRequest = functions.database
  .ref("/friendRequests/{toUid}/{fromUid}")
  .onCreate(async (snap, ctx) => {
    const { toUid, fromUid } = ctx.params;
    const val = snap.val() || {};
    const name = val.fromName || (await lookupName(fromUid));
    await sendToUser(toUid, "New friend request", `${name} sent you a friend request`, {
      type: "friend_request",
      fromUid,
    });
  });

// ── Game challenge / room invite ────────────────────────────────────────────
exports.onChallenge = functions.database
  .ref("/challenges/{toUid}/{cid}")
  .onCreate(async (snap, ctx) => {
    const { toUid, cid } = ctx.params;
    const val = snap.val() || {};
    const name = val.fromName || (await lookupName(val.fromUid));
    const game = val.gameType ? ` (${val.gameType})` : "";
    await sendToUser(toUid, "Game challenge", `${name} challenged you to a game${game}!`, {
      type: "challenge",
      cid,
      fromUid: val.fromUid || "",
      gameType: val.gameType || "",
      gameKey: val.gameKey || "",
    });
  });

// ── Chat message ────────────────────────────────────────────────────────────
exports.onChatMessage = functions.database
  .ref("/chats/{chatId}/{msgId}")
  .onCreate(async (snap, ctx) => {
    const { chatId } = ctx.params;
    const msg = snap.val() || {};
    const from = msg.from;
    if (!from) return;
    // chatId is "uidA__uidB" — the recipient is whichever id isn't the sender.
    const parts = String(chatId).split("__");
    const toUid = parts.find((p) => p !== from);
    if (!toUid) return;
    const name = await lookupName(from);
    const text = msg.text ? String(msg.text) : "Sent you a message";
    const body = text.length > 120 ? `${text.slice(0, 117)}…` : text;
    await sendToUser(toUid, name, body, {
      type: "chat",
      fromUid: from,
      chatId,
    });
  });
