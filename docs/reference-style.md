# Reference-inspired interface

The supplied references use a vivid blue overview, heavy rounded typography,
charcoal cards on a dark canvas, generously rounded corners, inset dividers,
solid category-color icon tiles, and a labeled glass dock. NullSign applies this
hierarchy to its own catalog, library, and settings data.

## Shared treatments

- Apps and Signer use centered navigation titles, a blue count overview, and a
  curved turquoise transition into the black dashboard. Counts remain tied to
  the existing repositories and Core Data fetches.
- Settings and its detail pages use a charcoal canvas and lighter grouped
  cards, with 24-point continuous corners and inset row separators.
- Electric blue marks links, outlined actions, selection, and download progress.
  A slightly deeper blue backs white primary-button and overview text.
- Certificate and privacy icons use green; signing customization uses purple;
  storage uses orange; diagnostics and destructive actions use red. Status
  descriptions accompany status colors. The existing tvOS badge stays red.
- Compact all-caps section labels use SF Rounded Heavy. App names and controls
  use Bold; descriptions and identifiers use Regular. Semantic fonts retain
  Dynamic Type, and the overview metric scales relative to the large-title style.
- The dock adds visible tab names and a dark selected capsule. Existing tab
  retention, keyboard handling, tap feedback, and reduced-motion behavior remain.
- Compact action buttons retain at least a 44-point interaction area. Search
  fields and settings rows use minimum heights rather than fixed text heights.

## Verification

Source review covers primary and destructive actions, pushed-page toolbar
backgrounds, card/selection shape alignment, form and sheet surfaces, and iOS 16
API availability. The white-on-primary-blue contrast is above 4.5:1. Decorative
waves and overview symbols are hidden from accessibility and do not intercept taps.

`NullSignThemePreviews.swift` contains isolated SwiftUI component previews for
standard and 320-point phone widths and larger accessibility text. These use the
real shared view components without fetching repositories or signing files.
They are excluded from Release builds. The development host is Windows, so the
native previews and IPA still require visual verification on Apple hardware.

After installing the IPA, check each tab at default and larger text sizes, push
into a repository and return, open certificate/import/install sheets, swipe Copy
and Delete, select multiple library items, and show/hide the keyboard. Verify
StadiumSync and tvOS artwork still render, and that primary actions remain blue
while destructive controls remain red.
