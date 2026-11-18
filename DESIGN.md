---
name: Veny
description: The Elite Marketplace. Verified independent pros, real free slots, booked in a few taps.
colors:
  ink-lacquer: "#0e0a18"
  lacquer-panel: "#161025"
  lacquer-raised: "#1f1832"
  ivory: "#f2ece1"
  muted-mauve: "#b8afc4"
  subtle-mauve: "#8e869b"
  violet-seam: "#2a2140"
  brass: "#c9a86a"
  brass-line: "#5e4e33"
  amethyst: "#7552e0"
  amethyst-hover: "#6544cf"
  amethyst-soft: "#2a2140"
  on-amethyst: "#ffffff"
  lilac-ring: "#a88cf5"
  sea-green: "#6cc0b2"
  sea-green-soft: "#16302d"
  marigold: "#e3b04b"
  marigold-soft: "#33280f"
  coral: "#e8796d"
  brick: "#b9443a"
  coral-soft: "#3a1714"
  info-soft: "#251c3f"
  pearl-light: "#f6f4f9"
  pearl-panel-light: "#fdfcfe"
  pearl-raised-light: "#efebf5"
  ink-text-light: "#17121f"
  muted-mauve-light: "#574f66"
  subtle-mauve-light: "#6e6680"
  violet-seam-light: "#e1dbea"
  brass-light: "#7d5f27"
  brass-line-light: "#cdb98f"
  amethyst-light: "#6544cf"
  amethyst-hover-light: "#5636bb"
  amethyst-soft-light: "#ebe5fb"
  sea-green-light: "#1f6f63"
  marigold-light: "#8a5a00"
  brick-light: "#b3372c"
typography:
  display:
    fontFamily: "Bodoni Moda Variable, Bodoni 72, Didot, serif"
    fontSize: "4.75rem"
    fontWeight: 500
    lineHeight: 1.04
    letterSpacing: "-0.02em"
  headline:
    fontFamily: "Bodoni Moda Variable, Bodoni 72, Didot, serif"
    fontSize: "3rem"
    fontWeight: 500
    lineHeight: 1.1
  title:
    fontFamily: "Bodoni Moda Variable, Bodoni 72, Didot, serif"
    fontSize: "1.5rem"
    fontWeight: 500
    lineHeight: 1.25
  body:
    fontFamily: "Manrope Variable, ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.9375rem"
    fontWeight: 400
    lineHeight: 1.6
    fontFeature: "'tnum' 1, 'lnum' 1"
  label:
    fontFamily: "Manrope Variable, ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.8125rem"
    fontWeight: 600
    lineHeight: 1.4
    fontFeature: "'tnum' 1, 'lnum' 1"
rounded:
  sm: "6px"
  md: "10px"
  lg: "14px"
  full: "9999px"
spacing:
  xs: "8px"
  sm: "12px"
  md: "24px"
  lg: "40px"
  xl: "64px"
  section: "80px"
  section-lg: "112px"
components:
  button-primary:
    backgroundColor: "{colors.amethyst}"
    textColor: "{colors.on-amethyst}"
    rounded: "{rounded.md}"
    padding: "0 20px"
    height: "44px"
  button-primary-hover:
    backgroundColor: "{colors.amethyst-hover}"
  button-secondary:
    backgroundColor: "{colors.lacquer-raised}"
    textColor: "{colors.ivory}"
    rounded: "{rounded.md}"
    padding: "0 20px"
    height: "44px"
  button-outline:
    backgroundColor: "transparent"
    textColor: "{colors.ivory}"
    rounded: "{rounded.md}"
    padding: "0 20px"
    height: "44px"
  button-destructive:
    backgroundColor: "transparent"
    textColor: "{colors.coral}"
    rounded: "{rounded.md}"
    padding: "0 12px"
    height: "36px"
  button-destructive-hover:
    backgroundColor: "{colors.brick}"
    textColor: "{colors.on-amethyst}"
  input:
    backgroundColor: "{colors.lacquer-panel}"
    textColor: "{colors.ivory}"
    rounded: "{rounded.md}"
    padding: "0 14px"
    height: "44px"
  slot-chip:
    backgroundColor: "transparent"
    textColor: "{colors.ivory}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    height: "44px"
  slot-chip-selected:
    backgroundColor: "{colors.amethyst-soft}"
    textColor: "{colors.ivory}"
  badge-brass:
    backgroundColor: "transparent"
    textColor: "{colors.brass}"
    rounded: "{rounded.full}"
    padding: "2px 10px"
  badge-success:
    backgroundColor: "{colors.sea-green-soft}"
    textColor: "{colors.sea-green}"
    rounded: "{rounded.full}"
    padding: "2px 10px"
  card:
    backgroundColor: "{colors.lacquer-panel}"
    rounded: "{rounded.lg}"
    padding: "24px"
  dialog:
    backgroundColor: "{colors.lacquer-panel}"
    rounded: "{rounded.lg}"
    padding: "24px"
