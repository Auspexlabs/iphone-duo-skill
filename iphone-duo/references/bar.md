# The vertical bar: what each toolbar construct does

Measured on the iPhone Duo simulator (iOS 27.1), cover display, light mode, every item marked
`.axisBehavior(.verticalPreferred)` unless noted. The bar is the same on the inner display in landscape.
Screens of the gallery that produced this table live in the probe app (`-bar1` … `-bar8`).

## Contents
- Grouping and pinning
- Button styles and shapes
- Content kinds
- Capacity and overflow
- Placements
- Axis behavior, spacers, search
- Tab bar in the bar
- Recipes

## Grouping and pinning

| Construct | Result |
|---|---|
| Two adjacent `ToolbarItem`s | one shared glass bubble |
| `ToolbarSpacer(.fixed)` between items | splits bubbles; a gap of ~12 pt |
| `ToolbarItemGroup { a; b }` | its own bubble, same as two adjacent items after a fixed spacer |
| `ToolbarItem(placement: .bottomBar)` | pinned to the bottom of the bar, above the home indicator; several bottom items share one bubble |
| `ToolbarSpacer(.flexible)` | **does not** push following items to the bottom; it only splits bubbles. Use `.bottomBar` to pin. |

## Button styles and shapes

| On the `Button` | Result in the bar |
|---|---|
| default | icon in the shared bubble |
| `.buttonStyle(.glass)` | same as default |
| `.buttonStyle(.glassProminent)` | its own **filled** (tint-colored) circle; leaves the shared bubble |
| `.buttonStyle(.borderedProminent)` | same as `.glassProminent` |
| `.buttonStyle(.bordered)` | its own bubble, tinted icon |
| `.buttonBorderShape(.roundedRectangle)` alone | ignored — still a circle |
| `.bordered` + `.buttonBorderShape(.roundedRectangle)` | a white rounded square **inside** the shared bubble (the bubble stretches around it; looks odd) |
| `.tint(.red)` | icon colored; `.foregroundStyle` on the label is overridden |
| `.disabled(true)` | greyed, stays in the bubble |
| `.controlSize(.large)` | no visible change |

### Square buttons

The bar's own bubbles are circles. For a square, hide the shared background and draw the shape yourself:

```swift
ToolbarItem {
    Button { } label: {
        Image(systemName: "stop.fill").foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(.blue, in: RoundedRectangle(cornerRadius: 9))      // solid
            // or: .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 9))   // glass
    }
}
.sharedBackgroundVisibility(.hidden)
.axisBehavior(.verticalPreferred)
```

Both the solid and the glass square rendered cleanly as standalone squares.

## Content kinds

| Content | Result |
|---|---|
| `Button("Done")` (text) | text in the bubble, same height as an icon |
| `Label` with `.labelStyle(.titleAndIcon)` | icon only — the bar drops titles |
| toggle: `Label(...).symbolVariant(on ? .fill : .none)` | works; fill shows the state, bubble unchanged |
| `Menu { … } label: { Label("More", systemImage: "ellipsis") }` | icon in the bubble; opens a menu |
| `Text("12:34")` + `.sharedBackgroundVisibility(.hidden)` | bare text, no bubble — status readouts |
| `ProgressView().controlSize(.small)` | went to the overflow menu on a full bar; untested on a short bar |
| `.badge(3)` on a button | no badge drawn |
| `.navigationTitle` | stays horizontal at the top of the content, never in the bar |

Text wider than ~44 pt wraps character by character: keep bar text short, `.lineLimit(1)` + `.fixedSize()`.

## Capacity and overflow

The cover's bar holds about **8** items (plus the status area at the top and the home indicator at the
bottom). Beyond that the rest go into a "⋯" overflow menu bubble; `.bottomBar` items and a tab bar reduce
the room. 12 plain items → 1–8 visible, 9–12 in "⋯".

## Placements (all `.verticalPreferred`)

| `ToolbarItem(placement:)` | Where it went |
|---|---|
| `.topBarLeading`, `.navigation`, `.cancellationAction` | top of the bar, in order |
| `.topBarTrailing`, `.primaryAction`, `.confirmationAction` | below the leading group; `.confirmationAction` text is bold |
| `.principal` | stays horizontal, as the title at the top of the content |
| `.secondaryAction` | inside a "⋯" menu (as everywhere) |
| `.status` | not shown |
| `.bottomBar` | pinned to the bottom |

Order inside the bar: leading-ish placements first, then trailing-ish, then overflow, then bottom.

## Axis behavior, spacers, search

| Construct | Result |
|---|---|
| plain `ToolbarItem` (no `axisBehavior`) | went into the vertical bar anyway (`.automatic` infers from content) |
| `.axisBehavior(.horizontalOnly)` | stays as a round button in a horizontal bar at the top-right of the content |
| `DefaultToolbarItem(kind: .search, placement: .bottomBar)` with `.searchable` | magnifier pinned at the bottom of the bar; the search field appears at the top of the content when active |

## Tab bar in the bar

With a `TabView` whose tab holds the `NavigationStack`: the tab bar lives at the **bottom** of the vertical
bar (selected tab highlighted), toolbar items above it, and `.bottomBar` items sit directly above the tab bar.
UIKit exposes which side compresses first (`UINavigationItem.verticalBarCompressionBehavior`); no SwiftUI
equivalent was found.

## Recipes

- **Persistent controls** (Home, record, stop): one `@ToolbarContentBuilder` reused with `.toolbar { … }` on
  every pushed destination, or the bar loses them on push.
- **Related actions as one unit** (pause + stop): adjacent items, `.bottomBar`, red `.tint` on the destructive
  one.
- **Hide a bar item during a transition**: the bar ignores `.opacity` on item content; use
  `.tint(.clear)` (or swap the label) instead.
- **Status readout** (clock, level): `Text` + `.sharedBackgroundVisibility(.hidden)`.
