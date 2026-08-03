# Implementation Plan - Add Loading Indicators to Order Actions

Add loading overlays to order processing actions in the Verify, Shipping, and Receive screens to prevent duplicate submissions and provide visual feedback.

## Proposed Changes

### [UI Enhancements]

#### [MODIFY] [verify.dart](file:///D:/all code/Flutter all projects/dadu_admin_panel/lib/pages/screens/verify.dart)
- Add a loading dialog to `_rejectOrder` method.
- (Existing `_acceptOrder` already has a loading indicator).

#### [MODIFY] [shipping.dart](file:///D:/all code/Flutter all projects/dadu_admin_panel/lib/pages/screens/shipping.dart)
- Add a loading dialog to `_cancelOrder` method.
- (Existing `_shippedOrder` already has a loading indicator).

#### [MODIFY] [receive.dart](file:///D:/all code/Flutter all projects/dadu_admin_panel/lib/pages/screens/receive.dart)
- Add a loading dialog to `_cancelOrder` method.
- Add a loading dialog to `_completeOrder` method.

## Verification Plan

### Manual Verification
1.  Navigate to the **Verify** screen and click **Reject** on an order.
    - Verify a loading indicator appears.
    - Verify the order is removed and the loader disappears after completion.
2.  Navigate to the **Shipping** screen and click **Canceled** on an order.
    - Verify a loading indicator appears.
3.  Navigate to the **Receive** screen and click **Canceled** or **Delivered** on an order.
    - Verify a loading indicator appears.
4.  Confirm that multiple rapid clicks are prevented while the loader is active.
