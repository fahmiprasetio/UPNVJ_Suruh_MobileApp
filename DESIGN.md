---
name: UPNVJ Suruh
description: A campus errand marketplace dressed as an embroidered varsity patch — badge green, motorcycle maroon, and prices you can read across the room.
colors:
  patch-green: "#4B7043"
  patch-green-tint: "#8FBF80"
  motor-maroon: "#8B2331"
  motor-maroon-tint: "#E8909A"
  badge-ink: "#1E302E"
  dirt-road-sand: "#C8B080"
  paper: "#F5F8F4"
  paper-card: "#FFFFFF"
  paper-container: "#E9F0E7"
  paper-outline: "#D3DFD0"
  paper-outline-strong: "#6F8577"
  paper-on: "#17231C"
  paper-on-variant: "#4A5A50"
  night: "#13211A"
  night-lowest: "#0E1813"
  night-low: "#182820"
  night-container: "#1F3229"
  night-card: "#253B31"
  night-highest: "#2E483C"
  night-outline: "#5E8271"
  night-outline-strong: "#395648"
  night-on: "#EAF1EE"
  night-on-variant: "#B2C8BE"
typography:
  display:
    fontFamily: "Roboto, sans-serif"
    fontSize: "36px"
    fontWeight: 400
    lineHeight: "44px"
  headline:
    fontFamily: "Roboto, sans-serif"
    fontSize: "24px"
    fontWeight: 600
    lineHeight: "32px"
  title:
    fontFamily: "Roboto, sans-serif"
    fontSize: "14px"
    fontWeight: 600
    lineHeight: "20px"
  body:
    fontFamily: "Roboto, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: "20px"
  label:
    fontFamily: "Roboto, sans-serif"
    fontSize: "11px"
    fontWeight: 600
    lineHeight: "16px"
rounded:
  control: "12px"
  bubble: "14px"
  card: "16px"
  pill: "999px"
spacing:
  sm: "8px"
  gutter: "12px"
  md: "16px"
  lg: "24px"
components:
  button-primary:
    backgroundColor: "{colors.motor-maroon}"
    textColor: "{colors.paper-card}"
    rounded: "{rounded.control}"
    typography: "{typography.title}"
    height: "52px"
  button-primary-disabled:
    backgroundColor: "{colors.paper-container}"
    textColor: "{colors.paper-on-variant}"
    rounded: "{rounded.control}"
    height: "52px"
  card:
    backgroundColor: "{colors.paper-card}"
    textColor: "{colors.paper-on}"
    rounded: "{rounded.card}"
    padding: "16px"
  card-service:
    backgroundColor: "{colors.paper-card}"
    textColor: "{colors.paper-on}"
    rounded: "{rounded.card}"
    padding: "16px"
    height: "148px"
  input:
    backgroundColor: "{colors.paper-container}"
    textColor: "{colors.paper-on}"
    rounded: "{rounded.control}"
    padding: "16px"
  status-pill:
    backgroundColor: "{colors.paper-container}"
    textColor: "{colors.paper-on-variant}"
    rounded: "{rounded.pill}"
    typography: "{typography.label}"
    padding: "4px 10px"
  appbar:
    backgroundColor: "{colors.paper-container}"
    textColor: "{colors.paper-on}"
    height: "56px"
---

# Design System: UPNVJ Suruh

## Overview

**Creative North Star: "The Varsity Patch"**

The whole system comes out of one object: the embroidered badge of a helmeted crocodile riding a motorcycle down a dirt road, ringed and lettered like something stitched onto a jacket. That patch is not a logo dropped on top of a generic app — it is the source of the palette, the ink, and the attitude. Every color in this system is sampled from it. The crocodile's body green is the primary. The motorcycle's maroon is the action. The outline ink is the darkest text. When a future screen needs a color, the question is not "what does Material suggest" but "where is it on the patch."

The register is **bold, but never at the cost of legibility**. The reference the team actually admires is Gojek: a product that dares to be visually loud, distinct, and eye-catching while still telling you exactly what you are paying and what is happening to your order. That is the bar. Confident color blocking, large unambiguous prices, and status you can read at arm's length are all in bounds. What is out of bounds is decoration that costs the user a fact. If a flourish makes a price, a state, or an address one degree harder to find, the flourish loses — every time, without argument.

Two things this must never become. It must never look like **untouched Material 3** — the default baseline with stock components and no brand anywhere, the "obviously a Flutter demo" failure. And it must never look like a **fintech app** — cold, gray, corporate restraint that drains the campus warmth out of a service run by students for students. This is a green, warm, slightly proud product with a cartoon reptile at its heart. It should feel like it belongs to a campus, not to a bank.

