## Three-second warnings and focused control polish

For WoW Burning Crusade Classic2.5.6 / Interface20506. The owner explicitly authorized publishing this completed issue13 follow-up on October30,2026. It preserves the v0.5.0 Brawl/watch, host-succession, hit-feedback and varied-AI gameplay while shortening the real warning clock and polishing the existing original UI. Blizzard/native asset skins, a style toggle, unique levels and AFK-dialog changes are not included.

### Upgrade every participant together

This release uses **R6**. Published v0.5.0 and the earlier frozen b98c93c candidate use R5 and cannot participate, even though that candidate displays0.4.0 and this source displayed0.5.0 before release. Timing, AI and checkpoint simulation semantics changed; matching display labels or packet field widths are not compatibility proof. Install the same versioned release ZIP on every participant, with one `Rampage` folder directly under `Interface/AddOns`, then safely `/reload` when ready and out of combat.

Publication and local installation are separate verified operations. No forced reload, external SavedVariables edit or other-PC access. Preserved versioned ZIPs/frozen runtimes remain rollback points; a junction to moving primary main is not an immutable old release.

### Real three-second boss warnings

- Every boss now uses **3s patrol +3s locked warning +0.5s impact +3s recovery =9.5s**. Warning-to-impact is actually three authoritative game-clock seconds, not a relabelled countdown or hidden earlier seven-second phase.
- Warning origin and lanes remain locked; damage applies once in Model. Shared moving hitboxes, shields, range,100HP,35 boss damage,20 Brawl damage, action/PvP cooldowns, pause and exact checkpoint clocks remain.
- Dodger begins avoidance at2.5s remaining; Smasher/Chaser/Scrapper at2s. Their normal0.3–0.6s decision cadences and legal movement/range/damage rules remain. No AI gains immunity, stronger hits or teleports.
- One newly locked warning requests an early ordinary full-world snapshot through the existing bounded queue. A pending world completes first; capture retries when it drains. There is no separate hazard event, predicted impact, client-side damage or larger transport cap.

Healthy two-client simulation covered80 combinations of four bosses, ground/top-floor starts and five snapshot phases using200ms round trip,20fps ticks,0.5/0.75s reaction and250ms legal repeated input. All escaped; worst warning notice0.8s, minimum margin0.3s, maximum five actions. This is a measured envelope, not a guarantee for slower input, congested/lossy raids or native Blizzard transport. A blackout longer than three seconds can hide the complete warning; the host still applies exactly one authoritative hit and later state must not replay it. Dodge promptly.

### Original segmented controls and alignment

- Mouse/Keyboard are equal original112x30 segments with separate indicator, selected fill and border—no bracket/ASCII radio labels. The segment shows the saved preference; separate status text truthfully distinguishes Keyboard active from preferred/inactive.
- Keyboard is the fresh default. Existing valid Mouse/Keyboard settings persist; nil/invalid legacy values migrate to Keyboard. Preference can be changed while idle, lobby, auto-watching or host-watching without admission/action packets, avatar creation or key capture.
- Explicit Join fight arms Keyboard only when the accepted fighter role reaches active play. A full/denied join stays watching with preference preserved and no capture. Mouse remains uncaptured with action buttons. Leave fight releases but preserves preference; explicit rejoin can activate it again.
- Escape, chat/edit focus, modifier/focus loss, interruption, combat, Info/Settings, close, KO and watching release capture immediately without changing preference or automatic re-grab. Ordinary city transitions retain active keyboard routing while clearing held actions until release/fresh press.
- Header buttons, primary action/help row, selectors/mouse actions, crew stats, local HP/bar and footer baselines share consistent spacing. Long status/name and7HP fixtures remain bounded. The duplicate shield badge that overlapped the ground rail was removed; numeric shield health and the single reach label remain.
- Window stays900x660. Fixed mock pools after500 renders:111 frames,1,606 textures and131 font strings. Original facade panes/trim, Info/Settings, confirmed hit feedback, Reduced Motion and optional audio-off-by-default remain.

### Multiplayer and recovery limits

R6 remains normal PARTY/RAID within one group: no independent-party bridge, instance-chat transport, external server or competitive anti-cheat claim. Maximum tested world is494 body bytes /3 packets /662 charged bytes, largest216/255. Forty maximum-name admissions took57.0s, queue53. Sustained107.7s mixed play measured684.3 chargedB/s,3.95 host messages/s, queue45 and5.0s worst active display gap. A short admission average can consume the allowed initial burst; it is not a sustained-rate claim.

Host succession remains intentionally conservative. Small graceful handoff measured5.3s. Forty-node graceful loss/reordering measured36.3s including settling with a6,919-byte/40-fragment checkpoint; crash with4.35% recipient loss measured44.5s including convergence using6,933 bytes, then the unique successor advances. Sparse40-native/3-admitted recovery measured38.7s and only admitted members vote.

Recovery is not instant and crashes can roll back uncommitted world, HP and score. Missing matching checkpoints, admitted-voter quorum or safe membership fences pauses instead of running competing authorities. Native roster absence alone does not retire a vote. A true process restart forgets volatile lineage and may require a fresh room, especially with two participants. This is not perfect partition consensus or Byzantine resistance.14s lease,20s host detection,16s election grace,40s election window,35s graceful deadline and120s checkpoint lifetime remain distinct.

### Verification and first checks

The settled candidate passes **179 checks**:37 model,55 protocol/migration,40 feedback,39 actual-TOC UI and8 real-adapter flow. SavedVariables migration and real idle/watch/lobby/join/full-denial/leave/rejoin preference lifecycles are included in the UI/flow suites, plus separate Lua5.1 grammar and zero dependency audit findings. The release pipeline reruns the complete suite against the final version-bumped runtime before tag or upload. Fengari executes Lua5.3 semantics; grammar parsing and mocks are not native WoW.

The old snapshot scheduler was restored only in memory against the same80-case test and missed two Queuezilla top-floor cases; the bounded warning-onset request passes all80. Exact checkpoint remaining times3/1.37/0.01s pause/resume to one locked impact for every boss. Graceful and crash adoption each preserve1,200 exact AI decisions across24s. All prior delayed-vote/rejoin, fresh-process lineage, asymmetric roster, witness-lock, input safety, automatic-watch consent, hit attribution and stale-effect regressions remain.

Source-derived before/after/watch/fight/solo/Info/Settings/low-HP/long-name/keyboard previews were inspected at native-like scale, but they are strict mocks—not native screenshots. Native fonts/scaling/layering, keyboard focus/taint, optional audio, subjective feel and real two-client/large-raid delivery remain manual. Start with solo plus five AI, then two real clients on the same R6 release before scaling.
