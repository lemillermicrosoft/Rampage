# QA — first playable FOUR MORE BOSSES MVP

## Evidence boundary

**Automated checks were run on 2026-10-28 on Windows, Node v24.18.0 / npm 11.16.0. No actual WoW/TBC client or two real game accounts were used for this implementation's verification.** This is a ready-for-playtest MVP, not a claim of in-game compatibility, taint safety or visual approval.

Fengari **0.1.5 uses Lua 5.3 semantics**. The test bootstrap supplies the Lua 5.1-style global `unpack` for that runner. Separately, `luaparse@0.3.1` parses every runtime/test Lua file with `luaVersion: '5.1'`. No native Lua 5.1 executable was available. Neither the parser nor the mocks verifies all differences in WoW's embedded VM/API.

## Actually executed

| Check | Result |
| --- | --- |
| `npm ci --ignore-scripts --no-fund --no-audit` | Reproduced exact lockfile install, exit 0 |
| `npm test` | **36/36 passed**, exit 0 |
| Lua 5.1 grammar checks within test run | All **4 TOC runtime files + 3 Lua test files** parsed |
| `npm run check:lua51` | **7/7 files passed**, exit 0 |
| TOC manifest check | All runtime entries exist; `Interface: 20506` |
| `git diff --check` | No whitespace errors, exit 0; standard Windows LF→CRLF notices only |
| `npm audit --audit-level=moderate` | **0 vulnerabilities**, exit 0, after pinning Fengari 0.1.5 |
| Full two-client simulated playthrough | All four bosses, both players scoring, identical shared victory, **2380 total fame**, synchronized replay |
| Largest configured snapshot fixture | **103 bytes**, under 255; every simulated emitted packet checked at send |
| Fixed mocked UI allocation fixture | **30 frames / 144 textures / 15 font strings**, unchanged after 100 renders |

An initial audit of Fengari 0.1.4 found a vulnerable development-only `tmp` dependency. The runner was deliberately pinned to **0.1.5** instead; a subsequent audit found zero vulnerabilities. There are no npm/runtime dependencies loaded by WoW.

### Seven deterministic model tests

- Explicit lobby/start/replay; four-player cap.
- Ground bounds; tower-only climbing; no sideways walking while elevated; bad action/slot rejection.
- Two monsters damage the **same** floor; tower collapse drops both safely; per-player scoring.
- Boss shield, exposed-boss reach restrictions and city scoring.
- All four complete stages, two-second transitions, shared victory, exact total and fresh replay.
- Pause blocks both actions and intermission progression.
- Removing/adding a player does not reset city damage.

### Twenty-two protocol/simulation tests

- Explicit discovery/join; unsolicited membership cannot auto-join.
- Two-client shared floor destruction, positions and personal-score convergence.
- Actual roster-sender checks; foreign host, wrong session/member token rejected.
- Duplicate/out-of-order and too-fast actions cannot double-apply.
- Strict snapshot bounds/shape; stale and malformed snapshots are rejected without partial mutation.
- Late join into a partly destroyed stage 3 with existing host score.
- Four-player cap and full fifth client's bounded timeout.
- Leave/rejoin with a fresh token; old input and delayed removal revision rejected.
- Roster/group departure and no host migration.
- Silent host and silent guest timeouts; explicit host end/new session.
- Guest combat blocks input; host combat pauses everyone; liveness survives 21 seconds of combat.
- Lost snapshot heals with a newer full snapshot.
- Outbound/inbound token-bucket bounds, fixed/coalesced queue and maximum message size.
- Actual roster membership names and extreme configured snapshot values.
- Malformed/fuzz packets do not crash or grow game/queue state.
- Prior-stage/replay and impossible future-snapshot input references rejected.
- Lost membership heals through join retries without duplicate players.
- Periodic membership cannot mask a stalled world-state stream.
- Eight-lobby cache cap and expiry.
- Full two-client four-boss victory and replay.
- Solo works without a group or transport; combat cannot start it.

### Seven TOC / mocked WoW tests

- Real TOC load order, initialization events, version, saved-variable sanitation and no forced window.
- Solo slash flow, original shape pools, mouse buttons, visible damaged/destroyed tile state and local best.
- Combat hides/disables controls; only a previously open window is restored.
- Stable frame/texture/font pool sizes after repeated rendering.
- Wrong prefix/distribution/outsider rejected; same character names on different realms stay distinct.
- Host/Start/Leave slash flow; PARTY then RAID addon transport; host combat pause.
- Explicit join, group-departure reset, local help and position persistence.

