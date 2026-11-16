# Version 1 Android APK preparation

Release is blocked until the following are complete:

- Deploy the Node backend to an approved, reachable HTTPS origin. Configure
  Firebase Admin credentials securely, `VPAY_QR_PAYMENT_EXECUTION_ENABLED`,
  Rupio staging credentials, and a public HTTPS `RUPIO_CALLBACK_URL` ending in
  `/api/webhooks/rupio`. Do not put secrets in the APK. No deployment is part of
  this change.
- Set `VPAY_API_BASE_URL` to that HTTPS origin with `--dart-define` for the
  release build. Release code rejects missing or non-HTTPS values; it cannot
  fall back to localhost, `127.0.0.1`, or `10.0.2.2`. No ADB reverse is needed.
- Replace the current debug-key release signing configuration in
  `android/app/build.gradle.kts` with an approved release keystore supplied
  through local or CI secrets. Set and protect the final application ID and
  version code.
- Verify the Firebase Android app registration for
  `com.vpay.vpay_mobile`, the matching `google-services.json`, FCM credentials
  on the backend, and notification permission on Android 13 and later.
- Confirm the release manifest has internet access and no cleartext HTTP
  exception. The HTTP exception is confined to `src/debug`.
- Run `flutter pub get`, `flutter analyze`, and `flutter test`, then build and
  install a signed release APK on a physical Android device. Exercise foreground,
  background, notification tap, cold start, logout, account switch, offline
  recovery, Android back gesture, checkout, and delayed Rupio callback.

The backend sends a generic Android notification payload and a typed data
payload with a binding ID. The app accepts foreground and tapped events only
for its current in-memory registration. A cold-start tap received before
registration is ignored; authenticated home loading still fetches current
balances and activity. Android can show the generic OS alert before the app
checks the binding. It contains no account, balance, merchant, or transaction
details. Offline logout cannot immediately remove the backend token, but it
clears the local binding; the next authenticated registration transfers token
ownership. Physical device behavior remains unverified by widget tests.
