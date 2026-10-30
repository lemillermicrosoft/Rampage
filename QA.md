# QA — combined UI flow, succession and AI playtest

## Candidate boundary

This extends PR #11 / issues #10 and #12 on `feat/issue-10-hit-feedback`, based on previous reviewed candidate `eef148fdb21acb4c468c36166b15e92af651d7e4`. Sole edited checkout: `C:\Users\leroy\repos\Rampage-hit-feedback`.

**Owner-authorized release, Oct30 at13:59:** positive in-game feedback followed by "I think we can publish this version." This release preserves approved installed b98c93c gameplay and its seven-second boss warning. The later maximum-three-second warning and control/alignment work are separate; Blizzard assets remain deferred.

The final versioned runtime is fully tested before tag/upload. The primary main checkout advances to the release while its unrelated untracked Explorer `docs/previews/Thumbs.db` remains untouched. No source/gameplay edits beyond version synchronization. The owner's actual anniversary addon junction stays on the frozen b98c93c candidate; publication does not relabel it. Old ZIPs and worktrees remain. An old rollback junction targeting primary now follows the new main; use the preserved v0.4.0 ZIP/frozen runtime for actual old-version rollback. No forced reload, SavedVariables edit, other-PC access or unrelated configuration changes.

**Wire R5 requires every player to upgrade from v0.4.0/R4.** The b98c93c candidate already uses the same R5 gameplay, but the versioned release ZIP is the coordinated distribution. Co-op code remains internal; public paths expose Brawl and never silently convert a room. Owner live feedback is not proof of two-client/full-raid, native focus/taint or every rendering configuration.

## What was checked locally

- Actual UI/TOC suite: **36 tests** retained/adapted for requested flows, including all original hit-feedback, building layers, keyboard safety, stale effect and optional-audio coverage.
- Additional fresh real-adapter/two-node flow suite: **8 tests**, including actual packet exchange and profile tooltip metadata—not fake net-method success.
- Feedback suite: **40 tests**, including new term/migration pause baseline reset alongside39 prior attribution/lifecycle tests.
- AI/model suite: **37 tests**, including real short trace divergence, each-profile completion, fair action/damage gates and time-partition determinism.
- Syntax scope: **12 Lua files** (seven actual TOC modules plus five test files).

**Final full `npm test`:174/174 PASS —37 Model,53 Protocol/migration,40 Feedback,36 actual-TOC UI,8 real-adapter flow.** `npm ci --ignore-scripts` reproduced the locked dependencies; `npm run check:lua51` parsed12/12 Lua files; `npm audit --audit-level=low` found0 vulnerabilities; `git diff --check` clean. Runtime/test SHA256 values were captured before the full run and remained unchanged afterward. Full log and tested-source hash receipt are in `artifacts/rampage/ui-flow/`; the head-labelled package manifest records final archive evidence. Execution is **Fengari Lua5.3 semantics**, with a separate Lua5.1 grammar pass. Neither is native WoW execution. Strict API mocks reject unsupported methods; source-derived geometry previews are not native screenshots.

## Polished UI and real input flow

Main window is city-first900×660 with compact host/count/Brawl status, boss health/telegraph, local health and one contextual participation action. Instructions moved to INFO; audio, mute, Reduced Motion, host AI controls and Leave game moved to SETTINGS. No Co-op selector or Spectate button. Brawl/PvP consent remains visible before Join fight.

Mouse/Keyboard are actual mutually exclusive selectors. Keyboard explicitly calls the existing eligible-fighter capture path; selecting it again does not release accidentally. Mouse immediately releases. Watchers cannot arm Keyboard. Actual capture—not a stored preference—drives selection, so Escape/chat/focus/combat/close return to Mouse. Ordinary intermissions retain chosen routing but clear held actions until fresh keypress. All unknown shortcuts/edit-focus/modifier/missed-key-up/long-stall releases remain; no automatic recapture.

INFO/SETTINGS release capture before opening, block gameplay keys while open, close with main hide/combat and leave Mouse selected afterward. Layout tests bound actual panel/control rectangles within the fitted window. Native font wrap and focus/taint remain manual.

### Watch and membership paths

