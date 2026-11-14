# VPay Member 3 Implementation and Team Handoff

**Purpose:** record what Member 3's current code implements, the API contract future work should reuse, and the remaining work needed to complete the app. This document describes the checked-out repositories; it does not claim that an unmerged branch is integrated into the team's shared branch.

## Repositories and current branch

- Flutter: `D:\V_Pay\V_Pay_Mobile`
- Node.js/Express backend: `D:\V_Pay\V_Pay_Backend`
- Current local branch observed in both repositories: `feature/merchant-qr`
- The attached architecture and responsibility plan is dated **8 October 2026**. It names `development` as the shared integration branch and assigns the work described below. Treat the plan's proposed merchant-account schema as a proposal that still needs to be frozen with the team.

## Member 3 scope in the updated team plan

The plan assigns Member 3:

- Merchant dashboard and merchant balance display.
- Enter-amount/payment-request UI and validation.
- Payment-intent backend module, expiry, and status retrieval.
- QR generation containing only the payment-intent reference or an approved deep link.
- Pending-payment/status UI.
- Received-payment list integration.
- Displaying Member 4's backend-confirmed final result and updated merchant balance.

The plan assigns actual QR payment execution, customer debit, merchant credit, and transaction-record creation to Member 4. It assigns shared transaction-history querying/presentation and notifications to Member 5. Flutter must not update customer or merchant balances.

## Implemented by Member 3 in the current code

### Flutter merchant entry and dashboard

- [lib/features/auth/vpay_account_gate.dart](lib/features/auth/vpay_account_gate.dart) routes a `MERCHANT` profile to `MerchantDashboardScreen`; the customer routing branch remains present.
- [lib/features/auth/models/vpay_user_profile.dart](lib/features/auth/models/vpay_user_profile.dart) parses optional `businessName` for the merchant dashboard.
- [lib/features/merchant/screens/merchant_dashboard_screen.dart](lib/features/merchant/screens/merchant_dashboard_screen.dart) displays the merchant identity and Create Payment Request action.
- The dashboard deliberately shows an unavailable balance message and an empty received-payments placeholder. It does not display a fabricated balance or payment history.

### Create Payment Request and API integration

- [lib/features/merchant/screens/create_payment_request_screen.dart](lib/features/merchant/screens/create_payment_request_screen.dart) validates positive LKR amounts with up to two decimal places, converts amounts to minor units, prevents duplicate submissions, shows loading/errors, and navigates only after a valid backend response.
- [lib/features/merchant/services/payment_intent_service.dart](lib/features/merchant/services/payment_intent_service.dart) uses the existing shared `ApiClient` through an adapter. It does not create a second HTTP client or write Firestore data from Flutter.
- Creation request: `POST /api/payment-intents` with `amountMinor`, `currency: "LKR"`, and optional `description`.
- Retrieval request: `GET /api/payment-intents/:paymentReference`.
- Both requests use the shared API client, which attaches the authenticated Firebase ID token as a Bearer token.

### QR and payment status

- [lib/features/merchant/models/merchant_payment_intent.dart](lib/features/merchant/models/merchant_payment_intent.dart) represents the server response, including payment reference, amount, currency, status, creation/expiry timestamps, and optional description/paid time.
- The QR payload is the `paymentReference` only. It contains no balance or credentials.
- [lib/features/merchant/screens/payment_intent_qr_screen.dart](lib/features/merchant/screens/payment_intent_qr_screen.dart) shows the server-returned reference, amount, and expiry countdown. It polls authenticated backend status while `PENDING` or `PROCESSING`, stops on a final state or disposal, and does not infer success from a network failure.
- The Flutter model currently maps legacy backend `COMPLETED` to the agreed display value `SUCCESS`. Keep this compatibility mapping only while the team needs it; agree on one canonical status vocabulary before removing it.

### Backend payment intents

- [src/app.js](../V_Pay_Backend/src/app.js) mounts the payment routes.
- [src/modules/payments/payment.routes.js](../V_Pay_Backend/src/modules/payments/payment.routes.js) defines the authenticated create and reference-retrieval routes.
- [src/modules/payments/payment.controller.js](../V_Pay_Backend/src/modules/payments/payment.controller.js) checks email verification, validates request bodies, and returns success/error envelopes.
- [src/modules/payments/payment.validation.js](../V_Pay_Backend/src/modules/payments/payment.validation.js) accepts positive safe-integer `amountMinor`, requires `LKR`, trims optional descriptions up to 200 characters, rejects unexpected fields, and validates `expiresInSeconds` from 60 to 86,400 seconds (default 900 seconds).
- [src/modules/payments/payment.service.js](../V_Pay_Backend/src/modules/payments/payment.service.js) reuses Firebase Admin and Firestore. It derives the merchant UID from the verified Firebase ID token, requires an active `MERCHANT` profile, creates a unique Firestore document ID in `paymentIntents`, stores the intent, returns server-generated timestamps, checks merchant ownership on retrieval, and expires an overdue `PENDING` intent server-side.
- The current status constants are `PENDING`, `PROCESSING`, `SUCCESS`, `FAILED`, and `EXPIRED`. Creation sets `PENDING`; the expiry check can change `PENDING` to `EXPIRED`. This Member 3 code does not execute a payment or write `SUCCESS`/`FAILED` outcomes.

Current Firestore intent fields written on creation are:

| Field | Source / meaning |
|---|---|
| `merchantUid` | UID from the verified Firebase ID token |
| `merchantName` | Merchant profile's `businessName` |
| `amountMinor` | Validated amount in LKR minor units |
| `currency` | `LKR` |
| `status` | Starts as `PENDING` |
| `createdAt` | Backend-generated time |
| `expiresAt` | Backend-generated time plus the validated duration |
| `description` | Optional trimmed merchant description |

