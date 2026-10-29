# Rampage — chaos iteration plan

## Vision
Keep the friendly city-smashing raid-break game, but give monsters something to react to: helpful computer teammates, optional mutual Brawl, health/quick respawns and bosses with readable attacks. Co-op remains the default. All damage stays inside the addon minigame.

## Bounded scope delivered
- Host/solo Add AI / Remove AI, one at a time, at most five in the 25-actor cap. Deterministic local logic; no LLM, physical roster impersonation or real WoW actions. Humans take priority over filler AI.
- Optional advertised Co-op / Brawl mode with explicit Join Brawl consent. Owner changes only before Start or replay and with no real guests joined; never silently convert a running/joined game into PvP.
- 100HP, bounded same-height/adjacent Brawl punches, separate KO credit, four-second KO, three-second respawn shield, visible health/hurt/KO/immunity cues.
- Four repeated boss lane patterns, seven-second warning, single damage impact and recovery. Boss attacks before/after shield removal; legal dodging and forgiving damage.
- R3 snapshots carry bots/HP/clock/mode/hazards atomically within bounded packets, queues and the existing per-sender budget. Guest combat protection via authenticated notification and read-only physical-roster fallback, reconciled before simulation.
- Consistent button interaction states, host AI controls, font-safe ASCII fallback controls and truthful visible-window key status. Existing capture/escape/chat/combat/audio safeguards retained.

## Verification
- [x] Deterministic gameplay tests including AI-only four-boss completion and AI being hurt/KO'd.
- [x] Consent, authority, spectator safety, cooldown/range/KO/respawn, host pause, guest protection and stale/lost/reordered protocol tests.
- [x] Forty-node finite-budget simulation with 20 human actors +5AI +20spectators through four bosses/replay; maximum-name join/reconnect and warning-blackout fixtures.
- [x] Integrated real TOC mocked UI/input/audio tests; fixed pools and actual geometry preview export/inspection.
- [ ] Real native AI/Brawl/hazard visual playtest, keyboard/focus/taint and audio.
- [ ] Real two-client response/play balance, then larger raid transport behavior.

## Known tradeoffs
Worlds still arrive every 1.25s, not at animation speed; R3 requires three fragments and a slower name carousel. Seven-second warnings exceed the tested4s worst world gap, but arbitrary loss can still hide a warning. Brawl is forgiving, noncompetitive chaos, not precision network fighting. Simple AI pathing/scuffle/dodge behavior is intentionally bounded; no complex boss phases, host migration or progression expansion.

## Delivery and release boundary
Create a new tested PR for issue #5 from released v0.2.0. Preserve original release/tag/archives; package a uniquely named R3 chaos candidate in task artifacts with portable paths and hash-verified runtime files. Keep TOC version0.2.0 until publication is authorized, clearly distinguish candidate R3 from published R2. No merge/tag/GitHub/CurseForge upload from the feature request; wait for fresh explicit ship approval. No forced client reload or SavedVariables edits.