---

# Design System: Veny

## Overview

**Creative North Star: "Bombay Deco Nights"**

Veny is a Bombay Art Deco foyer at night, built as a working product. The ground is ink-violet lacquer; panels sit one step lighter; every edge is a thin brass seam rather than a shadow. Gilded detail is spent sparingly on the moments that carry trust (the verified seal, the pro's monogram, the price, the stepped frame around the booking panel), and the rest of the surface stays calm and geometric so a household can find a verified pro and book a real slot in a few taps.

The system is dark-first with a full light counterpart; both pass WCAG AA. Density is moderate: generous section rhythm on public pages, tighter time-ranked rows in the vendor dashboard. A high-contrast Didone carries names, headings and prices; a quiet grotesque with tabular numerals carries every control and every time. Motion is a short ease-out on state change only (150 to 250ms) and collapses under reduced motion.

It refuses the category default of white rounded photo cards with an icon row, and the legacy app's neon cosmic glow.

**Key Characteristics:**
- Ink-violet lacquer ground with tonal, one-step-raised panels.
- Brass hairline seams in place of shadows.
- Amethyst reserved for the primary action.
- Bodoni Moda display over Manrope UI with tabular numerals.
- One stepped Deco frame per page, around the booking panel.
- Small, consistent radii (6 / 10 / 14px).

## Colors

A low-key lacquer palette: violet-black neutrals, one gilded line colour, one jewel accent for action, and muted semantic tones on soft tinted grounds.

### Primary
- **Amethyst** (amethyst; light mode amethyst-light): the fill of the primary action and nothing else, plus the text-selection highlight and skip link. Hover deepens to amethyst-hover. Its soft tint (amethyst-soft) backs the selected state of slot and day chips, always with a brass edge.

### Secondary
- **Gilt Brass** (brass; light mode brass-light): the gilded detail. The verified seal, monogram initials, rating stars, italic accent words in a headline, active tab underline, active dashboard icon, the stepped frame shell and the Deco mark. Used as text and 1 to 2px lines, never as a large fill.
- **Brass Seam** (brass-line; light mode brass-line-light): the structural hairline. Header and footer rules, outline buttons, cards, dialog edges, input hover, the category band rules.

### Tertiary
- **Sea Green** (sea-green, on sea-green-soft): success, completed bookings, "included" checks.
- **Marigold** (marigold, on marigold-soft): pending states and the preview banner.
- **Coral / Brick** (coral, brick, on coral-soft): destructive text and outline; brick fills only on destructive hover.
- **Lilac** (lilac-ring, on info-soft): focus ring and informational (confirmed) status.

### Neutral
- **Ink Lacquer** (ink-lacquer; light pearl-light): page ground.
- **Lacquer Panel** (lacquer-panel; light pearl-panel-light): cards, inputs, dialogs, the frame core, alternate section bands.
- **Raised Lacquer** (lacquer-raised; light pearl-raised-light): secondary buttons, active nav row, in-progress row, skeletons, typographic covers.
- **Violet Seam** (violet-seam; light violet-seam-light): default borders and row dividers inside panels.
- **Ivory** (ivory; light ink-text-light): primary text.
- **Muted Mauve** (muted-mauve; light muted-mauve-light): secondary text, ledes, inactive nav.
- **Subtle Mauve** (subtle-mauve; light subtle-mauve-light): placeholders, table headers, metadata.

### Named Rules
**The One Jewel Rule.** Amethyst fills only the primary action. If a screen shows two amethyst buttons in the same decision, one of them is wrong.

**The Gilt-as-Line Rule.** Brass is a line, a glyph or a word, never a panel fill. Hairline structure uses Brass Seam; full Gilt Brass is for marks of trust and the signature frame.

**The Two-Theme Rule.** Components use semantic tokens only, never raw hex, so dark and light both resolve and both hold AA contrast.

## Typography

**Display Font:** Bodoni Moda Variable (with Bodoni 72, Didot, serif)
**Body Font:** Manrope Variable (with ui-sans-serif, system-ui, sans-serif)

**Character:** A high-contrast Didone gives names, prices and headings the gilded-lobby voice; Manrope stays out of the way and keeps every number aligned with tabular, lining figures set on the body.

### Hierarchy
- **Display** (500, 76px desktop stepping to 60px and 44px on smaller screens, 1.04, -0.02em): the home hero headline only. An italic brass word may carry the emphasis.
- **Headline** (500, 48px desktop / 36px mobile, ~1.1): page titles and section headings.
- **Title** (500, 24 to 30px): sub-section headings, pro names, dialog titles, category names, prices, dashboard times.
- **Body** (400, 15px UI / 16 to 18px reading, 1.6): controls at 15px; ledes and descriptions at 18px muted, capped at 52 to 65ch.
- **Label** (600, 13px): field labels, slot-picker labels, the verified seal, badges at 12px. Sentence case, no tracking.

### Named Rules
**The Didone-for-Names Rule.** Names, prices, headings and times shown as content are set in Bodoni Moda; controls, labels and metadata are Manrope. Italic Bodoni in brass is the only typographic ornament (accent words, monograms, step numerals, cover initials).

**The Tabular Rule.** Numerals are tabular and lining everywhere, so slot times, prices and table columns align.

**The No-Eyebrow Rule.** No small labels above headings. A heading stands on its own; context goes in the lede below it.

## Layout

Public pages sit in a 1440px (90rem) container with 16 / 32 / 64px gutters at mobile / tablet / desktop. Desktop compositions use a 12-column grid split 7 / 5: content on the left, the booking or next-free panel on the right (sticky on the service page). Sections breathe at 80px vertical rhythm, 112px on large screens; internal stacks step 8 / 12 / 24 / 40px.

The dashboard uses a 264px brass-ruled sidebar beside a 1216px (76rem) content column; on mobile the sidebar becomes a fixed bottom tab bar with a brass top rule and brass active state. The vendor's day is a time-ranked table on tablet and up, and stacked cards on phones.

Lists and bands are ruled rather than boxed: categories sit in a band between brass rules with hairline column dividers; featured services and reviews are divided rows. Service detail on mobile lets a real photo own the first screen (4:5); without a photo, the typographic cover collapses to a short band (128px, 192px from tablet).

## Elevation & Depth

The system is flat and tonal. Depth comes from one-step-raised lacquer panels and brass hairline seams, not shadows. The only drop shadow is the modal dialog's single ambient shadow over the dimmed overlay, which separates a true layer from the page.

### Shadow Vocabulary
- **Modal ambient** (`box-shadow: 0 24px 64px -24px rgb(8 5 14 / 0.8)`): dialogs only.
- **Selected inner seam** (`box-shadow: inset 0 0 0 1px var(--brass)`): doubles the brass border of a selected slot chip. A line, not depth.

### Named Rules
**The Seam-Not-Shadow Rule.** Resting surfaces never cast shadows. Separate them with a tonal step or a brass hairline. Only a modal floating over the overlay gets a shadow.

## Shapes

Corners are small and consistent: 6px for focus targets in nav and tiny controls, 10px for buttons, inputs, chips and thumbnails, 14px for cards, dialogs, the hero search and empty states. Badges and monograms are fully round. Borders are 1px; the only heavier strokes are the 2px brass top rule on verification steps, the 2px active-tab underline and the 1.5px brass shell of the Deco frame. The stepped Deco profile (a ziggurat corner with a 12px step) appears in exactly two places: the brand mark and the signature frame.

### Named Rules
**The Stepped-Corner Rule.** The ziggurat silhouette belongs to the logo mark and the Deco frame. Do not step-cut buttons, cards or images.

## Components

### Buttons
Confident and quiet: one jewel, everything else in seams.
- **Shape:** gently rounded (10px); heights 36 / 44 / 48px (sm / md / lg), 44px square icon button.
- **Primary:** amethyst fill, white semibold text, 20px side padding at md.
- **Hover / Focus:** hover deepens to amethyst-hover; press scales to 0.98; focus shows a 2px lilac outline offset 2px. Transitions 200ms on the deco ease.
- **Secondary:** raised lacquer with a seam border that turns brass on hover.
- **Outline:** transparent with a brass seam border; raised fill on hover.
- **Ghost:** transparent, raised fill on hover (header log-in, menu toggles).
- **Link:** ivory text with a brass-seam underline that brightens to brass.
- **Destructive:** outline only (coral text, coral border at 60%), filling brick only on hover, usually at sm size and placed apart from the primary action (opposite end of the row).

### Chips
- **Slot and day chips:** 44px, 10px radius, seam border, semibold tabular text. Hover turns the border brass-seam.
- **Selected:** amethyst-soft fill with a doubled brass edge. Unavailable slots lose the border, drop to subtle mauve and are struck through. Slots form an ARIA radio group with arrow-key movement.

### Badges
- **Style:** full-round, 12px semibold, soft tinted ground with its tone's text (neutral, info, success, warning, danger); the brass tone is outline-only. Status mapping: pending marigold, confirmed lilac, in progress brass, completed sea green, declined coral, cancelled neutral.

### Cards / Containers
- **Corner Style:** 14px.
- **Background:** lacquer panel; in-progress rows use raised lacquer.
- **Shadow Strategy:** none (see Elevation & Depth).
- **Border:** brass seam for request cards and the hero search; violet seam for tables and stacked rows; dashed brass seam for empty states.
- **Internal Padding:** 24px (16px on stacked mobile rows).

### Inputs / Fields
- **Style:** 44px, lacquer panel fill, violet-seam border, 10px radius, 15px text, subtle-mauve placeholder.
- **Focus:** border shifts to lilac with a 2px lilac ring at 40%; hover warms the border to brass seam.
- **Error / Disabled:** invalid shows a coral border and coral ring; disabled drops to 50% opacity.

### Navigation
- **Public header:** sticky 72px bar on the ink ground under a brass hairline; wordmark with Deco mark, 15px medium nav links (muted, ivory when active), ghost log-in plus primary sign-up. On mobile a top sheet drops in with Bodoni links on hairline rows.
- **Tabs:** 2px underline that turns brass when active, muted text otherwise, on a seam baseline.
- **Dashboard:** 44px sidebar rows, active row raised with a brass icon; mobile bottom tab bar with brass active label.

### Deco Frame (signature)
The stepped Art Deco frame: a 1.5px gilt-brass shell clipped to a ziggurat top profile (12px steps) around a lacquer-panel core with matching profile, 24 to 32px padding and extra top room. It holds the booking panel only: the slot picker with price, day, address and the primary booking action (home "next free pro" and the service booking aside). At most one per page.

### Service Cover
A service photo, or an honest typographic placeholder when there is none: raised lacquer with a large italic brass Bodoni initial and the category in small muted text. When it leads a page without a photo it is a short band, never a full-bleed hero.

### Monogram and Verified Seal
A 56px round raised-lacquer disc with a brass seam and an italic brass initial stands in for missing pro photos. The verified seal is a brass shield icon with "Verified by Veny" in 13px bold brass, shown beside every pro name.

### Preview Banner
Screens running on sample data carry a full-width marigold-soft note bar under the header stating that the data is a preview and when live data arrives, with a link to all previews.

## Do's and Don'ts

### Do:
- **Do** use amethyst only for the one primary action in a decision.
- **Do** separate surfaces with a tonal step or a brass hairline (1px brass-line).
- **Do** put the booking panel (slot picker, price, book action) inside the Deco frame, once per page.
- **Do** set names, prices, headings and displayed times in Bodoni Moda (500), and controls in Manrope with tabular numerals.
- **Do** keep destructive actions outline-only and spatially apart from the primary action.
- **Do** keep motion to 150 / 200 / 250ms with cubic-bezier(0.22, 1, 0.36, 1), on state changes only, and honour reduced motion.
- **Do** use the 6 / 10 / 14px radii and semantic tokens only, verified in both dark and light themes at WCAG AA.
- **Do** show the typographic Service Cover as a short band when a service has no photo, and carry the Preview Banner on any screen running sample data.
- **Do** draw icons as thin outline strokes (1.5 to 1.75) in muted or brass, at 16 to 20px.

### Don't:
- **Don't** add shadows to resting cards, panels, buttons or the frame; the modal dialog is the only shadowed layer.
- **Don't** fill a button, chip or panel with amethyst outside the primary action, or fill large areas with brass.
- **Don't** use the Deco frame or stepped corner more than once per page or on anything but the booking panel and the logo mark.
- **Don't** place eyebrow or kicker labels above headings.
- **Don't** use side-stripe accents on cards or rows.
- **Don't** fabricate trust claims, ratings or photos; use "New on Veny", the monogram and the typographic cover instead.
- **Don't** use em dashes in UI copy.
- **Don't** return to white rounded photo cards with an icon row, or to neon glow and gradients.
