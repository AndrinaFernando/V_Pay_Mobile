# VPay Member 3 Implementation and Team Handoff

**Last reviewed:** 16 November 2026
**Purpose:** explain Member 3's current implementation, remaining work and dependencies needed to finish and integrate the VPay application. This document distinguishes code present in the checked-out repositories from work another member still owns.

## Repository state

- Flutter mobile: `D:\V_Pay\V_Pay_Mobile`
- Node.js/Express backend: `D:\V_Pay\V_Pay_Backend`
- Current branch in both repositories: `integration/merchant-customer`
- The attached **VPay Updated Architecture, Member Responsibilities and Timeline** is the project planning reference. Its responsibility assignments are planning guidance; the implementation status below is based on the current code.
- The working trees contain uncommitted changes. This handoff does not mean those changes have been reviewed, committed, pushed or merged to another branch.

## Member 3 scope and status

| Responsibility | Current status | Notes |
|---|---|---|
| Merchant dashboard | **Implemented** | Uses authenticated profile data, VPay branding, balance card, Create action, recent received-payment area and merchant navigation. |
| Merchant balance display | **Implemented** | Calls the authenticated read-only backend balance endpoint; no balance is hard-coded or changed by Flutter. |
| Create Payment Request | **Implemented** | LKR amount entry, positive/range/precision validation, optional description, loading, duplicate-submit prevention and API errors. |
| Payment-intent create/retrieve/expiry | **Implemented** | Backend verifies authentication and active merchant role, derives UID from the token, checks ownership on retrieval and enforces expiry server-side. |
| Merchant QR | **Implemented** | Encodes the payment reference only and displays amount, reference, creation/expiry details and countdown. |
| Pending/final status UI | **Implemented** | Polls while `PENDING` or `PROCESSING`; displays `SUCCESS`, `FAILED` and `EXPIRED` distinctly. Network errors remain uncertain. |
| Refresh on confirmed success | **Implemented** | A backend-confirmed `SUCCESS` triggers one balance/history refresh; returning from QR does not issue a duplicate success refresh. |
| Merchant received-payments UI/client | **Implemented, backend dependency pending** | Authenticated Flutter service, model, list UI, loading/empty/error/retry/refresh states are present. The backend endpoint is not present in the current backend routes. Member 5 owns it. |
| Merchant Profile and Logout | **Implemented** | Reuses the shared account/profile and Firebase sign-out flow. This was added to the merchant UI scope beyond the original payment-flow assignment. |
| Terminal tab | **Not part of current navigation** | The extra Terminal tab was removed; the navigation uses Dashboard, Create, Payments and Profile. Do not add another terminal page or duplicate QR/payment logic without a new team decision. |

**Member 3 completion assessment:** the assigned Flutter and backend payment-intent flow, balance display, profile/logout and received-payments client integration are implemented in this branch. The received-payment feature is not end-to-end until Member 5's backend history endpoint is available and the full cross-member flow is verified against the integrated backend. No separate Member 3 production-code feature is currently identified beyond that integration/verification work.

## Member 3 implementation map

### Flutter

