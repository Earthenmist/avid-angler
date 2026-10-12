# 1.1.0-Release

## Changes
- Catch history records Blizzard's localized subzone for new catches and shows precise locations such as `Feralas - The Forgotten Coast`. Older catches remain zone-only.
- Added optional performance monitoring, disabled by default and controlled from Settings or `/aa monitor`.
- Bounded, copyable reports cover frame hitches, addon operations, startup and reload context, native CPU samples when available, and time outside measured operations.
- Monitoring preferences persist across reloads. Export stops the active recording, and saved reports omit character names and catch details.

## Fixes
- Combined bursts of automatic inventory and toy refreshes into one scan while preserving immediate manual refreshes and action-time eligibility checks.
- Stopped delayed scoring updates from rebuilding hidden score panels; visible score windows and watches continue to refresh normally.

## Known issues
- None