Actual two-node adapter/protocol tests verify:
- Closed advertisements neither show the UI nor admit the player.
- Explicit window open auto-subscribes to the real Brawl host as spectator with no avatar/keys.
- Join fight explicitly changes to play; Leave fight returns to watch while preserving nonnil numeric admission ordinal/memberID.
- Adding/removing real AI never auto-promotes a watcher.
- Close retains admitted watch membership/tenure; explicit Leave disables auto-rejoin until a new user-open action.
- Public `host coop`/`solo coop` do not mutate or host a room.
- Discovery retries stay bounded; watching cannot arm keyboard.
- Five real Add AI calls produce at least four model profiles, and actual crew hover shows each profile label/description. Settings displays the concise automatic-mix hint.

Separate UI capacity tests cover40-real/25-actor limits, AI replacement, existing watcher switching roles at full real membership, and host-watch controls. Integration updated synthetic capacity fixtures to submit authenticated R5 membership receipts and use the real adapter settle tick; uncertified membership is explicitly asserted disabled rather than bypassing pause/certification flags. Co-op engines remain exercised internally without exposing a casual public mode path. Closing/focus/combat does not transfer the host; Leave or actual liveness loss does.

## Preserved and improved damage feedback

Incoming true HP loss produces one short damped sprite-local recoil/tint, aggregate `YOU -N HP` and health-loss trails. Exact host/solo local building/boss damage says `YOU HIT -N HP`; remote sampled totals say `TEAM HIT -N HP`. Fame and hit counters cannot fabricate damage. Client sends justify swing intention only. Air punches show no successful-contact sparks/numbers.

Immutable baseline tests cover old/duplicate/reordered/gapped worlds, independent name/mapping streams, known identity/role/epoch changes, heals/KO/respawn, final hits, visibility/combat and synchronous changed callbacks. Previous-sample freshness is measured before replacing timestamps, including no-render stalls;2.5s inclusive boundary retained. Authority term/migration resets suppress checkpoint rollback effects. Ordinary snapshots still lack a bot incarnation token: same-ID remove/re-add entirely between samples remains indistinguishable for cosmetic feedback; recovery checkpoints do retain insertion order and exact AI timers.

Visual review found simultaneous local-loss/building-hit labels overlapping in the new fighter scene. The integration fix stacks conflicting labels in the fixed12-entry pool; regression asserts at least148px horizontal or19px vertical separation. Local/boss slots take priority; excess decoration is omitted above the playfield instead of hiding HP. No gameplay position/hitbox changes or world/window shake.

Reduced Motion immediately removes decorative recoil/bob/bounce/number rise/particles while retaining static numbers, trails and highlights. Exact cleanup is checked on expiry/hide/KO/combat/stage/known identity change. Original window panes/crossbars/sills/roof/facade explicit draw layers and damaged alpha remain checked.

### Object pools

Exactly500 renders with25 actors and changing real HP retain **111 frames /1,593 textures /129 font strings**, **12 damage labels /72 particles /48 boss-cue textures**. No frame/texture/font creation per render. This demonstrates bounded WoW-object pools, not zero Lua allocation or native frame-time performance.

## AI variation: behavior, not just labels

ImmutablebotID profiles and actual decision intervals:
1. Smasher west-first roof-down demolition —0.4s.
2. Chaser city work near boss, then exposed pursuit —0.3s.
3. Scrapper short Brawl rival hunts then objectives, Co-op fallback —0.5s.
4. Dodger early escape/safe objectives, ordinary vulnerability —0.6s.
5. Smasher east-first target bias —0.5s.

Per-ID offsets on the authoritative game-clock schedule prevent lockstep without unseeded randomness. Existing `nextBot`, `nextAction`, `nextPunch` checkpoint fields preserve exact scheduling; no extra profile strings inflate the wire. Human action/range/cooldown/immunity/damage rules are reused unchanged. No teleports, health buffs, LLM/service or real WoW character input.

