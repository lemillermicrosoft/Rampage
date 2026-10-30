# Rampage — FOUR MORE BOSSES!

**<Toast>'s pocket raid-break arcade.** Original monsters smash a shared city, then flatten four fictional bosses. For **TBC Classic 2.5.6 / Interface20506**. Original art inspired by classic climb-and-smash play; no affiliation with the original Rampage game's owners.

## R6: three-second warnings and preferred controls

Issue [#13](https://github.com/lemillermicrosoft/Rampage/issues/13) follows published v0.5.0 with **real three-second boss warnings**, original segmented Mouse/Keyboard controls and focused layout/alignment improvements. It retains confirmed hit feedback, Brawl-first automatic watching/explicit fighter consent, INFO/SETTINGS, oldest-admitted host succession and four varied AI profiles.

**All testers need the same R6 release.** Published v0.5.0 and the earlier installed `b98c93c` candidate use R5 and cannot join it. Field widths are unchanged but timing/simulation semantics differ, so old peers are explicitly rejected. Matching an old display label does not establish compatibility.

The owner explicitly authorized publishing and installing this completed issue13 scope on October30,2026. Publication uses the reviewed versioned ZIP; the local addon is frozen from that exact release after archive verification, never linked to an editable worktree/main. No forced reload or SavedVariables edits. Previous releases/candidates and genuine frozen v0.4.0 rollback remain preserved.

Blizzard/native assets or a skin comparison toggle, unique levels and AFK dialog investigation are **not included**.

## Start playing

1. After coordinating installation of the same R6 candidate on every participant, type **`/rampage`**. In a PARTY/RAID, opening automatically watches an available Rampage room. Watching creates **no avatar, damage target or captured keyboard**.
2. Click **Join fight** to explicitly enter **BRAWL / PvP**. **Leave fight** returns to watching without leaving the room. A full fight keeps you watching; a seat becoming free never auto-joins you.
3. **Keyboard is the fresh default.** Choose Keyboard or Mouse while idle, in a lobby or watching—this saves only a preference and never joins, creates an avatar or captures keys. After explicit **Join fight** is accepted and active play begins, Keyboard may activate through the normal safe lifecycle; Mouse remains uncaptured with action buttons. Escape releases capture but keeps Keyboard preferred/inactive; it does not silently switch the saved preference or auto-recapture.
4. If no room exists, choose **Host Brawl**, then Start. **Solo practice** or `/rampage solo` starts local Brawl without requiring a group. Solo and hosting do not automatically capture keys.
5. **SETTINGS → + Add AI** adds a mixed-profile bot. **INFO** contains instructions, shortcuts and feedback explanations. Settings holds audio/mute, Reduced Motion, owner AI controls and **Leave game**.

Only Brawl is exposed in the UI/public new-game commands. Co-op Model/Protocol code remains for future use and regression tests. A legacy/internal Co-op room is never silently changed to PvP; this public UI can watch but does not offer a casual Co-op fighter path. `/rampage solo coop` and `/rampage host coop` are rejected, not reinterpreted.

### Watching and room ownership

- Existing selected room remains sticky. If several unrelated rooms are discovered together, name/session ordering chooses a deterministic fallback; independent world states are never merged. Hosting does not replace an already known room. Simultaneous unseen Host clicks are not a global creation-time oracle.
- Closed advertisements do not open the window or subscribe. Discovery is user-open/visible-gated and throttled. No-party state offers calm solo practice rather than an endless joining screen.
- **Close hides; Leave game exits.** Closing retains admitted membership and host tenure, with keys released. Reopening does not restore keyboard capture. Leave disables automatic rejoin until a fresh user open/Watch action.
- Fighter/watch role changes preserve continuous admission order. A host can watch without an avatar while retaining room controls. Focus loss and real WoW combat do not transfer authority.
- On host departure, succession uses host-assigned admission order among real participants, including watchers and excluding AI. A promoted watcher does not become a fighter. Complete verified checkpoints restore the world rather than starting a new game. Graceful Leave may spend time paused while transferring; crashes/partitions may roll back uncommitted progress or remain paused when authority evidence is insufficient. Small graceful handoff measured about5s; the40-person loss fixture about32s plus settling. Crash recovery measured about39–44s, not instant. See [QA.md](QA.md) and [docs/PROTOCOL.md](docs/PROTOCOL.md) for exact results.
- A true client reload/process restart forgets volatile voting history. If too few old members remain to safely certify the replacement membership, the room pauses rather than risking two hosts—particularly possible in a two-person room. Leave and establish a fresh room if it cannot recover. This is not seamless reload/partition recovery; ordinary same-process role changes/Leave/rejoin preserve the applicable order/lineage rules.

## Controls and accessibility

Mouse/Keyboard segments are mutually exclusive and show the persisted preference with a separate indicator/fill, not ASCII radio text. Fresh/nil/invalid legacy settings migrate to Keyboard; an explicit saved Mouse choice stays Mouse. Separate status text says whether Keyboard is **active** or merely **preferred/inactive**. Preference is selectable while idle, in lobby, watching—including host-as-spectator—or after a full/denied join, without admission/action traffic.

Ordinary city intermissions preserve active routing while held actions are cleared; the next city requires key-up/fresh key-down. Escape, chat/edit focus, unknown shortcuts, modifiers, window-focus loss, long interruptions, close/Leave fight, KO and real combat release capture while retaining preference. INFO and SETTINGS release before opening and never auto-recapture on close. **No permanent/override bindings, protected spell actions or safety-release auto-grab.** Actual-client focus/taint still needs manual verification; mocks cannot prove native event ordering.

**Reduced Motion** in Settings persists through normal addon settings. It immediately removes decorative recoil/bob/bounce, number rise and moving particles, while retaining health text/trails, target highlights and essential boss telegraph poses. Gameplay movement is unchanged. No world-camera/UIParent/window shake.

## Read the hit, not the score

- **`YOU -20 HP`** is actual incoming health loss: short warm tint, up to0.28s damped sprite-local recoil and amber loss trails. Other actors react more subtly.
- **`YOU HIT -1 HP`** is exact confirmed host/solo local damage to a building/boss. An air swing shows a fist, not contact sparks or damage numbers. Floor damage is not its10 fame reward; boss damage is not its15 fame reward.
- **`TEAM HIT -3 HP`** is net target HP loss observed between timely remote worlds, possibly several hits from humans or AI. No per-attacker receipt is invented. Sending input only proves swing intention, not a host-confirmed hit. Hits/heals between samples can aggregate.
- Numeric boss HP remains visible through shield/exposure. Remaining floors, ground/range guidance and the Brawl priority highlight use actual Model helpers. Client reach guidance is explicitly sampled/estimated, not a guaranteed host hit or rejection.
- Duplicate/reordered/gapped/stale samples, joins/reopen, stage/replay/role/known actor replacement and authority changes rebaseline without catch-up. Previous-sample age is tested before arrival timestamps are replaced, even after no-render stalls. Heals/respawns are not damage; drawing never applies damage or fame.

Queues and decoration are bounded:32 queued receipts,8 nonlocal receipts per undrained batch,12 reused labels with local/boss priority,72 particles. Overlapping text stacks rather than overwrites; excess decoration is omitted rather than covering boss health. This is not a complete per-hit combat log. Ordinary display worlds still cannot distinguish a same-ID bot removed and replaced entirely between two received snapshots; observed replacement/reset does rebaseline.

## Rules

### City and bosses
- Walk sideways; climb towers in lanes **2,4,6**. Each floor takes two punches; the lowest floor is reachable from the ground. Collapsing towers drop climbers to the street.
- Flatten all floors to remove the boss shield. Punch the exposed boss **on the ground within one lane of its actual moving position**—not old fixed lanes3–5. Body contact alone does no damage.
- Boss HP:10/12/14/16 for **Crumb Baron, Permitron9000, Snack Tax, Queuezilla**. Two-second city transitions lead to shared victory.
- Floor hits award10 fame, final tower collapse40, boss hits15 and final boss hit100. KOs are separate, not bonus fame. Team fame sums current actors; leaving/spectating removes that actor's current score. Local personal best persists.

### Faster, readable attacks
Each boss cycle is **3s patrol →3s locked warning →0.5s attack →3s stationary recovery**:9.5s rather than13.5s, **29.6% shorter**. This really reduces the warning-to-impact interval; no hidden earlier telegraph or cosmetic countdown relabel. Damage is unchanged. Patrol stays within lanes2–6 and travels at most two lanes per segment. Warning origin/targets lock before impact; at least four lanes remain safe.

- Crumb Baron throws at one column, all heights.
- Permitron9000 beams two adjacent columns, all heights.
- Snack Tax pursues then stomps nearby columns **ground-only**; climb to escape.
- Queuezilla barrages three adjacent columns simultaneously, all heights.

Boss movement, hit checks and AI use the same position rule. Remote animation follows only a received patrol segment and stops at its endpoint/staleness; no next attack is predicted. A short attack pose may fall between ordinary1.25s snapshots. Newly locked warnings request an immediate bounded full-world snapshot, without replacing partially sent worlds or bypassing the transport budget. Timely consecutive samples can show static confirmed aftermath at previously warned targets, never a delayed damaging projectile. **Three-second warnings cannot survive arbitrary packet loss:** a blackout longer than the warning can hide the whole attack. Dodge promptly; slow reactions, long descents, lower frame rates and network congestion reduce the margin.

### Health and Brawl
100 HP,20-damage Brawl punch,35-damage boss impact. Model actions have a0.2s minimum gap; PvP damage has a separate0.6s cooldown. A punch selects the lowest eligible other actor at the same height within one lane, then retains existing city/boss rules. Damage gives brief0.8s immunity and bounded knockback. No profile changes these values.

Zero HP causes a4s KO, then full-health respawn with3s immunity. Select Keyboard again after KO if wanted. Watchers have no combat avatar. Real WoW combat hides/releases controls; host combat pauses simulation, and guest combat/protection is reconciled before model hazards/AI ticks. Detection/network delays still exist.

### Varied addon AI
Settings adds up to **five AI within25 total actors**, one click each; no external bot service or real character automation. Defaults cycle a mixed roster:

- **Smasher:** spreads work across intact buildings/floors.
- **Chaser:** helps destroy the shielded city, then pursues the exposed boss.
- **Scrapper:** briefly seeks Brawl rivals, then returns to objectives; retained Co-op falls back safely.
- **Dodger:** avoids hazards earlier and positions more cautiously, without immunity or abandoning objectives.

Dodger begins warning avoidance at2.5s remaining; others at2s, still subject to their normal0.3–0.6s decision cadence and ordinary action gates. None gains immunity or stronger damage. The fifth bot reuses a profile with deterministic bias. Profiles differ in actual priorities/cadence, not just names or colors. Hover a crew slot/monster for its profile tag. No manual advanced selection is required. Immutable bot identity and authoritative state keep behavior consistent across recovery; no unseeded client randomness or extra wire profile names. Remove AI removes the oldest bot, never a person.

AI consumes no real membership seat. Rooms support40 real participants and25 actors:20 human fighters+5 AI can coexist with20 watchers. A human joining at the actor cap evicts the oldest AI before denying admission; existing human fighters are not displaced. Watchers are not automatically promoted.

## Network and evidence

**R6 only; normal PARTY/RAID** reaches members of the same group, including different raid subgroups. No independent-party bridge, instance-chat/battleground routing, external server or competitive anti-cheat claim. Authenticated sender/room/term, admission generation, role and input epoch/sequence validate messages. Bots are never physical roster members.

Ordinary snapshot interval remains1.25s, with one early request on each real warning onset. A pending older world finishes first; capture retries after it drains rather than waiting another interval. No separate hazard-event channel, predicted impact, client damage authority or higher bandwidth cap is introduced. In80 healthy two-client tests spanning all four bosses/ground/top floor/five snapshot phases,200ms round-trip latency,20fps ticks,0.5/0.75s reaction and250ms legal key cadence, every threatened actor escaped: worst notice delay0.8s, minimum escape margin0.3s. This is a measured envelope, not a guarantee for slower input, larger/lossy groups or native transport. All traffic, including new recovery checkpoints, shares **700 chargedB/s and8messages/s** limits, with1,000-byte/10-message bursts and255-byte packet maximum. Checkpoints carry complete bounded membership and exact simulation timers for recovery. Safety takes priority over availability when membership/authority evidence is inconsistent. Friendly, nonprecision play; native transport and partition behavior cannot be certified by headless tests.

Development uses existing locked Fengari/luaparse tools:

```text
npm ci --ignore-scripts
npm test
npm run check:lua51
npm audit --audit-level=moderate
node tests/run.cjs --suite=flow
node tests/ui-preview.cjs --scene flow-watch --output docs/previews/flow-watch.svg
node tests/ui-preview.cjs --scene flow-settings --output docs/previews/flow-settings.svg
node tests/ui-preview.cjs --scene flow-ai --output docs/previews/flow-ai.svg
```

Fengari executes Lua5.3 semantics; separate Lua5.1 grammar checks do not equal native WoW execution. Actual-UI previews are explicitly labelled mocks. Final exact test counts, migration/AI measurements, packaging and remaining manual checks belong in [QA.md](QA.md). No native graphics/focus/taint, live two-client/raid performance or subjective animation-feel claim is implied.

Repository: https://github.com/lemillermicrosoft/Rampage
