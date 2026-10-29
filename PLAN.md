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
The owner explicitly authorized publishing reviewed AI/Brawl candidate ac5bef3 on October 29, 2026 at10:34. Publish PR #6 through the existing default release pipeline, assign a new matching runtime/TOC version and verify GitHub/CurseForge outcomes and ZIP hashes. Every machine must upgrade from old R2/v0.2.0 to the same R3 release. Preserve original tags/archives and leave the main checkout on the new release for the owner's and wife's compatibility. No forced reload, junction swap or SavedVariables edits. Roaming/more visibly attacking bosses are a separate next iteration; unique levels are later backlog. Neither is included or automatically authorized for publishing here.
