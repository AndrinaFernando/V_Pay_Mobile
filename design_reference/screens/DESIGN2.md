---
name: Precision Neo-Banking
colors:
  surface: '#fcf9f8'
  surface-dim: '#dcd9d9'
  surface-bright: '#fcf9f8'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f2'
  surface-container: '#f0eded'
  surface-container-high: '#eae7e7'
  surface-container-highest: '#e5e2e1'
  on-surface: '#1b1c1c'
  on-surface-variant: '#414753'
  inverse-surface: '#303030'
  inverse-on-surface: '#f3f0ef'
  outline: '#717784'
  outline-variant: '#c1c6d5'
  surface-tint: '#005db6'
  primary: '#005aaf'
  on-primary: '#ffffff'
  primary-container: '#0072dc'
  on-primary-container: '#fbfaff'
  inverse-primary: '#a9c7ff'
  secondary: '#00658e'
  on-secondary: '#ffffff'
  secondary-container: '#25b9fe'
  on-secondary-container: '#004665'
  tertiary: '#325a9e'
  on-tertiary: '#ffffff'
  tertiary-container: '#4d73b9'
  on-tertiary-container: '#fbfaff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d6e3ff'
  primary-fixed-dim: '#a9c7ff'
  on-primary-fixed: '#001b3d'
  on-primary-fixed-variant: '#00468b'
  secondary-fixed: '#c7e7ff'
  secondary-fixed-dim: '#85cfff'
  on-secondary-fixed: '#001e2e'
  on-secondary-fixed-variant: '#004c6c'
  tertiary-fixed: '#d8e2ff'
  tertiary-fixed-dim: '#acc7ff'
  on-tertiary-fixed: '#001a40'
  on-tertiary-fixed-variant: '#174588'
  background: '#fcf9f8'
  on-background: '#1b1c1c'
  surface-variant: '#e5e2e1'
typography:
  display-lg:
    fontFamily: Hanken Grotesk
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Hanken Grotesk
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Hanken Grotesk
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Hanken Grotesk
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.01em
  title-md:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Hanken Grotesk
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-md:
    fontFamily: Hanken Grotesk
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.04em
  label-sm:
    fontFamily: Hanken Grotesk
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.02em
  mono-num:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.25rem
  space-xl: 1.5rem
---

## Brand & Style
The design system embodies precision neo-banking: institutional trust paired with swift, digital-first execution. The interface prioritizes clarity, financial confidence, and ergonomic speed. It is engineered primarily for mobile touch interactions on compact viewports (baseline 390×844pt) with immediate thumb reachability and unambiguous transactional feedback.

The aesthetic direction is **Modern Precision Minimalist**. Surfaces remain clean, white, and airy to eliminate financial clutter, while bold architectural accents anchor security-critical flows. Decorative ornamentation, superfluous 3D assets, and heavy translucent glass effects are strictly omitted in favor of structural clarity, crisp micro-borders, and high-readability typographic hierarchies.

## Colors

### Brand Swatches
- **Electric Blue (`#0072DC`)**: Primary interactive color. Governs primary action buttons, focused input highlights, active tab switches, and confirmed transaction states.
- **Electric Pressed (`#005DB8`)**: Dedicated active tap/down state for Electric Blue components.
- **Arc Cyan (`#27BAFF`)**: Surgical secondary accent. Reserved for active biometric glows, QR scanner targeting brackets, notification badges, and precise interactive indicators.
- **Strong Blue (`#01397C`)**: High-contrast brand anchor. Used for critical badge fills, secondary visual framing, and prominent brand accents.
- **Deep Space (`#00193C`)**: Top gradient tone for high-tier virtual card surfaces and executive statement headers.
- **Void (`#000815`)**: Base gradient terminal for virtual card surfaces and premium dark UI modals.

### Strict Neutrals
- **Canvas White (`#FFFFFF`)**: Base application background, modal containers, and elevated white cards.
- **Surface Gray (`#F7F7F7`)**: Base screen backdrops, search input troughs, transaction item backgrounds, and inactive segment indicators.
- **Surface Gray 2 / Divider (`#EBEBEB`)**: Structural strokes, list dividers, hairline borders, and keyline boundaries.
- **Ink (`#222222`)**: Primary headers, display balances, active icon fills, and primary labels.
- **Primary Supporting Text (`#484848`)**: Secondary narrative text, dense transaction names, and form field values.
- **Secondary Text (`#767676`)**: Timestamps, account metadata, transaction tags, and field labels.
- **Tertiary Text (`#B0B0B0`)**: Inactive placeholders, disabled icons, and structural breadcrumb dividers.

### Semantic Status
- **Success Green (`#10B981`)**: Positive balance inflows, verified ticks, successful transfers.
- **Warning / Pending Amber (`#F59E0B`)**: Pending settlements, escrow holds, attention warnings.
- **Error / Destructive Red (`#EF4444`)**: Transaction cancellations, destructive flows, overdrawn limits, validation failures.

## Typography
Typographic rhythm relies uniformly on **Hanken Grotesk**, selected for its geometric rigor, high legibility in dense data sheets, and structural balance across fractional numeric scales.

### Numerics & Currency Formatting
All primary balances must strictly employ tabular figures (open type `tnum`) to eliminate layout jitter when figures refresh dynamically.
- Currency strings conform to exact structural notation: `Rs. 12,850.00`.
- The prefix `Rs.` is styled at 75% scale of the principal integers.
- Cents/decimals retain the primary integer weight but drop to secondary text color (`#767676`) for glanceability.

