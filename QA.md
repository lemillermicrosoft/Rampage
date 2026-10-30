# QA — issue13 short warnings and focused control polish

## Candidate boundary

New isolated `feat/fast-windup-controls` branch from published v0.5.0 `c0f906d2b13382c4414518a53304d6f637c7090a`. Primary tracked files/head, unrelated untracked Explorer cache and actual frozen b98c93c installation remain untouched. Old worktrees and v0.4.0/eef/b98/v0.5.0 archives are preserved. Genuine old-version rollback is the v0.4.0 ZIP or `release-preflight/frozen-v0.4.0/Rampage`, not a junction to advancing primary main.

**Unreleased/not installed.** R6 intentionally rejects R5/v0.5.0 and earlier protocols because duration/AI/checkpoint semantics changed despite identical field widths. TOC/app remains0.5.0; every tester needs the same new head-labelled candidate. Parent independently checks before coordinating installation. No merge/tag/bump/CurseForge upload, forced reload, SavedVariables, other-PC access or release-tool edits. Native assets/toggle, unique levels and AFK dialog work deferred.

## Actual timing and AI proof

- Actual constants3s patrol /3s warning /0.5s impact /3s recovery. Four bosses, three cycles each,0.05/0.1s partitions measure **9.5s**, versus13.5s prior:4s /29.630% shorter. Warning is not merely relabelled or hidden behind another phase.
- All64 legal lane/tower-height cases (51 threatened) escape using legal Model actions after **1.5s reaction**, maximum action sequence1.0s. Locked origin/lanes stay fixed and impact occurs at exactly3s with unchanged35HP damage once.
- Shared3s aliases, phase pauses, knockback, ranged/all-height versus ground-only stomp, real fractional hitbox, shield,0.2s action gate,0.6s PvP gate and ordinary HP/immunity remain.
- Dodger begins avoidance at2.5s remaining; other profiles at2s, still bound by their normal cadence. Distinct choices and targets, no extra damage/teleports/immunity. Five mixed bots clear all four bosses in39.4s Co-op /41.8s Brawl.
- Individual Smasher/Chaser/Scrapper/Dodger/east-Smasher clear in108.4/82.9/143.7/156.3/158.9s in either mode. Scrapper and Dodger each take35HP in their actual deterministic run; cautious is not invulnerable. All exact shared-score/action-gate and mixed cadence tests retained.
- For each boss, serialized exact checkpoint remaining3/1.37/0.01s survives a5s pause and resumes to the same single locked impact; damage does not replay. Existing actual graceful/crash adoption each preserves1,200 per-bot decisions across24s.

## Human reaction over actual transport

The test uses two actual protocol instances with real admission/certification, bounded outbound queues and packet parsing. Client decisions use only received warnings/positions; input goes through the real client sender and authoritative receiver. No direct client warning injection, synthetic host action or teleport substitutes for delivery.

**80 cases:** four bosses, ground/top-floor start, five snapshot phases,0.5/0.75s reaction,200ms round trip (100ms each way),20fps ticks and250ms legal repeated inputs (205ms keyboard interval rounded to20fps). **Zero hits**, worst complete-warning notice0.8s, minimum escape margin0.3s, at most five actions. This is one measured healthy envelope, not an arbitrary latency guarantee. At10fps and300ms repeated presses, a slow top-floor dodge can still miss; native gameplay should dodge promptly or choose a safer starting position.

The same80-case matrix with ONLY the old snapshot scheduling restored in memory fails in two Queuezilla top-floor cases:0.75s reaction, late snapshot phases0.9/1.2, notice1.2/1.3s. Probe does not modify repository files. The retained fix requests one early ordinary full snapshot on actual warning onset; pending worlds finish first. Capture retries after queue drain, rather than discarding fragments or waiting another1.25s interval. Existing snapshot/control priorities,3-fragment bound,1.25s ordinary interval and all byte/message caps remain. No second hazard-event protocol, predicted impact or client-applied damage.

**Blackout truth:** suppressing snapshots across the entire3s warning hides it and the stationary actor takes exactly35HP. Reconnection updates displayed HP without applying/replaying another hit. The candidate does not promise sufficient warning under >3s blackout,40-node congestion/loss, low frame rate or slow reaction. Short0.5s attack poses may be skipped; timely known-warning aftermath is cosmetic only, with stale/gapped resets retained.

## Retained network safety

Sender/room/term/generation/role/input validation; authenticated admission and explicit Brawl consent; automatic-watch user-intent boundary;25 actors versus40 real members; five AI not voting members; old-host lease fences and certified admitted-voter elections; delayed old votes, fresh-process lineage, asymmetric roster shrink and witness locks all remain required regressions.

