# QA — keyboard / 25-player polish candidate

## Evidence boundary

The requester supplied an actual WoW screenshot of **the original four-player MVP** running solo at stage 3/4 with 1,150 fame. This is evidence of original solo loading/play, not proof of this new iteration's keyboard, graphics, audio or raid networking.

**This iteration was checked on Windows with Node v24.18.0, Fengari 0.1.5 (Lua 5.3 execution semantics), and luaparse 0.3.1 (separate Lua 5.1 grammar). No native Lua 5.1 runtime, real 25-player raid, 15 real spectators, native keyboard routing/taint or actual audio playback was verified.**

## Executed automated checks

- `npm test`: **37/37 passed** — 8 model, 17 protocol, 12 strict WoW/UI/input/audio mock checks.
- `npm run check:lua51`: **9/9 files parsed** (6 TOC runtime files and 3 Lua suites).
- `node tests/run.cjs --suite=wow`: **12/12 passed** independently after integration fixes, including missed key-up without a window-focus helper and Meta-key release.
- `git diff --check`: clean (Windows LF/CRLF notices are not failures).
- `npm audit --audit-level=moderate`: zero vulnerabilities in pinned test dependencies.
- Actual UI mock export: `node tests/ui-preview.cjs --scene <scene> --output docs/previews/mock-<scene>.svg`; solo, raid, boss, victory, spectator scenes generated. SVGs rasterized with an isolated review-only resvg helper and visually inspected. Runtime does not depend on it.
- Runtime pool after **500 animated 25-player renders**: **93 frames / 1,190 textures / 83 font strings**, no frame/texture/font growth; 72 recycled effect particles.

The test runner supports `--suite=model`, `--suite=protocol`, and `--suite=wow`. Full protocol tests are intentionally heavier than syntax checks because every broadcast reaches the 40-node simulation. Do not equate a mock preview or syntax parse with native WoW behavior.

## Model and protocol coverage

Eight model checks cover lobby/start/replay, 25-slot cap, movement/climb bounds, shared floor/collapse, exposed boss reach, exact four-stage total, pause, late members, and simultaneous 25-monster collapse/reset.

Seventeen protocol checks cover:
- Explicit opt-in discovery/join; no incoming forced join/window.
- Actual roster sender, host/session, host-issued admission generation, role/input sequencing and challenge replay prevention.
- Duplicate/out-of-order/rapid/prior-stage/prior-role/future input rejection.
- Atomic fragments, reordered/duplicate/stale/incomplete snapshots, bounded expiring assemblies and malformed worlds.
- Spectator late join, no avatar/score/input/start, active-full spectator fallback, role switching, no displaced active players.
- Shared damage, healing dropped snapshots, host combat pause and input epoch invalidation.
- Departures, host loss, stalled worlds, silent spectators, removal-record loss recovery, reconnect.
- Counter saturation refusal; coalesced bounded queues, inbound floods, strict member records and malformed/fuzz input.
- Forty-client maximum-name admission and simultaneous reconnect.
- Sustained 25-active + 15-spectator four-boss/replay run under loss/duplication/reordering and combat.

### Measured finite-budget fixtures

| Fixture | Observed result |
| --- | --- |
| Maximum-field world | 2 packets, **340 combined payload bytes**, each ≤255 |
| Forty 96-byte names | admission **23.0s**, simultaneous reconnect converged |
| Maximum-name host traffic | **4.61 msgs/s**, **577.0 payload B/s**, **650.7 charged B/s** |
| Maximum-name queue / world gap | **47/128**, **1.5s** |
| Sustained 25+15 duration | **124.7s**, four bosses through actual client inputs, replay, combat pause |
| Loss fixture | **4.35% per-recipient loss**, plus duplication/reordering; exact final convergence |
| Sustained host traffic | **3.47 msgs/s**, **307.5 payload B/s**, **363.0 charged B/s** |
| Sustained whole-group traffic | **60.79 msgs/s**, **1,968.0 payload B/s**, 601 guest heartbeats |
| Sustained queue / maximum world gap | **41/128**, **2.9s** |

Hard per-sender budget: 8 msgs/s, 700 charged B/s, burst 10/1,000; 16-byte allowance per message. Snapshot interval **1.25s (0.8 Hz)**, not the approximately 30Hz visual animation cadence or 5Hz keyboard sampling. Queue 128, at most 3 assemblies × 2 parts, 6s expiry. The conservative snapshot rate is a known remote-responsiveness tradeoff, not a promise of action-game latency. Admission can wait up to the bounded 90s timeout.

## Input, UI and audio coverage

Twelve mock checks cover full TOC load, saved-variable sanitation, no forced window, solo mouse fallback, explicit keyboard grab, WASD/arrows/Space mapping, bounded held repeat, unknown/chat shortcut propagation, edit focus, Escape, focus loss, missed key-up reconciliation without `IsWindowFocused`, Alt/Meta release, long stalls, hide/world departure/spectator/combat release, scaling, visible-only discovery, explicit Join/Spectate, party/raid filtering and canonical cross-realm names.