**Key Characteristics:**
- Every color traceable to the badge artwork; no color-wheel generation
- Green ground, maroon action — two voices, never more
- Prices are the loudest element on any order surface
- Flat today by circumstance, not by law; shadows are permitted and should be ink-tinted
- Generous 16px rhythm, 16px card corners, full-round status pills
- Indonesian throughout; the product's real language, not a localization layer

## Colors

The palette is sampled directly from `mobile/assets/logo/lencana.png` — the crocodile's green, the motorcycle's maroon, the outline's ink, the road's sand. Nothing here was generated from a color wheel.

> **Migration note.** These values are normative and the code has not caught up. `mobile/lib/core/theme/app_theme.dart` still seeds from navy `#16336B` with an amber `#F5A524` secondary. That navy scheme is the **legacy incumbent**, not the system. New work builds green; the theme file is the one place that has to change.

### Primary
- **Patch Green** (`#4B7043`): The crocodile's own body color, confirmed by sampling the artwork (`#486840` dominant). Carries brand identity, active timeline steps, completed states, and price values that are settled. It is the color of *things being true* — a stage reached, a number confirmed. Passes AA on both paper and card grounds (5.7:1).
- **Patch Green Tint** (`#8FBF80`): The dark-theme substitute. Never use the full-strength green as text on a dark ground; it drops below readable contrast. The tint reads 7.9:1 on night surface.

### Secondary
- **Motor Maroon** (`#8B2331`): The motorcycle's body, and the loudest thing in the badge after the crocodile. This is the **action** color — primary buttons, the runner's TERIMA, anything the user is meant to press. It is near-complementary to the green, so a maroon button on a green-tinted screen genuinely pops, which is exactly the Gojek-grade boldness this system is after. 8.8:1 against white.
- **Motor Maroon Tint** (`#E8909A`): Dark-theme text and icon substitute, 7.1:1 on night surface.

### Neutral
- **Paper** (`#F5F8F4`): The scaffold ground in light theme. A green-tinted off-white, not a pure white — the tint is what keeps the app from reading as clinical.
- **Paper Card** (`#FFFFFF`): Cards sit *above* paper as true white. The separation is only 1.07:1, so in light theme the hairline border does the real work of defining a card, not the fill. This is deliberate and matches the incumbent implementation.
- **Paper Container** (`#E9F0E7`): App bar, input fills, neutral status pills. One clear step down from paper.
- **Paper Outline** (`#D3DFD0`) / **Paper Outline Strong** (`#6F8577`): Hairline card borders and dividers; the strong value for anything that must survive as a visible stroke.
- **Paper On** (`#17231C`) / **Paper On Variant** (`#4A5A50`): Primary and secondary text, 15.2:1 and 6.8:1 on paper.
- **Badge Ink** (`#1E302E`): The outline color of the artwork itself. Reserved for the splash lettering and for tinting shadows. Not a general text color — `Paper On` is.
- **Dirt Road Sand** (`#C8B080`): Present in the badge (the road) and available as a warm neutral for illustration grounds or empty states. **Currently unassigned in code** — do not invent a role for it without a decision.

### Night (dark theme)
The dark surface ladder is transposed from the carefully tuned navy ladder that ships today: same lightness steps, same two-step separation between card and background, rotated to forest hue and pulled to ~23% saturation so it reads as deep forest rather than mint.

- **Night** (`#13211A`) scaffold · **Night Lowest** (`#0E1813`) · **Night Low** (`#182820`) · **Night Container** (`#1F3229`) app bar · **Night Card** (`#253B31`) · **Night Highest** (`#2E483C`)
- **Night On** (`#EAF1EE`) 14.5:1 · **Night On Variant** (`#B2C8BE`) 9.4:1 on ground, 6.8:1 on card
- **Night Outline** (`#5E8271`) · **Night Outline Strong** (`#395648`)

### Named Rules

**The Badge Sourcing Rule.** Every color that enters this system must be traceable to a pixel in `lencana.png`. If you cannot point at it in the artwork, it does not ship. This is why the amber was dropped and why the sand sits unassigned rather than invented into a role.

**The Two Voices Rule.** Green states, maroon acts. Green describes what *is* — a stage completed, a price agreed. Maroon asks for a *tap*. A screen with three accent colors has one too many; a green button or a maroon timeline is a bug, not a variation.

