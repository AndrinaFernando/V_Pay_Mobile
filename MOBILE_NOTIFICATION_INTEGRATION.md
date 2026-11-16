# VPay Android push notifications

## Setup and scope

Based on mobile development `e094f37`, on `feature/member5-mobile-fcm`.
Dependency resolution selected firebase_messaging 16.7.1 and firebase_core 4.15.2 with the existing Firebase Auth constraint. Firebase initialization and existing Android Google Services configuration remain in place. Use the team's Firebase project configuration; never add service-account keys to Flutter. Android requires Google Play services and notification permission (`POST_NOTIFICATIONS`, declared in the main manifest). No local-notification plugin is used.

This integration is enabled on Android only. iOS/APNs configuration and web service workers are outside this change. The generated macOS plugin registration is a dependency-generated file, not an enabled macOS notification flow.

## Architecture

`NotificationService` injects permission/token functions, message streams, a session guard, and token registration for isolated tests. `NotificationTokenApi` uses the existing `ApiClient.authenticatedPost`. The Firebase adapter owns messaging SDK access. `NotificationScope` mounts inside the existing device access gate, after the profile exists, without changing customer or merchant dashboard code.

After login or app restart, permission is requested at most once per app process; subsequent checks read notification settings. Denial or SDK/backend failure never blocks normal use. With permission, the current token is registered and token refresh events trigger registration. A captured UID guards asynchronous ID-token retrieval; old-session listeners are ignored and cancelled. The account gate retains the registration service across device locks; the unlocked scope detaches UI callbacks while locked. No tokens, payloads, or credentials are logged.

## Backend contract

`POST /api/notifications/token`, bearer Firebase ID token, JSON `{ "fcmToken": "<device token>" }`. Success requires HTTP 200 and `success: true`. Registration returns a safe result for 401, missing profile (404), malformed responses and other errors. There is no automatic payment retry or blocking authentication error. Failed registration can retry on a later token refresh or scope initialization (for example sign-in/restart); there is no persistent retry queue or success guarantee while offline.

The notification backend branch must be reviewed/integrated and deployed separately. The app's `VPAY_API_BASE_URL` must point to that backend. Members 2 and 4 must install appropriate post-commit sender hooks and coordinate duplicate attempts; client integration does not send payment notifications itself.

## Reception

Accepted `data.type` values: `TOP_UP_SUCCESS`, `PAYMENT_SUCCESS`, `PAYMENT_RECEIVED`. Unknown/malformed values are ignored. Customer messages are handled in the customer session; payment-received messages in the merchant session.

Foreground: a generic in-app SnackBar offers Refresh. It does not display untrusted payload text or amounts. Refresh returns to the existing role home and recreates it so existing services fetch authoritative data. Background: Android/FCM displays the backend's notification payload; the entry-point background handler initializes Firebase but neither posts a duplicate notification nor writes data. Notification taps (`onMessageOpenedApp` and `getInitialMessage`) refresh the existing authenticated role home after profile/device gates. No new screen or financial state is created from payloads. This intentionally returns to home rather than deep-linking to a particular transaction.

## Logout / account-switch limitation — approval required

Local listeners stop when the protected scope is disposed; session checks prevent stale UI callbacks and token retrieval for a different user. Existing logout behavior is unchanged.

**This is not sufficient to guarantee push privacy after logout.** The backend retains the old user's token, and a device token may be shared across subsequent account registrations. Notifications may still reach the system tray while signed out or after account switching. Payloads contain no recipient identity, so same-role stale notifications cannot be distinguished locally. Generic text and authoritative refresh do not fix this server association.

Proposed contract, NOT implemented: an authenticated token-removal operation that conditionally clears `users/{verifiedUid}.fcmToken` only when it equals the supplied device token. Team approval must define endpoint/method, offline logout behavior, cross-account token ownership, and races with replacement devices. Client deletion/rotation alone cannot guarantee removal of the server association or queued messages. Stop this part until that contract is approved; do not claim shared-device/logout notification privacy is complete.

## Testing

Run `flutter pub get`, `flutter analyze`, and `flutter test`. Tests use fake streams/API responses and no Firebase credentials. Cover registration, token refresh, 401, 404, denial, malformed types/responses, foreground and opened events, stale sessions, disposal and exception containment.

On an Android device with a test Firebase account/backend: verify allow/deny permissions; restart; token refresh; foreground generic banner; background system notification; terminated-app tap; customer/merchant routing; device-lock gating; offline/missing-profile/backend errors. Check that only authoritative backend data changes balances. Verify no duplicate system banners. Explicitly test and record the unresolved logout/account-switch limitation before shared-device release.

Firebase behavior reference: https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages

## Validation results

- `flutter pub get`: passed (the initial `pub add` attempt reported Windows symlink support, but the subsequent requested dependency-get command succeeded).
- `flutter analyze --no-pub`: no issues found after fixing the initial analysis findings.
- `flutter test --reporter expanded`: 167 total, 166 passed, 0 failed, 1 skipped. The existing API-base-URL override test requires a compile-time environment override and remains conditionally skipped. The original ten notification tests and fifteen additional lifecycle/coordinator tests pass. Three existing role-gate tests now unwrap NotificationScope while retaining their role and shared-auth assertions.
- No live Firebase sends, physical-device testing, or APK build was performed.


## Follow-up lifecycle fixes

Registration uses a serial queue with successful-token deduplication. Failed tokens remain eligible for retry. Refresh events supersede a pending getToken snapshot; session activity is checked before queued sends and after completion. A service survives device locking and is disposed with its account gate. Unlock and app resume trigger a single recovery attempt, and token refresh can recover failed registration. There is no retry timer or infinite loop. Permission checks after the first request do not prompt again in the same process.

The AuthGate-owned NotificationOpenCoordinator captures background opens and initial messages before profile/device gating. It retains only one typed refresh intent and up to 64 message IDs for duplicate suppression. It binds the pending intent to the current local authentication session, drops it on account changes, and rejects delayed initial messages crossing session changes. Signed-out taps are discarded because their recipient cannot be established. Only NotificationScope inside AppAccessGate consumes an intent, after unlock. Multiple pending taps coalesce into one authoritative home refresh. Messages without IDs can only be coalesced while pending, not reliably deduplicated after consumption.

The former Future.timeout wrapper was removed: it did not cancel the HTTP request and could allow overlapping backend writes. A stalled request now holds the queue until the underlying request settles; it does not block the UI. Absolute ordering after ambiguous transport failures or between devices still needs server-side versioning/ownership rules; the client cannot undo a request already accepted by the server.

**Release blocker remains:** no unregister endpoint exists. One-token-per-user storage permits a shared token on several accounts. Local session binding cannot identify a stale push from the previous user received during a new session because payloads have no recipient identity. Backend ownership, conditional removal, offline logout, queued sends, and in-flight registration races require an approved contract before shared-device release. No backend or financial processing code was changed.

Follow-up tests use fake streams, delayed futures, and a fake LocalAuthService with the real AppAccessGate. They cover serial registration, duplicates, token ordering, recovery, asynchronous logout, disposal, pending opens, account switching, duplicate message IDs, role filtering, and protected UI remaining hidden through lock/unlock.

Final follow-up validation: `flutter pub get` passed; `flutter analyze` reported no issues; full `flutter test --reporter expanded` passed 166 tests with 1 existing environment-dependent skip and 0 failures. `git diff --check` passed. No real-device test or APK build was performed.
