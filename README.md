# Rampage — FOUR MORE BOSSES!

**<Toast>'s pocket raid-break arcade.** Original monsters climb and smash a shared city, then flatten four fictional bosses. For **TBC Classic 2.5.6 / Interface 20506**. Inspired by classic climb-and-smash play, with original art and no affiliation with the original Rampage game's owners.

## Chaos release — AI, Brawl and bosses that fight back

This release extends v0.2.0 with deterministic computer monsters, optional PvP Brawl, health/knockouts, active boss threats and clearer controls ([issue #5](https://github.com/lemillermicrosoft/Rampage/issues/5)). **Default remains PvE Co-op:** teammates cannot hurt each other, but bosses can. **Brawl is optional:** monsters can also punch one another. The owner explicitly authorized publishing the reviewed AI/Brawl build on October 29, 2026 after positive in-game feedback.

**Every participant must upgrade to this same new release.** It uses **R3**, incompatible with v0.2.0's R2. The release pipeline assigns a new matching TOC/runtime version; use the versioned ZIP from [GitHub releases](https://github.com/lemillermicrosoft/Rampage/releases) or [CurseForge](https://www.curseforge.com/wow/addons/rampage-four-more-bosses), not the older candidate ZIP. CurseForge upload acceptance and public approval are separate. Old release/tag/archives remain preserved.

Bosses already deal telegraphed lane damage, but their display remains stationary apart from presentation animation. **Roaming bosses and more varied levels are future work, not included or automatically approved for publication in this release.**

## Try the new fun in one minute

1. Install the same versioned release on both machines: place its `Rampage` folder inside `Interface/AddOns`, then safely `/reload` when you choose. Do not nest the folder twice. The owner's linked checkout remains on the release; no forced reload or junction change is performed.
2. Type **`/rampage solo`** for default Co-op. Click **+ ADD AI** to add one helper. Click **PLAY • GRAB KEYS** and use **WASD/arrows + Space**. **Escape releases keys**.
3. For friendly fighting, **Leave**, select **BRAWL**, then **Solo practice**, or use **`/rampage solo brawl`**. Add one AI and punch it from the same height within one lane. AI can hit you back, but still works on the city.
4. **Dodge marked boss lanes.** Warnings last seven authoritative game seconds before impact. Descend if necessary and move out of the marked columns; every height in a marked lane is threatened.
5. In a party/raid, open `/rampage`, choose Co-op or Brawl and **HOST LOBBY**. Add AI if desired, then **START GAME**. Friends explicitly click **JOIN CO-OP**, **JOIN BRAWL**, or **SPECTATE**.

A host can choose mode only in lobby/victory **with no other real participants joined**. No silent mid-match or replay conversion into PvP. Start a new lobby or have guests leave before changing mode. Spectators switching to Brawl see **JOIN BRAWL**; a generic chat `/rampage join` or `/rampage play` does not silently opt them into PvP.

## Rules and balance

### Smash the city
- Walk sideways on the ground; climb towers in lanes **2, 4, 6**.
- Punch each floor twice, descend between floors. The lowest floor can also be hit from the ground. Collapsing a tower drops its climbers to the street.
- Flatten all towers to remove the boss shield; punch the exposed boss from ground lanes **3–5**.
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

### Active boss patterns
Every boss attacks while shielded **and** exposed. Each cycle is **7s warning → one impact → 0.5s impact display → 3s recovery**. Warning/impact zones affect all floors in marked lanes, always leaving a safe lane:
- Crumb Baron: rotating single-lane falling crumbs.
- Permitron 9000: adjacent two-lane beam.
- Snack Tax: alternating tower/street lane zones.
- Queuezilla: rotating three-lane sweep.

The UI only displays authoritative threats; it never applies damage locally. Seven seconds is deliberately longer than the **4.0s maximum world gap in the tested loss fixture**, not a guarantee under arbitrary network loss. Remote countdowns are samples from the most recent full host world and can lag; move early, not on the final displayed second.

## Raid controls and protection

Keyboard capture is explicit and visible, only for an active, healthy monster. Unknown keys/chat shortcuts, edit focus, Escape, hide, Leave, combat, modifier shortcuts, physical missed-key-up reconciliation and long interruptions release it. **No permanent/override keybindings or protected spell actions.** Mouse fallback uses font-safe **A/Left, W/Up, SPACE, S/Down, D/Right** labels. Reopening no longer displays the stale “Window hidden” reason.

Host WoW combat freezes the game clock, AI, hazards, HP/KO/immunity and transitions. A guest in real WoW combat receives damage/action protection via a versioned notification **or** the host's read-only `UnitAffectingCombat` roster check. The fallback is applied before the hazard/AI tick. Unresponsive guests are protected after 12s and removed after 35s. Detection/notification still has an inherent delay; unavailable status cannot be known before evidence arrives. This is friendly protection, not exploit-proof PvP.

Combat hides the window. Returning can restore the previous window but never recaptures keys automatically. Native taskbar focus/propagation/taint still needs the actual-client checklist in [QA.md](QA.md); a mock cannot prove it. The screenshot's red “You have no target” was not attributed to this addon without evidence.

## Optional audio and visuals

**Local BM** remains **OFF by default**, plus independent **Mute Rampage**. It uses separately installed `BlasterMaster_GetSfxPath` mappings (`crit`, `combatStart`, `levelUp`), honors None/mute/provider variants, checks playback success, and never copies sound files or changes global volume. Local hurt cues are rare/throttled; spectators hear only major transitions. No 25-monster network sound chorus or catch-up burst.

Original warm city and creatures now show HP, hurt flashes, immunity, KO countdowns and AI/KO labels. Seven fixed lane markers plus 72 pooled particles handle warnings/impacts/destruction. Buttons have consistent hover/pressed/disabled/selected states. The 900×660 window fits down to available UI space. Mock pool remains **104 frames / 1,349 textures / 96 fonts** after 500 animated 25-actor renders; this is allocation evidence, not native frame-time proof.

## Network and limitations

**R3, incompatible with R1/R2.** Actual roster sender, host/session, admission generation, input epoch/sequence and role validation remain. Bots have no physical membership identity and cannot be commanded by forged guest packets. Complete worlds carry mode, game clock, human/bot positions, HP/KO/immunity/protection/KOs and hazard pattern/timer.

- **Three fragments per world**, max-field fixture **591 combined payload bytes**, every packet ≤255; atomic bounded assembly, stale/malformed/duplicate/incomplete rejection.
- Per sender: **8 msgs/s / 700 charged B/s**, burst 10 /1,000, including 16-byte accounting allowance per packet; queue 128, assemblies 3×3 with 6s expiry.
- **Complete snapshots every 1.25s (0.8Hz)**; ~30Hz animation and ~5Hz key sampling do not mean fast network response. No prediction. Name carousel one record/second; names may populate gradually.
- Maximum-name 40-client simultaneous join took **40.4s** in simulation, join timeout90s. Host-world timeout20s; keepalive8s. No host migration, no instance-chat/battleground routing; normal PARTY/RAID only.
- **87.4s 40-client fixture:** 20 human actors +5AI +20 spectators, four bosses/replay/combat and 4.35% loss+jitter/reordering/duplicates; exact final convergence. Host **3.43 msgs/s /509.5 charged B/s**, whole group **41.65 msgs/s /1,544.5 payload B/s**. Max world gap4.0s.

These are headless tests, **not real 40-client WoW transport measurements**. Combat is deliberately forgiving and noncompetitive at this cadence. Start with solo and two clients before a crowded raid. Protocol details: [docs/PROTOCOL.md](docs/PROTOCOL.md).

## Development / evidence

```text
npm ci --ignore-scripts
npm test
npm run check:lua51
npm audit --audit-level=moderate
node tests/run.cjs --suite=wow
node tests/ui-preview.cjs --scene brawl --output docs/previews/brawl-mock.svg
```

**55 tests**: 14 model, 23 protocol, 18 WoW/UI/input/audio mocks. **9 Lua files** parse as Lua5.1 grammar; **Fengari executes Lua5.3 semantics**, not native WoW Lua. A single AI clears all four bosses in 108.8 simulated game seconds; separate fixtures prove real AI harm/KO. Source-derived mock previews are labelled **not WoW screenshots**. See [QA.md](QA.md) for what was actually checked and remaining native tests.

Repository: https://github.com/lemillermicrosoft/Rampage
