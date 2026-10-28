# Rampage — FOUR MORE BOSSES!

## Vision

An opt-in cooperative city-smashing arcade game for <Toast> raid downtime in TBC Classic 2.5.6. Celebrate the guild's rise to fame with monsters, destructible towers, silly fictional bosses, and “just FOUR MORE BOSSES!” Take inspiration from climb-and-smash play, using original geometric art, names and jokes rather than copied assets or branding claims.

## First playable scope — implemented

- [x] Movable `/rampage` window; solo practice; explicit party/raid Host, Find, selected Join, Start/replay and Leave. No automatic invitations or forced windows.
- [x] Four-player cap including host; multiple independent lobbies within a normal group.
- [x] Deterministic Lua model: ground movement, tower climbing, two-hit destructible floors, shared collapse, shielded/exposed boss and per-player fame.
- [x] Exactly four short fictional boss stages, two-second transitions, shared victory and replay. Same basic city pattern; increasing boss HP keeps the first slice coherent.
- [x] Original geometric monster/boss/tower shapes, colored personal score labels, punch flashes, cracks and rubble. No copied art/audio or runtime library dependencies.
- [x] Bounded host-authoritative protocol: actual group roster identity, session/member correlation, full snapshots, revisions, sequence/duplicate/stale-stage checks, packet bounds, coalescing and rate limits.
- [x] Explicit late join with current city/score synchronization, retried join, keepalive, timeouts, group departure and host end. No migration.
- [x] Mouse-click controls only: no keyboard capture/global bindings, public chat/sound spam, protected actions or combat automation.
- [x] Combat hides local UI and blocks actions; host combat pauses shared model/transitions while network liveness continues. No surprise post-combat window if it was already hidden.
- [x] Saved local personal best and window position only.

## Architecture / existing-options preflight

This user explicitly requested a custom WoW minigame. The MVP uses existing WoW frame/texture/addon-message APIs rather than pulling in a UI/network framework. Original rectangles are sufficient for the first playable. Small pure Lua modules make the rules and transport independently testable:

1. `Model.lua` — deterministic rules, four bosses and scores; no WoW dependencies.
2. `Protocol.lua` — injected clock/transport; bounded four-player host/client state machine.
3. `UI.lua` — fixed shape/frame pools and discrete mouse controls.
4. `Rampage.lua` — WoW identity/roster/events, transport, combat gate, slash commands, persistence.

Existing development-only parser/runner packages were preferred over a bespoke Lua interpreter: exact-pinned `luaparse@0.3.1` and patched `fengari@0.1.5`, with lockfile and ignored `node_modules/`. Runtime has no npm dependency. See `docs/PROTOCOL.md` for wire format, trust boundary, budgets and recovery.

## Verification — completed automatically

- [x] TOC manifest exists and loads in order under API mocks; Interface **20506**.
- [x] Separate **Lua 5.1 grammar validation** for four runtime and three Lua test files.
- [x] **36 passing tests**: seven game rules, twenty-two protocol/network simulation, seven mocked WoW/TOC/UI smoke cases.
- [x] Complete deterministic solo and two-client four-boss playthroughs, exact total **2380 fame**, shared victory and synchronized replay.
- [x] Cooperative same-floor damage, independent personal scores, late stage-3 join, cap/full join, leave/rejoin and roster departure.
- [x] Foreign/forged/stale/malformed/duplicate/rapid packets; stale-stage input; queue/rate/lobby bounds; lost state/membership; host/guest timeouts.
- [x] No forced UI, input/combat gates, canonical same-name/different-realm identities, bounded addon-channel sends, saved best and constant frame/texture/font pools.
- [x] Development dependency audit clean after updating the initial runner pin to 0.1.5.

**Important:** Fengari executes **Lua 5.3 semantics**, not native Lua 5.1 or WoW. The Lua 5.1 parser is a separate syntax check. Mocks are not proof of actual TBC APIs, rendering, taint safety or real transport behavior.

## Before calling it in-game verified

- [ ] Perform the real TBC 2.5.6 solo/UI/combat/taint checklist in `QA.md`.
- [ ] Perform two real clients in party and raid: shared damage/victory, late join, timeout/reload/departure and combat pause.
- [ ] Check UI scale/locale, actual addon-message throttling alongside raid addons, and ordinary movement/spell bindings.
- [ ] Capture actual playtest feedback and iterate on responsiveness/readability before broad release.

## Delivery boundaries

- Feature tracked in GitHub **#1**, branch `feat/issue-1-four-more-bosses`.
- This implementation pass makes a local conventional commit; parent owns push/PR coordination.
- No workflow/release-script, installed-skill, `.claude`, `.agent`, `CHANGELOG`, or CurseForge configuration changes.
- CurseForge project ID/publication remains deliberately deferred in **#2**. No release or merge without explicit approval.
- No Discord messaging or access/allowlist changes; request originated in WebChat.

## Post-MVP ideas

More distinct boss patterns, safe hazards, feedback animation, monster silhouettes, optional locally controlled sound, cosmetic unlocks and more Toast in-jokes. Larger lobbies, host migration, alternate transport and richer synchronization only after the simple four-player loop is proven in actual clients. No expansion of scope should precede the manual safety/playtest pass.
