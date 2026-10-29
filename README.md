# Rampage — FOUR MORE BOSSES!

**<Toast>'s pocket raid-break arcade.** Original monsters climb and smash a shared city, then flatten four fictional bosses. For **TBC Classic 2.5.6 / Interface 20506**. Inspired by classic climb-and-smash play, with original art and no affiliation with the original Rampage game's owners.

## Roaming-boss release — R4

Bosses now **really patrol, wind up and attack from their visible ground position** ([issue #7](https://github.com/lemillermicrosoft/Rampage/issues/7)). The same pure position helper drives model punch reach, AI pursuit and UI location: this is not cosmetic bobbing over the old fixed hitbox. Four original personalities use visible charge/throw/beam/stomp/barrage cues and forgiving recovery windows. Existing AI, health/KO and optional Brawl remain; **Co-op is still the default**.

The owner authorized publishing the reviewed moving-boss build on October29,2026 at12:57. This release uses **R4, incompatible with v0.3.0/R3**. **Both machines/all participants must install the same new versioned release**, not an older release or head-labelled candidate ZIP. Download it from [GitHub releases](https://github.com/lemillermicrosoft/Rampage/releases) or [CurseForge](https://www.curseforge.com/wow/addons/rampage-four-more-bosses); CurseForge upload acceptance and public approval are separate.

Development stayed isolated until approval. Publication updates the primary linked checkout to the new release and leaves it there; it does not change the WoW junction, force a reload or edit SavedVariables. The owner can safely reload when ready after publication completes; the other machine needs the matching release ZIP. Old release/candidate archives are preserved. Unique levels remain later backlog, not included.

Pre-publication review also fixed a narrow presentation edge: an unrendered stale sample can no longer trigger late confirmed-impact residue when the next world arrives. Previous sample age is checked before replacing its timestamp, retaining timely confirmation and the exact2.5s boundary.

## Try the new fun in one minute

1. Install the **same new versioned R4 release** on both machines, then safely `/reload` when you choose. Preserve v0.3.0 for rollback. The owner's existing junction already points at the primary checkout that publication updates; do not extract over that junction or switch it to the development worktree.
2. Type **`/rampage solo`** for default Co-op. Click **+ ADD AI** to add one helper. Click **PLAY • GRAB KEYS** and use **WASD/arrows + Space**. **Escape releases keys**.
3. For friendly fighting, **Leave**, select **BRAWL**, then **Solo practice**, or use **`/rampage solo brawl`**. Add one AI and punch it from the same height within one lane. AI can hit you back, but still works on the city.
4. Watch the boss **patrol → raise/charge → attack → recover**. Dodge early during its seven-second warning. Ranged attacks affect every height in marked columns; **Snack Tax's stomp is ground-only**. After the city falls, chase the boss and punch from within one lane on the ground; the gold bracket shows its reach.
5. In a party/raid, open `/rampage`, choose Co-op or Brawl and **HOST LOBBY**. Add AI if desired, then **START GAME**. Friends explicitly click **JOIN CO-OP**, **JOIN BRAWL**, or **SPECTATE**.

A host can choose mode only in lobby/victory **with no other real participants joined**. No silent mid-match or replay conversion into PvP. Start a new lobby or have guests leave before changing mode. Spectators switching to Brawl see **JOIN BRAWL**; a generic chat `/rampage join` or `/rampage play` does not silently opt them into PvP.

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

Original warm city and creatures show HP, hurt flashes, immunity, KO countdowns and AI/KO labels. Seven fixed lane markers,72 pooled particles and48 boss-cue textures handle warnings/attacks/destruction. Buttons retain hover/pressed/disabled/selected states. The900×660 window fits down to available space. Pools remain **105 frames /1,404 textures /97 fonts** after exactly500 animated25-actor renders; this is bounded WoW-object evidence, not zero Lua allocations or native frame-time proof.

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
node tests/ui-preview.cjs --scene boss-patrol --output docs/previews/boss-patrol-mock.svg
node tests/ui-preview.cjs --scene boss-windup --output docs/previews/boss-windup-mock.svg
node tests/ui-preview.cjs --scene boss-impact --output docs/previews/boss-impact-mock.svg
```

**73 tests**:22 model,26 protocol,25 actual-TOC WoW/UI/input/audio mocks, retaining the stage-transition control-persistence regression. **9 Lua files** parse as Lua5.1 grammar; **Fengari executes Lua5.3 semantics**, not native WoW Lua. Single AI clears four moving bosses in100.8 simulated seconds; five AI in50.8s Co-op/85.2s Brawl; separate fixtures prove AI harm/KO. Source-derived mock previews are labelled **not WoW screenshots**. See [QA.md](QA.md) for what was actually checked and remaining native tests.

Repository: https://github.com/lemillermicrosoft/Rampage