`paymentReference` is the Firestore document ID, not a client-supplied field. `paidAt` is included in the public response if a later backend operation has stored it; Member 3 does not create that payment result.

### Local Android emulator API URL

- [lib/core/network/api_config.dart](lib/core/network/api_config.dart) uses `VPAY_API_BASE_URL` as a compile-time override and defaults to `http://10.0.2.2:3000` for the Android emulator reaching the Windows host.
- The debug Android manifest already allows internet access and local cleartext HTTP. No release cleartext permission was added.
- Deployment should pass the real HTTPS backend URL with `--dart-define=VPAY_API_BASE_URL=...`.

## Tests and verification recorded

Flutter tests include merchant dashboard/profile parsing, payment form validation/loading/duplicate-submit/error handling, API service request/response checks, QR/status rendering for all five statuses, expiry, network error handling, and a compact viewport QR check.

Backend tests include authentication middleware, controller errors, input validation, merchant authorization, create/retrieve ownership, expiry, processing/success preservation, unknown/malformed references, and a fake Firestore assertion that creation writes only a payment-intent document and does not touch balances.

Last recorded verification:

- `flutter analyze` — passed with no issues.
- `flutter test` — 23 tests passed.
- `npm test` in the backend — 20 tests passed.

These tests use fakes/mocks. They do not prove live Firebase behavior or a complete Android-emulator payment execution flow.

## Remaining work and handoffs

### Member 3: remaining integration work

1. **Merchant balance display:** the current dashboard is a placeholder. The updated plan proposes `merchantAccounts/{uid}` as the merchant account/balance document, but also says that proposal must be frozen before Member 4 relies on it. Agree with the team on fields, read authorization, and the backend balance-read contract. Then connect the dashboard through the shared authenticated API client. Never read a customer card balance for a merchant and never write balances from Flutter.
2. **Received payments:** the dashboard's received-payments section remains a placeholder. Integrate it with Member 5's shared transaction-history querying/presentation after Member 4 and Member 2 write trustworthy records and Member 5 publishes the approved endpoint/model. Do not reconstruct payments from local UI state or fabricate successful rows.
3. **Member 4 result refresh:** after Member 4 confirms payment atomically, retrieve the authoritative intent status and refresh the merchant account/history views through their agreed read APIs. Do not mark a payment successful locally.
4. **Cross-member handoff:** keep the payment-intent reference, amount, merchant identity, status, expiry, and error semantics aligned with Member 4's customer scanner/payment contract.

### Member 4: customer QR payment engine (per team plan)

- Build QR scanning and camera permission flow.
- Resolve a scanned reference on the backend. The current `GET /api/payment-intents/:paymentReference` is merchant-only and checks the intent's `merchantUid`; it is not a customer lookup endpoint. Member 4 and the team must approve customer lookup authorization/response rules before adding or changing routes.
- Validate customer, card status, merchant, amount, intent status/expiry, available customer funds, and duplicate/idempotency behavior on the backend.
- Execute the authoritative atomic customer debit and merchant credit. Create the stable `QR_PAYMENT` transaction record as part of the operation, and set the final intent status and paid timestamp only after the transaction commits.
- Return/retain authoritative status for timeout recovery. Flutter must check status instead of blindly retrying payment execution.
- Notify Member 3 of the finalized merchant-balance read and status contracts.

### Member 5: shared history and integration (per team plan)

- Own shared transaction model/formatting, merchant/customer history query/presentation, and the approved transaction-history API contract.
- Integrate merchant received payments only after Member 2/Member 4 records exist. Do not fabricate missing financial records.
- Coordinate shared error/response conventions, stable reference/logging consistency, FCM notifications, end-to-end integration, and regression/QA.

### Member 1 and Member 2: remaining work identified by the plan

- **Member 1:** finish profile work and backend/UI card freeze/unfreeze with the stable `ACTIVE`/`FROZEN` contract used by Member 4. Coordinate the shared auth/profile files touched for merchant routing and `businessName` with Member 1.
- **Member 2:** complete the separate MockPay/top-up flow, verify provider outcomes/callbacks, credit customer balance exactly once on verified success, and write the corresponding `TOP_UP` transaction record. Failed/cancelled/timed-out top-ups must not credit balances.

### Project-wide integration

- Merge/rebase only through the team's approved branch/PR workflow. The plan names `development` as the shared branch; this workspace is currently on `feature/merchant-qr`.
- After dependencies are merged, exercise the full flow on an Android emulator: merchant creates intent -> customer scans and confirms -> backend atomically applies payment -> merchant sees backend-confirmed final status, updated balance, and received transaction.
- Keep the post-core MockBank, payout/settlement, refunds, partial refunds, and negative merchant balance work out of the mandatory core unless the project owner explicitly starts that extension phase.

## Before committing this workspace

The working tree contains changes in two independent Git repositories. Review and commit each repository separately. In the Flutter repository, check whether the shared auth/profile changes are coordinated with Member 1, exclude the nearly empty untracked `package-lock.json` unless intentionally needed, and inspect generated platform registrant files that appear modified with line-ending warnings but no visible diff. Do not commit credentials or local `.env` files.

## Bottom line

Member 3 has the authenticated payment-intent create/retrieve/expiry path and merchant create-request/QR/status path implemented. Member 3's overall plan is **not fully complete**: merchant balance display and received-payment integration await agreed backend read contracts and the Member 4/Member 5 authoritative balance/history work. The current branch is suitable to hand off for review as partial work, but should not be described as a completed end-to-end merchant payment feature.