Combat mocks **throw if restricted propagation is mutated in combat**. Production hides the ordinary keyboard frame and clears held keys; it does not change permanent/override bindings or protected actions. Source signatures were checked against the `classic_anniversary` Blizzard UI mirror:
- `Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua`: EnableKeyboard / SetPropagateKeyboardInput and restrictions.
- `Blizzard_SharedXML/KeyCommand.lua`: physical `IsKeyDown` usage.

No guaranteed native window-focus API was established; `IsWindowFocused` is guarded. Taskbar switching, exact native key delivery/propagation, and frame taint need manual verification.

Audio mocks cover default-off, missing provider, provider None/nil, playback false/exception, explicit mute, per-cue/global throttles, own-hit-only behavior, major spectator transitions, duplicate transition suppression, and no late-join/hidden-window catch-up. No audio was copied or auditioned. Existing BlasterMaster role assignments are the user's mappings; duration labels in prior tooling were not acoustic proof. Missing/disabled provider remains silent, with no fallback surprise.

## Visual review — mock layouts, NOT native screenshots

`docs/previews/mock-{solo,raid,boss,victory,spectator}.svg` comes from the actual runtime UI and strict frame/texture/font geometry mocks. Review PNGs are task artifacts, not shipped Media.

Inspected readability of title/action buttons, compact fallback controls, warm skyline/window damage, varied colored creatures, local highlight, 25-player overlap fan and roster chips, exposed boss/HP bar, spectator-disabled controls and victory layout. No text/button clipping was seen in the normal-size mock fixtures. Twenty-five monsters can still overlap heavily; hover chips and local priority help but the real-client readability check remains necessary. The previews do not render native Blizzard fonts, tooltip behavior, input focus, sound or transport.

## Manual TBC 20506 checklist — outstanding for this iteration

Use identical R2 candidate ZIPs; R1 is incompatible. Do not force a user/client reload from automation.

- [ ] **Install/load:** enable or safe `/reload`; no Lua errors/forced window. Verify six TOC Lua modules, preserved personal best/position, default-off audio.
- [ ] **Keyboard:** `/rampage solo`, click PLAY, WASD/arrows/Space hold. No movement/spells reach WoW while consumed. Press unknown keys, Enter, slash and custom chat bindings; keys propagate and capture releases. Type into chat/search; no game movement.
- [ ] **Focus recovery:** Escape, hide, Leave, group departure, Alt-Tab, Win/Meta shortcut, taskbar switch, missed key-up, loading screen and long stall. No stuck repeat/capture. PLAY must be explicit to recapture. Test native API behavior with no assumed `IsWindowFocused` helper.
- [ ] **Combat / taint:** enter combat while holding Space and dragging; frame hides, game input stops, no restricted-action errors. Host pauses everyone; guest alone does not pause host. After combat window may return but keyboard stays released. Normal raid movement, targeting, spells and bindings remain unaffected.
- [ ] **Graphics / scale:** small/large UI scales and resolutions; drag/clamp, local-player halo, 25-chip hover names, overlap, native font wrapping, cracks/rubble, punch/collapse effects, boss shield/HP and victory confetti. Verify no child frame anchor/scale surprises.
- [ ] **Simple lobby:** one Host & Start; another opens window and Join Game in progress; separate Spectate; active-full fallback, 40-total refusal, role switch after a slot opens; multiple lobbies and Next Host. Joining never forced.
- [ ] **Real two-client baseline:** each hits the same floor once and both see destruction; compare position/fame/boss/stages and replay. Check 1.25s authoritative latency is tolerable before scaling.
- [ ] **Real raid load:** build toward 25 active + 15 spectators, cross-realm roster, all late join/rejoin; no starved last members/fragment errors. Measure actual latency/traffic alongside raid addons. Host reload/disconnect ends cleanly; no migration.
- [ ] **Sound:** with BlasterMaster installed, opt in and verify local crit/combatStart/levelUp role mappings, None, provider variants, mute/SFX disabled/missing provider; no network hit chorus, stale transition bursts or global volume/settings edits.

## Known limits / release gate

Same forgiving four-stage rules; no hazards/death, no host migration, no alternate instance-chat transport, no competitive anti-cheat. Host is trusted authority. The host stays active; switching to spectate resets that player's current fame. Up to 25 active/40 total, not 40 active. UI is original geometric/pixel-style art, not licensed classic sprites.

Hold merge/release until explicit `!ship rampage`; CurseForge remains deferred. Original candidate commit `51b6b6d` and its ZIP are preserved for rollback. This file records automated evidence and separates all remaining native checks.
