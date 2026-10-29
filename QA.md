# QA — roaming-boss release (R4)

## Build and installation boundary

Issue #7 / PR #8 was developed in isolated worktree `C:\Users\leroy\repos\Rampage-boss-motion` from v0.3.0 commit `7c27d1b8900e37d855ec64539923697231469bc9`. The owner authorized publication on October29,2026 at12:57. Independent review passed the original72 checks,9 grammar parses,audit0,28,000 off-grid round trips and all13 candidate archive hashes, identifying one narrow render-stall cue defect corrected before publication.

The existing pipeline assigns a new matching TOC/app version and runs full exact bumped-runtime tests before tagging/uploading. Primary `C:\Users\leroy\repos\Rampage` advances only to the approved release and stays there. The anniversary AddOns/Rampage junction remains pointed at that primary checkout; no junction change, forced reload or SavedVariables edits. The isolated worktree and old archives are preserved.

**Both machines/all participants need the same new versioned R4 release**, incompatible with published v0.3.0/R3. Do not mix old releases or head-labelled playtest archives. After publication the owner can safely reload the linked release when ready; the other machine installs the matching ZIP. Do not extract over the owner's junction.

Unique levels remain later backlog. No new map, body-contact damage, platform physics, service/dependency, or borrowed art/audio.

## Executed verification

- Full integrated `npm test`: **74 checks** —22 model,26 protocol,26 actual-TOC mocked WoW/UI/input/audio tests. All prior gameplay/security/capacity/control checks retained; moving-threat fixtures now drive the sole authoritative `bossMotion` state.
- `npm run check:lua51`: **9 files**, actual six TOC runtime modules plus three Lua test suites.
- Final focused UI suite: **26/26**, including confirmed-impact residue, no catch-up/replayed damage and explicit restored building-detail layering.
- New actual-UI regression first failed against2ae1dd3: no renders while a warning sample aged4s, then a consecutive same-cycle recovery incorrectly confirmed residue. The fix measures prior sample age before overwriting its timestamp, combines it with remembered staleness, suppresses confirmation and clears stale baseline particles. Tests cover no intermediate render, >2.5s suppression, exact2.5s timely boundary, ordinary1.25s confirmation and existing rendered-stale/pause/replay/late-join guards. This changes no gameplay, wire schema, latency or damage behavior.
- `npm ci --ignore-scripts` in the isolated worktree: five locked development packages, zero audit findings; no manifest changes or global installation.
- `npm audit --audit-level=moderate`: **zero vulnerabilities**. `git diff --check`: clean.
- Input.lua and Sound.lua untouched from v0.3.0; adapter code unchanged except the release pipeline's version assignment. TOC version is synchronized by that same pipeline. No release script/config/workflow/installed-skill changes.

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

## Actual UI/input/audio mock:26 checks

Real TOC loading; existing combat, keyboard propagation/capture, chat/focus/modifier/Escape/hide/leave/long-stall/physical-key-up safety, mouse fallback, saved variables, optional audio and capacity/consent controls retained.

**The shipped level-transition correction is unchanged:** selected keyboard/mouse mode stays across ordinary clear/intermission/next-stage transitions. No actions while inactive; known keys remain consumed; held inputs require release/fresh press. Explicit/safety releases never auto-recapture. No input/adapter/audio edits.

Additional evidence:
- Ground boss center matches model position while shielded/exposed; constant1.5 scale, moving shield and ±1-lane reach bracket. Host rendering never extrapolates from wall clock.
- Guest smoothing follows only the known patrol, capped at its endpoint and2.5s snapshot age. Pause/staleness freezes; no next phase predicted. Stage/epoch/replay/gap/hide/session changes reset visual baselines.
- Distinct stride/raised windup/release/lowered recovery poses and stomp leg pose. Fixed48-texture origin-to-target cues for crumb/beam/stomp/barrage; ground/all-height warnings distinguished.
- A0.5s attack can fall between1.25s worlds. A timely consecutive same-cycle windup→recovery receipt can show **0.65s static residue**, labelled IMPACT CONFIRMED. It does not fire a late projectile, infer damage, award score, repeat per frame, or trigger for late join/gap/staleness/pause. Missed attack frames otherwise remain missed.
- Exactly500 animated25-actor renders leave **105 frames /1,521 textures /97 fonts**,seven lane markers,72 particles and48 boss-cue textures unchanged. This establishes bounded WoW-object pools, not zero Lua allocations or native frame time.