**The Status Collision Rule.** Making maroon the secondary puts it next door to `error`, and the status badge map currently spends both: `menungguPembayaran` uses `errorContainer` and `mencariRunner` uses `secondaryContainer`. Under the new palette those two read as the same red and the distinction dies. When the theme migrates, `mencariRunner` must move off secondary — to a neutral container or a green container — so that red keeps meaning *"you owe something"* and nothing else.

**Settled.** `mencariRunner` now uses `primaryContainer` and `dikerjakan` full `primary`, and the runner quota badge ("Butuh 3 orang, 1 sudah gabung") moved off `secondaryContainer` for the same reason: at eleven pixels tall it was indistinguishable from `errorContainer`. Red means one thing, that something is owed. The rule stands for every surface still unbuilt: **check whether it spends a secondary role on something that is actually a state.**

## Typography

**Display / Body / Label Font:** Roboto (Material 3 default, with the platform sans fallback)

**Character:** The system ships entirely on Material's default face. There is no custom typeface loaded and no display font assigned. Personality currently comes from **weight and size contrast**, not from letterforms — headline greetings and price values are pushed to 600/700 while supporting text stays at 400, and that gap is what carries hierarchy. This is the largest un-exercised lever in the system: a display face is the single cheapest way to move further toward the boldness the brief asks for, and it is deliberately left open rather than guessed at here.

### Hierarchy
- **Display** (400, 36px/44px): Not currently used on any screen. Available for a future hero moment.
- **Headline** (600, 24px/32px): The home greeting ("Halo, [nama]") and the accepted quote price on the offer card. The largest type a user actually meets.
- **Title** (600, 14px/20px): Card titles — service names, order service labels. Also 20px/600 for the app bar title, and 16px/600 for button labels.
- **Body** (400, 14px/20px): Descriptions, addresses, chat messages. Secondary body drops to 12px/16px for metadata (order code, relative time).
- **Label** (600, 11px/16px): Status pills and quota badges only. Always paired with a full-round container.

### Named Rules

**The Price Is Loudest Rule.** On any surface where money appears, the price is the largest and heaviest element on that surface. The offer card puts it at headline/700; the order card puts it at title/700 in Patch Green. A screen where the price is not visually dominant is a screen that has buried the one fact the user opened it for.

**The Waiting Price Rule.** A Track B order with no agreed price is not missing data — it is a legitimate state with its own style. Render "Harga menunggu penawaran" at the same size as a real price, in `Paper On Variant` rather than Patch Green. Never render a placeholder dash, a zero, or an estimate.

## Layout

The spatial model is a single scrolling column with a **16px page inset** and a **16px vertical rhythm**, stepping to 24px between major sections. Screens are `ListView`-based, not sliver-composed.

**The coloured header is for screens that welcome, not screens that finish.** Home and sign-in both carry a full-bleed green panel with rounded bottom corners; every task screen stays calm. Sign-in earns it more than home does, because until it there is nothing on screen to recognise the app by. Its badge sits on a **white disc**, never straight on the green: `lencana.png` is drawn for white and reads as a misplaced sticker on any other ground, which is the same reason the splash overlay is white in both themes. The sign-in panel scrolls with the rest of the page rather than being pinned, so an open keyboard cannot squeeze the field and its error message off a short phone.

**Home is two doors, and the split is spatial.** Six catalogued services sit in a responsive grid (`maxCrossAxisExtent: 220`, fixed `mainAxisExtent: 148`, 12px gutters) — the tiles reflow from two columns on a phone to more on a tablet without a breakpoint being declared anywhere. Below them, a labeled "atau" divider, then the free-form request as a **full-width horizontal bar** rather than a seventh tile. The shape difference is the message: the grid means the price is already known (Track A), the bar means the price comes later through a quote (Track B).

**Forms cap at 420px** and center themselves (`masuk_screen`), so the auth flow does not stretch into an unreadable line length on a tablet or a browser window.

**Density is comfortable, not compact.** Cards carry 16px internal padding on all sides; touch targets clear both platform floors (primary buttons at 52px, in-card actions at 46–48px, against Android's 48dp and iOS's 44pt minimums).

### Named Rules

**The Two Doors Rule.** The catalogued grid and the free-form bar must never merge into one uniform list. Their difference in shape is the only place the user learns that one path prices itself and the other has to be quoted. A seventh tile in the grid would silently promise a price that does not exist.

## Elevation & Depth

