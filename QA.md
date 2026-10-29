# QA — isolated roaming-boss candidate (R4)

## Build and installation boundary

New issue #7 worktree `C:\Users\leroy\repos\Rampage-boss-motion`, based on released v0.3.0 commit `7c27d1b8900e37d855ec64539923697231469bc9`. This feature is **not published or installed**.

Primary `C:\Users\leroy\repos\Rampage` remains clean main at that release. The actual anniversary-client junction `C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\Rampage` still targets the primary checkout. **Reloading it loads v0.3.0/R3, not this candidate.** No junction, forced reload or external SavedVariables changes were performed.

Candidate TOC/app remains0.3.0, but its wire protocol is **R4**. All test participants need the same head-labelled boss-motion ZIP; matching displayed versions do not establish compatibility. Keep both household machines on released v0.3.0 unless explicitly coordinating a candidate install. Do not extract over the existing release junction. No merge/tag/GitHub/CurseForge publication is authorized for this new feature.

Unique levels remain later backlog. No new map, body-contact damage, platform physics, service/dependency, or borrowed art/audio.

## Executed verification

- Full integrated `npm test`: **72 checks** —22 model,26 protocol,24 actual-TOC mocked WoW/UI/input/audio tests. All prior gameplay/security/capacity/control checks retained; moving-threat fixtures now drive the sole authoritative `bossMotion` state.
- `npm run check:lua51`: **9 files**, actual six TOC runtime modules plus three Lua test suites.
- Final focused UI suite: **24/24**, including confirmed-impact residue and no catch-up/replayed damage.
- `npm ci --ignore-scripts` in the isolated worktree: five locked development packages, zero audit findings; no manifest changes or global installation.
- `npm audit --audit-level=moderate`: **zero vulnerabilities**. `git diff --check`: clean.
- Input.lua, Rampage.lua, Sound.lua and TOC untouched from released v0.3.0. No release script/config/workflow/installed-skill changes.

Execution is **Fengari0.1.5 Lua5.3 semantics**, with separate luaparse0.3.1 Lua5.1 grammar. These are not native Lua5.1/WoW API/taint or live multiplayer certifications.

## Model:22 checks

Baseline city/movement/climbing/shared destruction, four bosses/replay/score, default Co-op no friendly fire, Brawl mutual hits/range/cooldown, health/KO/respawn/immunity/protection/pause all retained. Added:

- Actual fractional patrol in lanes2–6, reflected route bounds, ≤2 lanes per5 seconds, deterministic partitioned ticks.
- Shared `bossPosition` / `bossInReach` for model punches and AI chase; exposed ground distance≤1, shield unchanged. Old fixed3–5 hitbox no longer works when the boss moves away. No body-contact damage.
- Every boss phase freezes during host combat; the known-segment helper never advances a phase. Stage/replay resets position/cycle/AI action clock and clears old hazards.
- Seven-second warning locks origin/lanes; once-only35 damage impact;0.5s attack;5s stationary recovery. At least four safe lanes.
- Ranged columns affect all heights; Snack Tax stomp affects ground only. Knockback uses the actual boss origin, not fixed lane4.
- Nearest eligible target pursuit with deterministic lowest-slot ties; protected/KO actors excluded.
- One AI clears four moving bosses in **100.8 game seconds**; five AI in **50.8s Co-op /85.2s Brawl**, with movement observed on all stages. Separate fixtures prove AI damage/KO and legal warning avoidance.

## Network:26 checks

Existing host/actual-sender/roster/session/generation/epoch/sequence/role authority, spectator immunity/read-only behavior, Co-op/Brawl consent at join and victory, capacities/bot eviction, malformed/stale/future input, challenge handshake, reconnection/liveness and pre-impact combat protection remain.

R4 adds an eleven-character boss record replacing the nine-character hazard: cycle ID, phase, target mask, remaining deciseconds and source/destination lanes. Every phase of all four bosses round-trips. Strict phase/clock/route/mask constraints reject bad worlds atomically; R1–R3 are rejected. Mid-patrol late join reconstructs position; decode/client tick never replays impact damage. Off-grid rounding adds at most0.04 lane positional quantization.

### Measured, not estimated

Every emitted broadcast independently fans out to other real nodes. Byte/message/queue/assembly bounds are checked during simulation.

| Fixture | Observed |
| --- | --- |
| Maximum valid world | **494 assembled body bytes**,3 fragments,**593 payload /641 charged bytes**,largest packet**209/255**,fragment max176 |
| Forty96-byte-name participants | all admitted in **41.3s**,simultaneous reconnect converges |
| Maximum-name host | **4.20msg/s,618.7 payloadB/s,685.9 chargedB/s**,queue53/128,world gap1.5s |
| Mixed run | **82.9 simulated seconds**,40 real nodes =20 human actors+20 spectators,plus5 AI;four bosses/replay/combat |
| Disruption | deterministic **4.35% per-recipient loss**,0–300ms jitter/reordering/duplicates;exact final convergence |
| Mixed host | **3.46msg/s,457.8 payloadB/s,513.1 chargedB/s** |
| Whole group | **36.00msg/s,1,375.9 payloadB/s**,402 guest heartbeats |
| Mixed queue/world gap | **41/128**,**4.0s** maximum |

