const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendAlertPush = functions.firestore
  .document("alerts/{alertId}")
  .onCreate(async (snap) => {
    const alert = snap.data() || {};

    const type = String(alert.type || "alert");
    const note = String(alert.note || "");
    const lens = String(alert.lens || "");

    const title = type.replaceAll("_", " ");
    const body = note || (lens ? `Lens: ${lens}` : "New alert");

    const message = {
      topic: "alerts_all",
      notification: {
        title: title,
        body: body,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "alerts_channel",
        },
      },
      data: {
        alert_id: snap.id,
        type: type,
      },
    };

    await admin.messaging().send(message);
    return null;
  });
