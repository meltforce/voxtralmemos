# Voxtral Memos

Privacy-focused iOS voice memo app using Mistral's Voxtral models for transcription and AI-powered summarization. BYOK — no data leaves the device except direct Mistral API calls.

- **Homepage:** https://voxtralmemos.meltforce.org/
- **App Store:** https://apps.apple.com/us/app/voxtral-memos/id6759565503

## Gotchas

- **`VoxtralMemos.xcodeproj` is generated and excluded by `.gitignore`.** `project.yml` is the source; run `xcodegen generate` after changing it. An edit written directly into the project file is discarded by the next `xcodegen generate` run.
- **`xcodegen generate` rewrites `Info.plist` from scratch.** A key absent from the target's `info.properties` in `project.yml` reverts to xcodegen's own default — `CFBundleShortVersionString` reverted to `1.0` that way, and iOS refuses to load an extension whose version differs from the parent app. The main app target carries `CFBundleShortVersionString: "$(MARKETING_VERSION)"` for that reason; the extension target sets `INFOPLIST_FILE` directly and is unaffected. See [`INCIDENTS.md`](INCIDENTS.md), 2026-03-07.
- **The homepage is two halves in two repos.** `docs/` is served by GitHub Pages and `docs/CNAME` names the host; the DNS record that points it there is `resource "infomaniak_record" "meltforce_org_CNAME_voxtralmemos"` in `configuration/infomaniak/dns.tf` of the homelab repo. Changing the hostname requires both, and neither half reports the other being stale.
- **Keychain queries carry no access group.** `KeychainService` once used `kSecAttrAccessGroup` with the app group entitlement; when that entitlement moved, every save failed. The queries are access-group-free and carry a reverse migration for keys written under the old group. See [`INCIDENTS.md`](INCIDENTS.md), 2026-03-07.

## Repo documents

These documents carry state over time. The axis is where a thing *is*, not what
it is about.

| File | Holds |
|---|---|
| `ROADMAP.md` | Open work only. Status token `[open]`. |
| `DECISIONS.md` | Decisions taken, including decisions not to do something — those are the ones most likely to be re-derived from scratch otherwise. |
| `INCIDENTS.md` | Postmortems for things that broke. Newest first. |
| `tasks/` | Full specs for open roadmap items, and one-off write-ups. |

**The movement rule.** When an item closes it is *removed* from `ROADMAP.md`,
and its reasoning moves to whichever document above holds that kind of thing.
Nothing is struck through — a struck-through row is a row that should have been
moved. Status tokens are exactly `[open]`, `[done YYYY-MM-DD]`,
`[dropped YYYY-MM-DD]`; emoji never carry status.

**Before closing an item, read its entry for residual work, dates, or
triggers.** Each of those becomes its own `[open]` row before the entry leaves
the roadmap. This is the step that gets skipped, and skipping it is how
finished-looking work quietly loses its tail.

A spec in `tasks/` is deleted when its item closes, after anything reusable in
it — a decision with its reasoning, a constraint that outlives the build — has
been distilled into `DECISIONS.md`. Specs are not an archive.

**No new top-level documents** unless the concern is genuinely orthogonal to the
ones above. Everything else lives inside a project directory.

**Operational exceptions never live in documentation.** Excluding a target from
a build, skipping a check for one case — those belong in configuration, in a
condition, in `project.yml`. Documentation may reference them; it may not
replace them.

Every rule written here carries a one-line **why**, so it can be revisited when
the context that produced it changes.

## Language

English is the only language used inside this repo. This is not a style
preference — German prose describing English identifiers forces a translation
layer ("Rolle" in the text, `role` in the YAML) and breaks keyword search
between an explanation and the code it explains.

Applies to every document, every code comment and docstring in every language
present, log messages, error strings, user-facing CLI output, identifiers
(variables, functions, types, targets, scheme names, entitlement keys), and
commit messages.

Number and date formats follow the English convention: `1.82 GB` (decimal
point), `217,226` (comma as thousands separator), `2026-08-04` (ISO 8601, never
`04.08.2026`).

