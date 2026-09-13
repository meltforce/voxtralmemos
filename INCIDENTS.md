# Incidents

Postmortems for things that broke. One section per incident, newest first.

Add an entry after fixing something that was not obvious — the kind of failure
where the useful question six months later is "have I seen this before?". Skip
routine config changes, dependency bumps, and one-line typos.

Structure per entry: **symptoms** (what was visible), **root cause** (concrete:
component, version, why), **fix** (what changed), **lesson** (one line,
actionable).

---

## 2026-03-07 — The extension did not load, because `xcodegen generate` reset the app version

**Symptoms.** The action extension did not appear in the share sheet. The app
itself built, installed and ran normally, and the extension target reported a
successful build — nothing in the build log named the extension as the problem.

**Root cause.** `xcodegen generate` writes `Info.plist` from scratch on every
run, from the target's `info.properties` in `project.yml`. Any key absent there
takes xcodegen's own default, and the default for `CFBundleShortVersionString`
is `1.0`. The main app target did not carry the key, so every regeneration
reset the app's marketing version to `1.0` while the extension target, which
sets `INFOPLIST_FILE` directly, kept the real one. iOS refuses to load an
extension whose version differs from its parent app, and it reports that by
omitting the extension rather than by raising an error.

**Fix.** `CFBundleShortVersionString: "$(MARKETING_VERSION)"` added to the main
app target's `info.properties` in `project.yml`. Verified by regenerating the
project and reading the built `Info.plist` of both targets, which is the real
failure path — checking `project.yml` alone would not have caught it, because
`project.yml` was never the file that was wrong.

**Lesson.** A generated file is not evidence of what the generator was told; for
xcodegen, read the built `Info.plist`, not the spec.

---

## 2026-03-07 — Keychain saves failed after the app group entitlement moved

**Symptoms.** Saving the Mistral API key failed. The keychain query returned an
error rather than writing, and the app had worked with the same code before the
share extension was removed.

**Root cause.** `KeychainService` passed `kSecAttrAccessGroup` naming the app
group. An access group is only usable while the entitlement granting it is on
the target; the entitlement left with the share extension, so every query named
a group the app no longer had.

**Fix.** The access group was removed from all keychain queries, and a reverse
migration reads keys still stored under the old group so an existing
installation does not lose its API key. The app group entitlement returned later
with the action extension (2026-03-07, `2f6882e`) — the keychain queries stay
access-group-free regardless, because they do not need to be shared.

**Lesson.** A keychain access group is a dependency on an entitlement; removing
an extension removes entitlements from the parent app too.
