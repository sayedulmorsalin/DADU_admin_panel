# Walkthrough - Transaction ID and Unified Search

I have implemented Transaction ID tracking and a unified search system across all order management screens.

## Changes Made

### 1. Transaction ID Tracking
- **Verify Screen**: When an admin clicks "Accept" on an order, a dialog now prompts for a **Transaction ID**.
- **Data Persistence**: The Transaction ID is saved into each order item within the Firestore `users` collection when the order is moved to the "Shipping" stage.
- **Display**: The Transaction ID is displayed prominently in the order cards on the **Verify**, **Shipping**, **Receive**, and **Delivered** screens.

### 2. Unified Search System
- **New Search Bars**: Added search bars to the **Verify** and **Delivered** screens (consistent with the existing ones in Shipping and Receive).
- **Searchable Fields**: Users can now search for orders by:
  - **Transaction ID**
  - Customer Name / User Name
  - Customer Email / User Email
  - Phone Number
  - District / Thana / Address
  - Payment Method
  - Order ID (if present)
- **Fuzzy Search**: Implemented fuzzy search logic to provide relevant results even with partial or slightly mistyped queries.

### 3. Database Layer
- Updated `DatabaseService` to allow passing extra data (like `transactionId`) when moving orders between stages.
- Ensured that `transactionId` is applied to all items being moved to the `to_ship` list.

## Verification

### Automated Analysis
- Verified that all modified screens (`verify.dart`, `shipping.dart`, `receive.dart`, `delivered.dart`) are syntactically correct and follow the project's design patterns.
- Confirmed that `DatabaseService` transactions correctly merge the `transactionId`.

### Manual Test Steps
1.  Go to the **Verify** screen.
2.  Click **Accept** on any order.
3.  Enter a unique ID (e.g., `TXN-ABC-123`) in the dialog and confirm.
4.  Verify that the order moves to **Shipping** and shows `Transaction ID: TXN-ABC-123`.
5.  Try searching for `TXN-ABC-123` in the **Shipping** search bar.
6.  Move the order to **Receive** and **Delivered**, verifying the ID remains visible and searchable at every step.
