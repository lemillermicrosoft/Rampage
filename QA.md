# QA — chaos / AI / opt-in Brawl release

## Evidence boundary and release gate

The owner supplied an actual WoW screenshot of the **published v0.2.0 UI in solo play**. It shows original graphics working, missing arrow glyphs and a stale visible “Window hidden” label. The red “You have no target” message was **not attributed to Rampage** without evidence. The screenshot does not prove this new AI/HP/Brawl/boss iteration, native keyboard routing or live raid networking.

The owner explicitly authorized publishing the reviewed `ac5bef3` AI/Brawl build on October 29, 2026 at 10:34 after positive in-game feedback. This lifts the prior feature-only publication gate, but is not native two-client/raid/input certification. Independent QA passed 55 tests, 9 grammar checks, zero audit findings, four supplemental probes and all13 candidate entry hashes. The release pipeline assigns a new matching TOC/runtime version. **Both machines/all participants must use the same new versioned R3 release**, not published v0.2.0/R2 or the earlier candidate archive. Existing release and candidates are preserved; roaming bosses/new level designs are not included in this release.

Headless execution: Node v24.18.0, Fengari0.1.5 (**Lua5.3 semantics**); separate luaparse0.3.1 **Lua5.1 grammar**. No native Lua5.1 VM, actual new client rendering/input/taint/audio or real 25-/40-client transport proof is claimed.

## Executed checks

- Pre-correction integrated baseline: `npm test` **55/55**. Current release adds one actual-TOC control-persistence regression: **56 checks** (14 model +23 protocol +19 WoW/UI/input/audio); the existing release gate reruns the full exact version-bumped runtime before publication.
- `npm run check:lua51`: **9/9 files parsed** (six actual TOC runtime modules, three Lua test suites).
- `node tests/run.cjs --suite=wow`: **19/19** with the requested control-persistence correction.
- `npm audit --audit-level=moderate`: **zero vulnerabilities**; no dependency changes.
- `git diff --check`: clean. No workflow, release script, CurseForge config or installed-skill changes.
- `node tests/ui-preview.cjs --scene brawl|hazard|ko ...`: exports the actual UI.lua geometry via mocks. Rasterized review PNGs and inspected Brawl/AI, warning and KO scenes; regenerated raid/solo fixtures. **These are mock layouts, not WoW screenshots.**
- After 500 animated 25-actor renders: **104 frames, 1,349 textures, 96 fonts**, seven fixed lane markers and 72 recycled particles; no frame/texture/font growth. This does not establish native frame time or absence of all Lua allocations.

## Model gameplay evidence (14 tests)

Retains original city/movement/climbing/shared destruction/boss exposure/four-stage/replay/score tests, plus:
- Default Co-op rejects human-human/human-AI friendly damage.
- Brawl actual mutual human-human, human-AI, AI-human and AI-AI punches; same-height/adjacent range, action/PvP cooldowns, no multi-target splash.
- 100HP,20 punch damage/35 maximum hazard damage, bounded knockback, separate KO credit, four-second KO, three-second respawn immunity, protection and timer freeze.
- All four bosses repeatedly warn/impact/recover while shielded and exposed, with distinct lane patterns; actual health loss and legal dodge.
- A stationary AI is actually damaged and KO'd by hazards, not just visually flashing.
- A single deterministic AI clears all four bosses with no human inputs in **108.8 simulated game seconds**, exact city fame2,380; repeated run gives the same time.
- Host pause freezes game clock, hazard timing and respawn state. Work is bounded by substeps; stalled-host catch-up is clamped.

## Protocol / authority evidence (23 tests)

Retains roster/host/session/generation/input epoch/role/sequence, malformed/oversize/stale/future/replay, admission challenge, role changes, late join/reconnect, chunk atomicity, loss/reorder/duplicate, timeout/departure and bounded queue/bucket/assembly tests. Added/extended:
- **R3 rejects R2**; Co-op/Brawl advertisement and admission mode must agree.
- Midmatch mode changes rejected; mode changes also rejected at lobby/victory while **any player or spectator is joined**. Already-admitted clients retain consent and fail closed on an unsolicited changed-mode world.
- AI is host/solo authority, at most5/25actors, no physical member IDs/roster names/tokens. Guests cannot command forged AI actors. Human admission/Play requests vacate the oldest AI first; real people are not displaced.
- Spectators remain unattackable/read-only with no avatar/HP/score/input/Start; mode and role switches are explicit.
- Authenticated combat notification sequences reject old/conflicting toggles; host roster fallback OR notification protection. **Roster protection is reconciled before the impact/AI tick**; regression places impact at the very next tick and proves zero damage.
- Full worlds preserve clock, threat id/lanes/phase/timer, health, KO, immunity, protection, KOs and fixed AI identities. Late join is presentation-only; old snapshots cannot reapply damage.
- Three-second snapshot-blackout fixture: warning still visible after recovery, a legal client action escapes and actor takes no impact damage. Arbitrary loss is not guaranteed fair.

### Measured 40-node simulation

Every emitted broadcast independently reaches every other node through the simulated transport. Per-send byte/message budgets and per-tick queue/assembly bounds are asserted.

| Fixture | Observed result |
| --- | --- |
| Maximum-field 25-actor world | **3 fragments,591 combined payload bytes**,639 charged bytes; every packet≤255 |
| Forty96-byte-name real participants | simultaneous admission **40.4s**, full reconnect converges |
| Maximum-name host averages | **4.27 msgs/s,625.1 payload B/s,693.4 charged B/s** |
| Maximum-name queue/world gap | **52/128**, **1.5s** |
| Mixed AI run | **87.4 simulated seconds**,20 human actors+5AI+20spectators; four bosses,replay,host combat,movement |
| Network disruption | **4.35% per-recipient loss**,0–300ms jitter/reordering and duplicates; exact final convergence |
| Mixed-run host | **3.43 msgs/s,454.6 payload B/s,509.5 charged B/s** |
| Whole group | **41.65 msgs/s,1,544.5 payload B/s**,422 guest heartbeats |
| Mixed-run queue/max world gap | **41/128**, **4.0s** |

