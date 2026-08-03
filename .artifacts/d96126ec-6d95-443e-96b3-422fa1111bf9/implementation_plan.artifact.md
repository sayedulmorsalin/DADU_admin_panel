# Implementation Plan - Display and Send Images in Chat

The Dadu app now supports sending images in messages. This plan covers updating the Admin Panel to display these images and enabling the admin to send images as well.

## User Review Required

> [!IMPORTANT]
> I will be using Cloudflare R2 for uploading chat images from the admin panel, as it's the primary storage used in the admin panel's `ImageUploadService`. The client app uses Cloudinary, but both should work as the backend stores and provides the full URL.

## Proposed Changes

### [ApiService]

#### [MODIFY] [api_service.dart](file:///D:/all code/Flutter all projects/dadu_admin_panel/lib/services/api_service.dart)
- Update `sendReply` to accept an optional `imageUrl`.

### [ImageUploadService]

#### [MODIFY] [image_upload_service.dart](file:///D:/all code/Flutter all projects/dadu_admin_panel/lib/pages/services/image_upload_service.dart)
- Add `uploadChatImage` method to upload a chat image to Cloudflare R2.

### [AdminChatScreen]

#### [MODIFY] [admin_chat_screen.dart](file:///D:/all code/Flutter all projects/dadu_admin_panel/lib/pages/screens/admin_chat_screen.dart)
- Update the message bubble to display an image if `imageUrl` is present in the message data.
- Use `CachedNetworkImage` for better performance and error handling.
- Add an image picker button to the message input area.
- Add UI to preview the selected image before sending.
- Update `_sendMessage` logic to upload the image if selected and include its URL in the API call.

## Verification Plan

### Automated Tests
- I'll check for compilation errors after changes.

### Manual Verification
- Deploy the admin panel and navigate to a message thread.
- Verify that messages with images from the client app are displayed correctly.
- Test sending a text-only message.
- Test sending an image-only message (with optional text).
- Test sending a message with both text and an image.
- Verify that the image is uploaded to R2 and displayed in the chat.
