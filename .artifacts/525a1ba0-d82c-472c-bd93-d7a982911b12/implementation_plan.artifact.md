# Implementation Plan - Transaction ID Tracking & Search

Implement Transaction ID input during order verification and ensure it is displayed and searchable across all subsequent order stages.

## Proposed Changes

### [Database Layer]

#### [MODIFY] [database_service.dart](file:///D:/all code/Flutter all projects/dadu_admin_panel/lib/pages/services/database_service.dart)
- Update `_moveOrder` to accept an optional `Map<String, dynamic> extraData` to merge into moved orders.
- Update `moveItemsToShip` to take `transactionId` and pass it to `_moveOrder`.

### [Verify Orders Screen]

#### [MODIFY] [verify.dart](file:///D:/all code/Flutter all projects/dadu_admin_panel/lib/pages/screens/verify.dart)
- **Input**: Update `_acceptOrder` to show a dialog with a `TextField` for the Transaction ID.
- **Search**: Implement search UI (search bar) and fuzzy search logic.
- **Display**: Show Transaction ID if present (though usually added here).

### [Shipping & Receive Screens]

#### [MODIFY] [shipping.dart](file:///D:/all code/Flutter all projects/dadu_admin_panel/lib/pages/screens/shipping.dart)
#### [MODIFY] [receive.dart](file:///D:/all code/Flutter all projects/dadu_admin_panel/lib/pages/screens/receive.dart)
- **Display**: Show `Transaction ID` prominently in the order card.
- **Search**: Update `_buildSearchableText` to include `transactionId`.

### [Delivered Screen]

#### [MODIFY] [delivered.dart](file:///D:/all code/Flutter all projects/dadu_admin_panel/lib/pages/screens/delivered.dart)
- **Search**: Implement search UI and fuzzy search logic (consistent with other screens).
- **Display**: Show `Transaction ID` in the order card.

## Verification Plan

### Manual Verification
1. **Verify**: Accept an order, enter "TEST-TXN-123".
2. **Search**: In the Verify screen, search for "TEST-TXN-123".
3. **Flow**: Move the order to Shipping -> Receive -> Delivered.
4. **Verification**: In each screen, confirm "Transaction ID: TEST-TXN-123" is visible and the search bar finds the order when typing that ID.
