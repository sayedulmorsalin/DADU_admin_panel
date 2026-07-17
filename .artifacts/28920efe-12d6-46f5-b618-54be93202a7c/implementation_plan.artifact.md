# Implementation Plan - Fix Android-Only Notification Images

Since the app is Android-only, I will focus exclusively on optimizing the Android FCM payload to ensure images are displayed correctly in the system tray.

## Research Findings
- **Android-Specific Fields**: To guarantee images show up as "BigPicture" notifications on Android, we should ensure the `android.notification` block is properly configured with `priority: "high"` and the correct `image` field.
- **Notification Channels**: High-priority notifications (required for images/banners) often work best when a `channel_id` is specified, though a default is usually used if omitted.
- **Payload Structure**: I will simplify the payload to remove iOS-specific clutter and focus on the properties that Android's FCM system uses.

## Proposed Changes

### Firebase Cloud Functions

#### [MODIFY] [index.js](file:///D:/all code/Flutter all projects/dadu_admin_panel/functions/index.js)
1. **Focus on Android**: Remove the APNS (iOS) specific code to keep the payload lean.
2. **Optimize Android Notification**:
    - Ensure `android.notification.image` is set.
    - Set `android.priority` to `"high"` (for the message) and `notificationPriority` to `"PRIORITY_MAX"` (for the visual display).
    - Add `default_notification_channel_id` as a common standard for Flutter apps.
3. **Data Payload**: Keep `image` and `link` in the `data` block for app-level processing.
4. **Sync Order Notifications**: Apply the same Android-focused logic to `sendOrderPushNotification`.

## Verification Plan

### Manual Verification
- **Deployment**: `firebase deploy --only functions`
- **Testing**:
  1. Send a notification with an image URL from the Admin Panel.
  2. Verify the notification appears on the Android device with the image visible.
  3. Verify that tapping the notification correctly handles the deep link.
