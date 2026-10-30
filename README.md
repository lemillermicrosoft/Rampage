# Rampage — FOUR MORE BOSSES!

**<Toast>'s pocket raid-break arcade.** Original monsters climb and smash a shared city, then flatten four fictional bosses. For **TBC Classic 2.5.6 / Interface 20506**. Inspired by classic climb-and-smash play, with original art and no affiliation with the original Rampage game's owners.

## Hit-feedback playtest — unreleased, compatible R4

This iteration makes damage easier to **feel and understand** ([issue #10](https://github.com/lemillermicrosoft/Rampage/issues/10)): brief monster-local recoil, readable HP-loss numbers/trails, confirmed contact sparks, persistent boss HP/shield/range guidance, and a **Reduced Motion** toggle. It does not rebalance gameplay or add levels.

**This is a new, unreleased candidate based on v0.4.0**, not a new CurseForge/GitHub release. Displayed TOC/app version stays0.4.0. **Model.lua and Protocol.lua are unchanged from v0.4.0; wire protocol remains R4**, with no new messages or budget increase. It can communicate with v0.4.0/R4, but use the same head-labelled feedback candidate on testers who want these visuals. Older v0.3.0/R3 is incompatible.

The primary WoW-linked checkout stays clean on published **v0.4.0**. Its junction is unchanged; simply reloading that installation **does not load this candidate**. No forced reload, install or external SavedVariables change is performed. Keep the matching release on household machines until choosing a coordinated playtest; do not extract over the owner's primary-checkout junction. Earlier worktrees/releases/candidates remain preserved. A new approval is required to merge/tag/publish; previous release approvals are consumed.

Moving bosses, shared actual hitbox/AI, seven-second warnings, the prior stale-render cue fix, restored building windows/trim and input-mode persistence are retained. **Co-op remains the default**, Brawl is optional, unique levels remain later work.

## Try the new fun in one minute

1. After review and choosing to test, install the **head-labelled hit-feedback ZIP** in a coordinated test install and safely `/reload` when ready. Preserve v0.4.0 for rollback. Do not extract over the owner's existing junction; it deliberately still targets the stable release.
2. Type **`/rampage solo`** for default Co-op. Click **+ ADD AI** to add one helper. Click **PLAY • GRAB KEYS** and use **WASD/arrows + Space**. **Escape releases keys**.
3. For friendly fighting, **Leave**, select **BRAWL**, then **Solo practice**, or use **`/rampage solo brawl`**. Add one AI and punch it from the same height within one lane. AI can hit you back, but still works on the city.
4. Watch the boss **patrol → raise/charge → attack → recover**. Dodge early during its seven-second warning. Ranged attacks affect every height in marked columns; **Snack Tax's stomp is ground-only**. After the city falls, chase the boss and punch from within one lane on the ground; the gold bracket shows its reach.
5. In a party/raid, open `/rampage`, choose Co-op or Brawl and **HOST LOBBY**. Add AI if desired, then **START GAME**. Friends explicitly click **JOIN CO-OP**, **JOIN BRAWL**, or **SPECTATE**.

A host can choose mode only in lobby/victory **with no other real participants joined**. No silent mid-match or replay conversion into PvP. Start a new lobby or have guests leave before changing mode. Spectators switching to Brawl see **JOIN BRAWL**; a generic chat `/rampage join` or `/rampage play` does not silently opt them into PvP.

## What the feedback means

- **Incoming:** `YOU -20 HP` means your health actually fell by20. A short warm tint, at most0.28s damped sprite recoil and an amber health-loss trail reinforce it. Nearby monsters react more subtly. No world camera, window or authoritative hitbox moves.
- **Outgoing:** `YOU HIT -1 HP` over a building/boss is an exact confirmed host/solo local action. A swing into empty space only shows the fist—no contact sparks or damage number. Building HP damage is **not** the10 fame awarded for a floor hit, nor boss damage the15 fame awarded for a boss hit.
- **Remote:** `TEAM HIT -3 HP` is total observed target HP loss between timely worlds, potentially several hits from anyone/AI. R4 has no per-attacker receipts, so the client never claims those hits were yours. A successful input send proves only swing intention. This does not reduce1.25s network feedback delay.
- **Boss clarity:** HP/maxHP remains visible while shielded or exposed. The readout shows remaining floors to destroy, and ground/range guidance uses the same moving-boss helper as hit checks. Host/solo air punches get throttled known explanations; remote guidance/bracket is explicitly **sampled/estimated**, not a host rejection acknowledgement. In Brawl, the highlighted eligible rival is the lowest slot at the same height within one lane; city/boss damage can also occur on that punch under the existing rules.
- **Reduced Motion:** toggle at bottom right. Saves through ordinary addon settings; immediately removes recoil, decorative bob/bounce, number rise and moving particles. Useful static numbers, health trails, highlights and essential boss telegraph poses remain. Gameplay movement and damage do not change.
- New-session/reopen/stage/replay/role/known slot replacement, pause/combat, expired/duplicate/reordered/gapped/stale samples rebaseline without catch-up effects. The previous arrival's age is checked before replacing its timestamp, even after a render stall;2.5s is the inclusive cutoff. Heals/respawns do not become damage. Repeated renders never repeat a hit or award score.

Feedback is deliberately bounded:32 queued receipts, at most8 nonlocal receipts per undrained batch,12 reused number labels with local/boss priority, existing72 pooled particles. Labels can combine short-lived losses; they are not a fabricated hit-by-hit combat log. Under heavy load some nonlocal decoration is omitted. R4 cannot distinguish a same-ID bot removed/readded entirely between snapshots; visible removals, bot-ID changes and known membership generations do reset feedback.

## Rules and balance

### Smash the city
- Walk sideways on the ground; climb towers in lanes **2, 4, 6**.
- Punch each floor twice, descend between floors. The lowest floor can also be hit from the ground. Collapsing a tower drops its climbers to the street.
- Flatten all towers to remove the boss shield; punch the exposed boss **on the ground within one lane of its actual moving position**. Fixed lanes3–5 no longer hit a boss that has moved away. No damage from body contact.
- Defeat **The Crumb Baron**, **Permitron 9000**, **The Snack Tax**, and **Queuezilla**. Boss HP is 10/12/14/16; two-second scene changes lead to shared victory.
- Floor hits give 10 fame, final tower collapse 40, boss hits 15 and the final boss hit 100. **KOs are a separate counter**, not bonus city fame. Team fame sums current actors; removing an actor/switching to spectate removes that actor's current score. Personal best persists.

### AI monsters
**+ ADD AI / - REMOVE AI** are host/solo-only, one monster per click, **maximum five AI within 25 total actors**. They are deterministic in-addon game logic, not an LLM/backend, WoW character bot, or automation of real spells/movement.

Pebble Pal, Noodle Knight, Mochi Boots, Waffle Scout and Bumble Brick climb/smash, fight exposed bosses, try to dodge imminent hazards and briefly scuffle in Brawl. They use the same legal model actions/cooldowns and can be hurt/KO'd. They are intentionally simple, not perfect players. Remove AI removes the oldest bot.

AI does not consume any of the **40 real participant** seats. A human joining or switching to Play at the 25-actor cap automatically vacates the oldest AI first. With 20 human actors + five AI, up to 20 real spectators can watch. Without AI, the usual full roster is 25 human actors +15 spectators. No active human is displaced.

### Health, Brawl and respawns
- **100 HP**; Brawl punch **20 damage**, boss impact **35 damage**. Co-op punches never harm allies.
- Brawl hits at most one other actor, at the same height and within one lane. Model actions are capped at 0.2s; PvP punch damage has a separate **0.6s cooldown**. Damage briefly grants 0.8s immunity and knocks you one ground lane or one floor down.
- At zero HP, **4-second KO**, then respawn at lane 1 with full health and **3 seconds of immunity**. Stage changes reset health/protection timers; replay resets fame and KOs.
- KO releases keyboard capture; click PLAY after respawn to take control again. Spectators have no avatar, health target, attacks, score or Start authority.
- The host and mode are trusted for friendly play, not a competitive anti-cheat service. There is no prize, permanent death or PvP penalty outside this minigame.

### Roaming bosses and visible attacks
Every boss moves and attacks while shielded **and** exposed. Each cycle is **5s patrol →7s locked windup → one impact /0.5s attack pose →5s stationary recovery**. Patrol stays in lanes2–6 and covers at most two lanes in five seconds. The five-second stop lets remote players catch up and punch. Warning origin/targets are fixed before impact, never track your dodge; at least **four of seven lanes remain safe**.

- **Crumb Baron:** one-lane reflected stroll; throws crumbs at one warned column, all heights.
- **Permitron9000:** two-lane reflected march; beams two adjacent warned columns, all heights.
- **Snack Tax:** one-lane pursuit of the nearest eligible actor, deterministic ties; stomp affects its lane and adjacent lanes **on the ground only**. Climbing is a valid escape.
- **Queuezilla:** alternating one-/two-lane strides; three adjacent warned columns hit **together**, all heights—not an unannounced sequential sweep.

Visible limb poses and a fixed48-texture pool connect the boss's locked origin to the warned targets. Shield and ground reach move with it. AI follows the same actual hitbox, leaves threatened lanes and waits through impact instead of instantly walking back in.

The UI never applies damage. Clients smooth only the current known patrol segment, capped at its endpoint and2.5s snapshot age; pause/staleness freezes the pose and no next phase is predicted. A0.5s attack can fall between1.25s worlds. A timely consecutive windup→recovery receipt can show **0.65s static impact residue**, clearly labelled confirmed, at already-known targets; it never launches a late projectile or awards damage. Late joins, gaps, stale snapshots and pause do not trigger catch-up cues. Not every attack frame is guaranteed visible remotely.

Seven-second warnings exceed the measured **4.0s maximum world gap** in the tested fixture, not arbitrary loss/delay. Remote countdowns are samples and can lag; dodge early. Known-segment animation does not make multiplayer movement/hits low-latency.

## Raid controls and protection

Keyboard capture is explicit and visible, only for an active, healthy monster. **Your chosen keyboard or mouse control mode persists across ordinary stage/intermission transitions.** Captured keys remain routed to Rampage while gameplay is paused between cities; held actions are cleared and require key-up/fresh key-down in the next city. Escape/close and safety releases still cancel capture, with no automatic recapture. Unknown keys/chat shortcuts, edit focus, Escape, hide, Leave, combat, modifier shortcuts, physical missed-key-up reconciliation and long interruptions release it. **No permanent/override keybindings or protected spell actions.** Mouse fallback uses font-safe **A/Left, W/Up, SPACE, S/Down, D/Right** labels. Reopening no longer displays the stale “Window hidden” reason.

Host WoW combat freezes the game clock, AI, hazards, HP/KO/immunity and transitions. A guest in real WoW combat receives damage/action protection via a versioned notification **or** the host's read-only `UnitAffectingCombat` roster check. The fallback is applied before the hazard/AI tick. Unresponsive guests are protected after 12s and removed after 35s. Detection/notification still has an inherent delay; unavailable status cannot be known before evidence arrives. This is friendly protection, not exploit-proof PvP.

Combat hides the window. Returning can restore the previous window but never recaptures keys automatically. Native taskbar focus/propagation/taint still needs the actual-client checklist in [QA.md](QA.md); a mock cannot prove it. The screenshot's red “You have no target” was not attributed to this addon without evidence.

## Optional audio and visuals

**Local BM** remains **OFF by default**, plus independent **Mute Rampage**. It uses separately installed `BlasterMaster_GetSfxPath` mappings (`crit`, `combatStart`, `levelUp`), honors None/mute/provider variants, checks playback success, and never copies sound files or changes global volume. Local hurt cues are rare/throttled; spectators hear only major transitions. No 25-monster network sound chorus or catch-up burst.

Original warm city and creatures show HP, hurt flashes, immunity, KO countdowns and AI/KO labels. Seven fixed lane markers,72 pooled particles and48 boss-cue textures handle warnings/attacks/destruction. Buttons retain hover/pressed/disabled/selected states. The900×660 window fits down to available space. Pools remain **106 frames /1,586 textures /111 fonts** after exactly500 animated25-actor renders; this is bounded WoW-object evidence, not zero Lua allocations or native frame-time proof.

## Network and limitations

**R4, incompatible with R1/R2/R3.** Actual roster sender, host/session, admission generation, input epoch/sequence and role validation remain. Bots have no physical membership identity and cannot be commanded by forged guest packets. Complete worlds carry mode, game clock, human/bot positions, HP/KO/immunity/protection/KOs and hazard pattern/timer.

- **Three fragments per world**, maximum-valid fixture **494 assembled body bytes /593 combined payload bytes /641 charged bytes**, largest packet209/255. R4 adds only two body bytes over R3; atomic bounded assembly/stale/malformed/duplicate/incomplete rejection retained.
- Per sender: **8 msgs/s / 700 charged B/s**, burst 10 /1,000, including 16-byte accounting allowance per packet; queue 128, assemblies 3×3 with 6s expiry.
- **Complete snapshots every 1.25s (0.8Hz)**; ~30Hz animation and ~5Hz key sampling do not mean fast network response. No prediction. Name carousel one record/second; names may populate gradually.
- Maximum-name40-client simultaneous join took **41.3s**, host685.9 chargedB/s, queue53/128 in simulation; join timeout90s. Host-world timeout20s; keepalive8s. No host migration, no instance-chat/battleground routing; normal PARTY/RAID only.
- **82.9s40-client fixture:**20 human actors+5AI+20spectators, four moving bosses/replay/combat and4.35% loss+jitter/reordering/duplicates; human drivers chase from their delayed snapshots, exact final convergence. Host **3.46msgs/s /513.1chargedB/s**, whole group **36.00msgs/s /1,375.9payloadB/s**. Queue41/128; maxworldgap4.0s.

These are headless tests, **not real 40-client WoW transport measurements**. Combat is deliberately forgiving and noncompetitive at this cadence. Start with solo and two clients before a crowded raid. Protocol details: [docs/PROTOCOL.md](docs/PROTOCOL.md).

## Development / evidence

```text
npm ci --ignore-scripts
npm test
npm run check:lua51
npm audit --audit-level=moderate
node tests/run.cjs --suite=wow
node tests/run.cjs --suite=feedback
node tests/ui-preview.cjs --scene hit-before --output docs/previews/hit-before.svg
node tests/ui-preview.cjs --scene hit-impact --output docs/previews/hit-impact.svg
node tests/ui-preview.cjs --scene hit-settle --output docs/previews/hit-settle.svg
node tests/ui-preview.cjs --scene hit-reduced --output docs/previews/hit-reduced.svg
```

**119 tests**:22 model,26 protocol,39 feedback-state,32 actual-TOC WoW/UI/input/audio mocks, retaining all74 baseline checks including stage controls, stale-residue and building details. **11 Lua files** parse as Lua5.1 grammar; **Fengari executes Lua5.3 semantics**, not native WoW Lua. Single AI clears four moving bosses in100.8 simulated seconds; five AI in50.8s Co-op/85.2s Brawl; separate fixtures prove AI harm/KO. Source-derived mock previews are labelled **not WoW screenshots**. See [QA.md](QA.md) for what was actually checked and remaining native tests.

Repository: https://github.com/lemillermicrosoft/Rampage
