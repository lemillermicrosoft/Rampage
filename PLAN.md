# Rampage — FOUR MORE BOSSES!

## Vision
An opt-in cooperative city-smashing arcade game for <Toast> raid downtime in TBC Classic 2.5.6. Celebrate the guild's rise to fame with monsters, destructible towers, silly fictional bosses, and the refrain “just FOUR MORE BOSSES!” Take inspiration from Rampage's climb-and-smash play, using original geometric art, names, and jokes rather than copied assets or branding claims.

## Scope (MVP)
1. A movable /rampage window with solo practice and explicit raid/party Host, Join, Start, Leave controls. No automatic invitations or forced windows.
2. Simple move/climb/punch gameplay: original blocky monsters demolish a shared city, with visible damage and punch feedback.
3. Exactly four short stages with fictional boss encounters, shared victory, personal score, and Toast/fame flavor.
4. Host-authoritative cooperative state using bounded, throttled addon-channel messages; group-member validation, duplicate/out-of-order defense, join/rejoin synchronization, timeout and group-leave handling.
5. Raid-safe defaults: no public chat/sound spam, no global keybindings, and no active game controls during combat. Local saved best score/settings only.

## Technical Tasks
1. Scaffold from SwingPulse's repository tooling; Interface 20506 verified against SwingPulse.toc.
2. Separate a deterministic Lua 5.1-compatible game model from communication and rendering.
3. Implement bounded protocol and roster/session validation; keep each message below WoW's 255-byte limit.
4. Implement a readable original-geometry arcade UI and explicit mouse controls; keyboard capture optional and scoped only to focused play.
5. Add host/client adapters, combat safety, slash command help, and persistence.
6. Exercise gameplay and simulated multiplayer via a headless Lua runner; document the real-client smoke test separately.

## QA and Validation
- Load all TOC files under Lua 5.1-compatible runtime with mocked WoW globals.
- Move, climb, punch, demolish towers, defeat each of four bosses, finish and restart.
- Simulate at least two clients: discover, join, shared score/state, late join, duplicate/stale/foreign packets, rate limit, host disappearance and roster departure.
- Verify message lengths, bounded player count, timers and frame allocation; no generic raid chat writes.
- Manually verify two actual TBC clients in the same raid, combat hides/disables controls, UI geometry, and input release. Mark unperformed checks honestly.

## Post-MVP Ideas
- More monster silhouettes, animation, optional sound effects, hazards, cosmetics, and polished pixel art.
- Raid-night records and more Toast in-jokes after the guild tries the first slice.
- Host migration and larger lobbies only after basic networking is proven.

## Deliverables
- GitHub repository, working local WoW development junction, playable feature PR, test evidence, and playtest instructions.
- CurseForge project ID deferred at deehoc's request. No release or merge until explicit !ship.
