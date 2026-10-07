# VPay Mobile Design System — Airbnb iOS Inspired

Design system docs for VPay, using the [Airbnb iOS app](https://apps.apple.com/us/app/airbnb/id401626263) as structural and interaction inspiration. This is not Airbnb's official system. Layout, typography, spacing, and component patterns remain reference material, while the chromatic layer has been replaced with VPay's blue brand palette.

## Files

| File | Description |
|------|-------------|
| `DESIGN.md` | Framework-neutral design spec (9 sections) |
| `DESIGN-swiftui.md` | SwiftUI implementation — `Color` / `Font` extensions, components, haptics |
| `DESIGN-expo.md` | Expo / React Native implementation — design tokens, themed components, Reanimated |
| `preview.html` | Interactive design token catalog (light mode) |
| `preview-dark.html` | Interactive design token catalog (VPay navy dark mode) |

## Signature Moves

- **White canvas** with photography as the hero — content-first, editorial
- **VPay Electric** (`#0072DC`) as the primary action color — main CTA, selected controls, active tab, and interactive emphasis
- **Arc** (`#27BAFF`) as the bright signature accent — reserved for logo/icon detail, scanner highlights, progress, and illustration moments
- **Strong Blue** (`#01397C`), **Deep Space** (`#00193C`), and **Void** (`#000815`) for deeper brand surfaces, virtual-card treatments, and gradients
- **Stay cards** — 4:3 photos with 16pt corner radius, save heart top-right, rating row beneath, full-width stacking (never 2-col)
- **"Where to?" search pill** — full-pill white with subtle shadow, Location / Check in / Check out / Who segmentation
- **Horizontal category bar** — icon + label chips with a sliding underline on the selected category
- **Sticky Reserve footer** — translucent blur at the bottom of every stay detail, total price + date range + VPay Electric CTA
- **Airbnb Cereal** — proprietary warm geometric sans by Dalton Maag (2018); weights 400/500/700/800

## Inspiration & VPay Palette

- [Airbnb Design — Redesigning Our DLS](https://airbnb.design/building-a-visual-language/)
- [Dalton Maag — Airbnb Cereal case study](https://www.daltonmaag.com/work/airbnb)
- [Airbnb 2020 rebrand and the Bélo](https://airbnb.design/)
- VPay brand palette: Electric `#0072DC`, Electric Pressed `#005DB8`, Arc `#27BAFF`, Strong Blue `#01397C`, Deep Space `#00193C`, Void `#000815`
- Neutral foundation retained: Canvas `#FFFFFF`, Surface Gray `#F7F7F7`, Divider `#EBEBEB`, Hof `#484848`, Foggy `#767676`, Ink `#222222`
