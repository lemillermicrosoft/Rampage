# Rampage — FOUR MORE BOSSES!

**<Toast>'s pocket raid-break arcade.** Original monsters climb and smash a shared city, then flatten four fictional bosses. For **TBC Classic 2.5.6 / Interface 20506**. Inspired by classic climb-and-smash games; no copied Rampage artwork/audio or affiliation claimed.

## Current release: keyboard + 25-player polish

This release line adds **25 active monsters and up to 40 total participants**, including read-only spectators; streamlined late join; opt-in keyboard controls; an original warm pixel-style city/creature overhaul; and optional locally installed BlasterMaster sounds. [PR #3](https://github.com/lemillermicrosoft/Rampage/pull/3) covers the MVP and [iteration #4](https://github.com/lemillermicrosoft/Rampage/issues/4). Publishing was explicitly authorized on October 29, 2026. Project: [CurseForge 1772524](https://www.curseforge.com/wow/addons/rampage-four-more-bosses); [GitHub releases](https://github.com/lemillermicrosoft/Rampage/releases). The sites show current file availability/approval; upload acceptance alone does not imply public approval.

The user demonstrated original-MVP solo play in WoW. **This new keyboard/UI/network iteration has automated and mock-layout verification, not a live 25-player raid or native keyboard/taint sign-off.** See [QA.md](QA.md).

## Install / update

Extract the candidate ZIP so `Interface/AddOns/Rampage/Rampage.toc` exists. Its runtime files are `Model.lua`, `Protocol.lua`, `Input.lua`, `Sound.lua`, `UI.lua`, `Rampage.lua`, and `Media/icon.png`. Node/npm/tests are development-only, never WoW dependencies.

Enable Rampage at character selection and `/reload` when safe. **All participants must use this same R2 build**; the original four-player R1 candidate cannot join R2 games. Updates do not change your SavedVariables file externally. Personal best/window position are retained; new sound settings default off.

## Get playing

1. **Solo:** `/rampage solo` or Solo practice.
2. **Raid/party:** `/rampage`. The visible window automatically looks for current group games. Click **JOIN GAME**, or **SPECTATE** to watch. Joining is always explicit; incoming messages never open a window.
3. If nobody is hosting, **HOST & START** opens a game immediately. **Next host** is the secondary multiple-lobby selector. Late join works after a stage has begun.
4. Click **PLAY • GRAB KEYS**. Hold **WASD or arrows** to move/climb/descend; **Space** punches. The most recently held gameplay key wins, with a global approximately five-actions/second limit. Compact mouse buttons remain available.
5. **Escape** releases keyboard capture. Click PLAY to recapture. Close hides and releases keys; **Leave** exits the session.

### Smash school

- Walk horizontally on the ground to tower lanes **2, 4, 6**.
- Climb to the top. Punch twice per floor; descend between floors. Flattening a tower drops its climbers to the street.
- Flatten all three towers to expose the boss. Punch from ground lanes **3–5**.
- Defeat **The Crumb Baron**, **Permitron 9000**, **The Snack Tax**, then **Queuezilla**. Boss HP is 10/12/14/16, with two-second stage transitions.
- Individual hit/collapse/boss rewards feed team fame. Current participants' scores count; leaving or switching to spectate removes that avatar's current score. Returning to play starts at zero. Local personal best remains.
- **25 active / 40 total:** a full 25-player game still has room for 15 spectators. Unused active capacity can hold more spectators within the total ceiling. Active slots are never stolen. A discovered 40-total lobby labels both admission buttons **GAME FULL** and disables them. At 25 active with observer space, **PLAYERS FULL** disables Join while **SPECTATE** stays available; slash/race-path full active joins still fall back to spectator in the protocol. Existing spectators can explicitly **Switch to Play** when an active slot opens, even if total membership is already 40. The host remains a player and owns Start/replay.

## Keyboard and raid safety

- An ordinary, opt-in frame handles keys. **No permanent or override bindings, protected spell buttons, combat automation, public chat or raid sound messages.**
- Capture is allowed only while the window is visible and an active player can play. Spectators never capture gameplay keys.
- Escape, unknown keys (including Enter/slash/chat shortcuts), edit-box focus, hide, leave, world departure, combat, Alt/Ctrl/Meta shortcuts and long frame interruptions release capture and held keys. Unknown keys propagate to WoW.
- Physical key-state reconciliation stops a repeat after a missed key-up when `IsKeyDown` is available. A native window-focus helper is guarded, not assumed present. **Taskbar switching and exact native key propagation still require the manual test.**
- Combat hides the window and releases the keyboard. Host combat pauses everyone; guest combat blocks only that guest's local input. The previous window can return after combat, but **keyboard capture never automatically returns**.
- The addon hides its non-secure capture frame instead of changing restricted propagation during combat. Actual client taint behavior remains a release gate.

## Optional local BlasterMaster audio

**Local BM: OFF** is the default. Opt in with the button; **Mute Rampage** independently silences cues.

Rampage calls the already-installed `BlasterMaster_GetSfxPath(role)` accessor for `crit` (local impact), `combatStart` (collapse/stage), and `levelUp` (boss/victory). It honors that provider's remapping, **None**, and pre-rendered volume variants. Missing/disabled/broken provider or failed `PlaySoundFile` stays silent. No hard dependency, copied game audio, settings hooks, fallback surprises or global volume/CVar changes.

Only local hits and rare authoritative transitions make cues. Spectators hear major transitions only. Cues are deduplicated, globally spaced by at least 1.3–2.2 seconds and per-cue throttled; late join/reopen does not play a catch-up burst. Playback uses the normal **SFX** channel. Per-call gain is not available here; configure existing provider variants or WoW SFX volume yourself.

## Graphics / performance

Original stepped creature silhouettes, expressive faces, walk/climb/punch poses, local-player highlight, bounded overlap offsets, 25 hover roster chips, boss health/shield display, warm skyline, cracked windows, rubble, dust, stage banners and victory confetti. Window layout is 900×660 and scales down to fit available UI space.

Fixed runtime pools: **93 frames, 1,190 textures, 83 font strings**, including **72 reusable particles**, unchanged after 500 animated 25-player renders in mocks. Visual smoothing targets roughly 30 Hz, **not the network tick rate**.

## Network performance and limits — read before a big raid

R2 uses ordinary PARTY/RAID addon messages only. Host authority verifies the actual roster sender, session, host-issued admission generation, role and input epoch/sequence. It supports late join, reconnect, sequenced role changes, atomic full-state fragments, expired members, malformed/replayed packet rejection and no host migration.

- Every packet ≤255 payload bytes. Full 25-player state: at most **2 fragments**, maximum-field fixture **340 payload bytes combined**.
- Per-sender hard budget: **8 messages/s and 700 charged bytes/s**, bursts 10 messages/1,000 charged bytes (16-byte accounting allowance per packet). Queue cap 128; partial assembly cap 3×2 parts, expiry 6s.
- **Authoritative snapshots every 1.25 seconds (0.8 Hz)**, potentially longer with loss/throttling. Keyboard samples about 5 Hz but there is no speculative client movement. A remote player's feedback can therefore lag; this is not a precision-action networking claim. Full-state smoothing favors a conservative traffic budget.
- Names/roles are sent on a rotating broadcast schedule, separately from world fragments. Initial names can populate gradually. Forty simultaneous maximum-length-name clients admitted in **23 seconds** in the test fixture; the bounded join timeout is 90 seconds.
- Guests heartbeat every 8 seconds; stalled hosts expire at 20 seconds, silent guests at 35 seconds. Host departure requires a new game. Lost world fragments heal on a later complete snapshot. Inputs coalesce under send pressure and are not retransmitted.
- **Measured 124.7s simulated 25+15 run:** four bosses, combat pause, replay, movement, 4.35% per-recipient loss plus duplication/reordering; exact final convergence. Host averaged **3.47 messages/s / 307.5 payload B/s**; whole group **60.79 messages/s / 1,968 payload B/s**; maximum observed world gap 2.9s.

These are finite-budget simulations, **not measurements from 40 real WoW clients**, and do not account for every other addon sharing the client transport. Real raid latency/traffic and usability need a guild playtest. Detailed protocol: [docs/PROTOCOL.md](docs/PROTOCOL.md).

## Slash commands

`/rampage` toggle; `solo`; `host`; `find`; `join [Name-Realm]`; `spectate [Name-Realm]`; `play`; `start`; `leave`; `help`.

`host` opens a lobby without starting (unlike the main Host & Start button). `play` requests an active slot but does not capture keys from chat; click PLAY afterward. Only host/solo can Start or replay.

## Development

```text
npm ci --ignore-scripts
npm test
npm run check:lua51
npm audit --audit-level=moderate
node tests/run.cjs --suite=protocol
node tests/run.cjs --suite=wow
node tests/ui-preview.cjs --scene raid --output docs/previews/mock-raid.svg
```

**38 tests:** 8 model, 17 protocol (including 40-node simulations), 13 strict mocked WoW/UI/input/audio checks. **9 Lua files** parse as Lua 5.1 grammar. Execution uses **Fengari Lua 5.3 semantics**, not a native WoW VM. Pinned dev dependencies: Fengari 0.1.5 and luaparse 0.3.1.

`docs/previews/` contains mock renders captured from the actual `UI.lua` geometry, **not WoW screenshots**. They are review artifacts, not runtime Media and are not included in the install ZIP.

Repository: https://github.com/lemillermicrosoft/Rampage
