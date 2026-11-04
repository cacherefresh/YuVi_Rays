# Plan 005 — feature/write-perm_storage-savefeature

**Status:** **Deferred** (Rob, 2026-11-03). Don't build until Rob reopens it.
**Branch name when started:** `feature/write-perm_storage-savefeature`
**Covers:** the two features that **write** data and need storage that lasts. Everything that only reads, such as Serato cue import and hot cues in memory, was split out and built in plan 002.

---

## The two parts

- **A. Track metadata cache (FR-008).** Remember what the app learns about each track (detected BPM, hot cues, later key, beat grid), so a track loads instantly next time without touching the file.
  - **Storage: IndexedDB**, the browser's built-in database: large and lasting, for this site only. Rob suggested a permanent cookie, but a cookie holds only about 4 KB, is sent with every request, and Chrome keeps it for at most 400 days. IndexedDB has none of those limits.
  - **Key: a hash of the file's bytes** (SHA-256 through the browser's built-in crypto API), so a renamed or moved file keeps its data.
  - **YAML export and import** in Settings, matching the MIDI profile format, for backups and moving to another machine. One YAML document holds all tracks.
  - Ask the browser to keep the data even when disk space runs low (`navigator.storage.persist()`).
  - Suggested shape: a reusable package `yuvi_track_library`, with a storage contract (`TrackLibraryStore`), an IndexedDB implementation, and an in-memory one for tests.

- **B. Hot cue save, "save to the track".** Keep hot cues between sessions, and optionally write them back into the MP3 so Serato sees them.
  - **Step 1: save in the browser.** Hot cues go into part A's store under the same file hash. On load, saved YuVi cues win over Serato cues read from the file.
  - **Step 2, optional and behind a setting: write back to the MP3.** Uses Chrome's File System Access API, so a file must be opened with `showOpenFilePicker` to be writable. Encodes a `Serato Markers2` GEOB frame and rewrites the ID3 tag.
    - **Risk:** a wrong encoder can damage a DJ's Serato library. Before enabling it: byte-for-byte round-trip tests on real Serato files, and a backup copy of the original file.
    - Chrome and Edge only. Other browsers fall back to step 1.
  - **Alternative:** an "Export MP3 with cues" download, which writes a new copy and never touches the original.

## Dependencies

- Plan 002's read side, now built: the `HotCue` model, the `Serato Markers2` decoder, and the ID3 reader in `yuvi_track_metadata`.
- Plan 004's detected BPM, which part A will store.

## Open questions, for when this reopens

1. Is step B2 (write-back) wanted at all, or are A and B1 enough?
2. Should the YAML export include detected BPM, or only things a person set, such as cues?
