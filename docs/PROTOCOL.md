# Rampage R3 protocol and engine contract

R3 is intentionally incompatible with **R1 and R2**. Prefix remains `ToastRampage1`; every payload begins `R3`. Runtime is self-contained Lua 5.1: no serialized Lua, `loadstring`, external AI, services or packages. Addon AI is deterministic local rules executed **only by the host/solo authority**.

## Public model/UI contract

- `state.mode = 'coop' | 'brawl'`, default `coop`. Co-op never damages allies. Brawl enables mutual human/human, human/AI and AI/AI punches.
- `state.time` is authoritative **seconds as a number** (fractional seconds); wire precision is tenths, rounded upward. Host WoW combat freezes this clock, AI, hazards, KO and respawn timers. Guests never advance the model; UI may interpolate presentation, not apply damage.
- `state.hazard` is nil outside active threats or `{phase='warning'|'impact'|'idle', lanes={1..7}, remaining=seconds, id=counter}`. Warning lasts **7 seconds**, impact **0.5 seconds**, recovery **3 seconds**. Only entry into impact deals damage, once per actor. Threats continue while the boss shield is up and after the city falls. Stage patterns: single rotating lane; adjacent pair; alternating tower/street lanes; rotating three-lane sweep. All affect every height in marked lanes, always leaving a safe lane.
- `state.players[1..25]` retains `x,y,score,hit`; adds `hp,maxHP=100,ko=remainingSeconds,invuln=remainingSeconds,kos,bot,botID,name,protected`. `bot` and `protected` are booleans. Bot name/ID are optional for humans. `protected` means real-combat/unresponsive-human protection: no actions/damage, KO/immunity clocks frozen. No player exists for spectators.
- All actions have a **0.2-second model gate**. Brawl damage has a separate **0.6-second punch gate** and strikes at most one other actor, within one lane and at exactly the same height. A punch deals **20 HP**, boss hazards **35 HP**. Damage cannot exceed 35 per application; normal damage gives 0.8 seconds immunity. Knockback is one ground lane, or one floor downward. KO lasts **4 seconds**, then respawns at lane 1 with 100 HP and **3 seconds immunity**. KO credit is `kos`, separate from city `score`; hazards never award player KO credit.
- `M.BOT_NAMES`: Pebble Pal, Noodle Knight, Mochi Boots, Waffle Scout, Bumble Brick. At most five, unique fixed IDs. Decisions are evaluated at most every 0.35 seconds (0.4 at 0.1-second simulation ticks), use the same legal model actions, descend/dodge near impacts, climb/smash the city, fight exposed bosses and briefly scuffle in Brawl. No random numbers or physical-roster impersonation.
- New actors and new stages receive full HP and spawn immunity. Replay clears city score and KOs. Model tick has bounded 0.1-second substeps; network clamps each elapsed update to 0.5 seconds, preventing an alt-tab/stalled host from replaying a backlog of attacks.

## Public network/adapter contract and capacity