Human drivers chase from their delayed snapshots, not teleported omniscient positions. Both40-member fixtures assert measured host averages under700 chargedB/s and8msg/s, alongside per-send token-bucket checks. No bandwidth increase.

Unchanged limits:8msg/s burst10,700 chargedB/s burst1,000 (16-byte allowance/message),queue128,three assemblies×three fragments,6s expiry;1.25s worlds,1s name carousel,90s join/20s world/35s guest timeouts. The three-second blackout fixture still lets a client see a warning and legally dodge. **Arbitrary loss can hide warnings.** Seven seconds exceeds the measured4s gap, not every possible delay. No prediction/precision-PvP claim.

## Actual UI/input/audio mock:24 checks

Real TOC loading; existing combat, keyboard propagation/capture, chat/focus/modifier/Escape/hide/leave/long-stall/physical-key-up safety, mouse fallback, saved variables, optional audio and capacity/consent controls retained.

**The shipped level-transition correction is unchanged:** selected keyboard/mouse mode stays across ordinary clear/intermission/next-stage transitions. No actions while inactive; known keys remain consumed; held inputs require release/fresh press. Explicit/safety releases never auto-recapture. No input/adapter/audio edits.

Additional evidence:
- Ground boss center matches model position while shielded/exposed; constant1.5 scale, moving shield and ±1-lane reach bracket. Host rendering never extrapolates from wall clock.
- Guest smoothing follows only the known patrol, capped at its endpoint and2.5s snapshot age. Pause/staleness freezes; no next phase predicted. Stage/epoch/replay/gap/hide/session changes reset visual baselines.
- Distinct stride/raised windup/release/lowered recovery poses and stomp leg pose. Fixed48-texture origin-to-target cues for crumb/beam/stomp/barrage; ground/all-height warnings distinguished.
- A0.5s attack can fall between1.25s worlds. A timely consecutive same-cycle windup→recovery receipt can show **0.65s static residue**, labelled IMPACT CONFIRMED. It does not fire a late projectile, infer damage, award score, repeat per frame, or trigger for late join/gap/staleness/pause. Missed attack frames otherwise remain missed.
- Exactly500 animated25-actor renders leave **105 frames /1,404 textures /97 fonts**,seven lane markers,72 particles and48 boss-cue textures unchanged. This establishes bounded WoW-object pools, not zero Lua allocations or native frame time.

## Inspected visual previews

Actual UI.lua geometry exported using explicit WoW mocks, not hand-drawn concepts:
- `boss-patrol-mock`: shielded boss at lane2.5 with stride and ground bracket.
- `boss-windup-mock`: exposed boss at lane4 with raised charge and locked warning lane.
- `boss-impact-mock`: boss at lane5 with crumb trajectory toward warned lane3.

SVGs are underdocs/previews; final review PNGs under `artifacts/rampage/boss-motion/`. Inspected readable mode/health/input controls, changing ground positions/poses, warning columns, visible origin trajectory and reach bracket. No normal-size control clipping seen. Character/boss overlap is intentional; native fonts/scaling/raid clutter still require testing. These are **MOCK LAYOUTS, not WoW screenshots**. Earlier preview files depict their historical builds.

## Manual playtest outstanding

Only after explicitly choosing and installing the same candidate on all test machines:

- [ ] `/rampage solo`→Add AI→PLAY. Watch shielded patrol,7s windup/attack,then5s recovery. No body-contact damage.
- [ ] Flatten city; chase and hit inside the actual boss bracket, miss outside even in old lanes3–5. AI also chases and finishes.
- [ ] Observe all four personalities. Ranged columns damage all heights; Snack Tax stomp is ground-only. Targets stop tracking once warning starts; dodge early.
- [ ] Control selection survives cities; held actions need release/fresh press. Escape/close/chat/focus/combat still release and never auto-arm.
- [ ] Host combat pauses movement/windup/recovery; guest protection precedes known impacts, while acknowledging initial detection delay.
- [ ] Two actual clients in one PARTY/RAID on the sameR4 ZIP: warning visibility, hit response, interpolation/pause/staleness, late join/replay. Separate parties/guild chat are not connected.
- [ ] Brawl consent, human/AI hits/KO, spectator immunity and bot eviction; scale only after two-client response is acceptable.
- [ ] Native fonts/scaling/taint/taskbar focus/audio; optional BM off/mute/None unchanged. Restore matching publishedv0.3.0 on both machines if rolling back.

## Handoff gate

New tested PR and head-labelled portable ZIP only, with per-entry hashes. **Not installed/not published.** Primary release and older archives preserved. Parent independently reviews; the user chooses whether and when to test. Fresh owner approval is required to merge/tag/publish; unique levels remain future work.
