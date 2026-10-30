## Brawl flow, safer host succession and varied AI

For WoW Burning Crusade Classic 2.5.6 / Interface 20506. The owner approved publishing the installed b98c93c playtest on October 30, 2026 after positive in-game feedback. This release preserves that gameplay; only the release version and documentation change.

### Upgrade every participant together

All players need this R5 release. Published v0.4.0 uses R4 and cannot participate. The reviewed b98c93c candidate already uses the same R5 gameplay, but use the versioned release ZIP for a coordinated installation. Extract its single Rampage folder into Interface/AddOns without double nesting; safely reload when ready and out of combat.

The owner's local installation remains the tested frozen b98c93c candidate during publication; publishing does not relabel or overwrite those files. No forced reload or external SavedVariables edit. The primary checkout advances to the published release. An older rollback junction pointing to that primary checkout therefore follows the updated release, not v0.4.0; preserved v0.4.0 ZIP/frozen files are the actual old-version rollback.

### UI and participation

- Compact city-first layout, separate INFO and SETTINGS, and Mouse/Keyboard selectors reflecting actual capture. Opening panels and safety events release keyboard capture without silently taking it back.
- Normal UI and ordinary commands create Brawl rooms. Opening the window may automatically watch an available Brawl room, without an avatar or keys; Join fight requires explicit consent. Leave fight returns to watching; closing retains membership, while explicit Leave suppresses automatic rejoin.
- The legacy Co-op engine remains unchanged for compatibility/testing; normal UI does not create or casually join a Co-op fight or silently convert an existing room.
- Confirmed local damage is YOU; sampled shared damage is TEAM, never an invented remote per-hit combat log. Reduced motion retains static truthful feedback. Same-ID bot replacement entirely between ordinary snapshots remains indistinguishable for cosmetics.

### Bosses and AI

- Actual boss cycle is 3s patrol + SEVEN-SECOND locked warning + 0.5s impact + 3s recovery = 13.5s. The future request for a maximum three-second warning is NOT included in this release.
- Five AI automatically mix Smasher, Chaser, Scrapper and Dodger profiles, distinct targets and legal cadences; the fifth Smasher has an eastern objective bias. AI obey ordinary movement, range, damage, vulnerability and cooldown rules. AI can never become host.
- Up to 25 actors including five AI, with up to 40 real participants including watchers. Human fighters replace filler AI first. Real combat safety and optional audio-off-by-default behavior remain.

### Host succession and honest limits

Host ordering uses longest continuously admitted real participant, including watchers. Leaving/rejoining gets a new ordinal; changing role or closing the window does not. An ordinary host Leave transfers a complete checkpoint without restarting the match; a promoted watcher need not become a fighter.

Recovery is NOT instant. Measured small graceful handoff: 5.3s. Forty-participant graceful handoff with loss/reordering: 31.5s plus 5s settling = 36.5s. Forty-participant crash: 36.4s plus 8s convergence = 44.4s. Crash adoption can roll back uncommitted world, HP and score. These are deterministic transport measurements, not guaranteed native latencies.

Insufficient matching checkpoints, admitted-voter quorum or safe membership evidence pauses rather than running two authorities. Native roster absence cannot revoke an outstanding vote. A true client process restart forgets volatile lineage and may require a fresh room when too few old members remain, especially a two-person room. This is not perfect partition consensus or Byzantine anti-cheat. Checkpoint evidence expires after 120s.

### Verification and first checks

174 automated checks passed: 37 model, 53 protocol/migration, 40 feedback, 36 actual-TOC UI and 8 real-adapter flow; 12 Lua 5.1 grammar checks and zero dependency audit findings. Full tests run again against the final version-bumped runtime before publication. Execution uses Fengari Lua 5.3 semantics, not native WoW.

The 40-node loss test demonstrates a unique unpaused successor advancing its clock. Delayed-vote/rejoin, fresh-process, asymmetric roster and witness-lock regressions pass. Both graceful and crash checkpoints preserve 1,200 exact AI decisions across 24s. Sustained 40-node play measured 677 charged bytes/s and 3.91 host messages/s; initial admission burst averages are not claimed as sustained-rate success.

Owner in-game feedback is positive, but it does not certify two-client/large-raid behavior. Native keyboard focus, rendering/alignment, scaling/taint, optional audio and real PARTY/RAID transport remain manual checks. Start with solo plus five AI, then two clients on the same release before scaling.

Follow-up only: shorter boss warnings, control/radio styling and alignment polish. Blizzard assets or a comparison toggle remain deferred and are not part of this release.
