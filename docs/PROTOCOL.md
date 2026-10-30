# Rampage R5 protocol and engine contract

## Compatibility and boundary

This is the **unreleased UI-flow/host-succession/AI-profile candidate in PR #11**, extending issues #10/#12. Wire version is **R5**, not compatible with publishedv0.4.0/R4 or the earlier `eef148f` feedback candidate. The TOC/app version remains0.4.0 until publication is separately authorized. Matching display version is not matching protocol. Every test participant must install the same new candidate.

Transport remains `ToastRampage1` addon messages over normal PARTY/RAID in one real group. Actual roster sender names are canonical Player-Realm identities. No guild-wide, instance-chat, independent-party bridge, external authority server, cryptographic authentication or Byzantine/competitive anti-cheat service is claimed. Correlation tokens/digests are not secrets/signatures. All input, membership and authority packets must pass actual sender/room/term/context validation.

Primary checkout remains on publishedv0.4.0. The owner separately authorized local installation at13:22: use a frozen head-labelled ZIP extraction, not a live edited branch, and reversibly repoint only the anniversary addon junction with installed-file hash verification. The separate install receipt records completion. No release, forced reload, other-PC access or SavedVariables changes.

## Distinct identities and capacities

- Up to **40 real admitted participants**; up to **25 active model actors**.
- Up to **5 AI** within the actor cap; AI never occupies real membership or voting seats.
- Every real participant has its own member ID, name/token, admission generation and durable host-assigned `joined` ordinal. IDs/ordinals are not wall-clock times or local discovery order.
- Role changes retain continuous membership and ordinal. Leave/rejoin is a new admission with a new ordinal. Lowest ordinal wins succession, with canonical name tie-break.
- `ownMemberID`, actor `slot`, host identity and role are independent. A host can be a watcher with **no avatar**, including after succession. No fixed assumption that member1/actor1 remains host.
- Watch→fight consumes no new human seat. At25 actors, a human can displace the oldest filler AI but not another human. A full human fight leaves the requester watching; no later automatic promotion.
- Co-op remains an internal engine/protocol mode; public UI/adapter passes Brawl explicitly. Advertised/accepted mode is validated; receiving an unsolicited mode conversion fails closed. Watching is not PvP consent.

## Ordinary display worlds

Worlds remain bounded atomic snapshots with explicit sequence/input epoch/member revision and authority term. They encode phase, stage, mode, game clock, shared building/boss HP, all human/bot positions, score/hit counters, HP/KO/immunity/protection/KOs and boss motion. A40-position member→actor mapping separates observers from actors; bot flags/IDs remain distinguishable from human membership.

Boss movement includes only an authorized phase, remaining time, fixed segment origin/target and warned lanes/cycle ID. Model decoding validates legal stage-derived patterns and bounded phase durations. A world is accepted only as a complete valid assembly from the expected authority; malformed/oversize/incomplete/stale/duplicate/reordered worlds do not partially mutate displayed state.

Normal worlds use **176-byte body fragments**, at most **3 packets**, with ordinary assembly count3 and expiry6s. Packets are at most255 bytes. The nominal complete-world cadence remains **1.25 seconds (0.8Hz)**. Name/member records arrive independently; unknown or mismatched actor identity suppresses feedback attribution until metadata catches up. Display names are not an authentication substitute for roster sender validation.

Input commands carry room, admission generation, requested/accepted role context, input sequence/epoch and term. Host rejects spectators, unknown/forged identities, replays, out-of-order/future/stale epochs, old terms and rate-invalid actions. Old host packets cannot regain authority by retaining a matching displayed room name. Host changes reset unsafe input/effect baselines rather than replay held commands.

## Host succession: authority and exact recovery

`net.term` fences authority. `net.migration`/`migrationActive` describe an unsafe transfer/election; `net.leaving` permits asynchronous graceful departure. `state.paused` stops hazards, AI and gameplay while authority is unresolved. Focus loss, UI close and real combat do **not** elect a replacement. Actual Leave, roster departure or liveness failure starts the applicable path.

### Complete checkpoints, not display snapshots

Recovery streams include a complete bounded simulation/member checkpoint:
- world state and exact game/phase/motion clocks;
- exact KO/immunity and `nextAction`, `nextPunch`, `nextBot` timers;
- participant names/tokens, generations, input/role/protection/keepalive counters, admission ordinals and member revisions;
- actor mapping, next generation/ordinal counters, AI immutable IDs and insertion order;
- current membership/authority fencing context needed to validate continuation.

