const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendNotification = onDocumentCreated("notifications/{id}", async (event) => {
    const data = event.data?.data() || {};

    const title = data.title;
    const body = data.body;
    const deepLink = data.deepLink || "";
    const audience = data.audience || "All Users";
    const userId = data.userId || "";
    const segment = data.segment || "";
    const highPriority = Boolean(data.highPriority);
    const withSound = data.withSound !== false;

    if (!title || !body) {
      console.log("Notification skipped: missing title or body.");
      return null;
    }

    console.log("New notification:", title, body, "Audience:", audience);

    const tokens = [];
    const pushToken = (doc) => {
      const token = doc.data().fcmToken;
      if (token) tokens.push(token);
    };

    if (audience === "Specific User" && userId) {
      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      if (userDoc.exists) {
        pushToken(userDoc);
      }

      const anonDoc = await admin.firestore().collection("anonymous_users").doc(userId).get();
      if (anonDoc.exists) {
        pushToken(anonDoc);
      }
    } else if (audience === "User Segment" && segment) {
      const [usersSnapshot, anonymousSnapshot] = await Promise.all([
        admin.firestore()
          .collection("users")
          .where("segment", "==", segment)
          .get(),
        admin.firestore()
          .collection("anonymous_users")
          .where("segment", "==", segment)
          .get(),
      ]);

      usersSnapshot.forEach(pushToken);
      anonymousSnapshot.forEach(pushToken);
    } else {
      const [usersSnapshot, anonymousSnapshot] = await Promise.all([
        admin.firestore().collection("users").get(),
        admin.firestore().collection("anonymous_users").get(),
      ]);

      usersSnapshot.forEach(pushToken);
      anonymousSnapshot.forEach(pushToken);
    }

    if (tokens.length === 0) {
      console.log("No tokens found for audience:", audience);
      return null;
    }

    const message = {
      tokens: tokens,
      notification: {
        title: title,
        body: body,
      },
      data: {
        deepLink: deepLink,
      },
      android: {
        priority: highPriority ? "high" : "normal",
        notification: withSound ? { sound: "default" } : undefined,
      },
      apns: {
        headers: highPriority ? { "apns-priority": "10" } : { "apns-priority": "5" },
        payload: {
          aps: withSound ? { sound: "default" } : {},
        },
      },
    };

    await admin.messaging().sendEachForMulticast(message);

    console.log("Sent to", tokens.length, "users");

    return null;
  });
