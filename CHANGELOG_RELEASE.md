# v0.3.0

Changes since v0.2.0.

## Features
- AI monsters, opt-in Brawl and active boss threats (#6) (dffe63d)

## AI monsters, optional Brawl and active boss hazards

For **World of Warcraft: The Burning Crusade Classic 2.5.6 / Interface 20506**. This publishes the reviewed AI/Brawl build from PR #6, explicitly authorized by the owner after in-game feedback on October 29, 2026. **Roaming bosses and unique level layouts are NOT included**; those are separate future iterations. Bosses currently stay in their display position while dealing real telegraphed lane attacks.

### Everyone upgrade together

**Install this same new versioned release on both machines/all participants.** Its **R3** protocol is incompatible with published **v0.2.0/R2**. Extract the single `Rampage` folder into `Interface/AddOns` and safely `/reload` when you choose. Do not mix with old releases or head-labelled playtest archives. No forced reload, SavedVariables edits or junction swaps are performed by publishing.

### What's playable

- **Default PvE Co-op:** smash the shared city and four bosses without hurting teammates. Optional **Brawl** also permits human/human, human/AI and AI/AI punches; **JOIN BRAWL** is explicit consent. Host chooses before Start/replay only with no other real participants joined.
- Host/solo **Add AI / Remove AI**, one per click, **maximum five AI within 25 total actors**. They climb/smash, dodge warnings and scuffle in Brawl using bounded deterministic addon logic, not an LLM/backend or real WoW character automation. Human admission/Play requests vacate the oldest filler AI first.
- **40 real participants** including the host; AI does not consume human seats. Example:20 human actors +5AI +20spectators. Spectators have no avatar, attack, health target, score or Start authority.
- **100HP**,20-damage adjacent/same-height Brawl punches,35-damage boss impacts, bounded knockback/cooldowns and KOs separate from fame. **Four-second KO/respawn, three-second spawn immunity**; click PLAY after respawn to recapture keys.
- Four repeated boss lane patterns while shielded and exposed: **seven-second warning → one impact →0.5s impact display →three-second recovery**. Move out of marked lanes early; all heights are affected. Shared city/four-boss completion and replay remain.
- Clear health/AI/KO/shield HUD, seven pooled danger-lane markers, consistent hover/pressed/disabled/selected buttons, ASCII fallback action labels and corrected stale “Window hidden” text.
- **Chosen keyboard/mouse mode now persists across ordinary level transitions**, as requested before publication. Captured controls stay selected through intermission without acting; held input is cleared and needs a key release/fresh press next city. Explicit PLAY capture for WASD/arrows/Space; **Escape releases keys**. Chat/edit focus, combat, hide/leave, modifier shortcuts and interruptions release capture. No permanent keybinding changes. Host combat pauses the world; guest combat protection combines authenticated notification with read-only real roster status.
- Optional **Local BM remains OFF by default**, using separately installed BlasterMaster mappings. Rare local impact/hurt and major transition cues, provider None/mute respected. No external sound clips bundled or global volume changes.

### Quick start

`/rampage solo` → **Add AI** → **PLAY**. For fighting: Leave → BRAWL → Solo practice, or `/rampage solo brawl`, then Add AI. In a party/raid: Host Lobby → select mode/AI → Start Game; the other machine explicitly Join Co-op / Join Brawl / Spectate.

### Verified evidence and limitations

**56 automated checks**,9 Lua5.1 grammar parses, zero dependency audit findings. The prior55-check candidate was independently reviewed with four supplemental probes; the additional actual-TOC regression covers the requested stage-transition control persistence and safety cancellation. A single AI clears all four bosses in108.8 simulated seconds. A40-real-node loss/reorder test with25 actors including5AI converges through bosses/replay; this is **not proof of live40-client WoW transport**. Execution uses Fengari Lua5.3 semantics, grammar checking is separate.

**Full authoritative worlds remain every1.25s (0.8Hz), no prediction.** Remote feedback/countdowns can lag. Seven-second warnings exceed the tested4s maximum world gap, but arbitrary delay/loss can hide a warning; dodge early. Brawl is friendly/nonprecision play, not a competitive network-fighting guarantee. Native keyboard focus/taint, two-client response, new audio and large live raid checks remain manual; see QA.md. Positive owner play feedback does not certify those checks.