- `net.mode` remains transport mode `idle|solo|host|joining|client` (NOT game rules mode). `net.state.mode` is game mode. `net.role` remains existing `play|spectate`; spectator `net.slot` is nil.
- `net:setMode(mode)` succeeds for idle selection or owner host/solo in **lobby or victory only**. Never mid-play/intermission. A host cannot change mode while any other real participant (player or spectator) is admitted: use a new lobby or have guests leave first. Admitted clients retain their consented mode and fail closed if an unsolicited world changes it. `net:host(mode)` / `net:solo(mode)` default to selected mode, initially Co-op. Solo starts immediately; pass selection to `solo(mode)` or select while idle. Existing `start/leave/discover/action/setRole/setRoster/count/spectatorCount/lobbyList` remain.
- `net:addAI()` adds **one** bot; `net:removeAI()` removes **one oldest** bot. Host/solo only, at most 5 and within 25 total actors. Adding fails in combat. `net:botCount()` reports bots. `net.members[slot]` includes `{name,bot=true,botID,slot}` for bots; these are never real participants or roster identities.
- **25 total active actors**, host permanently slot 1, plus **40 real participants** including host. AI does not use a real participant ID/budget. Thus 20 humans + 5 bots + 20 spectators is legal. A human admission or Play role request automatically removes the oldest bot if the actor cap is full. With no bots/free slots, requested Play falls back to spectator, with visible status. Spectating relinquishes avatar/score; there is no automatic human waitlist/promotion.
- `join(hostName,sid,role,expectedMode)` defaults role to `play` and omitted expectedMode to the current advertisement. Explicit expectedMode must match advertised mode. J handshake and own admission record validate the selected mode. A changed-mode admission fails closed with a review/rejoin notice, never silently admits a Co-op selection into Brawl.
- Lobby entries: `name,sid,phase,count,spectators,bots,mode`. Count includes bots; spectators counts real watchers only. UI must label mode before joining and distinguish bots, human actors and watchers.
- `setCombat(bool)` pauses the host's whole simulation or sends a bounded guest combat-protection update. Guest controls also stop locally. Optional adapter `env.inCombat(canonicalName)` returns actual `UnitAffectingCombat` status for host roster polling; alternatively call `net:setMemberCombat(name,bool)`. Host protection is notify **OR** roster-combat fallback; a false/missing roster result cannot cancel a true guest notification. Roster fallback/protection is reconciled before the authoritative hazard/AI tick, so an already-detectable combat transition cannot take damage for one extra tick. Never use addon UI visibility as WoW combat status.
- Combat notification is versioned, high-priority, and retried at most once/second until a snapshot confirms it; ordinary keepalive is every 8 seconds. This is friendly prototype protection, not competitive anti-cheat. Guests unresponsive >12 seconds are protected until refreshed/removed; expiry is 35 seconds. There is inherently a delivery/detection window: the host cannot know combat/disconnection before a notify or roster update arrives.
- `N.new(env)` retains `name,now(),token(),send(payload),changed(net)` and adds optional `inCombat(name)`. `send` is one PARTY/RAID broadcast, never per-recipient whispers. Spectators receive the same world but cannot act/start/manage AI/mode.

## Trust boundary and packet grammar

The adapter validates prefix/distribution and canonicalizes the **actual WoW addon-message sender** to `Name-Realm`. Authorization uses that actual sender and current physical roster, never a payload-claimed actor. Only the selected host/session can publish worlds/members. Bot slots have no token/generation or member ID: ghost bot inputs cannot pass admission. Names: 1–96 bytes, no control characters or `|`; tokens: 1–16 ASCII alphanumeric bytes, public correlation values, not credentials. Trust the cooperative host; no claim of malicious-host protection.

Exact field counts, literal `|`, decimal integers at most six digits without signs/exponents. Counters do not wrap. `p/s` = play/spectate; `c/b` = Co-op/Brawl; phase `l/p/c/v` = lobby/play/clear/victory.

```text
R3|Q
R3|A|session|phase|actorCount|spectatorCount|c/b|botCount
R3|J|session|joinToken|p/s|c/b
R3|C|session|targetName|joinToken|admissionGeneration
R3|B|session|joinToken|admissionGeneration
R3|M|session|recordRevision|memberID|name|joinToken|admissionGeneration|activeSlot|roleSequence|c/b
R3|M|session|recordRevision|memberID|-|-|0|0|0|c/b
R3|S|session|snapshotSequence|part|partCount|bodyFragment
R3|I|session|joinToken|admissionGeneration|inputSequence|seenSnapshot|inputEpoch|roleSequence|action
R3|R|session|joinToken|admissionGeneration|roleSequence|p/s
R3|K|session|joinToken|admissionGeneration|protectionSequence|inCombat0or1
R3|L|session|joinToken|admissionGeneration
R3|E|session
```

