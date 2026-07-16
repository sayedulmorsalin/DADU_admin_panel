# Implementation Plan - Fix Notification Payload and Individual Delivery

The user reports that images and deep links are still not working correctly, particularly for individual users, although images started working for "All Users".

## Research Findings
- **Field Consistency**: The `Specific User` and `Topic` payloads are structured similarly, but empty strings in `image` and `link` might be causing issues.
- **Android Property Names**: In `firebase-admin`, `clickAction` is the correct property name for the SDK, but adding `click_action` to the `data` payload is also essential for Flutter's background handling.
- **Missing Sync**: The `sendOrderPushNotification` function was completely ignored in previous updates and lacks image/link support.
- **Robustness**: The Cloud Function should only include `image` and `link` in the payload if they are non-empty.

## Proposed Changes

### Firebase Cloud Functions

#### [MODIFY] [index.js](file:///D:/all code/Flutter all projects/dadu_admin_panel/functions/index.js)
1.  **Refactor Payload Generation**: Create a helper function or a clean logic to build the FCM message. This ensures consistency between "Specific User" and "All Users" flows.
2.  **Conditional Fields**: Only add `image` and `link` to the payload if they are not empty. Sending `""` can break notification rendering.
3.  **Standardize Click Action**: Use both `clickAction` (for SDK) and `click_action` (in `data` for Flutter plugin) to ensure the app opens on tap.
4.  **Update Order Notifications**: Bring `sendOrderPushNotification` up to parity with the main `sendNotification` logic, allowing it to also carry links and images if added in the future.
5.  **User Lookup**: Ensure `userId` can be looked up effectively.

## Verification Plan

### Manual Verification
- **Deployment**: `firebase deploy --only functions`
- **Testing**:
  1. Send a notification to "All Users" with an image and link. Verify success.
  2. Send a notification to a "Specific User" with an image and link. Verify success.
  3. Send a notification with NO image and NO link. Verify it still arrives as a plain text notification.
  4. Test tapping the notification when the app is in the background to verify deep linking.
