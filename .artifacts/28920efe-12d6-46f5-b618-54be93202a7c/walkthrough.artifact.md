# Walkthrough - Android-Only Notification Image Fix

I have optimized the Firebase Cloud Function to ensure notification images are displayed correctly on Android. By focusing exclusively on Android, I've made the payload more robust and eliminated unnecessary iOS-specific code.

## Changes Made

### Firebase Cloud Functions

#### [index.js](file:///D:/all code/Flutter all projects/dadu_admin_panel/functions/index.js)
- **Android-Specific Optimization**:
    - Removed all APNS (iOS) specific code to simplify the payload.
    - Set `android.priority` to `"high"` for all messages to ensure immediate delivery and background processing.
    - Set `android.notification.notificationPriority` to `"PRIORITY_MAX"` and `visibility` to `"PUBLIC"`. This forces Android to display the notification as an expanded banner with the image when possible.
    - Added `channelId: "default_channel"`. This is a common standard for high-importance notifications in Flutter.
- **Payload Reliability**:
    - Ensured the `image` field is set correctly in both the `notification` and `android.notification` objects.
    - Continued to provide `image` and `imageUrl` in the `data` block for app-level handling.
- **Unified Order Notifications**: Applied the same high-priority, Android-focused logic to the `sendOrderPushNotification` function.

## How to Deploy

Redeploy your Cloud Functions to apply these Android optimizations:

```bash
firebase deploy --only functions
```

## How to Verify

1.  **Test Send**: Use the Admin Panel to send a notification with a direct link to an image.
2.  **Notification Tray**: Check the notification on your Android device. It should now appear with the image, especially if you expand the notification.
3.  **Tapping**: Verify that tapping the notification still opens the correct deep link.
