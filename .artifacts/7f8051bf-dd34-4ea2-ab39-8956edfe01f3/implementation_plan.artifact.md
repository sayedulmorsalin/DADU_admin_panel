# Implementation Plan - Infinite Scrolling for Message Threads

This plan outlines the changes to implement pagination (infinite scrolling) in the `MessageThreadsPage`, allowing users to load the next 20 chats when scrolling to the bottom.

## User Review Required

> [!IMPORTANT]
> - **Backend Support**: This implementation assumes the `/admin/messages/users` endpoint supports `page` and `limit` query parameters. I have already updated the `ApiService` to include these.
> - **Polling Interaction**: Real-time polling (every 30s) will refresh the **first page only** to keep the most recent messages updated. Loading more pages will happen only on user scroll.

## Proposed Changes

### UI & Scroll Management

#### [MODIFY] [message_threads.dart](file:///D:/all code/Flutter all projects/dadu_admin_panel/lib/pages/screens/message_threads.dart)
- **State Additions**:
    - `ScrollController _scrollController`: To monitor scroll position.
    - `int _currentPage = 1`: Tracks the current page.
    - `bool _hasMore = true`: Flag to stop loading when no more data is available.
    - `bool _isLoadingMore = false`: Prevents multiple simultaneous load requests.
- **Scroll Listener**:
    - Attach a listener to `_scrollController` that triggers `_loadMoreThreads()` when the user is near the bottom (e.g., 200 pixels from edge).
- **Refactored Loading Logic**:
    - `_loadThreads({bool showLoading = true})`: Resets to page 1 and clears existing threads. Used for initial load and refresh.
    - `_loadMoreThreads()`: Fetches the next page and appends it to `_threads`.
- **List Construction**:
    - Update `ListView.separated` to use `_scrollController`.
    - Add a loading indicator (bottom spinner) as the last item in the list if `_hasMore` is true.

## Verification Plan

### Manual Verification
1. Open the "User Messages" screen.
2. Scroll to the bottom of the first 20 messages.
3. Verify that a loading spinner appears and new messages are appended to the list.
4. Verify that the "Pinned" threads still remain at the top (pinned status check will be applied to newly loaded items as well).
5. Verify that manual refresh (pull-to-refresh or button) correctly resets the list to the first page.
