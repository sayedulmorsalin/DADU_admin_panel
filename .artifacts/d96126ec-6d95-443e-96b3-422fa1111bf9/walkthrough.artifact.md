# Walkthrough - Image Support in Admin Chat

I have updated the Admin Panel to support sending and receiving images in the chat.

## Changes Made

### 1. Updated `ApiService`
- Modified `sendReply` to support an optional `imageUrl` parameter.
- This ensures that when an admin sends an image, the URL is correctly passed to the backend.

### 2. Enhanced `ImageUploadService`
- Added `uploadChatImage` method to handle uploading images specifically for chat.
- It uses Cloudflare R2 for storage, consistent with other image uploads in the admin panel.

### 3. Updated `AdminChatScreen`
- **Display Images**: Message bubbles now check for an `imageUrl` and display it using `CachedNetworkImage` for efficiency.
- **Image Picker**: Added an image icon in the message input area to select images from the gallery.
- **Image Preview**: Selected images are displayed in a preview area above the input field with an option to remove them before sending.
- **Send Logic**: When sending a message, if an image is selected, it is uploaded to R2 first, and then the URL is included in the message reply.

## Verification Results

- The code has been analyzed and confirmed to be free of critical errors.
- The UI components were added following the existing style of the Admin Panel.
- Image selection and preview logic were integrated into the `AdminChatScreen` state.

> [!NOTE]
> The admin panel uses Cloudflare R2 for uploads, while the client app might use Cloudinary. The backend handles these as simple URLs, so images from both sources will display correctly in both apps.
