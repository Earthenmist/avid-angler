# Changelog

## 2026-09-07 - v1.0.3-Release

### Changes

- Enlarged close buttons throughout the addon.
- Added fishing skill across all expansions in the headers and also the Midnight-only
  Venom display for The Coiled Huntress when it is equipped in the fishing-tool slot.
- Cached each character’s last known fishing levels for unavailable live reads.
- Added optional per-character Venom reminders with dismissible themed toasts.
  Set a threshold beside Disable Soft Icon in General settings; blank or 0
  disables alerts. Dismissed reminders return after another 25% of the
  threshold or on your next login.
- Expansion pages recover automatically when fishing skill data becomes available.

### Fixes

- Fixed the floating fishing button intercepting clicks on its close control.
- Fixed learned fishing expansions sometimes showing as not learned after login.
- Preserved confirmed fishing skills in each character's saved cache, even when
  Blizzard returns incomplete data or another profession's journal is open.

### Known issues

- None currently reported.
