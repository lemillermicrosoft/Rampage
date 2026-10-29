# Rampage R2 protocol

R2 is intentionally incompatible with R1. Runtime is self-contained Lua 5.1; no serialized Lua, `loadstring`, external services, or runtime packages. The existing addon-message prefix remains `ToastRampage1`; the first payload field selects **R2**.

## Capacity and public interface

- One shared authoritative city, four sequential bosses, **25 active slots**. Host permanently occupies slot 1. Active late joins start on the street with zero score without resetting the city.
- **40 total participants**, including host. At 25 active, a requested player admission becomes a spectator with an explicit status message. Spectators have no model player, avatar, personal score, action, or Start permission. They receive the same world broadcasts. The spare capacity can also accommodate more than 15 spectators when fewer than 25 are playing (up to 39 spectators plus host).
- A client can request Play/Spectate at any stage. Spectate relinquishes the avatar and its current score; Play allocates a free active slot with zero score. A full Play request remains spectating and explains why. There is no automatic waitlist/promotion.
- `N.new(env)` keeps `name`, `now()`, `token()`, `send(payload)`, optional `changed(net)` unchanged. `send` is one **group broadcast**, never a whisper/per-recipient fan-out.
- Modes: `idle`, `solo`, `host`, `joining`, `client`. `net.role` is `play` or `spectate` while participating; `net.slot` is nil for spectators. Solo/host are always play. `net.members[activeSlot]` contains known active `{name, ...}` records; internal `participants[1..40]` includes spectators separately.
- Existing methods remain: `discover`, `host`, `solo`, `start`, `leave`, `action`, `setCombat`, `setRoster`, `tick`, `count`, `lobbyList`. `join(hostName,sid,role)` defaults to play; `setRole(role)` requests a client role change; `spectatorCount()` reports watchers. Lobby list entries contain `name,sid,phase,count,spectators`. Status remains a string.
- Numeric world/counts and names have independent recovery streams. Names can arrive after the world, so renderers must tolerate an unknown member name. No snapshot waits for a full 40-name roster.

## Transport and trust boundary

Use the adapter's current normal `PARTY`/`RAID` distribution. The adapter validates prefix/distribution and canonicalizes the actual WoW addon-message sender to `Name-Realm`. Protocol authorization matches that actual sender against the current group roster; payloads cannot claim an input sender. Cross-realm identities remain distinct.

Names: 1–96 bytes, no control characters or `|`. Session/join identifiers: 1–16 ASCII alphanumeric bytes. Identifiers are public correlation values, **not credentials**. Host authority is trusted cooperative play, not protection against a malicious host or someone already controlling another player's WoW identity.

Only the explicitly selected actual host and exact session can send accepted world/membership. Host accepts guest messages only from the admitted actual sender with the current join token **and host-issued admission generation**. A challenge/confirmation handshake prevents a delayed old join request/confirmation from rotating a newer admission back to an old identity. Unknown/non-roster senders cannot allocate buckets. Roster updates prune sender buckets, discoveries, challenges, and departed memberships. The adapter bounds its roster to a real 40-person raid.

## Packet grammar

Literal `|` separators, exact field counts, no trailing fields. Decimal integers have no sign/exponent/fraction, at most six digits. Sequence/generation/revision counters never wrap. `p/s` means play/spectate.

```text
R2|Q
R2|A|session|phase|activeCount|spectatorCount
R2|J|session|joinToken|p/s
R2|C|session|targetName|joinToken|admissionGeneration
R2|B|session|joinToken|admissionGeneration
R2|M|session|recordRevision|memberID|name|joinToken|admissionGeneration|activeSlot|roleSequence
R2|M|session|recordRevision|memberID|-|-|0|0|0
R2|S|session|snapshotSequence|part|partCount|bodyFragment
R2|I|session|joinToken|admissionGeneration|inputSequence|seenSnapshot|inputEpoch|roleSequence|action
R2|R|session|joinToken|admissionGeneration|roleSequence|p/s
R2|K|session|joinToken|admissionGeneration
R2|L|session|joinToken|admissionGeneration
R2|E|session
```

