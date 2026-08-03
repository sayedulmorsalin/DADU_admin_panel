# Implementation Plan: Real-time WebSocket Chat for Admin Panel

This plan outlines the steps to replicate the real-time WebSocket chat system from the `DADU` user app into the `dadu_admin_panel`. This will replace the current 10-second polling mechanism with a more efficient and responsive WebSocket connection.

## User Review Required

> [!IMPORTANT]
> The current project does not use `GetX` for state management in the chat screen. I will implement the `ChatSocketService` as a singleton class with a `StreamController` for message events, which is compatible with the existing `StatefulWidget` architecture.

## Proposed Changes

### Dependencies

#### [MODIFY] [pubspec.yaml](file:///D:/all%20code/Flutter%20all%20projects/dadu_admin_panel/pubspec.yaml)
- Add `web_socket_channel: ^3.0.1` (or latest stable version).

### Core Services

#### [NEW] [chat_socket_service.dart](file:///D:/all%20code/Flutter%20all%20projects/dadu_admin_panel/lib/services/chat_socket_service.dart)
- Implement a singleton `ChatSocketService` to manage the WebSocket connection.
- Features:
    - Connection management with Firebase ID token authentication.
    - Automatic reconnection logic.
    - `StreamController` to broadcast incoming messages.
    - Methods to send messages and typing indicators.
    - WebSocket URL derivation from `apiBaseUrl`.

### UI Components

#### [MODIFY] [admin_chat_screen.dart](file:///D:/all%20code/Flutter%20all%20projects/dadu_admin_panel/lib/pages/screens/admin_chat_screen.dart)
- Remove `_pollingTimer` and related polling logic.
- Integrate `ChatSocketService`:
    - Connect to the socket on `initState`.
    - Listen to the message stream and update `_messages` list in real-time.
    - Update `_sendMessage` to prioritize WebSocket delivery, falling back to HTTP if necessary.
    - Add UI support for typing indicators (showing when the user is typing).
    - Handle socket connection state (show status if helpful).
    - Add a `TypingIndicator` widget with a bouncing dots animation that appears when the user is typing.

#### [MODIFY] [message_threads.dart](file:///D:/all%20code/Flutter%20all%20projects/dadu_admin_panel/lib/pages/screens/message_threads.dart)
- (Optional but recommended) Ensure the threads list also updates or at least refreshes properly when new messages arrive if the socket is global, though the source implementation seems room-specific.

## Verification Plan

### Automated Tests
- Since this is a UI-heavy change involving WebSockets, verification will be primarily manual. I will ensure the code builds and follows the pattern from the working `DADU` project.

### Manual Verification
- Deploy to an Android device/emulator.
- Open a chat thread.
- Verify that messages sent from the user app appear instantly in the admin panel.
- Verify that replies sent from the admin panel appear instantly in the user app.
- Verify typing indicators.
- Test connection recovery (e.g., toggling internet connection).
