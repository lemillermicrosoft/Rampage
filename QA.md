# QA — hit-feedback playtest candidate

## Scope and installation boundary

New issue #10, isolated worktree `C:\Users\leroy\repos\Rampage-hit-feedback`, based on released v0.4.0 commit `5ec13435deda1244c9bfbe63735777fe4af2de7b`. This iteration is **not installed or published**. Primary `C:\Users\leroy\repos\Rampage` remains clean main at that release; the actual anniversary-client `Interface/AddOns/Rampage` junction still targets primary. Merely reloading it does not load this candidate. No junction switch, forced reload, external SavedVariables editing or old-artifact overwrite.

New PR and head-labelled ZIP only. Previous publishing approvals were consumed by v0.4.0. No merge/tag/GitHub/CurseForge release, moderation polling, Discord/configuration changes, new levels or balance changes.

## Executed verification

- Full `npm test`: **119/119** —22 model,26 protocol,39 feedback-state,32 actual-TOC mocked WoW/UI/input/audio tests. All74 baseline checks retained, including control persistence, building layers and the no-render stale-impact guard.
- Final focused UI suite: **32/32** after explicit YOU HIT/TEAM HIT labels and preview metadata correction.
- `npm run check:lua51`: **11/11 Lua files**, seven TOC runtime modules and four test suites.
- Isolated `npm ci --ignore-scripts`: five existing locked development packages, no manifest or global install changes. `npm audit --audit-level=moderate`: **0 vulnerabilities**.
- `git diff --check`: clean. `Model.lua`, `Protocol.lua`, `Sound.lua`: unchanged from v0.4.0. Version stays0.4.0, interface20506.
- An in-memory same-input/model/UI regression was run against immutable v0.4.0 and the candidate. At lane1, punching air changed no floor/boss HP. **Old UI failed** the no-contact-sparks assertion; **candidate passed**. Neither source tree was modified by the probe. Evidence: `artifacts/rampage/hit-feedback/legacy-contact-regression.json`.

Execution is **Fengari0.1.5 Lua5.3 semantics**, with separate luaparse0.3.1 Lua5.1 grammar. Mock API/render evidence is not native WoW graphics, input/taint or live multiplayer proof.

## Feedback-state evidence:39 tests

`Feedback.lua` uses immutable numeric HP samples; never alters model state, applies damage, awards fame or sends a new packet. `Input.action` gains one delegation line; the wrapper calls existing `net:action` exactly once and preserves its result. Synchronous changed callbacks are deferred so an exact local result is not consumed/relabelled as TEAM.

Tests cover:
- Score and punch counters cannot fabricate contact. Exact host/solo building/boss damage says YOU, using HP loss rather than10/15 fame.
- Unrelated human/AI deltas are observed before local action and cannot acquire local credit. Client sends produce only numberless swing intention; remote target loss is TEAM aggregate.
- Positive incoming HP deltas, local priority, healing/respawn suppression, KO/reset generations, final same-stage boss hit and no stale terminal replay.
- Actual member generation, role sequence, separate name/mapping stream, observed bot identity/removal, local bot order and slot reuse. Missing/mismatched member evidence suppresses actor deltas.
- Join/reopen/session/stage/replay/epoch/role/local-slot changes, pause/combat and synchronous hidden callbacks baseline silently.
- Duplicate/reordered/gapped worlds, old model time, stale current/previous arrival, blackouts, render loops and no-intermediate-render stalls. **Previous arrival age is measured before timestamp replacement.** Exactly2.5s is allowed; greater than2.5s is suppressed.
- Throttled known local shield/ground/range/cooldown explanations, sampled client guidance, actual moving-boss reach helper and Brawl lowest eligible slot.
- Queue max32, at most8 nonlocal receipts per undrained batch, local/boss priority, expired queue removal and immutable snapshots under in-place model mutation.

**R4 limitation:** it has no bot incarnation counter or per-hit source history. A same-ID bot removed and readded entirely between two snapshots is not distinguishable on a client. Visible removals/ID changes and known human admission generations are handled. Remote HP changes can combine hits and heals, so feedback reports net observed loss, not an invented complete combat history. No extra protocol complexity was introduced for cosmetic precision.

## Actual UI evidence:32 tests

Existing26 release UI/input/audio checks retained; six added integrated feedback cases exercise the real TOC, adapter, Input, model and new observer:

1. Local incoming loss aggregates into `YOU -N HP`, with0.28s damped recoil, warm single tint and amber loss trails. Repeated renders do not repeat it; expiry restores base transforms without drift; heals/respawn are silent.
2. Air swings show a fist only; successful building/boss actions produce actual contact sparks/target response and `YOU HIT -N HP`. Boss numbers reflect HP, not fame; numeric HP remains visible when shielded/exposed and at the final hit.
3. Remote timely total loss says `TEAM HIT -N HP`, not YOU. Duplicate/gap/stalled deliveries cannot replay damage presentation.
4. Reduced Motion persists in normal addon settings, immediately restores offsets, suppresses decorative recoil/bob/bounce/number rise/particles and retains static useful numbers/trails/highlights. Hide, KO, phase reset and combat clean up effects and transforms.
5. Brawl target highlight follows the unchanged lowest eligible same-height adjacent slot. Client guidance/bracket is explicitly sampled/estimated, not an exact host promise.
6. Member/slot generation changes clear previous-occupant visual state; combat resets active recoil/labels/trails.

All original keyboard lifecycle protections remain: selected keyboard/mouse survives ordinary intermission/stage changes; held inputs require release/fresh press; Escape, chat/edit focus, close/Leave, modifiers/focus interruption and real combat release without auto-recapture. No restricted propagation mutation in combat. Sound.lua and provider/mute/defaultOFF behavior are unchanged.

