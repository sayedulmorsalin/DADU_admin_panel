# Implementation Plan - Differentiate Read and Unread Messages

This plan outlines the changes required to visually distinguish between read and unread message threads in the `MessageThreadsPage`.

## User Review Required

> [!IMPORTANT]
> The implementation assumes the backend API (`/admin/messages/users`) provides an `unreadCount` or similar field in the thread object. If this field is named differently (e.g., `unread_count`, `hasUnread`), please let me know.

> [!NOTE]
> I will also add a fallback check: if the last message was from the user and not the admin, we can treat it as "potentially unread" if a dedicated count is missing.

## Proposed Changes

### [Component Name] Messaging UI

#### [MODIFY] [message_threads.dart](file:///D:/all code/Flutter all projects/dadu_admin_panel/lib/pages/screens/message_threads.dart)

- Update the `ListView.separated` item builder to check for unread status.
- Apply different styles for unread threads:
    - **Background Color**: Use a light blue background (e.g., `Colors.blue[50]`) for unread threads.
    - **Unread Badge**: Display a red circular badge with the unread count.
    - **Text Styling**: Make the name or last message timestamp bolder for unread messages.
- Add a "Last Message" snippet if the data is available in the thread object.

#### [MODIFY] [home.dart](file:///D:/all code/Flutter all projects/dadu_admin_panel/lib/pages/screens/home.dart)

- (Optional) Update the "Messages" button on the dashboard to show the total number of unread messages across all threads if that information can be derived or fetched efficiently.

## Verification Plan

### Manual Verification
1. Open the "Messages" screen.
2. Observe that threads with unread messages have a distinct background color and a count badge.
3. Tap on an unread thread to open the chat.
4. Go back to the threads list and verify the thread is now marked as read (after the 30s polling or manual refresh).
