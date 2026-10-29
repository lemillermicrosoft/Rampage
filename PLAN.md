# Rampage — roaming-boss iteration

## User request
After v0.3.0's AI/Brawl improvement, make bosses visibly **move and attack**. Keep unique/different levels as later backlog. Do not mix the next candidate into the household's released install.

## Isolation / release boundary
- Worktree: `C:\Users\leroy\repos\Rampage-boss-motion`, feature branch for issue #7, based on `7c27d1b` / v0.3.0.
- Primary checkout remains clean released main; actual anniversary AddOns junction still targets `C:\Users\leroy\repos\Rampage`.
- Candidate is not installed. No forced reload, junction swap, SavedVariables edits, release/config/workflow/tooling changes or external audio/art.
- New PR + unique ZIP only. No merge/tag/GitHub/CurseForge publication without fresh approval. TOC remains0.3.0 but R4 is incompatible with released v0.3.0/R3; all testers must use the same head-labelled candidate.

## Implemented playable scope
- Shared pure boss position for movement, hit checks, AI pursuit and rendering. Ground patrol stays in lanes2–6 at ≤2 lanes per5s; no old fixed3–5 hitbox or body-contact damage.
- Cycle: **5s patrol →7s locked windup →0.5s once-only attack →5s stationary recovery**. At least four safe lanes; origin and targets stop moving before warning starts.
- Crumb Baron stroll/throw; Permitron march/beam; Snack Tax nearest-actor pursuit/ground-only stomp; Queuezilla alternating strides/simultaneous three-column barrage.
- Moving shield, ground reach bracket, phase-specific limbs and48 fixed boss-cue textures connect actual origin/targets. Clients only smooth the known patrol segment and freeze on pause/staleness. No client damage or future-phase prediction.
- If a timely consecutive world skips the short attack pose but confirms recovery of the same warned cycle, display a short static confirmed-impact residue, never a delayed projectile or catch-up damage. Late joins/gaps/stale/pause do not trigger it.
- Existing default Co-op, opt-in Brawl consent, health/KO/respawn, five-AI/25-actor/40-real-participant caps and pre-tick guest combat protection retained.
- Shipped control-persistence fix unchanged: selected keyboard/mouse survives ordinary level transitions, held inputs do not replay, explicit/safety releases never auto-recapture.

## Verification
- [x] Deterministic bounded movement, exact hit/miss/shield behavior, locked attack timing, stationary recovery, ground/ranged damage, pause and reset.
- [x] AI chase and solo/five-AI four-boss completion in Co-op/Brawl.
- [x] R4 strict compact-world round trips, late join, malformed/stale/reordered/lost worlds, no client impact replay.
- [x] Actual40-node maximum-name/mixed-AI simulations within existing700 chargedB/s and8msg/s limits; no higher bandwidth allowance.
- [x] Actual TOC/input/UI/audio regression suite; fixed object pools and source-derived patrol/windup/impact previews.
- [ ] New native WoW graphics, focus/taint, two-client response, audio and large live raid checks.

## Deliberate limits
Full worlds still every1.25s. Seven-second windup exceeds the measured4s gap but arbitrary loss can hide warnings. Clients may miss the0.5s attack pose; confirmed aftermath is presentation-only. Known-segment animation is not network precision. No host migration, malicious-host anti-cheat, map overhaul, new combat progression or contact physics.

## Later backlog — not this PR
Distinct level silhouettes, tower arrangements, palettes and boss-specific scenery after the moving-boss playtest. New level work receives separate scope/approval; it is not silently bundled here.