- `lib/features/merchant/screens/merchant_dashboard_screen.dart` — merchant dashboard, balance and received-payment views, navigation, refresh coordination and success callback wiring.
- `lib/features/merchant/screens/create_payment_request_screen.dart` — amount/description form, amount validation, duplicate-submit guard and payment-intent creation.
- `lib/features/merchant/screens/payment_intent_qr_screen.dart` — QR presentation, countdown, polling, retryable network errors and final status UI.
- `lib/features/merchant/models/merchant_payment_intent.dart` — payment-intent response model. `qrPayload` returns only `paymentReference`. A legacy `COMPLETED` response is normalized to the agreed `SUCCESS` UI status; keep this compatibility mapping documented until the team confirms old responses are no longer produced.
- `lib/features/merchant/services/payment_intent_service.dart` — create, retrieve and list calls through the shared authenticated `ApiClient`.
- `lib/features/merchant/models/merchant_balance.dart` and `lib/features/merchant/services/merchant_balance_service.dart` — LKR balance represented in integer minor units and fetched through the authenticated client.
- `lib/features/merchant/models/merchant_received_payment.dart`, `lib/features/merchant/services/merchant_received_payments_service.dart` and `lib/features/merchant/widgets/merchant_received_payment_tile.dart` — received-payment response model, service and reusable row.
- `lib/features/merchant/screens/merchant_profile_screen.dart` — merchant account/business profile display and logout UI.
- `lib/features/auth/vpay_account_gate.dart` and `lib/features/auth/models/vpay_user_profile.dart` — shared account routing and merchant business profile data consumed by the merchant screens. Coordinate changes to these shared auth files with Member 1.
- `lib/core/network/api_client.dart` — shared authenticated HTTP client; it attaches the Firebase ID token. Merchant services should continue using it instead of creating another client.
- `lib/core/network/api_config.dart` — environment-configurable backend base URL; Android emulator development uses `10.0.2.2` with the configured local backend port. Deployment should use the deployment URL; do not alter Firebase project configuration for this feature.

### Backend

- `src/app.js` mounts the modules below under `/api`.
- `src/modules/payments/payment.routes.js` exposes payment-intent and customer payment routes.
- `src/modules/payments/payment.controller.js`, `payment.validation.js` and `payment.service.js` implement request validation, authenticated controller responses, intent ownership/expiry and Member 4's separate customer payment execution code. Keep edits to payment execution, transfers and ledger writes with Member 4.
- `src/modules/merchant/merchant.routes.js`, `merchant.controller.js` and `merchant.service.js` expose and implement the read-only merchant balance operation.
- Backend Firebase Admin configuration and authentication middleware remain the source of truth. Do not expose credentials or add Flutter Firestore writes.

## Current API and data contracts

### Payment intents

The backend mounts these merchant intent paths (all under `/api`):

| Method and path | Purpose | Access/behavior |
|---|---|---|
| `POST /api/payment-intents` | Create a payment intent | Firebase-authenticated, verified active merchant. UID comes from the verified token, not a client-supplied merchant ID. |
| `GET /api/payment-intents/:paymentReference` | Retrieve an intent/status | Authenticated merchant owner only; server applies expiry rules. Response envelope is `{ success: true, data: { paymentIntent } }`. |
| `GET /api/payment-intents?limit=...` | List a merchant's intents | Authenticated; bounded list limit. This is not a replacement for the transaction-history endpoint. |

Create body currently accepts `amountMinor`, `currency: "LKR"`, optional `description`, and optional `expiresInSeconds`. The backend enforces integer minor units from **1000 through 10,000,000** (LKR 10.00 to LKR 100,000.00), LKR currency, description up to 200 characters, and expiry from 60 to 86,400 seconds (default 900 seconds). Flutter's default form uses the same LKR amount range and two-decimal entry rule.

Create returns HTTP `201` with `{ success: true, data: { paymentIntent } }`; retrieval returns HTTP `200` with the same envelope. The public intent includes the generated `paymentReference`, merchant name, amount/currency, status, server timestamps and optional description. Errors use `{ success: false, message }` (payment execution errors may also include a stable `code`).

`paymentReference` is generated by the backend and identifies the Firestore `paymentIntents` document. The QR contains only that reference. Creation timestamps and expiry are server-generated. Current agreed statuses are `PENDING`, `PROCESSING`, `SUCCESS`, `FAILED`, and `EXPIRED`. The backend expires overdue pending intents. Member 4 owns customer confirmation, atomic customer debit/merchant credit, successful ledger writes and authoritative final payment results. Flutter never creates or changes financial records.

The separate `GET /api/payment-intents/:paymentReference/payment-status` route is part of the customer payment operations. Merchant status UI uses the merchant-owned intent retrieval route above, which returns the full owned intent.

### Merchant balance

