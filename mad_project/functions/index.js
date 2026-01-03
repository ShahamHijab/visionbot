const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendAlertPush = functions.firestore
  .document("alerts/{alertId}")
  .onCreate(async (snap) => {
    const alert = snap.data();

    const uid = alert.user_id;
    if (!uid) return null;

    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const token = userDoc.data()?.fcm_token;
    if (!token) return null;

    const type = (alert.type || "alert").toString();
    const note = (alert.note || "").toString();

    await admin.messaging().send({
      token: token,
      notification: {
        title: type.replaceAll("_", " "),
        body: note,
      },
      data: {
        alert_id: snap.id,
        type: type,
      },
    });

    return null;
  });
