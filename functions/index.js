const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendNotification = onDocumentCreated(
  {
    document: "notifications/{id}",
    region: "asia-south1",
  },
  async (event) => {
    console.log("🚀 FUNCTION TRIGGERED");

    const snapshot = event.data;
    const notificationRef = snapshot?.ref;
    const data = event.data?.data() || {};

    const title = data.title;
    const body = data.body;
    const deepLink = data.deepLink || "";
    const audience = data.audience || "All Users";
    const userId = data.userId || "";
    const segment = data.segment || "";
    const highPriority = Boolean(data.highPriority);
    const withSound = data.withSound !== false;
    const serverTimestamp = admin.firestore.FieldValue.serverTimestamp;

    const updateNotificationStatus = async (status, extra = {}) => {
      if (!notificationRef) {
        return;
      }

      await notificationRef.set(
        {
          status,
          ...extra,
          processedAt: serverTimestamp(),
        },
        { merge: true }
      );
    };

    if (!title || !body) {
      console.log("❌ Missing title/body");
      await updateNotificationStatus("failed", {
        error: "Missing title/body",
      });
      return null;
    }

    try {
      // ===============================
      // 🔴 1. SEND TO SPECIFIC USER (TOKEN)
      // ===============================
      if (audience === "Specific User" && userId) {
        console.log("👤 Sending to specific user:", userId);

        const userDoc = await admin.firestore().collection("users").doc(userId).get();

        if (!userDoc.exists) {
          console.log("❌ User not found");
          await updateNotificationStatus("failed", {
            error: "User not found",
          });
          return null;
        }

        const token = userDoc.data().fcmToken;

        if (!token) {
          console.log("❌ No FCM token for user");
          await updateNotificationStatus("failed", {
            error: "No FCM token for user",
          });
          return null;
        }

        const response = await admin.messaging().send({
          token: token,
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
            headers: highPriority
              ? { "apns-priority": "10" }
              : { "apns-priority": "5" },
            payload: {
              aps: withSound ? { sound: "default" } : {},
            },
          },
        });

        console.log("✅ Sent to specific user:", response);
        await updateNotificationStatus("sent", {
          deliveredTo: userId,
          deliveryType: "specificUser",
          messageId: response,
        });
        return null;
      }

      // ===============================
      // 🟢 2. SEND TO ALL USERS / SEGMENT (TOPIC)
      // ===============================
      let topic = "allUsers";

      if (audience === "User Segment" && segment) {
        topic = `segment_${segment}`;
      }

      console.log("📢 Sending to topic:", topic);

      const response = await admin.messaging().send({
        topic: topic,
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
          headers: highPriority
            ? { "apns-priority": "10" }
            : { "apns-priority": "5" },
          payload: {
            aps: withSound ? { sound: "default" } : {},
          },
        },
      });

      console.log("✅ Sent to topic:", response);
      await updateNotificationStatus("sent", {
        deliveredTo: topic,
        deliveryType: audience === "User Segment" ? "segment" : "topic",
        messageId: response,
      });

    } catch (error) {
      console.error("🔥 Error sending notification:", error);
      await updateNotificationStatus("failed", {
        error: error instanceof Error ? error.message : String(error),
      });
    }

    return null;
  }
);
