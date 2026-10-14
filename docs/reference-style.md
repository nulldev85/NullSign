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
- Apps source options, repository/app long-press actions, Signer import choices,
  and the signing icon chooser use the same charcoal sheets, grouped cards,
  rounded fonts, inset dividers, and category-color icon tiles. Native file and
  photo pickers, error alerts, and safety confirmations remain system-owned.
- Import from URL uses a branded form with explicit Paste/Clear controls,
  keyboard submission, and inline HTTP/HTTPS validation. Links do not need an
  IPA suffix: redirects and query strings continue to work. Clipboard access
  happens only on a Paste tap, and Cancel starts no download.
- Menu-to-sheet actions run after dismissal rather than a fixed delay. Long
  presses and taps are mutually exclusive on repository and library cards.
  Copy actions show inline confirmation, and version downloads retain source
  provenance for future update checks.

## Verification

Source review covers primary and destructive actions, pushed-page toolbar
backgrounds, card/selection shape alignment, form and sheet surfaces, and iOS 16
API availability. The white-on-primary-blue contrast is above 4.5:1. Decorative
waves and overview symbols are hidden from accessibility and do not intercept taps.

`NullSignThemePreviews.swift` contains isolated SwiftUI component previews for
standard and 320-point phone widths and larger accessibility text. These use the
real shared view components without fetching repositories or signing files.
Import menu and URL-form previews also cover standard and accessibility sizes.
They are excluded from Release builds. The development host is Windows, so the
native previews and IPA still require visual verification on Apple hardware.

After installing the IPA, check each tab at default and larger text sizes, push
into a repository and return, open certificate/import/install sheets, swipe Copy
and Delete, select multiple library items, and show/hide the keyboard. Verify
StadiumSync and tvOS artwork still render, and that primary actions remain blue
while destructive controls remain red.

For build 19, open the Apps add-source sheet, source options, repository/app
long-press sheets, and Signer import/icon menus. Verify quick taps still navigate
and long presses do not navigate. Try Files, Photos, Info, Install, Sign/Re-sign,
Export, Copy, and Delete actions. Test URL import with an empty URL, a malformed
URL, an HTTP/HTTPS link with a query string, a redirect link, keyboard Go,
repeated submit taps, and Cancel/swipe dismissal. Verify only a valid submission
starts one download, and that subsequent imports open a fresh form.
