# Rampage — FOUR MORE BOSSES!

**<Toast> has just FOUR MORE BOSSES!** A small, opt-in cooperative city-smashing minigame for **TBC Classic 2.5.6 (Interface 20506)** raid downtime. Inspired by classic climb-and-smash arcade play, with original geometric monsters and fictional encounters. Not affiliated with the original Rampage game or its owners.

## Status

First playable MVP implemented for feature [#1](https://github.com/lemillermicrosoft/Rampage/issues/1). Automated rules, simulated multiplayer, Lua 5.1 syntax and mocked TOC/UI tests pass. **Not yet verified inside an actual TBC client**; see [QA.md](QA.md) for the real-client checklist. CurseForge publication remains deferred ([#2](https://github.com/lemillermicrosoft/Rampage/issues/2)); no release or merge is implied.

## Install

Copy the `Rampage` folder into your TBC client's `Interface/AddOns/` directory, for example:

```text
World of Warcraft/_anniversary_/Interface/AddOns/Rampage/
```

The folder must contain `Rampage.toc`, `Model.lua`, `Protocol.lua`, `UI.lua`, `Rampage.lua` and `Media/icon.png`. Enable the addon at character selection, then type **`/rampage`**. Both players need the same addon build for co-op. Node/npm and the `tests` directory are development tooling only, never WoW runtime dependencies.

## Quick play

- **Solo:** click **Solo practice**, or `/rampage solo`. No group needed.
- **Co-op:** form a normal party/raid. One player clicks **Host**. Friends click **Find lobbies**, use **Next host** if necessary, then **Join selected**. The host clicks **Start / replay**.
- **Maximum four monsters per lobby, including the host.** Separate lobbies can coexist in the same raid. Only the host starts/replays a shared game.
- **Leave** explicitly exits. **X** only hides the window; `/rampage` brings it back. Incoming messages never open a window.
- Late join is supported even after Start: current city, boss, positions and scores synchronize automatically.

### Smash school

All gameplay uses discrete mouse clicks. There are **no global keybindings or keyboard capture**.

1. Walk left/right **on the ground** to one of the three towers (lanes **2, 4, 6**).
2. **Climb** three times to the top. **PUNCH!** twice to destroy that floor.
3. **Down**, punch twice; **Down**, punch twice. The tower collapses into rubble and its climbers drop safely to the street. You can also punch the lowest floor from the ground.
4. Flatten all three towers together to remove the boss's shield. Stand on the ground in the middle three lanes (**3–5**) and punch the boss.
5. Defeat **The Crumb Baron**, **Permitron 9000**, **The Snack Tax**, and **Queuezilla**. Two-second scene changes lead to shared victory: **ZERO MORE BOSSES!**

Boss health is 10 / 12 / 14 / 16. This slice is intentionally forgiving: no player deaths, countdown failure, hazards or combat interactions. The city is truly shared: one player's punch damages the same floor another player is smashing; everyone sees the same boss and victory.

### Fame and safety

- Each floor hit earns 10 personal fame, the last hit collapsing a tower adds 40, boss hits earn 15, and the final boss hit adds 100. Team fame is the sum of current participants' scores.
- Leaving removes that participant from the current team total. Late entrants start at zero. Your **local personal best** and window position are saved in `RampageDB`; no raid-wide records or account data are transmitted.
- Punches/steps are limited to roughly five per second. Clients render authoritative full states at up to four snapshots/second; there is no speculative movement. Expect ordinary network latency, not action-game precision.
- **Combat hides the window and blocks local game input.** Host combat pauses the shared game, including stage transitions. A guest entering combat is unavailable locally while the others can continue. Heartbeats still run. The window returns only if it was already open before combat.
- No public chat announcements, sounds, invites, combat automation, protected action buttons, or copied art/audio. Help/status messages are local only.

## Commands

| Command | Action |
| --- | --- |
| `/rampage` | Toggle the window, out of combat |
| `/rampage help` | Print local help |
| `/rampage solo` | Start solo practice |
| `/rampage host` | Open a four-player group lobby |
| `/rampage find` | Request recent group lobbies and show the window |
| `/rampage join [Name-Realm]` | Join a discovered host; without a name, first sorted host |
| `/rampage start` | Host/solo start or replay after victory |
| `/rampage leave` | Exit the current lobby/game |

## Networking and limits

- Only `PARTY` / `RAID` **addon messages**, prefix `ToastRampage1`; no whispers, guild, battleground/instance-chat transport, or public chat.
- Actual canonical `Name-Realm` sender must be on the current group roster. Host/session, membership token, numeric bounds, message shape and sequence numbers are checked. Inputs also reference a snapshot from the current stage/replay, so delayed old-stage clicks are discarded.
- Full world snapshots avoid delta-chain corruption. Membership records carry monotonic revisions. Joining is retried and synchronized, never automatically accepted by a non-joining client.
- Every payload is at most 255 bytes. Per-addon outbound budget: **8 messages/second, burst 10**; queue capped at **24**, replaceable snapshots coalesced. Inbound limit per roster sender: **16/second, burst 24**. At most **8** discovered lobbies are cached.
- Ads/membership refresh every 4 seconds; ads expire after 12 seconds. Join attempts stop after 12 seconds (including a full lobby). Guests heartbeat every 3 seconds. Clients stop after 15 seconds without a newer host snapshot; hosts remove silent guests after 20 seconds.
- Group departure ends/removes the relevant session/member. **No host migration**: if the host leaves, disconnects or reloads, find or host a new game. Lost inputs are not retried; click again if needed. Lost snapshots heal on the next full snapshot.
- This is friendly group play, not a cheat-proof competitive service: the host is authoritative. Session/member tokens are correlation identifiers, not credentials.

Protocol details: [docs/PROTOCOL.md](docs/PROTOCOL.md).

## Development / verification

```text
npm ci --ignore-scripts
npm test
npm run check:lua51
npm audit --audit-level=moderate
```

Only pinned development dependencies: `fengari@0.1.5` and `luaparse@0.3.1` with a lockfile; `node_modules/` is ignored. **Fengari executes Lua 5.3 semantics**, not the WoW Lua 5.1 VM. `luaparse` independently checks every runtime/test Lua file using its **Lua 5.1 grammar**. Neither substitutes for in-game API, rendering, taint, or real network checks.

- `Model.lua`: deterministic rules, four stages and personal scores; no WoW APIs.
- `Protocol.lua`: bounded host-authoritative session, transport validation and timeouts; injected clock/transport.
- `UI.lua`: fixed pools of original geometric shapes and mouse buttons.
- `Rampage.lua`: WoW roster/events/transport, combat gate, slash commands and local persistence.
- `tests/`: deterministic model, multi-client network simulation and mocked TOC/UI smoke tests.

See [PLAN.md](PLAN.md) for scope and [QA.md](QA.md) for exact evidence and remaining manual checks.

Repository: https://github.com/lemillermicrosoft/Rampage
