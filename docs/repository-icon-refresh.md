# Repository icon refresh

## What's new

- Repository icons now follow the latest source feed when you refresh, including the icons beside All Apps.

## Cause and change

NullSign saved the repository icon URL when a source was added. Both the
repository row and the All Apps icon stack preferred that saved URL over the
icon URL in a successfully refreshed feed. An image already cached at the old
URL could therefore remain visible even after the feed supplied a new URL.

Both views now prefer the loaded repository's current icon URL. The saved URL
remains the fallback while a feed is unavailable. No saved sources, imported
apps, certificates, or image caches are deleted.

The public AppSource feed and both its original and versioned icon URLs were
checked: they serve the supplied dotted N artwork, with SHA-256
`760c2e66e9a5214bd698822370df0737f639d003ff1011f73e85c390868b8253`.

This app change is prepared as NullSign 1.4.9 (39). iOS build and device
verification remain pending. On an older installed version, re-adding only
the repository loads the current icon URL; a normal refresh retains the saved
URL preference.
