# FERTA upgrade checklist

## Existing implementation audit

- [x] Flutter farmer shell, home, soil testing, farms, history, chat, profile, and English/Tamil language selection exist.
- [x] FastAPI reading, validation, conservative fertilizer advice, and grounded assistant endpoints exist.
- [x] SQLite stores farms, fields, readings, crop selections, and chat; readings survive backend failures.
- [x] Simulator is clearly identified; no sensor conversion or BLE protocol is fabricated.
- [x] Local calendar task CRUD, completion, month/week filters and reminder scheduling now use the device SQLite store and local notifications.
- [ ] Notifications screen only reports integration status; there is no notification history/preferences.
- [x] Terrace gardening beginner guide, saved preferences and checklist added; crop specifics remain general pending reliable regional sources.
- [ ] Live expert dashboard remains unavailable; an explanatory support page identifies missing backend role/request/appointment services.
- [ ] Crop estimates are separate from market-demand data; no verified market feed exists.
- [ ] UI already has a nature palette, shared cards, and basic transitions; not every screen is redesigned or animated.

## Implementation plan

1. Add local-first persistent calendar tasks and connect local notification scheduling.
2. Add an honest market-demand unavailable experience and an India-aware beginner terrace guide with locally saved checklist/preferences.
3. Add accessible navigation to these experiences; clearly distinguish expert workflow limitations from real multi-user requests.
4. Update integration notes and tests; run analyzer, Flutter/backend tests, and Android debug build where toolchains permit. **Done:** analysis clean, Flutter tests passed, backend tests passed, debug APK built.
5. Review changes and git status; commit only if verification succeeds and the worktree contains only this task's changes. **Done:** committed as `1d77ebd`; push was rejected by automatic review pending explicit destination/payload approval.

## Status

- Done: local calendar task workflow, terrace guide/checklist, demand-data unavailable state with saved crop shortlist, and integration notes.
- Verified: analyzer and tests pass, APK builds, and the reviewed worktree is clean.