**Every surface sits flat except the primary button.** Cards and the app bar are `elevation: 0`; depth comes from tonal steps in the surface ladder plus a 1px `outlineVariant` hairline around each card. Two exceptions: the app bar's `scrolledUnderElevation: 1`, so content scrolling beneath it registers, and `filledButtonTheme`, which carries `elevation: 3` with a maroon `shadowColor` at 45% so the primary action reads as the destination on its screen. That elevation drops to `0` when the button is disabled, because a grey button that still floats promises something it cannot deliver.

**This flatness is circumstance, not doctrine.** It is how the app landed, and shadows are explicitly permitted going forward. Given the brief's appetite for boldness, a considered shadow vocabulary is one of the available moves — particularly to lift the primary action or a pending quote off the page. What is not permitted is *default* shadow: a stock black `BoxShadow` under a green-tinted card reads as dirt, not depth.

### Shadow Vocabulary
- **Lift** (`0 2px 8px rgba(30, 48, 46, 0.10)`): A resting card that needs to separate from a busy ground. Defined as `AppTheme.bayanganAngkat`; no screen spends it yet.
- **Action**: Under a maroon primary button, to make the CTA the obvious destination on the screen. **Already applied, globally, by `filledButtonTheme`** through `elevation: 3` plus a maroon `shadowColor`, not by a token you attach yourself. Wrapping a `FilledButton` in your own shadow stacks a second one on top of the theme's, and the result does not read as a more important button, it reads as a button with a dirty edge. If a button needs more presence, change the theme.
- **Sheet** (`0 -4px 24px rgba(30, 48, 46, 0.16)`): Bottom sheets and the payment panel, cast upward. Defined as `AppTheme.bayanganLembar`; no screen spends it yet.

### Named Rules

**The Grounded Shadow Rule.** Shadows tint with `Badge Ink` (`#1E302E`) or with the element's own color, never with pure black. A green-and-white system shadowed in `#000` looks smudged; shadowed in its own ink it looks printed.

## Shapes

The form language is **consistently rounded, with the radius encoding the element's job**:

- **Cards: 16px** (`radiusKartu`) — the softest corner in the system, used for every container that holds a unit of content.
- **Controls: 12px** — buttons, inputs, and the icon tile inside a service card. Tighter than cards so a control never reads as a card.
- **Chat bubbles: 14px**, sitting deliberately between the two, with the bottom corner facing the sender clipped to **4px**. That clip is the tail: it points at the origin of the message without a drawn triangle that would have to be recoloured and re-clipped against its ground on every theme change.
- **Pills: 999px** — status badges and quota badges are fully round. Full-round is reserved for *state labels only*; it is how the eye finds status without reading.

**Borders are hairlines, never heavy.** Cards carry a 1px `outlineVariant` stroke; inputs carry the same at rest. Icons are Material's outlined set throughout (`_outlined` suffix), never filled, at 16 / 18 / 20 / 22 / 28px depending on context.

## Components

### Buttons
- **Shape:** Softly rounded (12px), full-bleed width in forms
- **Primary (`FilledButton`):** Motor Maroon fill, white label, 52px minimum height, 16px/600 label. In-card variants drop to 46–48px. The runner's accept button uppercases its label ("TERIMA") — the only uppercase button in the system, and it earns it by being the single irreversible race-condition action.
- **Loading:** The label is replaced in place by a 20px `CircularProgressIndicator` at 2px stroke; the button keeps its footprint so nothing reflows. The button is disabled for the whole in-flight request so one tap cannot send twice.
- **Text buttons:** Used for every secondary path ("Belum punya akun? Daftar", "Ganti nomor", "Chat Klien" inside a runner card). **A secondary action that shares a card with the maroon primary must be a text button, never outlined**: two full-width buttons of equal weight leave the card with no primary action at all, only two competing demands.
- **Outlined buttons:** Only where nothing else on the surface is competing, such as "Muat N order lagi" standing alone at the foot of a list. Never beside a filled button.

### Cards / Containers
- **Corner Style:** 16px
- **Background:** White on paper in light; `Night Card` (two steps above ground) in dark
- **Shadow Strategy:** None at rest today; see Elevation
- **Border:** 1px `outlineVariant` hairline, always
- **Internal Padding:** 16px on all sides
- **Interaction:** Tappable cards wrap an `InkWell` *inside* `clipBehavior: Clip.antiAlias`, so the ripple is clipped to the 16px corner instead of spilling square.

