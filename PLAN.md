# Rampage — FOUR MORE BOSSES!

## Vision
A cooperative, opt-in Toast raid-break arcade: original expressive monsters flatten a shared city and four silly bosses. Keep raid controls safe, joining simple, and changes small enough to playtest quickly.

## Current delivered scope
- Original first playable: solo, shared destructible towers, move/climb/punch, four bosses, personal fame and host-authoritative party/raid lobbies.
- Issue #4 iteration: **25 active / 40 total**, explicit Spectate and role switching, late join with bounded R2 chunked snapshots, one-click Join Game / Host & Start with visible-window discovery.
- Explicit keyboard PLAY capture, WASD/arrows/Space repeat, Escape/focus/chat/hide/leave/combat releases, physical-key reconciliation, compact mouse fallback; no binding changes.
- Warm arcade city, varied stepped creature geometry, local highlight, 25-player hover chips/overlap offsets, boss HP/shield, pooled particle/destruction/stage/victory effects, fit-to-screen scale.
- Optional default-off external BlasterMaster role accessor; local throttled cues and spectator-major-event mode, no bundled game audio or global volume edits.

## Implementation and tests
- [x] Separate deterministic model, protocol, input, sound, UI and WoW adapter modules.
- [x] Preserve actual roster/host/session/generation/sequence authority and bounded packet/queue/fragment state.
- [x] Exercise 25 actors + 15 spectators in a finite-budget 40-node broadcast simulator with loss/reordering, reconnect, four bosses, replay and combat pause.
- [x] Integrate strict input/audio/UI lifecycle mocks and fixed frame/texture pools.
- [x] Lua 5.1 grammar checks and Fengari execution; no native VM proof implied.
- [x] Export and inspect actual-UI mock geometry scenes, not separate concept art.
- [ ] Actual TBC input propagation/taint/taskbar focus and visual scale verification.
- [ ] Real two-client baseline, then 25-player raid performance/play-feel verification.
- [ ] Actual local sound playback/remapping and mute verification.

## Important tradeoff
The traffic-safe R2 host currently sends complete worlds every **1.25 seconds**. Visual animation is smoother, but remote authoritative input feedback is not fast-action-game latency. Measure this with the guild before tuning the wire format/cadence or adding prediction. No claim that the simulated 40-node traffic proves Blizzard transport behavior.

## Deliverables and gates
Keep the original `51b6b6d` candidate untouched for rollback. Extend unmerged PR #3 with issue #4, a distinct tested playtest ZIP, hash/manifest verification and clear native-test steps. No forced client reload/SavedVariables edits. No merge/release until `!ship`; CurseForge project ID deferred in issue #2.

## Post-playtest priorities
1. Fix actual native focus/taint/rendering bugs first.
2. Measure/tune remote response cadence within a realistic addon traffic budget.
3. Refine monster animation, stage variation, optional original sound cues and tiny cooperative mechanics based on guild feedback.
4. Host migration, hazards, rich progression and complex matchmaking remain out of this quick iteration.