Checkpoint payloads are length-prefixed and strictly parsed. An assembly is unusable until all fragments and its commit marker agree with the corruption digest. A delayed last fragment/commit cannot refresh the true age of old evidence. Recovery uses **at most2 assemblies,16,000 bytes/91 fragments each,120s evidence/assembly lifetime**. Stream cache/repair queues are bounded. No partial checkpoint can take authority.

Ordinary recent display worlds may be newer but lack exact recovery state; they are never promoted into authoritative simulation merely because they look current. Progress after the last complete valid checkpoint can roll back after a crash. This can include positions, HP and score. The observer resets on host/term/epoch changes so rollback is not shown as a new hit/heal receipt.

### Graceful Leave

The leaving host pauses, captures/sends a recovery checkpoint, identifies the ranked successor and waits for admitted recipients' readiness. A valid old-host finish authorizes the new term; the successor restores exact checkpoint state, advances term/input epoch and resumes only when safe. A watcher remains a watcher. The departing host's actor is removed as an ordinary departure; other actor/AI state is preserved.

Leave is asynchronous and bounded, not a single-frame operation. If evidence/acknowledgments cannot finish before the deadline, the old host leaves and peers recover only with sufficient complete evidence. UI must not label transfer as already complete while `leaving` is true. Graceful timings and tested loss cases are recorded in QA; do not equate a simulated checkpoint transfer with live WoW transport performance.

### Unexpected loss and membership fences

Eligible candidates use the **certified committed admitted membership**, matching checkpoint/term/revision and actual roster identity—not every person in the native raid. Unopened/uninstalled group members are not voters. Stable small Rampage rooms inside larger native groups must remain recoverable.

Membership changes use a monotonic revision fence and acknowledgments across intersecting old/new admitted sets. A participant acknowledging a newer membership fence must not later vote from an older small checkpoint merely because the new certificate was lost. During incomplete membership evidence, simulation/recovery pauses. This prevents the unsafe shortcut of simply shrinking the voter set to whichever few clients are visible locally.

Vote locks and monotonic floors live in a bounded40-entry host/session/term incarnation history outside ordinary Leave/reset. A replacement admission may acknowledge an older generation only while the same live process remembers unbroken never-voted lineage; the packet includes its first remembered generation. Already-emitted votes cannot be retired by Leave/rejoin, a newer-generation ACK, or the host simply not seeing that person in its roster. A late adopter emitting recovery witnesses also locks its old incarnation before changing term, even if it learned the quorum without casting an initial ballot. Explicit never-voted departure can retire only the authenticated current incarnation. Host-only asymmetric roster shrink is not a receipt.

A real reload/process restart loses volatile lineage. It starts at the new admission generation and **cannot certify forgotten old generations**. If too few old voters remain to establish a safe membership fence—particularly a two-person room after a guest reload—the host pauses; participants may need to Leave and deliberately establish a fresh room. Ordinary in-process Leave/rejoin preserves lineage. This is a deliberate availability limit, not a claim of durable vote storage or transparent reload recovery.

Candidates announce liveness, wait a bounded grace window, rank continuously admitted responsive members and require sufficient matching voting evidence before adopting. Host leases bound old-authority continuation; repeated/replayed liveness does not indefinitely extend a lease. Old terms, forged candidates, mismatched checkpoints, stale membership and duplicate votes do not authorize takeover. Subsequent late old-host messages or a rejoining old host do not reclaim leadership; rejoin is normal new admission.

After adoption, participant liveness uses authenticated current election/ready evidence rather than old checkpoint last-seen ages. This prevents a healthy voter from being expired immediately on the first successor tick, which previously broke40-node crash convergence. Unseen crash peers remain protected during the bounded reconciliation window.

Configured waits:20s host-snapshot timeout,14s old-host lease,16s election grace,40s bounded election window and35s graceful Leave deadline. These are stage bounds, not an assertion that every recovery fits the largest single timer; a crash includes detection plus election/convergence. Small/large measured timings are listed in QA.

**Limits:** network partitions do not permit perfect consensus/availability without an external authority. An inconsistent/stale checkpoint, incomplete membership fence, insufficient admitted votes or prolonged/asymmetric partition may remain paused and require Leave/rejoin after the group heals. Crash recovery takes detection+election+convergence time, not an instantaneous handoff. Native roster observations are trusted and can differ temporarily. No split-brain-proof/Byzantine guarantee or zero-loss recovery is claimed.

