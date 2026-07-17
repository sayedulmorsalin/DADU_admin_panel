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
    const link = data.link || data.deepLink || "";
    const image = data.image || "";
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

      const expiresAt = new Date();
      expiresAt.setHours(expiresAt.getHours() + 24);

      await notificationRef.set(
        {
          status,
          ...extra,
          processedAt: serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
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
      // Base message structure optimized for Android
      const baseMessage = {
        notification: {
          title: title,
          body: body,
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high", // High priority for the message delivery
          notification: {
            sound: withSound ? "default" : undefined,
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
            notificationPriority: "PRIORITY_MAX", // Visual priority
            visibility: "PUBLIC",
            channelId: "default_channel", // A common standard, can be customized
          },
        },
      };

      // Add image if provided
      if (image && image.trim().length > 0) {
        const imageUrl = image.trim();
        baseMessage.notification.image = imageUrl;
        baseMessage.android.notification.image = imageUrl;
        baseMessage.data.image = imageUrl;
        baseMessage.data.imageUrl = imageUrl;
      }

      // Add link if provided
      if (link && link.trim().length > 0) {
        baseMessage.data.link = link;
        baseMessage.data.deepLink = link;
      }

      console.log("📤 Final Message Payload:", JSON.stringify(baseMessage, null, 2));

      // ===============================
      // 🔴 1. SEND TO SPECIFIC USER (TOKEN)
      // ===============================
      if (audience === "Specific User" && userId) {
        console.log("👤 Sending to specific user:", userId);

        let userDoc = await admin.firestore().collection("users").doc(userId).get();

        // If not found by ID, try searching by email
        if (!userDoc.exists) {
          console.log("🔍 User not found by ID, searching by email...");
          const userQuery = await admin.firestore().collection("users").where("email", "==", userId).limit(1).get();
          if (!userQuery.empty) {
            userDoc = userQuery.docs[0];
          }
        }

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
          ...baseMessage,
          token: token,
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
        ...baseMessage,
        topic: topic,
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

exports.sendOrderPushNotification = onDocumentCreated(
  {
    document: "order_push_notifications/{id}",
    region: "asia-south1",
  },
  async (event) => {
    console.log("🚀 ORDER PUSH NOTIFICATION TRIGGERED");

    const snapshot = event.data;
    if (!snapshot) return null;

    const notificationRef = snapshot.ref;
    const data = snapshot.data();

    const { title, body, userId, link, image } = data;

    if (!title || !body || !userId) {
      console.log("❌ Missing title, body, or userId");
      await notificationRef.delete();
      return null;
    }

    try {
      console.log("👤 Fetching user:", userId);
      const userDoc = await admin.firestore().collection("users").doc(userId).get();

      if (!userDoc.exists) {
        console.log("❌ User not found");
        await notificationRef.delete();
        return null;
      }

      const token = userDoc.data().fcmToken;

      if (!token) {
        console.log("❌ No FCM token for user");
        await notificationRef.delete();
        return null;
      }

      const message = {
        token: token,
        notification: {
          title: title,
          body: body,
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
            notificationPriority: "PRIORITY_MAX",
            visibility: "PUBLIC",
            channelId: "default_channel",
          },
        },
      };

      if (image && image.trim().length > 0) {
        const imageUrl = image.trim();
        message.notification.image = imageUrl;
        message.android.notification.image = imageUrl;
        message.data.image = imageUrl;
        message.data.imageUrl = imageUrl;
      }

      if (link && link.trim().length > 0) {
        message.data.link = link;
        message.data.deepLink = link;
      }

      const response = await admin.messaging().send(message);

      console.log("✅ Sent order notification:", response);
    } catch (error) {
      console.error("🔥 Error sending notification:", error);
    } finally {
      // Always delete the document after attempt (as per user request)
      console.log("🗑️ Deleting notification document");
      await notificationRef.delete();
    }

    return null;
  }
);
