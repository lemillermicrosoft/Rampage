# Rampage — three-second warnings and focused control polish

## Request/boundary
Owner Oct30 13:59 approved v0.5.0 publication FIRST, then requested boss waits of3s maximum, better radio/control visuals and alignment. Publication completed before this new issue13 branch. This is a new isolated candidate from `c0f906d2b13382c4414518a53304d6f637c7090a`, not an extension of merged PR11.

Worktree: `C:\Users\leroy\repos\Rampage-fast-windup`, branch `feat/fast-windup-controls`. Primary v0.5.0, its unrelated untracked Explorer cache, old branches/packages and the frozen installed b98c93c candidate remain untouched. No bump/tag/merge/CF upload, forced reload, SavedVariables or other-PC changes. Parent independently reviews and coordinates any later install. Blizzard assets/skin-toggle, unique levels and AFK dialog are deferred.

## Design
- Actual model windup3s, patrol3s, impact0.5s, recovery3s:9.5s total. Locked target/origin, damage once, shared moving hitbox, ordinary HP/damage/cooldowns and pause clocks remain.
- R6 is an explicit simulation-semantics boundary; old R5 clients reject rather than silently reconstructing another timing model. World/chunk formats and all safety caps stay fixed.
- One bounded early full-world snapshot request on real warning onset. Retain partial-world completion and existing queues/priorities. Retry capture as the pending world drains, without discarding fragments or adding separate hazard authority. No arbitrary-loss fairness promise.
- Dodger avoids at2.5s remaining versus2s for other profiles, subject to each normal cadence. No invulnerability/extra damage/teleport.
- Original segmented Mouse/Keyboard controls with separate selected marker/fill/border and consistent hover/pressed/disabled geometry. Oct30 15:34 correction: fresh default Keyboard, valid saved Mouse/Keyboard retained; preference can change idle/watch/lobby with no join/action/capture. Separate status distinguishes preference from active capture. Only explicit accepted Join may activate preferred Keyboard; denial/Leave/safety releases preserve preference and remain inactive. Stage-persistence semantics retained.
- Focused shared alignment for header/actions/selector, crew/localHP and footer baselines. Keep original city windows, hit feedback, Info/Settings and ReducedMotion. No fullscreen or native-skin overhaul.

## Finite verification
Retain/adapt all174 baseline tests. All four bosses/all legal positions, real3s warning and9.5s cycle, once-only impacts, pause/serialized/checkpoint clocks, fair AI progress. Actual healthy two-client phase-varied human reaction/dodge matrix and explicit >3s blackout limitation. Full40-node budget/loss/recovery and delayed vote/rejoin certification remain required. Source-derived matched before/after PNGs and watch/fighter/solo/info/settings/lowHP/longnames; fixed allocations and no clipping assertions. Native rendering/input/taint/livePARTY/RAID remain manual.

Settle ownership, hash all runtime/TOC/tests before final full npm test and compare afterward. Run separate Lua5.1 parser, locked npm ci, audit and diff. Commit/push new PR closing issue13; package unique head-labelled ZIP under `artifacts/rampage/fast-windup/` and verify every entry/hash. Deliver to parent, not directly install/publish.