Hard budgets unchanged:8msgs/s,700chargedB/s,burst10/1,000 (16-byte allowance/message), queue128, three assemblies×three fragments,6s expiry. Complete worlds every **1.25s (0.8Hz)**; names/roles carousel one record/second. Join timeout90s, world timeout20s, guest removal35s. The seven-second warning exceeds the tested worst world gap, but **delay/loss outside the fixture can still hide a warning**. Remote countdowns are authoritative snapshot samples, not perfect clock synchronization; dodge early. No prediction or competitive PvP fairness claim.

## Actual UI/input/audio mock coverage (19 tests)

Full TOC loading; saved variables; solo/mouse fallback; explicit capture and all mapped keys consumed; held-repeat bounds; unknown/chat/edit-focus/Escape/Alt/Ctrl/Meta/hide/leave/combat/world departure/missed-key-up safety; no restricted propagation mutation in combat; no permanent/override binding or public chat calls.

New checks exercise:
- ASCII fallback labels and visible reopen text instead of stale Window hidden.
- User's pre-publication correction: preserve chosen keyboard/mouse mode across clear/intermission and real model next-stage advance. Capture eligibility is separate from action eligibility. Gameplay inputs remain consumed but inactive during transition, old held/OS-repeat actions blocked until key-up, fresh actions work next stage. Escape, close, combat, chat, unknown shortcut and focus-loss during intermission cancel capture and never regrab next stage. KO/victory release behavior unchanged.
- Button hover/pressed/disabled/selected states.
- Mode setup, explicit JOIN BRAWL and spectator-to-player consent; generic chat commands do not auto-consent.
- Host/solo AI controls, five-bot/25-actor cap, distinct bot names/labels/hover chips and no fake roster.
- Admission at 40-real-seat cap and AI replacement at full actor capacity; spectator conversion can vacate an AI.
- Mode selection disabled while real guests are joined, including victory.
- HP bars, local/crew/monster health, KO/countdown/shield, seven threat lanes/warning/impact/recovery; render calls cannot alter model health.
- Host read-only canonical roster→`UnitAffectingCombat` adapter fallback.
- Optional audio defaultoff/missingprovider/None/playbackfalse/exception/mute, rare local hurt/ownhit and major spectator transitions, dedupe/no catch-up; no external assets copied.

Native `IsWindowFocused` is guarded, not assumed present. Physical key-state reconciliation catches lost key-up, not every possible taskbar focus change with no held keys. Native focus/taint remains a manual gate.

## Inspected visual previews

`docs/previews/brawl-mock.svg`, `hazard-mock.svg`, `ko-mock.svg` come from real UI.lua + fixture state. Review PNGs live under `artifacts/rampage/chaos-v3/`, outside the addon runtime Media. Inspected mode selection/readable JOIN/PLAY, AddAI/RemoveAI, AI/KO labels, local health/shield, KO-disabled controls, warning lane strips/edges and action labels. No normal-size button/text clipping seen. Full25monster overlap still exists; hover chips/local highlight help. Native font/color contrast/scaling must still be checked in game.

## Manual client checklist — outstanding for this new candidate

Use identical R3 ZIPs and voluntarily reload only in a safe area.

- [ ] `/rampage solo`: defaultCo-op, AddAI one at a time, bot climbs/smashes; RemoveAI works; HP and bosswarnings visible.
- [ ] Leave→Brawl→Solo→AddAI: move near same-height AI and exchangehits; distinct KOs versus fame, boundedknockback,4srespawn+3simmunity. No ally damage inCo-op.
- [ ] Eachboss warns beforeandaftershielddrops; moveearly outofmarkedlanes, observeavoiddamage; deliberatelystay for35damage. Checknativecontrast/countdownreadability.
- [ ] KeyboardPLAY knownkeys consumed, Escape releases; unknownkeys/chat/searchpass; hide/reopenlabeltruthful, ASCIIfallbacklegible, no stuckrepeats afterAltTab/taskbar/combat/worldload. NormalWoWmovement/spells notstolen whenreleased.
- [ ] Two real clients: lobbyCo-op/Brawllabelconsent, no modechange whileguestjoined, spectatorread-only, human/AI mutualdamage inBrawl, healthyplayer/UIstateconvergence. Native latencyat1.25sworldcadence mustbeacceptable before largeraid.
- [ ] Guest enters realWoWcombat whilehazardnearsimpact: locallyreleases/hides and hostprotects; hostcombatpausesall. Understandinherentdetectiondelay.
- [ ] Scale toward25actors/40realparticipants inclbots/spectators, latejoin/reconnect, botvacatesforhuman, no identitycollision or lastmemberstarvation, actualaddontrafficlimits.
- [ ] Fourbosscompletion/replay resetshealth/KOs/hazards; hostdisconnect/leaveendscleanly,nohostmigration.
- [ ] OptionalBM stillOFFbydefault; enableonlyifwanted; rarelocalhurt/impact,mute/None respected,noaudiochorus or globalvolumechanges.

## Handoff

Publish the currently approved AI/Brawl runtime through the existing pipeline and preserve v0.2.0/prior candidates. Verify exact bumped-runtime tests, portable archive hashes, GitHub asset and CurseForge upload receipt separately from public approval. Leave the main checkout on the new release for two-machine compatibility. No moving-boss implementation, forced client reload, junction swap or external SavedVariables changes in this publication task.