- `GET /api/merchant/balance`
- Requires Firebase authentication, verified email, an active `MERCHANT` user and an active valid merchant wallet.
- Identity is derived from the verified token. Backend reads `merchantAccounts/{uid}` and returns `{ success: true, data: { balanceMinor, currency: "LKR" } }`.
- `balanceMinor` is a non-negative safe integer in LKR minor units. Missing/inactive/malformed wallets return errors; this read route never creates or changes a wallet.
- Flutter formats this response for display and never writes to it.

### Merchant received payments — Member 5 dependency

The Flutter client is wired for the team's approved contract:

- `GET /api/merchant/transactions?limit=20` (Flutter requests 50 for the dashboard list; the backend contract allows a maximum of 50).
- Expected response: `{ success: true, data: { transactions: [...] } }`.
- Each item: `transactionId`, `paymentReference`, `amountMinor`, `currency`, `status`, `createdAt`.
- Only successful `QR_PAYMENT` records for the authenticated merchant, newest first, verified against successful payment intents; empty results return `[]`.

**Current blocker:** this path does not exist in `src/modules/merchant/merchant.routes.js` or the current payment routes. Member 5 explicitly approved and took responsibility for implementing the endpoint, Firestore index and backend tests. Do not add a duplicate backend endpoint in Member 3's work. After Member 5 merges it, verify the response amount units, timestamp format, ownership filtering and index against the Flutter service/model.

## Security and ownership rules for future contributors

1. Derive customer/merchant UIDs from verified Firebase ID tokens on the backend. Do not trust UID or merchant ID values in request bodies or query strings.
2. A merchant UI may display a final status only after the backend returns it. Network errors are unknown/temporary states, never evidence of success or failure.
3. Do not debit/credit balances, write transactions, or mark a payment successful from Flutter.
4. Keep payment-reference QR payload compatibility with the customer scanner. Do not put credentials, account balances or private profile data in the QR.
5. Do not change Member 4's customer confirmation/atomic transfer path while working on Member 3 presentation or read APIs.
6. Do not invent received-payment records, substitute customer card balance for merchant balance, or create a second source of financial truth.

## Other member work and handoffs

The items below describe team ownership from the architecture/responsibility plan and current route evidence. Confirm progress with the owner before assuming an item is unfinished or changing shared code.

### Member 1 — shared authentication, profile and card functionality

- Own Firebase email/password authentication, email verification/password reset, role onboarding/profile bootstrap, role routing/protected access, customer virtual-card creation/read and Customer Home.
- Own card `ACTIVE`/`FROZEN` state, backend/UI freeze and unfreeze, and sensitive card-action confirmation through the existing device-authentication facade.
- The current backend card routes expose authenticated `GET /api/card`; the route file does not expose freeze/unfreeze actions. Confirm those actions' status with Member 1 and keep the card-state contract stable for Member 4.
- Coordinate changes to `vpay_account_gate.dart`, `vpay_user_profile.dart` and shared account screens. Preserve both `CUSTOMER` and `MERCHANT` routing, Firebase sign-out behavior and protected-route handling.

### Member 2 — customer top-up

- The current backend contains authenticated top-up create/list/detail paths and a signed Rupio webhook in `src/modules/topups/topup.routes.js`; `topup.service.js` and `rupio.adapter.js` own provider processing. The plan calls the simulator MockPay, so confirm whether Rupio is the team's intended adapter/name or a temporary implementation.
- Member 2 owns the separate hosted provider simulation, SUCCESS/DECLINED/TIMEOUT/CANCELLED outcomes, verified callback/idempotency, exactly-once customer credit, `TOP_UP` ledger record, and Flutter checkout/receipt flow. Verify integrated tests and provider configuration with Member 2; never use top-up code to alter merchant funds.

### Member 4 — customer QR payment engine

- The current payment routes include customer preview, confirmation and minimal payment-status operations; payment execution and atomic financial writes are in `src/modules/payments/payment.service.js`.
- Own scanning/permission and customer confirmation UI, authoritative payment execution, idempotency/recovery behavior, customer debit, merchant credit, `QR_PAYMENT` transaction creation, and final `SUCCESS`/failure behavior.
- Coordinate status/reference/amount and wallet semantics with Member 3. In particular, ensure status retrieval for the merchant reads the same final intent updated by confirmation, and success is not returned before the transaction commits.

