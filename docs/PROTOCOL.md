# Rampage R1 protocol

This documents the first playable implementation, not a general-purpose networking library. Runtime is self-contained Lua; no serialized Lua, `loadstring`, external services or runtime packages.

## Transport and trust boundary

- Prefix: `ToastRampage1` (registered once).
- Distribution: current normal `PARTY` or `RAID`; all packets are group broadcasts. The adapter rejects other distributions/prefixes before dispatch.
- Sender is the WoW-provided addon-message sender, canonicalized to `Name-Realm` using the local normalized realm when omitted. Names are matched against actual unit identities on the current group roster, including distinct cross-realm names.
- Only an explicitly selected host/session may supply client state or membership. Only a host's admitted member, matching actual sender and current member token, may supply actions/leave/keepalive.
- Identifiers are at most 16 ASCII alphanumeric bytes, names at most 96 bytes and without control characters or `|`. Tokens are correlation identifiers visible to the group, **not secrets/authentication credentials**. The host can always choose its own state; this is cooperative friendly play.
- Unknown/non-roster senders cannot allocate rate buckets. Roster changes prune buckets/lobbies. The adapter bounds its roster to 40 raid members or four party units plus self.

## Packet grammar

Fields are separated by literal `|`. Exact field counts are required. No optional trailing fields. Numeric fields require decimal integer strings (no signs, exponents, NaN or fractions).

```text
R1|Q
R1|A|session|phase|count
R1|J|session|memberToken
R1|M|session|revision|slot|Name-Realm|memberToken
R1|M|session|revision|slot|-|-
R1|S|session|sequence|phase|stage|bossHP|paused|floors|players
R1|I|session|memberToken|inputSequence|seenSnapshotSequence|action
R1|K|session|memberToken
R1|L|session|memberToken
R1|E|session
```

- `Q`: explicit discovery query; host query replies are at most once/second.
- `A`: host advertisement; `count` 1–4, phase `l` lobby / `p` play / `c` between stages / `v` victory.
- `J`: explicit join request, retried every 2 seconds for at most 12 seconds. Full hosts silently decline; the joining client reports timeout/full-or-unavailable rather than displacing anyone.
- `M`: host membership record for slot 1–4; slot 1 is always the actual host. Four small records allow full canonical names without overflowing a packet. `revision` 1–999999 is monotonic. `-|-` clears a slot. The joining client's own name and newly generated token must appear before becoming active. Delayed older membership revisions are ignored. Names can arrive separately from the world; numeric player state remains authoritative.
- `S`: full numeric world state. `sequence` 1–999999 is strictly increasing; duplicates/older packets are ignored atomically. `stage` 1–4, boss HP 0–16 and no more than the stage's maximum, paused 0/1. `floors` is exactly nine digits 0–2, ordered bottom/middle/top for left/middle/right towers. `players` contains exactly four semicolon-separated records, either `-` or `x,y,score,punchCounter`. Bounds: x 1–7, y 0–3, score 0–99999, punch counter 0–999; elevated positions require a tower lane. Maximum configured snapshot fixture in tests: **103 bytes**.
- `I`: action `L`, `R`, `U`, `D`, `P`; strictly increasing per-member input sequence 1–999999. Seen snapshot must exist and be at least the first snapshot of the current stage/replay. Duplicate, stale-stage, out-of-order and too-fast actions cannot double-apply. Client positions, damage and scores are never accepted as inputs.
- `K`: liveness only; never changes game state.
- `L`: matching admitted guest leaves; another member cannot remove it by claiming its name/token.
- `E`: current actual host ends this session; no migration.

All received messages are bounded to 255 bytes before parsing. All generated messages are checked before enqueue/send. Action sequence saturation stops guest inputs until a fresh session; snapshot sequence saturation ends the hosted session instead of wrapping into stale sequence numbers.

## Scheduling and bounded work

- Outbound: token bucket **8 messages/s, burst 10**; at most **24** queued keys. Latest snapshot, ad and per-slot member record replace queued older equivalents. Inputs have distinct keys. No unbounded retransmission queue.
- Host: full state every 0.25 seconds; advertisements and four membership records every 4 seconds. Idle lobby snapshots also serve as heartbeat. Ordinary host steady state is roughly 5.25 packets/s, plus bounded join/leave churn.
- Inbound: per-current-roster sender token bucket **16 messages/s, burst 24**, before parsing. Processing scans at most four admitted members.
- Local input gate: 0.18 seconds; host's per-remote-member action gate: 0.16 seconds. This tolerates modest delivery jitter without accepting unlimited gameplay clicks.
- Guest keepalive: every 3 seconds, including while its UI is hidden/in combat. Guest dropped after 20 seconds without a valid matching keepalive/action/join. Client exits after 15 seconds without a newer host snapshot (membership packets cannot indefinitely hide a stalled host).
- Discovered lobbies: at most 8, expire after 12 seconds; group departure removes them immediately.
- No gameplay simulation before Start. Intermissions are two seconds of unpaused host model time. Host combat pauses rules/transitions but not network liveness; guest combat blocks only that guest's input.

## Recovery and limitations

- Clients do not predict or replay actions. Shared state appears on the next snapshot; a dropped input needs another click, a dropped snapshot heals automatically.
- Late join gets the current membership and full state without resetting the city. New members start on the street with zero score. An idempotent retry of the same join token does not reset action sequence or score.
- Explicit leave removes the player/score from current team totals. Rejoining gets a fresh token. A reload that rejoins before host expiry can reclaim its existing slot/score with a new token; old-token input is rejected. This is not host migration.
- A host reload generates a new session. Old session packets cannot revive it; guests time out and must explicitly join the new session.
- Raid membership is the trust boundary, not the entire guild. Normal party/raid transport only; battleground/instance-chat transport is not implemented.
- Tests simulate normal sends, dropped snapshots, stale packets, duplicate/rapid input, malformed packets, cross-realm roster identity, departure and timeouts. Actual Blizzard transport, throttling by other addons, unusual group categories and locale behavior still require real-client testing.
