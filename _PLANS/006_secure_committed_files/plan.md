# Plan 006 — Secure committed files

**Status:** **Deferred** (Rob, 2026-11-03). Don't build until Rob reopens it.
**Covers:** keeping personal and machine-specific data, and anything secret, out of git and off GitHub.

---

## What we found (2026-11-03)

- Rob's macOS account name is in files committed in `9e29532` ("added cue points and hardware support…"):
  - `macos/Flutter/ephemeral/*`: 5 files Flutter regenerates on every build, with absolute local paths.
  - `packages/*/build/`: 24 test-cache and asset files, including 47 MB `.dill` test caches.
- `9e29532` is pushed to `origin/feature/midi_hardware_plus_crossfader_via_audio`. It is **not** on `sanctuary` (checked with `git grep` on `origin/sanctuary`).
- `.vscode/` was never committed (checked the whole history).
- No passwords, tokens or keys were found. The only exposure is the account name in local paths.

## Already done (uncommitted at the time of writing)

- `.gitignore`:
  - `/build/` became `build/`, so build folders are ignored at any depth.
  - Added `**/Flutter/ephemeral/` and `.vscode/`.
- `git rm --cached` on `packages/*/build/` and `macos/Flutter/ephemeral/`. The files stay on disk.

That stops new leaks, but the old commit still holds the files.

## Deferred work

1. **Clean the history before merging.** Rewrite `9e29532` and the later commits on the feature branch so the files never existed in them, then force-push the feature branch only. Alternative: squash-merge the PR into `sanctuary` and delete the feature branch afterwards.
   - Never rewrite or force-push `sanctuary`.
   - GitHub may keep the old commit reachable by its ID for a while. It can be removed for good only through GitHub Support.
2. **Scan the whole repo history** for user names, absolute paths, emails, tokens and keys, for example with `gitleaks detect` and `git log -p | grep -E '/Users/|/home/'`.
3. **Catch leaks automatically:**
   - **A CI step** in "Test and build" that fails a PR when a committed file contains an absolute home path (`/Users/<name>/` or `/home/<name>/`) or a secret pattern. Candidates: gitleaks, or a small grep script in `tool/`.
   - **An optional local pre-commit hook** with the same check, so problems are caught before a push.
4. **Review the `.gitignore` files:** a root-level review against Flutter's current template, including per-platform folders such as `macos/`, `ios/` and `android/`.
5. **Commit metadata:** consider GitHub's noreply email address for commits if Rob prefers not to publish his email.

## Done when

- No history reachable from any branch contains personal paths or secrets.
- CI blocks a PR that adds them.