- Q/A: discovery at most one advert/2 seconds, normal every 5 seconds. Cache max 8 hosts/15 seconds. Actors 1–25, bots 0–5 and less than actors; `actors-bots+spectators <=40`.
- J/C/B: host-issued challenge prevents delayed old joins/confirmations replacing newer admissions. J retries every 4 seconds/90-second total, challenges expire at 60 seconds and resend at most once/12 seconds. Unconfirmed/replayed J cannot mutate membership or refresh liveness. Matching B is idempotent. Reload/rejoin preserves an existing actor when applicable but obtains a fresh generation.
- M: real member IDs 1–40, active slot 1–25 or 0 spectator. Revisions globally increment, compared **per ID**. Older/equal records cannot revert newer records; removals are tombstones. Host ID1/slot1 is mandatory. Names recover independently of worlds; renderers tolerate unknown human names. AI names derive directly from snapshot bot IDs, not this carousel.
- R/I: monotonic per-admission role/input sequences. Inputs only L/R/U/D/P (no positions/damage claims); actor must exist, sender token/generation must match, accepted role sequence must match, seen world must be at/after epoch floor and no later than host captured sequence. Epoch changes at Start/replay/stage transition and **every host combat transition**. Spectator, duplicate, stale/future, ghost and pre-pause input is rejected. Too-fast input consumes its sequence without execution.
- K: monotonic protection sequence; same-sequence conflicting combat value is rejected. Old admissions cannot toggle protection. Ordinary player/spectator keepalives continue in combat and hidden UI.
- Unknown/non-roster senders cannot allocate buckets. Clients discard peer gameplay before allocating buckets/parsing. Roster changes prune discoveries, sender buckets, challenges and departed participants. No migration.

## Atomic compact worlds

Exactly **three fragments** for current fixed-width worlds, each at most **176 body bytes**, **3 maximum / 528 assembled bytes**; every complete addon packet remains <=255 bytes. Sender finishes every queued fragment of a captured immutable snapshot before another capture; never coalesces half a world.

Body has twelve comma-separated fields:

```text
phase,stage,bossHP,paused,inputEpoch,membershipRevision,floors,memberMap,mode,clock,hazard,players
```

- Stage 1–4, boss 0–16 and <=8+2*stage, paused 0/1, epoch/revision 1–999999.
- Floors exactly nine digits 0–2. Member map exactly 40 characters indexed by real member ID: `.` absent, base36 slot 0–25 (`0` spectator). Slots unique, ID1 maps to1.
- Mode c/b. Clock five base36 digits in deciseconds; decoded as seconds. Hazard `-` or nine characters: ID(4), phase w/i/d(1), seven-lane bitmask(2), remaining-deciseconds(2). Warning max70, impact max5, idle max30 with empty lanes.
- Players exactly 25 records of **16 characters** each; absent is sixteen `-`. Present base36 layout: `x(1),y(1),cityScore(4),punchCounter(2),HP(2),KO-deciseconds(2),immunity-deciseconds(1),KO-credit(2),flags(1)`.
- Bounds x1–7/y0–3, score0–99999, hit0–999, HP0–100, KO0–40, immunity0–30, KOs0–1295. Elevated actor must be on tower lane. HP0 iff KO>0. Flags=`botID*2 + protected`; botID0 human or1–5 AI, each AI ID unique. Bots cannot claim real-combat protection or occupy a mapped human slot. Every human player agrees with member map. `maxHP=100` and friendly names reconstruct locally.
- At most three in-progress assemblies, three fragments each; expiry6 seconds. Reject malformed lengths/counts/fields/maps. Reordered parts accepted, duplicate parts ignored. Only a **complete valid strictly newer** world publishes; epoch/revision cannot regress. Newer complete state prunes older assemblies. Incomplete traffic never refreshes host-world liveness. World map omission removes an expired own admission even if its tombstone was lost.