## Building-detail correction before publication

The owner requested earlier window/facade detail back while the release was still at its test gate, before any new tag/upload. The initial pipeline was stopped there; its inferred0.4.0 bump is retained and resumed without another bump. Historicalv0.2.0/v0.3.0 UI declared windows and trim, but wall/frame/pane/mullions shared ARTWORK ordering and damaged panes fell to0.23 alpha. These are visibility risks, not proof of the user's native rendering cause.

Restored explicit ordering: wall BACKGROUND; shadows/brick seams BORDER; window frame ARTWORK0,lit panes ARTWORK1,glints ARTWORK2; mullions/sills/cornice OVERLAY. Damage retains0.65 pane alpha, distinct cracks and readable facade details. Added117 fixed textures (27 sills,27 vertical mullions,27 glints,36 brick seams), no new levels/assets/gameplay. Regression checks intact/damaged/destroyed floors, all nine floors at normal scale, layer/sublevel ordering and visible detail. Mock exporter now respects texture sublevels. Actual before/after patrol fixture inspected; native rendering remains unverified.

## Inspected visual previews

Actual UI.lua geometry exported using explicit WoW mocks, not hand-drawn concepts:
- `boss-patrol-mock`: shielded boss at lane2.5 with stride and ground bracket.
- `boss-windup-mock`: exposed boss at lane4 with raised charge and locked warning lane.
- `boss-impact-mock`: boss at lane5 with crumb trajectory toward warned lane3.

SVGs are underdocs/previews; final review PNGs under `artifacts/rampage/boss-motion/`. Inspected readable mode/health/input controls, changing ground positions/poses, warning columns, visible origin trajectory and reach bracket. No normal-size control clipping seen. Character/boss overlap is intentional; native fonts/scaling/raid clutter still require testing. These are **MOCK LAYOUTS, not WoW screenshots**. Earlier preview files depict their historical builds.

## Manual playtest outstanding

Use the same new versioned release on all participating machines:

- [ ] `/rampage solo`→Add AI→PLAY. Watch shielded patrol,7s windup/attack,then5s recovery. No body-contact damage.
- [ ] Flatten city; chase and hit inside the actual boss bracket, miss outside even in old lanes3–5. AI also chases and finishes.
- [ ] Observe all four personalities. Ranged columns damage all heights; Snack Tax stomp is ground-only. Targets stop tracking once warning starts; dodge early.
- [ ] Control selection survives cities; held actions need release/fresh press. Escape/close/chat/focus/combat still release and never auto-arm.
- [ ] Host combat pauses movement/windup/recovery; guest protection precedes known impacts, while acknowledging initial detection delay.
- [ ] Two actual clients in one PARTY/RAID on the sameR4 ZIP: warning visibility, hit response, interpolation/pause/staleness, late join/replay. Separate parties/guild chat are not connected.
- [ ] Brawl consent, human/AI hits/KO, spectator immunity and bot eviction; scale only after two-client response is acceptable.
- [ ] Native fonts/scaling/taint/taskbar focus/audio; optional BM off/mute/None unchanged. Restore matching publishedv0.3.0 on both machines if rolling back.

## Authorized publication handoff

Publish the reviewed PR with the render-stall fix through the existing regular release pipeline. Verify exact versioned archive/per-entry hashes, downloaded GitHub asset, tag/main/PR/issue state and CurseForge upload receipt separately from moderation/public visibility. Leave primary clean on the new release with its junction unchanged. Preserve the isolated worktree and older archives. This authorization covers current moving bosses only; unique levels remain future work.