### Bounded presentation

- **12 reusable number labels**, local incoming and boss readability reserved; remaining labels reused or omitted rather than flooded. Short-lived labels may aggregate nearby receipts without mixing YOU and TEAM attribution.
- Existing72 particles and48 boss telegraph textures. No per-frame frame/font/texture creation.
- Exactly500 renders with25 actors and actual changing HP: **106 frames /1,586 textures /111 font strings**, unchanged after the loop. This is bounded WoW-object evidence, not zero Lua allocations or native frame-time benchmarking.
- Recoil affects only draw coordinates; model positions/hitboxes never move. One damped pulse rather than repeating screen shake. Health immunity uses steady translucency rather than rapid flashing.
- No UIParent/world camera movement. Useful contact tint/trails remain with Reduced Motion; gameplay movement and essential telegraph poses remain.

## R4 compatibility and network evidence

Model/Protocol bytes are unchanged from the release:

- Model SHA256 `8A3CC601D90DF656169038A774BEB94397D5B8BC0D4D815DFDBD17D765A4E41B`
- Protocol SHA256 `C5017E7950EC6B511EF5F9A47564572FAF492F46BE20867C8A5805E4575EEB49`

This candidate retains **R4 compatibility with published v0.4.0**, unlike v0.3.0/R3. Use the same candidate on testers wanting the new effects; older R4 clients retain their original presentation. No new damage acknowledgement/event packets, health/cooldown changes, snapshot cadence or budget increases.

Full existing network suite rerun:
- Maximum valid world: **494 body bytes**,3 fragments,593 payload/641 charged bytes,largest packet209/255.
- Forty96-byte-name participants: admission41.3s; host4.20msg/s,618.7 payloadB/s,685.9 chargedB/s; queue53/128,world gap1.5s.
- Mixed40 real nodes =20 human actors+20 spectators plus5 AI:82.9 simulated seconds through four moving bosses/combat/replay,4.35% per-recipient loss,0–300ms jitter/reordering/duplicates; exact final convergence.
- Mixed host3.46msg/s,457.8 payloadB/s,513.1 chargedB/s; group36.00msg/s,1,375.9 payloadB/s;402 heartbeats; queue41/128; maximum world gap4.0s.
- Unchanged8msg/s and700 chargedB/s token budgets, with every emitted message checked. A single AI clears four bosses in100.8 game seconds; five AI50.8s Co-op/85.2s Brawl.

These are simulation figures, **not live40-client transport proof**. Full worlds remain1.25s; no prediction. Seven-second warnings exceed the measured4s gap, not arbitrary delay/loss. Damage deltas may arrive late or be intentionally omitted after a stale/gapped interval. Friendly/nonprecision play, no competitive fairness or host migration claim.

## Inspected visual sequence

Actual UI.lua/TOC geometry, not hand-authored concept art:
- `hit-before`:10/10 exposed boss, no new loss effects.
- `hit-impact`: real Model.damage plus local Input punch, then+0.08s. Boss9/10 with YOU HIT -1HP, local80/100 with YOU -20HP, trails and bounded reactions.
- `hit-settle`:same result after+1.4s; labels/trails/recoil gone and base transforms restored.
- `hit-reduced`:same confirmed damage with Reduced Motion enabled; static labels/trails remain, offsets/particles cleared.
- `hit-team`:consecutive client sample,total boss loss3 and local loss20; TEAM HIT attribution and SAMPLE/estimated guidance; actor metadata agrees with the four visible actors.
- `hit-shield`:10/10 HP, nine remaining floors, restored window/facade detail retained.

SVGs under `docs/previews/`; PNGs and a six-frame contact sheet under `artifacts/rampage/hit-feedback/`. Inspected outgoing/incoming distinction, local label clearance from boss face, HP trails, shield guidance and accessible Reduced Motion button. Normal-size controls/readouts show no obvious clipping in mocks. Dense25-actor native clutter/fonts/scaling remain manual. These are **MOCK LAYOUTS, not WoW screenshots**. Earlier preview files depict their historical builds.

## Manual playtest after choosing a coordinated install

- [ ] Keep publishedv0.4.0 on current household installs until choosing to test. Do not extract into the stable checkout via its junction. Candidate ZIP requires explicit test installation; reload alone does not install it.
- [ ] `/rampage solo`→PLAY. Punch air: fist and concise shield/range hint, no damage/contact number. Hit a floor:HP loss rather than fame; restored windows remain readable.
- [ ] Add AI, flatten city and chase the exposed moving boss. Verify numeric HP and exact solo YOU HIT response inside actual ground range; ground/range guidance outside it.
- [ ] Take one marked boss impact or Brawl hit. Check local recoil/trail/loss number is clear but restrained; health resets/respawn do not show fake damage. No screen/camera shake.
- [ ] Toggle Reduced Motion during an effect; motion stops immediately while static information remains. Hide/reopen/combat/stage changes must not replay old hits or retain offsets; control selection/safety unchanged.
- [ ] Two real clients in one PARTY/RAID: remote target loss says TEAM aggregate, not a local hit claim. Check subjective response at1.25s worlds, sampled range guidance, Brawl highlighting, joining/spectating/replay and sound mute/defaultOFF. Scale only after two-client response is acceptable.
- [ ] Native WoW focus/taint/fonts/scaling and optional audio remain unverified. A prior “fun tonight” report does not certify these specific checks.

## Handoff

New tested PR and unique head-labelled portable ZIP only, with every entry SHA256 checked against this checkout. No release tooling/config/workflow/installed-skill changes, no borrowed media/dependencies. Primary/release ZIP/old worktrees remain preserved. Parent performs independent review and user delivery. New explicit approval is required to merge/tag/publish; unique levels remain later backlog.