### Service Tile (signature)
A 148px-tall card whose icon sits in a 12px-rounded `primaryContainer` chip at the top, with the service name and description pinned to the bottom by a `Spacer`. Bottom-alignment is what keeps the six tiles optically regular even though their labels wrap to different heights.

### Free-Form Door (signature)
The Track B entry: a full-width card filled with `secondaryContainer`, laying its icon, title, description, and a trailing arrow in a single row. It is the only filled-container card on the home screen, and the fill plus the shape is what marks it as a different kind of door.

### Status Pill
- **Style:** Full-round (999px), 10px × 4px padding, 11px/600 label
- **State:** Background and text are a domain mapping, not a style choice — the pairing lives in the `OrderStatusWarna` extension because *which status counts as urgent* is a product decision. See The Status Collision Rule before changing it.

### Inputs / Fields
- **Style:** Filled with `Paper Container` (currently `surfaceContainerHighest` at 40% alpha), 12px radius, 1px `outlineVariant` border at rest and enabled
- **Validation:** Inline, below the field, and the phone-number pattern deliberately mirrors the server's exactly — a value that passes here and fails there shows the user a rejection they cannot locate
- **Error surface:** A separate 16px-radius `errorContainer` block with a 20px `error_outline` icon, placed at the bottom of the form rather than inline

### Order Timeline (signature)
A vertical rail of 18px circles joined by a 2px connector. Passed stages fill with Patch Green and carry a 12px check; the current stage is an open ring in Patch Green with its label at 700; future stages drop to `outlineVariant` with 400 labels. The stage list is derived per track — Track A shows four stages, not five, because its price was never in question. Cancelled orders replace the entire rail with a single error-colored row rather than drawing a broken path.

### Splash Overlay (signature)
Not a route — a layer stacked over the whole app by `MaterialApp.router`'s `builder`, so the destination screen is built and rasterized *behind* it during the animation. Always pure white in both themes, because the badge is drawn for white and would read as a misplaced sticker on a dark ground. The badge is sized at 48% of the shortest screen edge, clamped 120–190px. Sequence: rise with `elasticOut` (0–48%), a full perspective Y-axis spin (48–79%), then "UPNVJ SURUH" writing letter-by-letter along the ring's lower arc (69–100%) — 2100ms total, a 1000ms held beat, then a 220ms lift of the entire layer. Reduced-motion jumps to the end state but still waits on the session. **Treat the timings and the layer architecture as load-bearing**; they are covered by regression tests and were the fix for a visible white-flash defect.

## Do's and Don'ts

### Do:
- **Do** source every new color from `lencana.png`. If you cannot point at it in the badge, it does not ship.
- **Do** make the price the largest, heaviest element on any surface where money appears.
- **Do** put maroon on the thing you want tapped, and green on the thing that is already true. In chat this means green bubbles for messages already sent and a maroon send button; a green send button blurs the two things people most often tell apart on that screen.
- **Do** move maroon to whichever step is actually live. In the runner's completion sheet the photo button is maroon while there is no photo and Tandai Selesai takes over once there is; two maroon buttons are never live at once.
- **Do** be visually loud where loudness costs nothing — color blocking, scale contrast, confident containers. Boldness is the brief.
- **Do** keep the two doors on home shaped differently; the shape is how the user learns which path prices itself.
- **Do** clip ripples to the card radius (`clipBehavior: Clip.antiAlias` around the `InkWell`).
- **Do** tint shadows with `Badge Ink` or the element's own color when you add them.
- **Do** honor reduced-motion by jumping to end state, never by leaving a user mid-animation.
- **Do** use outlined Material icons; the set is consistent throughout.

### Don't:
- **Don't** ship untouched Material 3. A stock baseline with no brand anywhere is the explicit anti-reference.
- **Don't** drift toward fintech gray. Cold corporate restraint is the other explicit anti-reference; this product is warm and campus-issued.
- **Don't** let a flourish cost a fact. If decoration makes a price, a status, or an address harder to find, the decoration loses.
- **Don't** introduce a third accent. Green and maroon are the two voices; a third color is a bug.
- **Don't** reintroduce the amber `#F5A524` — it was dropped deliberately, even though the gold star exists in the artwork.
- **Don't** assign `Dirt Road Sand` a role without a decision; it is sampled and available, not yet spent.
- **Don't** leave `mencariRunner` on `secondaryContainer` after the palette migration; it will collide with `errorContainer`.
- **Don't** put the splash badge on a themed background, and don't convert the overlay back into a route.
- **Don't** use full-round (999px) corners on anything that is not a state label.
- **Don't** use pure-black shadows anywhere in this system.