- **Q/A**: explicit query plus periodic discovery. Ad counts active 1–25, spectators 0–39, total at most 40. Phase `l` lobby / `p` play / `c` clear / `v` victory. Cache at most 8 hosts, expires after 15 seconds. Query responses at most once per 2 seconds.
- **J/C/B**: join request, host-issued challenge addressed by canonical name, confirmation. Host allocates membership only after matching B. Join retries every 4 seconds for at most 90 seconds; challenge expires after 60 seconds and is resent at most once per 12 seconds. These limits accommodate simultaneous maximum-name raid joins at finite bandwidth. An unconfirmed J does not alter an existing player or refresh its liveness. Same admission B is idempotent. Rejoining after a simulated reload can preserve an existing active avatar/score, but obtains a fresh generation and input sequence.
- **M**: one member record, ID 1–40, active slot 1–25 or 0 for spectator. Record revision is globally increasing when any membership changes, but compared **per ID** at receivers. Equal/older records cannot revert newer records; removals are versioned tombstones. ID 1 must be the actual host in active slot 1. A client only completes its own admission when name, token and generation all match. Changed records are queued once/coalesced; periodic fair carousel repairs loss. No 40-record resend per join.
- **R**: monotonically increasing role-request sequence. Duplicate requests only resend membership acknowledgment (rate-limited). New requests change role at most once. The accepted role sequence is also required on inputs, so old player-role inputs cannot apply after a spectator round trip.
- **I**: only `L/R/U/D/P`, no position/score/damage claims. Strictly increasing per-admission input sequence. Seen snapshot must be at/after the first snapshot of the current input epoch and no later than host's current captured sequence. Input epoch changes on Start/replay, each next stage and **each host combat transition**; delayed prior-stage or pre-pause actions cannot resume after unpause. Spectator inputs are rejected. Too-fast inputs consume their sequence but do not execute.
- **K/L/E**: matching member liveness/departure; current actual host session termination. Departure is best-effort within the same send buckets, with roster/timeouts as fallback. No migration.

## Atomic world snapshots

Every normal world is **two fragments**, never one oversize message. Fragment payload maximum **176 bytes**; at most **2 fragments**, **352 assembled bytes**. Fragments contain captured immutable world data; the sender finishes any queued snapshot before capturing another, so replacement/coalescing cannot strand its own half-snapshot.

The assembled body has nine comma-separated fields:

```text
phase,stage,bossHP,paused,inputEpoch,membershipRevision,floors,memberMap,players
```

- Stage 1–4; boss 0–16 and at most `8 + stage*2`; paused 0/1; epoch/revision 1–999999.
- Floors: exactly nine digits 0–2, bottom/middle/top of each left/middle/right tower.
- Member map: exactly 40 characters, indexed by stable member ID. `.` absent; a lowercase base-36 digit represents active slot 0–25, where 0 is spectator. Active slots must be unique; ID 1 must map to slot 1.
- Players: exactly 25 fixed-width eight-character records. Absent is `--------`. Present is base-36 `x(1),y(1),score(4),punchCounter(2)`, bounded x 1–7, y 0–3, score 0–99999, punch counter 0–999. Elevated positions require a tower lane. Player presence must agree with the member map. Client reconstructs ordinary numeric `state.players[1..25]` fields used by the model/UI.
- Maximum-field fixture with 16-byte session and six-digit counters remains below 255 **per message**; the tests print exact combined payload bytes.

Receiver keeps at most **3** in-progress assemblies, each at most 2 fragments. Parts may arrive out of order; duplicate parts are ignored. Invalid counts, lengths, fields, world bounds and maps do not publish state. Assemblies expire after **6 seconds**, and older incomplete sequences are pruned after a newer complete snapshot is committed. A new assembly at the cap evicts the smallest sequence only if newer. Only a complete valid strictly newer snapshot replaces the world, and its epoch/revision cannot regress. Incomplete traffic never refreshes host-world liveness.

## Finite scheduling and bandwidth

Per addon instance, including the host:

- Packet token bucket: **8 messages/sec, burst 10**.
- Independent byte token bucket: **700 charged bytes/sec, burst 1000**. Each send is charged actual payload bytes **plus 16 bytes** for prefix/transport allowance. This is a conservative addon budget, not a promise that other addons or Blizzard's transport will leave that bandwidth available.
- Maximum **128 coalesced queue keys**. Two snapshot keys, at most forty member keys, bounded challenge keys, and small control keys. Input uses **one latest-action key**, not an unbounded delayed-action queue. An action may therefore be dropped/coalesced under congestion; clients never predict or replay it.
- Snapshot fragments and small advertisements have highest host priority; advertisements are globally capped at one per 2 seconds, so membership churn cannot suppress discovery or flood that lane. Changed/rotating membership and admission share FIFO priority. No join can enqueue a per-client full snapshot or roster. Host snapshots every **1.25 seconds**; names carousel at most **2 records/sec**, advertisements every **5 seconds**. At maximum canonical-name sizes the byte bucket, not a fictitious messages-only allowance, throttles bursts. Simultaneous joins are intentionally allowed tens of seconds rather than starving ongoing world snapshots.
- Local action interval **0.2 seconds** (at most 5/sec); host remote action gate **0.16 seconds** to tolerate small delivery jitter.
- Per-roster-sender inbound bucket **16 messages/sec, burst 24**, before parsing. Clients discard other guests' gameplay broadcasts before bucket allocation/field splitting; only peer discovery and the selected host's session traffic need parsing. Iteration bounds are 25 players/40 members, not payload-controlled loops.
- Every guest, **including every spectator**, sends a staggered keepalive every **8 seconds**, even in combat/hidden UI. A full raid has 39 guest keepalive streams (~4.875 messages/sec aggregate); host's world stream is its heartbeat. Guests are removed after **35 seconds** without a valid matching message; clients end after **20 seconds** without a complete newer world. Membership traffic cannot hide a stalled snapshot stream. A newer world map that omits the client's own admitted ID also removes that client even if its membership tombstone was lost.
- Host combat pauses rules/transitions but network liveness, joins, role requests, discovery and snapshots continue. Guest combat only suppresses its own gameplay controls.

## Verification and remaining limits

`tests/protocol.lua` implements a real 40-node simulated broadcast bus: each send is delivered independently to the other 39 nodes, not a fake count or per-client shortcut. Tests enforce message/charged-byte budgets on every send, queue/assembly caps on every tick, and monotonic applied state. Coverage includes all 40 maximum-length canonical names joining an in-progress world, simultaneous reconnect, 25-active/15-spectator fallback and switching, dropped admission records, adversarial sender/token/session/generation/replay/malformed packets, incomplete assembly expiry, departures and host-world timeout.

A sustained 25-actor/15-spectator scenario runs through all four bosses using only each node's normal `action()` from its delayed local state. The transport applies deterministic **4.35% per-recipient loss**, 0–300ms jitter/reordering and duplicate deliveries; host combat pauses during the run. Replay and high-rate movement then exercise sustained input traffic, followed by exact 40-node world convergence. Tests print duration, host and group payload/message rates, charged host bandwidth, keepalive count, maximum queue and observed snapshot gap.

Recorded headless run (Fengari Lua 5.3 execution plus separate Lua 5.1 syntax checks):

- **8 model + 17 protocol tests passed.**
- Maximum-field world: **2 packets, 340 combined payload bytes**, each below 255.
- Forty 96-byte-name participants: all 39 guest admissions completed in **23.0 seconds** while already playing; simultaneous reconnect also converged. Across that test, host averaged **4.61 messages/sec, 577.0 payload bytes/sec, 650.7 charged bytes/sec**; maximum queue **47/128**, maximum observed world gap **1.5 seconds**.
- Sustained 25+15 loss/reorder run: **124.7 simulated seconds** spanning four real model stages, combat pause, replay and sustained movement. Host **3.47 messages/sec, 307.5 payload bytes/sec, 363.0 charged bytes/sec**. Whole group **60.79 messages/sec, 1968.0 payload bytes/sec**, including **601 guest keepalives** (host heartbeats are snapshots). Maximum queue **41/128**; maximum observed world gap **2.9 seconds**. Every send also passed cumulative packet/byte budget assertions, not just average-rate checks.
- These are deterministic test measurements, not throughput guarantees or wall-clock benchmark timings. Name roster recovery remains independent of numeric-world recovery.

**This is simulation evidence, not a real 40-WoW-client network proof.** Shared addon throttling, live server behavior, actual human latency, cross-realm localized names, atypical group categories and rendered/audio usability still need in-game testing. Normal party/raid only; no battleground/instance-chat transport or host migration. Individual lost actions need another click. Names may converge more slowly than numeric state under loss/churn. Counters stop/end the relevant operation at 999999 instead of wrapping.
