# Implementation Plan - Display Order Notes and Send to Steadfast

The Dadu app allows users to add a note during checkout. This plan covers displaying this note in the Admin Panel's verification and shipping screens and ensuring it's sent to Steadfast when an order is shipped.

## User Review Required

> [!NOTE]
> The note is already being sent to Steadfast in the `Shipping` screen. This task focuses on making it visible to the admin during the verification process.

## Proposed Changes

### [Verify Screen]

#### [MODIFY] [verify.dart](file:///D:/all code/Flutter all projects/dadu_admin_panel/lib/pages/screens/verify.dart)
- Update `_buildOrderSummary` to include the `note` field in the generated summary text.
- Update `_buildSearchableText` to make the `note` field searchable.
- In the `ListView.builder`, add a `buildSafeText` or `buildCopyableRow` for the "Note" field so admins can see it while verifying the order.

### [Shipping Screen]

#### [MODIFY] [shipping.dart](file:///D:/all code/Flutter all projects/dadu_admin_panel/lib/pages/screens/shipping.dart)
- Update `_buildSearchableText` to include the `note` field.
- In the `ListView.builder`, add `buildSafeText("Note", order['note'])` to the expanded order details.

## Verification Plan

### Manual Verification
- Place an order in the Dadu app with a custom note.
- Open the Admin Panel and go to the "Verify Orders" screen.
- Verify that the note is visible and searchable.
- Accept the order and move it to "Shipping".
- Go to the "Shipping Orders" screen and verify the note is still visible.
- Click "Shipped" and verify (via Steadfast logs if possible, or by confirming the API call includes the note) that the note is sent to Steadfast.
