# Rampage — hit feedback and boss readability

## Current request / boundary
The owner enjoyed v0.4.0 and requested clearer incoming impacts, satisfying successful hits and a clearer explanation of boss damage. This is a new feature iteration, **not publication authorization**. Prior approvals were consumed by v0.4.0. No CurseForge polling/reupload, Discord changes or new level work.

Develop only in `C:\Users\leroy\repos\Rampage-hit-feedback`, issue #10 branch, based on `5ec13435deda1244c9bfbe63735777fe4af2de7b` /v0.4.0. Primary `C:\Users\leroy\repos\Rampage` and its actual anniversary-client junction stay on the release for household play. Preserve the old boss-motion worktree and all release/candidate archives. No forced reload or external SavedVariables editing.

## Bounded design
- Confirmed incoming HP loss produces a short sprite-local reaction, tasteful tint/loss trail and aggregate damage text. Strongest for the local player; other actors restrained. No world-camera/window shake, authoritative movement or hitbox changes.
- Distinguish swing intent from confirmed contact. Exact local host/solo results may say YOU; remote snapshot target losses are TEAM/aggregate, never invented local attribution. Fame is not damage.
- Persistent boss HP with shield/floors-left/exposed/ground/range guidance based on the existing moving-boss helper. Remote guidance is explicitly sampled, not a host rejection acknowledgement. Explain Brawl target priority without changing it.
- Reduced Motion persists through normal addon settings. It removes shake/bounce while retaining useful static damage/health feedback. Every offset/effect resets on completion, hide/combat/KO, stage/session/role and identity changes.
- Bounded queues/pools and delta deduplication. No damage effects for heals/respawn, late joins/reopen, stale/reordered/blackout samples or slot reuse. Measure previous sample age before replacing timestamps; exact2.5s boundary retained.
- Preserve R4 wire and Model/Protocol bytes. Do not create a cosmetic event replication layer, change health/cooldowns or increase the bandwidth budget.

## Existing strengths to retain
Restored windows/explicit draw layers and damaged-floor readability; shared moving-boss hitbox/AI; seven-second telegraphs; default Co-op/explicit Brawl; five-AI/25-actor/40-real-participant caps; spectator immunity; pre-tick combat protection; keyboard/mouse selection across intermissions with all safety releases/no automatic recapture; optional audio default off/mute/deduplication.

## Verification / handoff
Retain all74 release checks plus focused pure-feedback and actual-TOC/UI tests. Run full network simulations despite unchanged wire, separate Lua5.1 grammar from Fengari execution, audit dependencies and verify diff scope. Inspect actual UI before/contact/settled/reduced-motion frames and bounded25-actor pools. Native WoW visuals/focus/taint and real multiplayer remain manual.

New issue/PR and a unique portable head-labelled ZIP only. Verify each archive entry against the checkout and preserve old artifacts. Primary and junction must remain unchanged at final handoff; merely reloading the current install does not load this candidate. Parent independently reviews and the user chooses installation. Fresh explicit approval is required for merge/tag/publication. Unique levels remain deferred.