Executed model evidence:
- **First2.9s:** five distinct actual action paths and timing schedules. West Smasher/Chaser/east Smasher prioritize towers2/4/6. Repeated runs and0.1/0.05/0.03+0.07 tick partitions agree.
- Every botID completes all four bosses in both retained Co-op and Brawl, under300s: westSmasher94.0s,Chaser83.2s,Scrapper102.7s,Dodger168.3s,eastSmasher158.4s. Exact shared objective score retained.
- Five mixed AI clear all four bosses in **37.5s Co-op /40.0s Brawl** in the fixture. A solo westSmasher clears in94.0s.
- Scrapper targets only eligible rivals briefly and returns to objectives; Co-op never inflicts friendly punch damage.
- Dodger earlier avoidance is real but it retains ordinary HP/punch/boss/knockback/KO vulnerability. The solo-completion fixture happens to avoid all boss damage; separate targeted tests establish damageability, not an immunity claim.
- Legal action comparison covers city/boss near/far/elevated and rival range/height, exact objective/PvP damage and cooldown parity. Runtime traces check no teleport or damage buff.
- Pause/replay/reset, remove/re-add/late-add immutable identity and authoritative snapshot reconstruction preserve decisions/cadence. Protocol tests additionally exercise actual graceful/crash continuation.

## Faster boss timing and legal escape

Cycle now **3s patrol+7s warning+0.5s attack+3s recovery=13.5s**, versus17.5s; **22.857% shorter**. Shared constants drive model, decoder and UI. No HP/damage/cooldown rebalance. Actual cycle tests cover four bosses, three cycles and0.05/0.1s ticks.

**64 legal boss/lane/height escape cases** passed;51 initially threatened. After a4s reaction delay, the longest required legal escape took1.0s, within the retained7s warning. At least four lanes remain safe; Snack Tax ground-only height and locked warning targets retained. Three-second recovery stays stationary/reachable. Arbitrary network loss can still hide warnings; this is not an unconditional dodge guarantee.

## Actual-UI previews inspected

Eight SVGs execute the actual TOC/UI:
- `flow-watch`, `flow-fight`, `flow-info`, `flow-settings`;
- `flow-idle`, `flow-solo`;
- `flow-ai`, `flow-ai-settings`.

AI scenes use five actual Add AI operations and3.5s of authoritative simulation, not hand-positioned profile concept art. Final PNG inspection confirms profiles spread into distinct work/positions, city detail/HP remain visible, panels fit, Mouse/Keyboard and consent states are clear, and incoming/outgoing text no longer overlaps. Settings profile hint fits above Leave game; full descriptions stay in tooltips rather than main-screen clutter.

Source SVGs: `docs/previews/`. Rasterized PNGs and contact sheet: `artifacts/rampage/ui-flow/`. **MOCK LAYOUTS, not native WoW screenshots.** Historical `hit-*`/boss preview files represent their earlier source states unless regenerated.

## Final R5 network measurements

Measured with real multi-node packet fan-out in the deterministic test transport:
- Maximum display world:494-byte body,3 fragments,614 payload /662 charged bytes, largest packet216/255 bytes.
-40 maximum96-byte-name participants admitted in52.1s; host4.56 messages/s. Admission averaged705.1 chargedB/s by consuming part of the explicitly allowed1,000-byte initial burst; this is **not** reported as a sustained rate below700.
- Sustained40-node gameplay over103.2s with25 actors (20 humans+5 AI),20 spectators, loss/reordering/combat/four bosses: **677.0 chargedB/s,3.91 host messages/s**, worst world gap4.3s, queue45. Overall stress maximum queue56 below128.
- Small graceful handoff:1,159-byte/7-chunk checkpoint,5.3s.
-40-node graceful loss/duplicate/reordering fixture:6,917-byte/40-chunk checkpoint, **36.5s including5s settling** (31.5s before that final wait), actual all-peer acknowledgments. Old host2.93 messages/s,540.5 chargedB/s during transfer. Display gap16.3s occurred while handoff was paused, not active gameplay.
- Small unexpected-loss recovery:38.7s from a complete1,135-byte checkpoint.
-40-node crash+4.35% deterministic per-recipient loss: **44.4s including8s convergence wait**,6,934-byte checkpoint, queue45. Healthy majority then has exactly one unpaused host and advances its clock2s.
-40 native raid members but only3 admitted addon participants:38.6s recovery; only the2 admitted non-host members vote. Uninstalled/unopened peers do not prevent recovery.