Mocks intentionally fail on unknown APIs and on public chat, global/override keybinds or sound calls. They **do not** render pixels, emulate protected actions/taint, model server transport throttling, or prove that every API exists in the exact TBC client build.

## Real TBC 2.5.6 checklist — NOT PERFORMED

Use the same build on two or more clients. Record client build/locale, errors, expected/actual result and screenshots when reporting a failure.

- [ ] **Install/load:** enable addon, confirm Interface 20506, `/reload`, inspect Lua errors. No window opens by itself and no chat/sound is emitted.
- [ ] **Solo rendering:** `/rampage solo`. Window drag/clamping/close/reopen at normal and small UI scales; check fonts, scoreboard, floor alignment, boss placement, horn colors and fist flashes. Hover/click controls while ordinary WoW bindings remain unaffected.
- [ ] **Solo gameplay:** walk onto a tower, climb to top, punch twice per floor, descend; see cracks, missing floors and rubble. Destroy all three towers; punch exposed boss from middle ground lanes. Finish all four bosses, see shared-victory text, replay and verify personal best persists through `/reload`.
- [ ] **Two-client party:** A Host, B Find/Join, A Start. Each damages the same floor once: exactly one floor breaks and each earns 10. Compare positions, boss HP, damage, personal scores and shared victory. A non-joining third client must never have a window forced open.
- [ ] **Raid / multiple lobbies:** repeat after party→raid conversion; different hosts discover/select the intended lobby. Verify true cross-realm canonical sender behavior if available. Ordinary PARTY/RAID only; instance/battleground categories remain unsupported.
- [ ] **Late join:** A starts/advances a stage before B joins. B sees existing city/boss/score state, starts at zero and can immediately contribute after synchronization.
- [ ] **Cap/retry:** fill four slots, attempt a fifth (bounded timeout); leave one and retry. No displaced players or unbounded messages.
- [ ] **Combat:** while visible, A enters combat. A's window hides and B sees paused state; no one can change the city. Return out of combat and resume. Repeat with only B entering combat: B's controls unavailable, A may continue. Enter combat while already hidden: no surprise window after combat. Test a drag interrupted by combat.
- [ ] **Departure/reload:** guest Leave and group kick/disband; host Leave and disconnect/reload. Check explicit end or documented 15s/20s timeout behavior; no migration/automatic rejoin. Rejoin explicitly and verify old state/input cannot leak into a new session.
- [ ] **Real transport:** moderate/high latency and alongside normal raid addons. Confirm normal addon traffic does not trigger server throttle warnings; dropped clicks may require a repeat, but later snapshots converge. Check no public RAID/PARTY/GUILD chat is generated.
- [ ] **Taint/protected actions:** use normal spell, movement, targeting and raid controls before/during/after play and combat. Inspect the client's taint/error tooling; no protected actions should be touched by this addon.

## Known MVP limits

- Four participants per lobby; eight visible lobbies; no host migration.
- Same basic city layout and encounter pattern across four named/color-tinted stages; increasing boss HP. No health/hazards/death, audio, elaborate animation or art polish yet.
- Ground-only horizontal movement; click-only input. No hold-to-repeat, keyboard/gamepad or client prediction.
- Full-state rendering up to 4 Hz plus transport latency, not a precision action-game network loop.
- Only normal party/raid addon channels. No battleground/instance-chat transport, friend whispers or guild transport.
- Host is trusted authority, not a competitive anti-cheat server. Lost inputs are not retried. A full/unreachable join uses a generic 12-second timeout.
- Team fame includes current participants only; explicit leavers take their score out of the team total. Local personal best remains.
- Window is a fixed 720×610 layout; exact UI-scale/text/locale behavior awaits the manual pass.
- CurseForge publication, release, merge and PR ownership remain outside this implementation pass.

## Final verification

Run `npm ci --ignore-scripts`, `npm test`, `npm run check:lua51`, `npm audit --audit-level=moderate` and `git diff --check` from the repository. The test runner exits nonzero on any failed assertion or Lua 5.1 parse error. This document distinguishes those executed automated results from the unchecked in-game checklist above.
