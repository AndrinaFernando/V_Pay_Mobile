# VPay Design Reference

This directory contains reference material used to implement the VPay Flutter UI.

## Priority

When implementing a screen, use references in this order:

1. VPay design-system files under `design_system/`
2. VPay branding under `branding/`
3. Screen designs under `screens/`
4. Existing Flutter UI components already implemented in the app

If references conflict, do not silently invent a solution. Preserve the established VPay design language and flag the conflict.

## Folders

### design_system

Contains the VPay design system, tokens, colors, typography, spacing, and component guidance.

### screens

Contains screen-layout references and UI inspiration exported from the design process.

### branding

Contains VPay logos and app-icon source files.

These files are design/development references. They are not automatically Flutter runtime assets.