## Budgets, cadence and limitations

Unchanged per-instance limits: **8 messages/sec burst10**, **700 charged bytes/sec burst1000**, charging payload+**16** per packet; **128 coalesced queue keys**. Incoming per-roster-sender **16 messages/sec burst24**. No unbounded queue, payload-controlled loop or per-client full-world/roster resend.

World snapshots every **1.25 seconds**, now three rather than two packets. Name carousel reduced to **one record/second** to leave headroom for HP/hazards/bots at maximum 96-byte canonical names. Changed membership/admission shares bounded FIFO priority; world/advertisements remain highest host priority. Inputs coalesce to one latest-action key, so lost/congested actions require another click, never client prediction/replay. Local action5/sec, host remote network gate0.16s plus model's0.2s gate. Keepalives stagger every8s; host removal35s/client timeout20s.

Seven-second telegraphs deliberately exceed the observed 4.0-second maximum R3 world gap in the tested fixture. This is not a transport latency guarantee: a severely delayed/lost stream can still hide a warning; the prototype cannot promise competitive fairness under arbitrary transport loss. Host combat does not stop snapshots/liveness. Normal PARTY/RAID only, no instance-chat/battleground routing or host migration.

## Verification

`node tests/run.cjs --suite=model` and `--suite=protocol` run pure-model/network suites (Fengari Lua5.3 execution with separate Lua5.1 syntax checks). Model covers default no-friendly-fire, mutual Brawl ranges/cooldowns, real hazard damage before/after shields, knockback, KO/respawn/immunity/protection/pause, deterministic AI-only four-boss completion and AI being hurt/KO'd.

Network bus delivers every broadcast independently to every other real node, with bounded buckets checked **on every send** and queue/assembly/sequence bounds checked every tick. Includes 40 maximum-name real participants, simultaneous joins/reconnect, actor/spectator/bot caps, human bot-eviction, advertised mode consent, protection replay/fallback, R2 incompatibility, malformed security fixtures, loss/reorder/duplicates, four bosses and replay. Final measured results are recorded below; this is **simulation evidence, not a 40-WoW-client live proof**.

Recorded headless evidence: **37 focused tests passed (14 model + 23 protocol)**, with Lua 5.1 syntax checks and a clean scoped `git diff --check`.

- **14 model tests passed**. A single deterministic AI, with no humans driving it, clears all four bosses in **108.8 game seconds**; a separate stationary-AI hazard fixture proves damage and KO.
- Maximum-field 25-actor world: **3 packets / 591 payload bytes / 639 charged bytes**, all packets below 255 bytes.
- Forty **96-byte-name real participants**: all guest admissions finish in **40.4 seconds** while already playing; simultaneous reconnect converges. Host averages **4.27 messages/sec, 625.1 payload B/sec, 693.4 charged B/sec**; maximum queue **52/128**, world gap **1.5 seconds**.
- Forty real participants with **20 human actors + 5 AI + 20 spectators**: four bosses, host-combat pause, replay and sustained movement over **87.4 simulated seconds**. Every packet fans out to the other 39 nodes with deterministic **4.35% per-recipient loss**, 0–300ms jitter/reordering and duplicates. Host **3.43 messages/sec, 454.6 payload B/sec, 509.5 charged B/sec**; whole group **41.65 messages/sec, 1544.5 payload B/sec**; **422 guest heartbeats**. Queue **41/128**, maximum world gap **4.0 seconds**. The seven-second warning exceeds that measured worst gap, not just the normal cadence.
- A separate **three-second snapshot blackout** test verifies a warning is still visible after recovery and a legal network action dodges the impact. It does not claim safety under arbitrary loss.
- Name recovery is independent of numeric worlds. Maximum-name admission is deliberately slower than R2 rather than violating the unchanged bandwidth ceiling. These are deterministic simulation rates, not live transport or render/frame-time benchmarks.