## Fair AI profiles and deterministic continuation

Profile identity derives from immutable botID, not local actor slot or a client-side random seed:

| botID | Profile | Decision cadence |
|---|---|---|
|1|Smasher, west-first roof-down demolition|0.4s|
|2|Chaser, objectives near boss then exposed pursuit|0.3s|
|3|Scrapper, short rival hunt then objective fallback|0.5s|
|4|Dodger, earlier avoidance and safe objectives|0.6s|
|5|Smasher, east-first bias|0.5s|

Absolute authoritative game-clock scheduling uses a per-ID phase offset. Existing exact `nextBot`/action/PvP timers are checkpointed; no new profile labels or client randomness inflate the wire. `Model.botProfile(botID)` exposes local metadata for crew tooltips/Settings. Different target priorities and action traces—not only labels—are tested.

Every profile calls the same legal Model actions as humans. Health100, PvP20 damage, boss35 damage,0.2s action gate,0.6s PvP damage cooldown, immunity, range and knockback remain unchanged. Co-op never inflicts ally punch damage. Scrapper diversions are bounded; every profile must progress city/boss objectives. Cautious does not mean invulnerable. Pause/replay/remove-readd/late-add and exact migrated behavior are covered by deterministic tests.

## Faster boss contract

Shared constants and aliases:
- `PATROL_TIME` / `BOSS_PATROL`:3s
- `WARNING_TIME` / `BOSS_WINDUP`:7s
- `IMPACT_TIME` / `BOSS_ATTACK`:0.5s
- `HAZARD_COOLDOWN` / `BOSS_RECOVER`:3s

Cycle13.5s instead of17.5s;22.857% shorter. Patrol travels at most two lanes within2–6. Warning origin/targets lock, never follow a dodge; at least four lanes remain safe. Snack Tax hits only ground height; other bosses affect marked columns at all heights. Damage occurs once through Model, never through UI.

`bossPosition`/`bossInReach` drive host combat, AI and presentation. Remote interpolation can advance only within the already received patrol segment, capped at its endpoint and2.5s sample age, freezing on pause/staleness. Warning/countdown labels are samples, not exact host time. A0.5s impact can fall between worlds; only timely consecutive known-warning evidence permits short static aftermath, not predicted damage or delayed projectile replay.

## Feedback and input invariants

`Feedback.lua` observes immutable authoritative numeric deltas without changing HP, score or the wire. Around a host/solo local action, it records before/after evidence and defers synchronous callbacks to preserve exact YOU attribution. Unrelated prior changes remain TEAM. Client successful sends only show swing intention; target loss is labelled TEAM aggregate.

Health loss, score/fame and hit counters are distinct. Air swings create no contact sparks/numbers. Heals, respawn, stage/replay/role/known occupant changes, authority changes, stale/gapped/reordered samples and reopen rebaseline. Prior sample age is checked before timestamp replacement, including no-intermediate-render stalls; exactly2.5s remains timely. Queues cap32 and8 nonlocal receipts;12 reused labels prioritize local/boss clarity. Reduced Motion changes draw effects only.

Mouse/Keyboard UI reflects actual capture. INFO/SETTINGS and safety releases never auto-recapture. Ordinary stage transitions preserve selected routing but clear held actions until fresh input. Combat reconciliation happens before model hazard/AI ticks; unavailable external combat state still has inherent notification/detection delay.

## Resource and validation limits

All normal, membership, recovery, repair and election traffic uses the same per-sender limits:
- 8 messages/s with a 10-message burst;
- 700 charged bytes/s with a 1,000-byte burst;
- 16-byte charged accounting allowance per packet;
- 255-byte maximum packet;
- queue cap128 with bounded coalesced keys;
- no unlimited assembly, retry or world-replay backlog.

A short-run average above700 can consume the explicitly allowed initial burst; it is not proof of bypassing the token bucket. Sustained budget and exact per-emission token assertions are both measured. Do not report old R4 payload metrics as R5 recovery metrics. Final normal-world maxima,40-node admission/gameplay gaps, graceful/crash transfer timing, checkpoint sizes and AI continuation results appear in [QA.md](../QA.md).

Headless evidence is Fengari Lua5.3 semantics with separate Lua5.1 grammar. Actual-TOC strict WoW mocks and source-derived previews test integration but cannot certify native frame-time, fonts/scaling, focus/taint or live PARTY↔RAID delivery. Start with solo, then two real clients on the same candidate, before scaling to a raid.