### Member 5 — transaction history and notifications

- Implement the approved merchant transaction-history endpoint, Firestore index and backend security/ownership tests. Member 3's Flutter UI already consumes the agreed response shape.
- Own shared transaction history conventions/formatting and notification/integration work assigned by the project plan. Coordinate the final response timestamps/amount units and merge availability with Member 3.

## Remaining actions for Member 3

1. **Wait for/coordinate Member 5's history endpoint.** Once available on the integration branch, run the Flutter history service/widget tests against its final response contract and perform an authenticated emulator check. Do not duplicate the backend endpoint.
2. **Verify full end-to-end integration with Member 4.** On a test environment, merchant creates QR -> customer scans/confirms -> backend commits the payment -> merchant sees `SUCCESS` -> balance and history reload. Use test fixtures/test accounts; do not change production financial data.
3. **Confirm the integrated branches and API URLs.** Verify both repositories point to the intended shared integration state and the Android emulator can reach the backend. Keep local/deployment configuration distinct and never commit secrets.
4. **Regression-check role navigation and logout** after shared auth changes from Member 1. Customer behavior must remain intact.

No new payment engine, Terminal tab, Firestore model, package or endpoint is currently required from Member 3. If the product owners add merchant-specific terminal operations, agree on their distinct purpose and backend contract before implementation; the current Create, Payments and Profile flows already cover the merchant features described here.

## Dependency order and future scope

- **Shared baseline:** Member 1's verified auth, role/profile and card-read contracts underpin Members 2, 3 and 4. Member 2 and Member 3 can proceed in parallel once this baseline exists.
- **Payment contract handoff:** Member 3 produces the intent reference, amount, merchant identity, expiry and status lookup contract; Member 4 consumes it. That contract is already implemented in this branch. Member 4's card-state handling also depends on Member 1's `ACTIVE`/`FROZEN` contract.
- **History integration:** Members 2 and 4 write their own trustworthy `TOP_UP` and `QR_PAYMENT` records during the money-changing operation. Member 5 queries and presents those records; it must not recreate missing ledger entries. This is why the Member 3 received-payment UI can be ready while the endpoint remains pending.
- **Integration/QA:** Member 5 coordinates common response/error conventions, notifications, logging/reference consistency, deployment and end-to-end/regression testing. The integration definition of done is a target-device flow with backend-authenticated APIs, success and failure cases, and no manual Firestore repair.
- **Post-core only:** after the mandatory top-up and QR-payment flows are stable, a later approved extension may add a separate MockBank simulator (project owner/Member 1), settlement/refund UI (Member 3), authoritative refund and bounded negative-balance rules (Member 4), and settlement/refund history/notifications (Member 5). These are not Member 3's current unfinished core work and must not delay core integration.

## Verification record

Most recent Flutter verification for the payment-result integration:

- `flutter test` — **PASS**: 130 passed, 1 skipped.
- `flutter analyze` — no errors; 6 informational curly-brace style lints remain in top-up files.
- Added/covered merchant tests include pending-to-success, processing-to-success, failed, expired, temporary network interruption/retry, dashboard balance/history refresh exactly once, and returning from the request flow.
- Backend tests were **not rerun as part of that Flutter verification**. Run the backend repository's configured test command after Member 5's endpoint is merged; do not treat Flutter tests as proof of backend authorization or live Firebase behavior.

## Final status

Member 3's merchant create-request, payment-intent, QR, status, balance, profile/logout and Flutter received-payment integration are implemented in the current integration branch. The remaining Member 3 work is cross-member integration and verification, especially consuming Member 5's not-yet-present merchant transaction-history endpoint and exercising the complete customer-to-merchant payment flow with Member 4. Backend financial writes remain owned by the backend payment flow; Flutter is display/read-only for authoritative balances and results.