## Layout & Spacing
The layout architecture is structured around standard mobile viewports (baseline 390×844pt) using a clean, content-first vertical flow.

### Grid & Canvas
- **Screen Margin:** 16px (`1rem`) outer canvas padding on horizontal edges ensures maximal data density while respecting mobile bevel safe boundaries.
- **System Padding:** 8px base rhythm unit.
- **Vertical Spacing:** Micro-gaps between related fields are 8px (`space-sm`), component inter-spacing is 16px (`space-md`), and structural section headers require 24px (`space-xl`) clearances.
- **Ergonomic Safe Area:** Top app bars reserve standard status bar clear-zones (44pt on iOS); primary sticky CTAs dock at screen bottom with a persistent 34pt home-indicator clearance.

## Elevation & Depth
Depth in the system is functional and restrained. Heavy blurs, glowing drop shadows, and complex skeuomorphic extrusions are prohibited.

### Tiers of Depth
- **Level 0 (Base Canvas):** Background tone (`#F7F7F7` or `#FFFFFF`).
- **Level 1 (Card & Module Surface):** Pristine `#FFFFFF` surface container layered over `#F7F7F7`, defined by a structural 1px hairline perimeter border in `#EBEBEB`.
- **Level 2 (Floating Surfaces & Toast Alerts):** `#FFFFFF` with a crisp, hyper-subtle drop shadow: `0 1px 3px rgba(0, 0, 0, 0.06)`, bordered by `#EBEBEB`.
- **Level 3 (Bottom Sheets & Overlays):** Background scrim using `#000815` at 40% opacity. Surfaces elevate without outer glow, anchored by perimeter edge definition.

## Shapes
Radii are allocated strictly according to component area hierarchy:
- **Interactive Controls (12px):** Input text boxes, compact action tags, segmented switches, and small buttons.
- **Primary Buttons & Action Blocks (16px):** Standard 48px CTAs, toast alerts, list grouping wrappers.
- **Account & Balance Cards (20px):** Information modules, virtual debit card displays, and dashboard balance cards.
- **Bottom Sheets & Modal Panels (24px):** Top-left and top-right corners of sliding modal drawers.
- **Pill Controls (`9999px`):** Status indicator tags, quick-transfer avatar borders, micro numeric badges.

## Components

### Buttons & Interactive Touch Targets
- **Ergonomic Standard:** Minimum touch envelope is strictly 48×48px across all clickable instances, satisfying mobile ergonomics.
- **Primary CTA:** Background `#0072DC`, foreground `#FFFFFF`, height 52px, border-radius 16px. Pressed state activates `#005DB8` instantly without delayed animation.
- **Secondary / Outlined:** Background `#FFFFFF`, border `1px solid #EBEBEB`, foreground `#222222`. Active state triggers `#F7F7F7`.
- **Destructive Action:** Background `#FFFFFF`, border `1px solid #EF4444`, foreground `#EF4444`.

### Virtual Payment Card (VPay Card)
- **Dimensions:** Standard credit card ratio (1.586:1), corner radius 20px.
- **Surface:** High-density linear gradient spanning 135° from Deep Space (`#00193C`) to Void (`#000815`).
- **Texture & Details:** Subtle structural vector lines in 5% white opacity. Integrated metallic golden-yellow smart contact chip graphic on left-center. Strictly no third-party network logos (no Visa or Mastercard markings).
- **Typography:** Balances and labels styled in `#FFFFFF`. Card numbers formatted exclusively in 4-digit masked chunks (`•••• •••• •••• 4092`). Active balances displayed cleanly in bottom-left.

### Input Fields & Search Bars
- **Container:** Height 48px, background `#F7F7F7`, border `1px solid transparent`, border-radius 12px, padding horizontal 16px.
- **Focus State:** Background `#FFFFFF`, border `1px solid #0072DC`, with subtle internal focus indicator.
- **Typography:** Input value `#222222`, placeholder `#B0B0B0`.

### Transaction List Items
- **Structure:** 72px fixed height row with horizontal layout.
- **Avatar/Icon Module:** 44×44px square, radius 12px, background `#F7F7F7` with center-aligned merchant or payment glyph.
- **Title & Subtitle:** Merchant/Recipient title in `#222222` (15px semibold); category and timestamp in `#767676` (13px regular).
- **Trailing Financial Value:** Formatted currency `Rs. 12,850.00`. Positive transfers prepend `+` and style in `#10B981`; deductions render standard in `#222222`.
- **Dividers:** Optional 1px bottom border in `#EBEBEB` offset by 60px from the left to clear leading icons.

### Status Chips & Selection Pills
- **Badge Shape:** Height 28px, border-radius 9999px, padding horizontal 12px.
- **Positive / Verified:** Background `#10B981` at 10% opacity, label `#10B981`.
- **Pending:** Background `#F59E0B` at 10% opacity, label `#F59E0B`.
- **Selected Filter:** Background `#0072DC`, label `#FFFFFF`.

### Checkboxes & Toggle Radios
- **Checkboxes:** 22×22px, 6px radius, inactive border `1.5px solid #EBEBEB`. Checked state fills `#0072DC` with a clean white tick mark.
- **Switches:** Flutter-style pill toggle, track width 44px, height 26px. Active track `#0072DC`, thumb `#FFFFFF`.