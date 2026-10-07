# VPay Flutter Development Guidelines

## Frontend Design References

Whenever implementing or modifying Flutter UI, first inspect the design references under:

- `design_reference/design_system/`
- `design_reference/screens/`
- `design_reference/branding/`

The design reference files are the visual source of truth for VPay.

Use them for:

- colors
- typography
- spacing
- button styles
- cards
- text fields
- border radius
- layout structure
- navigation appearance
- light/dark styling
- branding and logos

Do not invent a new visual style when an existing VPay reference is available.

## Branding

Reference logos:

`design_reference/branding/logos/`

Reference app icon:

`design_reference/branding/app_icons/`

Files under `design_reference/` are development references and should not automatically be treated as Flutter runtime assets.

If a branding file needs to be displayed by the Flutter application, copy/use the required production asset under the proper Flutter `assets/` directory and update `pubspec.yaml`.

## Architecture

Keep presentation, authentication, backend communication, and business logic separated.

Existing authentication structure:

- `AuthService` -> Firebase identity/session
- `AuthStrategy` -> authentication provider strategy
- `AuthGate` -> authentication-state routing
- `LocalAuthService` -> reusable device authentication

Do not place Firebase, backend, or local-auth implementation logic directly inside UI widgets when an existing service should own it.

Prefer simple reusable widgets where multiple screens share the same visual component.

Do not add unnecessary state-management or architecture packages unless explicitly agreed first.

## Backend Security

Flutter must never directly modify authoritative financial data such as:

- balances
- card state
- transactions

Those operations belong to the VPay backend.