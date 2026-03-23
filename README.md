# Book Viewer V2

Book Viewer V2 is a clean restart of the original app.

The rule for this repo is simple: do not port old implementation code. Rebuild only the product idea, using lessons learned from the first version.

## Current State

This repo contains a minimal SwiftUI iOS app scaffold with:

- A small library tab with add-book support
- A capture tab that starts from a selected book, supports camera or photo import, and carries a captured page into review
- An editable review screen that shows the captured page and saves draft quotes into the library
- A local OCR handoff that turns the captured page into editable draft quotes before review
- Lightweight local JSON persistence for books and draft state

The app still has no networking, cloud sync, or remote AI extraction. The current goal is proving the save-and-rediscover loop before adding those boundaries.

## V2 Product Scope

The first shipped loop should be:

1. Select a book
2. Capture a single marked page
3. Review the extracted quote immediately
4. Save it
5. Find it again in the library

Anything outside that loop is deferred until the core interaction feels effortless.

## Repo Rules

- Keep this repo app-only. Do not mix in backend, website, or release-marketing code.
- Keep files small and feature boundaries obvious.
- Prefer shallow navigation and explicit flows over clever shared abstractions.
- Add persistence only after the capture and review flow feels correct.
- Add search only after saved-quote readability is strong.

## Build

```bash
xcodebuild -project BookViewerV2.xcodeproj -scheme BookViewerV2 -destination 'generic/platform=iOS Simulator' build
```

## Next Steps

- Tighten the OCR output so it prioritizes the marked passage instead of broad page text
- Add a better empty/manual correction path when OCR misses the quote entirely
- Tighten the book detail and return flow after saving
- Decide whether the first persisted model should stay JSON-backed or graduate to SwiftData
