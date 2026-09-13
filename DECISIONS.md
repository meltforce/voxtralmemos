# Decisions

Decisions taken about Voxtral Memos, with the reasoning that led to them. One
section per decision, newest first.

A decision belongs here once it has been made — including decisions to *not* do
something, which are the ones most likely to be re-derived from scratch
otherwise. Open work lives in [`ROADMAP.md`](ROADMAP.md); postmortems live in
[`INCIDENTS.md`](INCIDENTS.md).

Structure per entry: **decision**, **reasoning**, **trigger to re-open**, and a
**revisions** log when the decision has changed. A revised decision is edited in
place with the old form recorded under revisions — the entry is not duplicated.

---

## 2026-09-13 — Open work is tracked in the repo, not in Plane

**Decided:** 2026-09-13

**Decision.** [`ROADMAP.md`](ROADMAP.md) holds open work and `tasks/` holds the
specs for items that need more than a row. Plane is not used by this project.

**Reasoning.** Plane no longer exists. `CLAUDE.md` carried a Plane project ID
and instructions to use `mcp__plane__*` tools, and no `plane` MCP server was
configured in any project — the guidance pointed at nothing and would have been
followed by a session that did not check.

**Alternative considered.** GitHub Issues, which the repo already has and which
`gh` already reaches. Rejected for planning work because a roadmap row is
reviewed in the same diff as the change it describes; issues are kept available
for reports arriving from outside.

**Trigger to re-open.** A second contributor, or a volume of incoming reports
that a single file stops serving.

---

## 2026-09-13 — `master` stays, and PRs are not used for own work

**Decided:** 2026-09-13

**Decision.** `master` remains the only long-lived branch and the default
branch. Work done in this checkout is committed straight to it. Pull requests
from outside are still accepted.

**Reasoning.** The standard's `git-solo` module specifies `main`. Renaming would
change a name that App Store metadata, GitHub Pages and documentation links
already resolve against, and buys nothing for a single developer. The PR that
existed (#2) came from a `claude/…` branch opened by the harness, not from a
contributor, so the PR flow was overhead rather than review.

**Alternative considered.** Renaming to `main` and taking `git-solo` verbatim.
Rejected on the cost/benefit above. Also considered declining `git-solo`
entirely and keeping the PR flow; rejected because branch-and-PR with one
developer is the overhead the module exists to remove.

**Trigger to re-open.** A second regular contributor, or a fork that becomes the
primary development line.

---

## 2026-03-10 — CarPlay is prepared in code but not shipped

**Decided:** 2026-03-10

**Decision.** The CarPlay scene delegate, the shared model container and the
`com.apple.developer.carplay-audio` entitlement are in the repo. The feature is
not shipped and not announced.

**Reasoning.** The entitlement is granted by Apple on application, with a stated
wait of 1-2 weeks, and the app cannot appear on CarPlay before it is granted.
Landing the plumbing first keeps the wait off the critical path. Estimated build
effort for the minimal scope is about four developer days; the scope is
recording plus automatic transcription, with no playback, no summaries and no
template selection in the car.

**Alternative considered.** Waiting for the entitlement before writing any code.
Rejected because `VoxtralCore` already carries recording, transcription and the
SwiftData models UI-independently, so the integration was cheap to write and
cheap to keep.

**Trigger to re-open.** Apple grants or refuses the entitlement. A refusal makes
the scene delegate dead code that should be removed rather than kept.

---

## 2026-03-07 — Audio import uses an action extension, not `CFBundleDocumentTypes`

**Decided:** 2026-03-07

**Decision.** Audio import is handled by `VoxtralMemosShareExtension`, an action
extension of type `com.apple.ui-services` with an `NSExtensionActivationRule`
for `public.audio`. It hands the file over through the app group container and a
URL scheme. `CFBundleDocumentTypes` is removed from the main app.

**Reasoning.** Declaring document types put the app icon into share sheets where
the import did not work, Voice Memos among them. An activation rule scoped to
`public.audio` offers the app exactly where it can act.

**Alternative considered.** Keeping `CFBundleDocumentTypes` and filtering
unsupported sources inside the app. Rejected because the icon appears before the
app can filter anything, so the wrong offer is already made.

**Trigger to re-open.** Apple changing how activation rules are evaluated, or a
source that the rule does not reach.

---

## 2026-03-07 — Transcription shows one stable indicator, not progress phases

**Decided:** 2026-03-07

**Decision.** A single spinner labelled "Transcribing" replaces the previous
`StatusBadgeView`, which cycled through Uploading, Waiting and Processing.

**Reasoning.** Transcription is one synchronous `POST` to the Mistral API with
no progress callback, so the phases were driven by a timer rather than by the
request. They also reset when the view reappeared, which made a long
transcription look like it had restarted.

**Alternative considered.** Estimating progress from audio duration. Rejected
because an estimate that is wrong in the visible direction is worse than no
estimate.

**Trigger to re-open.** Mistral exposing a streaming or progress-reporting
transcription endpoint.
