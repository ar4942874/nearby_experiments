# DESIGN.md — Nearby Connect

OpenDesign design system (9-section schema). This file is the single source of
truth for the app's visual language. All screens render against these tokens.
Source: https://open-design.ai — portable Markdown design system format.

## 1. Color

Three-color palette (max 3 brand colors):

| Token | Hex | Usage |
|-------|-----|-------|
| `color.background` | `#F7F5F0` | Warm off-white — every scaffold background |
| `color.accent` | `#3A7D6E` | Soft teal — primary actions, icons, sent bubbles |
| `color.text` | `#2D2D2D` | Dark charcoal — all primary text |
| `color.surface` | `#FFFFFF` | White — cards, inputs, received bubbles |
| `color.tint` | `#E8F5F3` | Teal 8% tint — icon containers, empty states |
| `color.danger` | `#D64545` | Reserved: recording/live states only |
| `color.border` | `#E0E0E0` | Hairline borders on cards/inputs |

Never introduce a fourth hue. State colors derive from `accent` + `danger` only.

## 2. Typography

- Family: system default (SF Pro / Roboto), no custom fonts.
- Display: 40px / w700 / letterSpacing -0.8 — screen titles ("Nearby").
- H1: 28px / w700 / letterSpacing -0.5 — feature screen titles.
- H2: 17–18px / w600 — card titles, app bar titles.
- Body: 14–15px / w400–500 / height 1.4 — subtitles, messages.
- Caption: 11–13px / w400 — timestamps, footers, hints.
- Never exceed 40px or go below 11px. No italics, no uppercase except tiny labels (letterSpacing 1.2).

## 3. Spacing

4px base grid:

| Token | Value |
|-------|-------|
| `space.xs` | 4px |
| `space.sm` | 8px |
| `space.md` | 16px |
| `space.lg` | 24px |
| `space.xl` | 32px |
| `space.2xl` | 48px |

Screen horizontal padding: 24px (home) / 16px (dense screens). Card padding: 20px.

## 4. Layout

- Single-column, vertical scroll; no sidebars.
- Home: header block → feature cards → `Spacer` → centered footer.
- Sub-screens: centered connection view (icon + title + form + buttons) OR content view (status card + body + input).
- Minimum touch target: 48px. Minimum gap between cards: 12–16px.

## 5. Components

| Component | Spec |
|-----------|------|
| `Card` | White, radius 20, 1px `border`, shadow `0 4 12 rgba(0,0,0,0.04)` or none |
| `IconBox` | 48–52px, radius 14–16, `tint` bg, `accent` icon 24–26px |
| `Button` (outline) | White, radius 16, 1px accent-30% border, accent icon + charcoal label |
| `Input` | White, radius 16 (forms) / 28 (chat), 1px border, focus: accent 1.5px |
| `Bubble` (sent) | `accent` bg, white text, radius 20 |
| `Bubble` (received) | White bg, 1px border, charcoal text, radius 20 |
| `AppBar` | Transparent on `background`, no elevation, centered title, back chevron |
| `ListTile` | White, radius 14–16, 1px border, 36px tint icon box |

## 6. Motion

- Implicit animations only, 200ms ease (talk button scale/color).
- No page transition customization; rely on Material defaults.
- No parallax, no looping animations, no shimmer.

## 7. Voice

- UI copy: sentence case, concise, no exclamation marks.
- Microcopy may be bilingual (Hindi/English mix as already used: "Pehle permissions den").
- Labels: ≤ 3 words ("Host", "Join", "Find Devices").
- Status lines: plain and calm — "Not Connected", "Connected".

## 8. Brand

- Name: **Nearby** (display) / "Nearby Connect" (formal).
- Promise: connect devices without internet.
- Personality: calm, soft, minimal, trustworthy — not playful or corporate.

## 9. Anti-patterns

- Forbidden: gradients, elevation > 2, emoji in primary UI, more than 3 hues.
- Forbidden: pure black `#000000`, saturated primaries (blue/green/orange) as brand color.
- Forbidden: heavy borders, drop shadows with >12 blur, pill-shaped text buttons where icon+label works.
- Forbidden: AppBar titles longer than 3 words; center-aligned body paragraphs.
- Forbidden: hardcoded color literals in widget files — use `AppTokens` only.
