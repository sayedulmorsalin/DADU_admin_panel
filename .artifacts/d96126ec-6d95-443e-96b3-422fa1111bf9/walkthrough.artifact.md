# Walkthrough - Deep Link Chat Notifications

I have updated the Admin Panel's chat system to trigger push notifications with a deep link when an admin replies to a user.

## Changes Made

### 1. Updated `DatabaseService`
- Modified `sendPushNotification` to accept optional `link` and `image` parameters.
- These fields are now correctly added to the `order_push_notifications` collection in Firestore, which triggers the Cloud Function.

### 2. Enhanced `AdminChatScreen`
- Integrated `DatabaseService` into the chat screen.
- Updated the `_sendMessage` logic to call `sendPushNotification` after a successful reply.
- The notification includes:
    - **Title**: "New Message from Admin"
    - **Body**: The message text or a placeholder if only an image is sent.
    - **Deep Link**: `https://dadubd.com/message`
    - **Image**: The URL of the image sent (if any).

## Verification Results

- **Firestore Trigger**: Verified that the notification document is created with the new fields:
    - `link`: "https://dadubd.com/message"
    - `image`: [Cloudflare R2 URL]
- **Cloud Function Compatibility**: The `functions/index.js` file was reviewed and confirmed to handle these specific fields (`link` and `image`) to build the FCM payload.

> [!TIP]
> This deep link will allow the user's Dadu app to navigate directly to the chat screen when they tap the notification.
