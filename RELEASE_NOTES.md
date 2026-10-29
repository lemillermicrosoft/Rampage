## Roaming bosses with visible attacks

For **WoW Burning Crusade Classic2.5.6 / Interface20506**. This publishes the reviewed moving-boss feature from PR #8 plus its narrow pre-publication stale-render cue fix. The owner authorized this release on October29,2026. Unique/different level layouts are later work, **not included**.

### Upgrade both machines together

**Every participant needs the same new versioned release. R4 is incompatible with v0.3.0/R3 and older protocols.** Use the attached release ZIP, not a head-labelled playtest archive. Extract its single `Rampage` folder into `Interface/AddOns`, without double nesting, and safely `/reload` when ready.

The owner's existing linked checkout is advanced to this approved release and left there. No junction swap, forced reload or external SavedVariables edits are performed. Do not extract over that junction; the other machine installs the same versioned ZIP. Earlier releases and candidate archives remain preserved for rollback.

### Boss movement and attacks

- Bosses really patrol ground lanes2–6, at most two lanes in five seconds. A **shared authoritative position** drives punch reach, AI pursuit and visible location; no stationary3–5 ghost hitbox. After flattening the city, hit the exposed boss **on the ground within one lane** of its actual position. The gold bracket follows its reach. No body-contact damage.
- Cycle: **5s patrol →7s locked windup →one impact /0.5s attack →5s stationary recovery**. Targets and attack origin lock before the warning, never track later dodges. At least four safe lanes remain. Recovery gives players time to catch and punch the boss.
- **Crumb Baron:** reflected stroll and one-column crumb throw, all heights.
- **Permitron9000:** two-lane march and adjacent-column beam, all heights.
- **Snack Tax:** nearest-actor pursuit and adjacent ground stomp. **Ground only**; climbing can avoid it.
- **Queuezilla:** alternating strides and three adjacent warned columns striking **together**, all heights.
- Visible moving shield, patrol/windup/release/recovery poses and pooled original throw/beam/stomp/barrage cues show the actual attack origin. Clients never apply damage from animation.
- Clients smooth only the known patrol segment, stopping at its endpoint and freezing when paused/stale. No future route/attack prediction. A timely confirmed recovery may show short static impact residue at already-known targets, never a late projectile or damage replay.

### Review fix included

An old warning sample could become stale while no frames rendered, then incorrectly show confirmed-impact residue when a delayed consecutive recovery arrived. The UI now checks **previous sample age before replacing its timestamp**, even without an intermediate render. More than2.5s suppresses late residue and clears the stale visual baseline; normal timely confirmation and the exact2.5s boundary remain unchanged. This is presentation-only; no gameplay/schema/latency change.

### Existing controls and multiplayer preserved

- **Selected keyboard or mouse mode persists across ordinary level transitions.** Held inputs are cleared and require release/fresh press next city. Escape/close/leave/chat/focus/modifiers/real combat still release capture, with no automatic recapture. KO/victory behavior unchanged.
- Default **Co-op**, explicitly opted-in **Brawl**,100HP,20-damage punches,35-damage boss impacts,4s KO/respawn and3s spawn immunity retained.
- Host/solo can add/remove up to **five AI within25 actors**; real humans displace filler AI first. **40 real participants** including spectators, separate from AI. Spectators remain read-only and immune. Host combat pauses movement/warnings/recovery; guest protection is reconciled before known damage.
- Optional local BlasterMaster audio remains **OFF by default**. No copied external audio/art or global volume changes.

### Quick start and confidence limits

`/rampage solo` →Add AI→PLAY. Watch a full patrol/windup/attack/recovery cycle, flatten the city, then chase the moving boss and hit inside its bracket. Start with two clients on the same release in one PARTY/RAID before scaling.

**73 automated checks** (22 model,26 protocol,25 actual-TOC WoW/UI/input/audio mocks),9 Lua5.1 grammar checks and zero dependency audit findings. The new no-intermediate-render regression was demonstrated failing before the fix and passing afterward. Independent baseline review also exercised28,000 off-grid world round trips. Execution uses Fengari Lua5.3 semantics, not native WoW.

**Authoritative worlds still arrive every1.25s; no prediction.** Seven-second warnings exceed the tested4s maximum gap but are not a guarantee under arbitrary network loss. Remote countdowns and hit feedback can lag; dodge early. Some0.5s attack frames can fall between snapshots. This is friendly/nonprecision play, not competitive network fighting. Native rendering/fonts/scaling, keyboard focus/taint, real two-client response, optional audio and large live raids remain manual checks. See QA.md for evidence and limitations.
