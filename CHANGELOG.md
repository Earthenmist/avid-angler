# Changelog

## 2026-09-10 - v1.0.8-Release

### Changes

- Selected unusable fishing items now show a skip notice while fishing continues, preserving the selection for when it becomes usable.

### Fixes

- Recheck character requirements and item usability before offering bag items as the next fishing action.
- Pole lures now target the equipped profession fishing rod, or a main-hand fishing pole when no profession rod is equipped, without a manual rod click.
- Check temporary enchants on the targeted rod rather than an unrelated main-hand weapon. Missing rods or unreadable enchant data safely skip lure application.

### Known issues

- None listed.