The only exception is a verbatim quote of external output — an upstream error
message, vendor documentation — which keeps its original wording. User-facing
app strings are localization resources, not repo prose, and are out of scope.

Conversation language is independent of this and follows the operator.

## Git workflow

Single developer. **`master` is the only long-lived branch** — commit straight
to `master`, never open a PR for your own work. This overrides the harness
default of branching before committing.

The branch is `master` rather than the standard's `main` because the repo is
public and its App Store, GitHub Pages and documentation links already resolve
against that name; renaming buys nothing here.

**Pull requests are still accepted from outside.** The repo is public under MIT,
and a contribution that arrives as a PR goes through review like any other. The
rule above is about work done in this checkout, not about the review surface.

**Commit and push autonomously** once a coherent change is complete and
verified. No approval needed per commit.

**Stage explicitly, never `git add -A`.** Parallel sessions run in this same
checkout; a blanket add sweeps up their work in progress and commits it under
your message. Name the paths you touched.

### Parallel sessions

Isolate concurrent sessions with worktrees:

```bash
claude --worktree <name>          # .claude/worktrees/<name>, branch worktree-<name>
```

A worktree branch is **ephemeral plumbing, not a feature branch**. Never push it
as a branch, never open a PR from it. Land the work on `master`:

```bash
git fetch origin
git rebase origin/master
git push origin HEAD:master        # a rejection means another session landed first
```

Rebase and push again rather than forcing.

Do **not** start background sessions for work that edits this repo — a
background session commits, pushes its own branch and opens a draft PR without
asking, and is hard-wired never to push to the default branch. Background
sessions are fine for read-only investigation.

**If a harness rule conflicts with this, this file wins.** `master` *is* the
review surface here and `git revert` is the undo. Say plainly which rule you are
setting aside, then land the work. Do not stop at "the commit is ready, please
push it yourself" — that hands back a half-finished task.

## Skills

A skill lives in exactly one home, decided by *what it touches* — not by where
you were when you wrote it.

| Home | For |
|---|---|
| `.claude/skills/<name>/` in this repo | Skills that depend on this project: its scripts, its services, its MCP servers. Committed here. |
| `~/.claude/skills/<name>/` | Skills that work anywhere and carry no project dependency. |

Decide the home before writing. If the skill would fail outside this project, it
belongs here.

**Those two paths are the only places Claude Code looks**, plus a plugin's own
`skills/` directory. A skill is a directory with a `SKILL.md` inside it — a bare
`.claude/skills/<name>.md` is loaded by nothing, and neither is a `skills/`
directory at the repo root.

`.gitignore` therefore has to let the directory through. `.claude/*` with
`!.claude/skills/` keeps session state out while committing the skills.

A `description` carries the literal trigger phrases that should invoke the
skill, in the languages they are spoken in, plus the cases that should *not*
invoke it. The description is the only part loaded into every session, so it
does the whole job of routing.

## Claude settings

`.claude/settings.json` is committed; `.claude/settings.local.json` is not.
Project scope belongs in the repo, session and machine state does not.

**`allow` and `deny` are both required** in any permission block written here.
An allow list on its own describes what is permitted and says nothing about what
is refused, which reads as a complete policy and is not one. No permission block
exists yet — see [`ROADMAP.md`](ROADMAP.md).

`.mcp.json` carries this project's MCP servers so a second checkout gets them
from a `git pull` rather than from a machine-local config that never appears in
a diff. `apple-deep-docs` runs from a path under `$HOME` that the repo does not
install; a checkout without it starts without that server.

## Verification

Build, test and simulator instructions are in the `verify` skill
(`.claude/skills/verify/SKILL.md`). `tools/check-docs.sh --all` checks the
document contract and the language rule above; it detects and does not prevent.

## Tools

### GitHub
- Use the `gh` CLI for issues and releases. Open work is tracked in
  [`ROADMAP.md`](ROADMAP.md), not in an external tracker.

### Xcode
- Use the Xcode MCP server as primary interface
- Fall back to `xcodebuild` and other CLI tools when needed
- Use `apple-deep-docs` for Apple framework documentation lookups