No instant host succession claim. Graceful transfers pause; crash recovery can roll back uncommitted HP/score/world progress. Missing complete checkpoints, old membership fences or real quorum pauses safely. True process restart forgets volatile history and can require a fresh room, particularly with two participants. Native roster is trusted; this is not Byzantine anti-cheat or perfect partition consensus.14s lease /20s loss detection /16s election grace /40s election window /35s graceful deadline are distinct existing phases;120s checkpoint evidence lifetime retained.

Transport caps remain8messages/s+10-message burst,700 charged bytes/s+1,000-byte burst,16 charged bytes/packet overhead,255-byte packets,128 queued entries,3 ordinary assemblies and2 recovery assemblies. Short admission averages may consume initial burst; they are not sustained-rate claims.

Current R6 measurements: maximum494-byte world body /3 packets /614 payload /662 charged bytes,216-byte largest packet. Forty maximum-name admission57.0s,704.5 chargedB/s including initial burst,4.55 host messages/s, queue53,1.5s snapshot gap. Sustained107.7s mixed play:684.3 chargedB/s,3.95 host messages/s, queue45,5.0s worst active display gap. Small graceful checkpoint1,160 bytes /7 chunks and5.3s handoff; crash38.7s from1,135-byte checkpoint. Forty-node graceful6,919 bytes /40 chunks,36.3s settle,525.7 chargedB/s,2.87 messages/s, queue44 and18.2s display gap. Forty-node crash4.35% loss:6,933 bytes,44.5s settle, queue44, unique host advances2s. Sparse40-native/3-admitted recovery38.7s.

## UI verification

Original segmented controls/alignment use existing primitives, no native asset skin or new dependency. Segment selection shows persisted preference; separate status shows Keyboard active versus preferred/inactive. Fresh/nil/invalid DB values become Keyboard, valid saved Mouse/Keyboard survive. Idle/watch/lobby/host-spectator toggles send no join/role/action packet and cannot create an avatar or capture keys. Explicit Join arms preferred Keyboard only after accepted fighter role and active play; full denial preserves preference/inactive state. Leave fight releases and preserves; rejoin applies preference. Mouse remains uncaptured. Escape/chat/focus/combat/Info/Settings/close/KO/watch safety releases cannot auto-regrab or silently switch preference. Ordinary intermission keeps active capture but clears held input until release/fresh press. Button labels do not change geometry; status text and city/boss/footer/crew baselines have reserved regions.

Actual-TOC WoW mocks and source-derived matched before/after/solo/watch/fight/info/settings/lowHP/longname SVG/PNG fixtures are inspected at native-like scale. Test intact/damaged facade ordering, long labels, localHP, selected/hover/pressed/disabled state and stable pooled allocations. These are mock-layout proofs, not new native screenshots. The owner's prior positive screenshot was for the previous build and is a visual reference only.

Confirmed-hit attribution, stale-sample resets,12 pooled labels/72 particles, boss48 cue textures, local-only recoil and ReducedMotion/static feedback remain. Original building panes/crossbars/trim are not removed. Optional audio stays off by default.

## Final settled-source gate

Settled candidate counts are37 model +55 protocol/migration +40 feedback +39 actual-TOC UI +8 real-adapter flow =179. Current40-node measurements and inspected images are above; the final versioned package manifest and release receipt are recorded at publication handoff. Run full `npm test` after file ownership settles, compare runtime/TOC/test SHA256 before/after, run separate `npm run check:lua51`, locked `npm ci --ignore-scripts`, `npm audit --audit-level=low`, and `git diff --check`. Fengari executes Lua5.3 semantics; separate Lua5.1 grammar is not native runtime proof.

## Manual playtest

1. After parent verifies/coordin­ates installation, safely reload when ready/out of combat; all participants need the same R6 ZIP, not published R5.
2. `/rampage solo`: observe each true3s warning/9.5s cycle and dodge promptly; try all AI profiles. Check damage occurs once and pause freezes remaining time.
3. Before joining, switch Mouse/Keyboard while idle and watching: preference changes, but no avatar/keys/actions. Fresh settings should show Keyboard; a saved Mouse setting should remain Mouse. Inspect selected indicator versus separate active/inactive status, hover/press styling, lowHP bar/text and header/footer alignment.
4. Same-build two clients in one PARTY/RAID: open to watch, choose Keyboard, explicitly Join fight, then verify activation only after fighter acceptance/active play. Escape/chat/alt-tab/combat/Info/Settings release without preference change or recapture; Leave fight stays watching/inactive and explicit rejoin applies preference. HostLeave transfers without restarting. Test real warning visibility/dodge before considering larger raids.
5. Native rendering/fonts/scaling, focus/taint, optional audio, subjective feel and actual large-raid delivery remain manual. No headless test certifies arbitrary network loss.