Every send is asserted within8messages/s+10-message burst and700 chargedB/s+1,000-byte burst;255-byte packets, bounded queues/assemblies remain enforced. Recovery timing is a simulation measurement, not a native transport promise.

## Concrete recovery corrections and finite limits

The first combined integration run reproduced the original40-node crash convergence failure (`expected term2, got nil`). The causal issue was stale checkpoint member ages being restored as live connection ages: healthy election participants could be expired on the new host's first tick, changing membership before peers adopted. Adoption now uses current authenticated election liveness (graceful readiness for planned handoff), not the old checkpoint's wall-time ages. The original loss/reorder/duplicate fixture remains; a strengthened assertion additionally requires one actual unpaused survivor host to advance its clock for2s—not just acquire the host label.

Focused regressions passed before the full rerun:
- Original40-node crash with five AI and4.35% per-recipient deterministic loss:44.4s including8s convergence wait;6,934-byte checkpoint, queue45.
- Genuine delayed old-generation vote after voter Leave/rejoin/new generation cannot refence its old electorate and create a second ticking host.
- A late follower can adopt an existing quorum before casting its own ballot. Its subsequent old-term recovery witnesses now retain the same incarnation vote lock; a dedicated real-packet regression proves the lock survives reset. This closes the same vote-exclusion invariant for both ballot and witness emission.
- Fresh Protocol instance after process restart cannot claim it remembers a forgotten old-generation vote fence; membership remains paused.
- Host-only asymmetric roster shrink cannot certify absent old voters as safely retired; at most the evidence-backed successor runs.
- Graceful AND crash mixed-profile recovery each match **1,200 exact per-bot decisions across24s**, including `nextBot`/action timers and full world comparison against the checkpoint reference.

Membership uses admitted voters rather than uninstalled/unopened native raid members. Stable40-native/3-admitted recovery is tested separately. A monotonic configuration fence requires an intersecting portion of old/new admitted voters, with bounded same-process incarnation history preventing post-vote ACKs after rejoin. Explicit never-voted departure can retire the authenticated current generation; mere roster absence or new-generation ACK cannot erase an outstanding old vote.

**Availability is deliberately finite:**20s host-snapshot timeout,14s old-host lease,16s election grace,40s election window and35s graceful Leave deadline. Missing/expired checkpoint, insufficient matching votes, unsafe membership transition or long partition pauses rather than runs two authorities. A real reload loses volatile lineage; if not enough old voters can certify replacement membership (notably a two-person room), participants may need to Leave and establish a fresh room. No guaranteed seamless reload/crash, no perfect consensus, no durable vote store. Checkpoint evidence expires after120s; a crash may roll back uncommitted world/HP/score, not just cosmetics. Native roster/identity and honest addon participants are assumptions; this is not Byzantine anti-cheat.

## Native test checklist after a deliberate install

- [ ] Install the same new R5 candidate on the chosen testers; keep publishedv0.4.0 rollback. Do not extract through the stable checkout junction. Reload alone does not install.
- [ ] `/rampage solo` → Settings → Add AI five times. Watch different targets/pace; hover profiles. Try Mouse then Keyboard. Escape/chat/Info/Settings/close/combat must release without recapture.
- [ ] Hit air/floors/exposed boss; take damage, inspect receipt/trail/readability, toggle Reduced Motion during a reaction. No window/camera shake or stale effect on reopen/stage/recovery.
- [ ] Two clients in the same PARTY/RAID: opening watches; Join fight explicitly consents; Leave fight keeps membership; Close hides; Leave game prevents immediate rejoin.
- [ ] Host Leave: wait through visible transfer pause; oldest admitted watcher/fighter becomes host without forced avatar. Check other scores/HP/AI continue. Test crash only with rollback expectations; do not assume instantaneous/always-available recovery.
- [ ] Test group roster changes, party↔raid/subgroup routing, native fonts/scaling/focus/taint, optional audio and real latency before larger raids.

Publication of this identified build was explicitly authorized Oct30 at13:59. Parent verifies final tag, GitHub downloaded-asset hash and CurseForge upload receipt separately from public approval, then delivers release links. Future feature changes need a separate candidate; no forced reload or silent installed-file replacement.
