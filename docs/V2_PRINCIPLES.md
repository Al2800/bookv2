# V2 Principles

## What We Learned From V1

- The product is simple, but the interface is the product.
- Large tabs and oversized design-system files hide the real user journey.
- Shipping every surrounding feature too early makes the core flow harder to judge.
- Reuse pressure creates accidental architecture; a restart only works if we resist porting.

## Design Constraints

- One repo, one app.
- Two primary surfaces: Library and Capture.
- Review is part of Capture, not its own product area.
- Book detail exists to read saved quotes, not to manage the entire system.
- Every screen should make the next action obvious.

## Architecture Constraints

- Start with plain Swift structs and one observable store.
- Keep services out until a real external boundary exists.
- No speculative abstractions for export, sync, subscriptions, collections, or onboarding.
- When a feature is not in the first-loop scope, document it instead of scaffolding it.

## First Real Milestone

The first milestone is not "camera works." It is this:

- A user can add one book
- Capture one page
- Correct one extracted quote
- Save it
- See it in the library immediately

If that loop is not smooth, nothing else should be added.
