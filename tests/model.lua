local M = Addon.Model
-- City-only fixtures advance the action clock without boss simulation.
local function act(s, slot, action) s.time = s.time + 0.21; return M.act(s, slot, action) end
local function active(mode)
    local s = M.new(mode); M.addPlayer(s, 1); M.start(s); return s
end
local function walk(s, slot, x)
    while s.players[slot].y > 0 do act(s, slot, "D") end
    while s.players[slot].x < x do act(s, slot, "R") end
    while s.players[slot].x > x do act(s, slot, "L") end
end
local function flatten(s, slot)
    for _, x in ipairs(M.TOWERS) do
        walk(s, slot, x)
        for _ = 1, 3 do act(s, slot, "U") end
        for _ = 1, 3 do
            act(s, slot, "P"); act(s, slot, "P"); act(s, slot, "D")
        end
    end
end

check("model: explicit lobby/start, 25-player cap and restart rules", function()
    local s = M.new(); eq(s.phase, "lobby")
    eq(M.MAX_PLAYERS, 25)
    for i = 1, 25 do assert(M.addPlayer(s, i)) end
    assert(not M.addPlayer(s, 26)); assert(not M.addPlayer(s, 1))
    assert(not M.addPlayer(s, 0)); assert(not M.addPlayer(s, 1.5)); assert(not M.addPlayer(s, "2"))
    assert(not act(s, 1, "R")); assert(M.start(s)); assert(not M.start(s))
    eq(s.boss, 10); eq(#s.hp, 9)
end)
check("model: bounded ground movement and tower-only climbing", function()
    local s = active()
    assert(not act(s, 1, "U")); act(s, 1, "L"); eq(s.players[1].x, 1)
    for _ = 1, 20 do act(s, 1, "R") end
    eq(s.players[1].x, 7); act(s, 1, "L")
    for _ = 1, 10 do act(s, 1, "U") end
    eq(s.players[1].y, 3); assert(not act(s, 1, "R")); eq(s.players[1].x, 6)
    for _ = 1, 10 do act(s, 1, "D") end
    eq(s.players[1].y, 0); assert(not act(s, 1, "BOOM")); assert(not act(s, 8, "P"))
end)
check("model: two monsters damage the SAME floor and share tower collapse", function()
    local s = active(); M.addPlayer(s, 2)
    walk(s, 1, 2); walk(s, 2, 2)
    act(s, 1, "P"); eq(s.hp[1], 1); act(s, 2, "P"); eq(s.hp[1], 0)
    eq(s.players[1].score, 10); eq(s.players[2].score, 10)
    for slot = 1, 2 do act(s, slot, "U"); act(s, slot, "U") end
    act(s, 1, "P"); act(s, 2, "P"); eq(s.hp[2], 0)
    for slot = 1, 2 do act(s, slot, "U") end
    act(s, 1, "P"); act(s, 2, "P")
    assert(not M.towerAlive(s, 1)); eq(s.players[1].y, 0); eq(s.players[2].y, 0)
    eq(s.players[2].score, 70); assert(not act(s, 1, "U"))
end)
check("model: boss shield, exposure and reach checks", function()
    local s = active(); walk(s, 1, 3); act(s, 1, "P"); eq(s.boss, 10)
    flatten(s, 1); assert(not M.cityAlive(s)); eq(s.players[1].score, 300)
    walk(s, 1, 7); act(s, 1, "P"); eq(s.boss, 10)
    walk(s, 1, 4); act(s, 1, "P"); eq(s.boss, 9); eq(s.players[1].score, 315)
end)
check("model: four complete stages, shared victory, exact score and replay", function()
    local s = active()
    for stage = 1, 4 do
        eq(s.stage, stage); flatten(s, 1); walk(s, 1, 4)
        for _ = 1, 8 + stage * 2 do act(s, 1, "P") end
        eq(s.boss, 0)
        if stage < 4 then
            eq(s.phase, "clear"); M.tick(s, 1); eq(s.stage, stage); M.tick(s, 1)
        else eq(s.phase, "victory") end
    end
    eq(s.players[1].score, 2380); eq(M.total(s), 2380)
    assert(not act(s, 1, "P")); M.tick(s, 100); eq(s.stage, 4)
    assert(M.start(s)); eq(s.stage, 1); eq(s.players[1].score, 0); eq(s.phase, "play")
end)
check("model: pause blocks input and intermission progression", function()
    local s = active(); s.paused = true
    assert(not act(s, 1, "R")); eq(s.players[1].x, 1)
    s.phase, s.wait = "clear", 1; M.tick(s, 5); eq(s.stage, 1)
    s.paused = false; M.tick(s, 1); eq(s.stage, 2)
end)
check("model: removal and late addition do not reset shared city", function()
    local s = active(); act(s, 1, "R"); act(s, 1, "P")
    M.addPlayer(s, 2); eq(s.hp[1], 1); eq(s.players[2].score, 0)
    M.removePlayer(s, 2); assert(not s.players[2]); eq(s.hp[1], 1)
end)
check("model: all 25 monsters share tower collapse, stage reset and the four-boss total", function()
    local s = M.new()
    for slot = 1, 25 do assert(M.addPlayer(s, slot)) end
    assert(M.start(s))
    for stage = 1, 4 do
        for slot = 1, 25 do walk(s, slot, 2); act(s, slot, "U") end
        local actor = stage == 4 and 25 or stage
        flatten(s, actor)
        for slot = 1, 25 do eq(s.players[slot].y, 0) end
        walk(s, actor, 4)
        for _ = 1, 8 + stage * 2 do act(s, actor, "P") end
        if stage < 4 then
            M.tick(s, 2)
            for slot = 1, 25 do eq(s.players[slot].x, 1); eq(s.players[slot].y, 0) end
        end
    end
    eq(s.phase, "victory"); eq(M.total(s), 2380)
    assert(s.players[25].score > 0)
end)
check("model: Co-op is default, human and AI allies never take friendly damage", function()
    local s = active(); M.addPlayer(s, 2, 1)
    eq(s.mode, "coop"); eq(s.players[2].name, "Pebble Pal"); assert(s.players[2].bot)
    s.players[1].invuln, s.players[2].invuln = 0, 0
    for _ = 1, 15 do act(s, 1, "P"); act(s, 2, "P") end
    eq(s.players[1].hp, 100); eq(s.players[2].hp, 100); eq(s.players[1].kos, 0)
    assert(not M.damage(s, 2, 35, 1)); assert(not M.addPlayer(s, 3, 6)); assert(not M.addPlayer(s, 3, 1))
end)
check("model: Brawl mutual human/AI punches are adjacent, same-height, bounded and cooldown gated", function()
    local s = M.new("brawl"); M.addPlayer(s, 1); M.addPlayer(s, 2, 1); M.addPlayer(s, 3); M.start(s)
    local a, b, c = s.players[1], s.players[2], s.players[3]
    a.x, b.x, c.x, a.invuln, b.invuln, c.invuln = 3, 4, 7, 0, 0, 0
    assert(M.act(s, 1, "P")); eq(b.hp, 80); eq(c.hp, 100); eq(b.x, 5)
    assert(not M.act(s, 1, "P")); eq(b.hp, 80)
    a.x, b.x, b.invuln = 3, 4, 0
    s.time = 0.21; assert(M.act(s, 1, "P")); eq(b.hp, 80)
    s.time = 1; assert(M.act(s, 2, "P")); eq(a.hp, 80)
    a.x, a.invuln, b.x, b.y = 4, 0, 4, 1
    s.time = 2; assert(M.act(s, 2, "P")); eq(a.hp, 80)
    b.y, c.x, c.invuln = 0, 4, 0; a.x = 7
    s.time = 3; assert(M.act(s, 2, "P")); eq(c.hp, 80)
    c.x, b.x, b.invuln = 3, 4, 0; s.time = 4
    assert(M.act(s, 3, "P")); eq(b.hp, 60)
    a.x, c.x, b.x, a.invuln, c.invuln = 3, 4, 7, 0, 0
    s.time = 5; assert(M.act(s, 1, "P")); eq(c.hp, 60)
    a.x, c.x, a.invuln = 3, 4, 0
    s.time = 6; assert(M.act(s, 3, "P")); eq(a.hp, 60)
    assert(M.addPlayer(s, 4, 2)); local d = s.players[4]
    b.x, d.x, b.invuln, d.invuln = 7, 6, 0, 0
    s.time = 7; assert(M.act(s, 2, "P")); eq(d.hp, 80)
    b.x, d.x, b.invuln = 7, 6, 0
    s.time = 8; assert(M.act(s, 4, "P")); eq(b.hp, 40)
end)
check("model: KO has separate score, four-second respawn, three-second immunity and protection freezes timers", function()
    local s = M.new("brawl"); M.addPlayer(s, 1); M.addPlayer(s, 2, 1); M.start(s)
    local a, b = s.players[1], s.players[2]
    b.invuln = 0; assert(M.damage(s, 2, 999, 1)); eq(b.hp, 65)
    b.invuln = 0; M.damage(s, 2, 35, 1); b.invuln = 0; M.damage(s, 2, 35, 1)
    eq(b.hp, 0); eq(b.ko, 4); eq(a.kos, 1); eq(a.score, 0)
    assert(not M.act(s, 2, "P")); b.protected = true; M.tick(s, 2); eq(b.ko, 4)
    b.protected = false; b.nextBot = 999; M.tick(s, 3.9); assert(b.ko > 0)
    M.tick(s, 0.1); eq(b.ko, 0); eq(b.hp, 100); eq(b.x, 1); eq(b.invuln, 3)
    assert(not M.damage(s, 2, 35, 1)); M.tick(s, 3); b.protected = true
    assert(not M.damage(s, 2, 35)); assert(not M.act(s, 2, "R"))
end)
check("model: all four bosses repeatedly telegraph real lane damage before and after shield drops", function()
    local patterns = {}
    for stage = 1, 4 do
        local s = active(); s.stage, s.phase, s.wait = stage-1, "clear", 0.1; M.tick(s, 0.1); M.tick(s, M.PATROL_TIME)
        local h, p = s.hazard, s.players[1]
        eq(h.phase, "warning"); assert(h.remaining >= 6.999)
        patterns[stage] = table.concat(h.lanes, ",")
        p.x, p.invuln = h.lanes[1], 0
        M.tick(s, 3); M.tick(s, 3); eq(p.hp, 100); eq(h.phase, "warning")
        M.tick(s, 1); eq(h.phase, "impact"); eq(p.hp, 65)
        assert(p.x ~= h.lanes[1] or p.x == 1 or p.x == 7)
        M.tick(s, M.IMPACT_TIME); eq(h.phase, "idle"); M.tick(s, M.HAZARD_COOLDOWN); eq(s.bossMotion.phase, "patrol"); M.tick(s, M.PATROL_TIME); eq(s.hazard.phase, "warning")
        local id = s.hazard.id; for i = 1, 9 do s.hp[i] = 0 end
        p.x, p.invuln = s.hazard.lanes[1], 0
        M.tick(s, 5); M.tick(s, 2); eq(p.hp, 30)
        M.tick(s, M.IMPACT_TIME); M.tick(s, M.HAZARD_COOLDOWN); assert(s.hazard.id > id)
    end
    assert(patterns[1] ~= patterns[2] and patterns[2] ~= patterns[3] and patterns[3] ~= patterns[4])
end)
check("model: stationary bot can be hurt and KO'd; deterministic AI alone clears all four bosses", function()
    local s = M.new(); M.addPlayer(s, 1, 1); M.start(s)
    local p = s.players[1]; p.invuln, p.nextBot = 0, 99999
    for _ = 1, 3 do
        M.tick(s, M.PATROL_TIME); eq(s.hazard.phase, "warning")
        p.x = s.hazard.lanes[1]; p.invuln = 0
        M.tick(s, 5); M.tick(s, 2)
        if p.ko == 0 then M.tick(s, M.IMPACT_TIME); M.tick(s, M.HAZARD_COOLDOWN) end
    end
    eq(p.hp, 0); assert(p.ko > 0)
    local function run(mode)
        local world = M.new(mode); M.addPlayer(world, 1, 1); M.start(world)
        local moved = {}
        for _ = 1, 5000 do
            if world.phase == "victory" then break end
            local b = world.bossMotion
            if b and b.phase == "patrol" and M.bossPosition(world) ~= b.fromLane then moved[world.stage] = true end
            M.tick(world, 0.1)
        end
        eq(world.phase, "victory"); eq(world.stage, 4); eq(M.total(world), 2380)
        for stage = 1, 4 do assert(moved[stage], "Solo AI skipped moving stage "..stage) end
        return world.time
    end
    for _, mode in ipairs({"coop", "brawl"}) do
        local t = run(mode); eq(run(mode), t)
        print(string.format("  Solo deterministic AI %s clears four moving bosses in %.1f game seconds (500s limit)", mode, t))
    end
end)
check("model: warning is dodgable and host pause freezes hazard, HP, respawn and game clock", function()
    local s = active(); local p = s.players[1]; M.tick(s, M.PATROL_TIME)
    p.invuln, p.x = 0, s.hazard.lanes[1]
    M.tick(s, 3); M.tick(s, 3); assert(M.act(s, 1, "R"))
    M.tick(s, 1); eq(p.hp, 100)
    local time, remaining = s.time, s.hazard.remaining
    s.paused = true; M.tick(s, 5); eq(s.time, time); eq(s.hazard.remaining, remaining)
    assert(not M.damage(s, 1, 35))
end)
local function close(a, b) assert(math.abs(a-b) < 0.000001, tostring(a).." != "..tostring(b)) end
local function atStage(stage, mode)
    local s = active(mode); s.stage, s.phase, s.wait = stage-1, "clear", 0.1; M.tick(s, 0.1); return s
end
check("model: shared boss timing aliases preserve seven-second warnings and half-second impacts", function()
    eq(M.PATROL_TIME, 3); eq(M.WARNING_TIME, 7); eq(M.IMPACT_TIME, 0.5); eq(M.HAZARD_COOLDOWN, 3)
    eq(M.BOSS_PATROL, M.PATROL_TIME); eq(M.BOSS_WINDUP, M.WARNING_TIME)
    eq(M.BOSS_ATTACK, M.IMPACT_TIME); eq(M.BOSS_RECOVER, M.HAZARD_COOLDOWN)
    eq(M.MAX_HP, 100); eq(M.MAX_BOTS, 5); eq(M.ACTION_INTERVAL, 0.2); eq(M.BOT_INTERVAL, 0.35)
end)
check("model: actual complete boss cycles take 13.5 seconds instead of 17.5 with unchanged warning and impact", function()
    local oldCycle = 5 + 7 + 0.5 + 5
    for stage = 1, 4 do
        for _, dt in ipairs({0.05, 0.1}) do
            local s = atStage(stage)
            local durations = {patrol=3, windup=7, attack=0.5, recover=3}
            for cycle = 1, 3 do
                local started = s.time
                eq(s.bossMotion.id, cycle)
                for _, phase in ipairs({"patrol", "windup", "attack", "recover"}) do
                    eq(s.bossMotion.phase, phase)
                    local phaseStarted, steps = s.time, 0
                    repeat M.tick(s, dt); steps = steps + 1 until s.bossMotion.phase ~= phase or steps >= 200
                    assert(steps < 200, "Boss phase stalled: "..phase)
                    close(s.time - phaseStarted, durations[phase])
                end
                local measured = s.time - started
                close(measured, 13.5); close(oldCycle - measured, 4)
                assert((oldCycle - measured) / oldCycle > 0.2285 and (oldCycle - measured) / oldCycle < 0.2286)
                eq(s.bossMotion.phase, "patrol"); eq(s.bossMotion.id, cycle + 1)
            end
        end
    end
    print("  Actual cycle 13.5s vs prior 17.5s: 4.0s / 22.857% shorter; four bosses, three cycles, 0.05/0.1s ticks")
end)
check("model: every legal lane and tower height has a real-input escape within the unchanged seven-second warning", function()
    local threatenedCases, maxEscape = 0, 0
    local function threatened(s, x)
        for _, lane in ipairs(s.hazard.lanes) do if lane == x then return true end end
        return false
    end
    for stage = 1, 4 do
        for x = 1, M.LANES do
            for y = 0, (M.towerIndex(x) and M.FLOORS or 0) do
                local s = atStage(stage); local p = s.players[1]
                p.x, p.y, p.invuln = x, y, 0
                M.tick(s, M.PATROL_TIME)
                eq(s.bossMotion.phase, "windup"); close(s.hazard.remaining, 7)
                local warningStarted, origin, lanes = s.time, M.bossPosition(s), table.concat(s.hazard.lanes, ",")
                M.tick(s, 4); eq(p.hp, 100) -- React only in the final three seconds, like AI.
                local function unsafe() return threatened(s, p.x) and (stage ~= 3 or p.y == 0) end
                if unsafe() then
                    threatenedCases = threatenedCases + 1
                    local safe, distance
                    for lane = 1, M.LANES do
                        if not threatened(s, lane) and (not distance or math.abs(lane-p.x) < distance) then
                            safe, distance = lane, math.abs(lane-p.x)
                        end
                    end
                    assert(safe, "No safe lane in boss warning")
                    local actions = 0
                    while unsafe() and actions < 15 do
                        local action = p.y > 0 and "D" or (p.x < safe and "R" or "L")
                        assert(M.act(s, 1, action), "Legal dodge input was rejected")
                        M.tick(s, M.ACTION_INTERVAL); actions = actions + 1
                    end
                    assert(not unsafe(), "Dodge did not escape warning")
                    maxEscape = math.max(maxEscape, actions * M.ACTION_INTERVAL)
                end
                local left = 7 - (s.time - warningStarted)
                assert(left > 0.01); M.tick(s, left - 0.01)
                eq(s.bossMotion.phase, "windup"); eq(p.hp, 100)
                close(M.bossPosition(s), origin); eq(table.concat(s.hazard.lanes, ","), lanes)
                M.tick(s, 0.01); eq(s.bossMotion.phase, "attack"); eq(p.hp, 100)
                close(s.time - warningStarted, 7)
            end
        end
    end
    assert(threatenedCases > 0); assert(maxEscape <= 1.2)
    print(string.format("  Real-input dodge: all 64 legal boss/lane/height cases, %d threatened; max escape %.1fs after 4s reaction delay", threatenedCases, maxEscape))
end)
check("model: actual fractional patrols stay in lanes 2..6, reflect and never exceed two lanes per three seconds", function()
    for stage = 1, 4 do
        local s = atStage(stage)
        for cycle = 1, 12 do
            local b, before = s.bossMotion, M.bossPosition(s)
            eq(b.phase, "patrol"); eq(b.id, cycle); eq(#b.lanes, 0)
            local distance = math.abs(b.toLane-b.fromLane)
            assert(distance <= 2); assert(b.toLane >= 2 and b.toLane <= 6)
            if stage ~= 3 then eq(distance, stage == 2 and 2 or (stage == 4 and (cycle%2==0 and 2 or 1) or 1)) end
            close(M.bossPosition(s, 999), b.toLane)
            M.tick(s, M.PATROL_TIME / 2); close(M.bossPosition(s), (b.fromLane+b.toLane)/2)
            close(math.abs(M.bossPosition(s)-before), distance / 2)
            assert(math.abs(M.bossPosition(s)-before) <= 1 + 0.000001)
            M.tick(s, M.PATROL_TIME / 2); eq(s.bossMotion.phase, "windup"); close(M.bossPosition(s), b.toLane)
            M.tick(s, 5); M.tick(s, 2); M.tick(s, M.IMPACT_TIME); M.tick(s, M.HAZARD_COOLDOWN)
        end
    end
end)
check("model: true fractional hitbox replaces fixed 3..5 reach and city shielding remains authoritative", function()
    local s = atStage(2); local p = s.players[1]
    M.tick(s, M.PATROL_TIME / 2); close(M.bossPosition(s), 5)
    p.x = 6; assert(M.bossInReach(s, p)); act(s, 1, "P"); eq(s.boss, 12) -- shield
    for i = 1, 9 do s.hp[i] = 0 end
    p.x = 3; assert(not M.bossInReach(s, p)); act(s, 1, "P"); eq(s.boss, 12)
    p.x = 6; act(s, 1, "P"); eq(s.boss, 11) -- old hitbox would miss
    M.tick(s, 0.1); close(M.bossPosition(s), 5 + 2 * 0.1 / M.PATROL_TIME)
    p.x = 4; assert(not M.bossInReach(s, p)); act(s, 1, "P"); eq(s.boss, 11)
    p.x, p.y = 6, 1; act(s, 1, "P"); eq(s.boss, 11)
    p.y = 0; act(s, 1, "P"); eq(s.boss, 10)
end)
check("model: warnings lock origin and lanes, impacts occur once, and stationary recovery offers three seconds", function()
    for stage = 1, 4 do
        local s = atStage(stage); local p = s.players[1]
        M.tick(s, M.PATROL_TIME); local b = s.bossMotion
        local origin, lanes = M.bossPosition(s), table.concat(b.lanes, ",")
        eq(b.fromLane, b.toLane); assert(#b.lanes <= 4)
        p.x = 7; M.tick(s, 3); eq(table.concat(b.lanes, ","), lanes); close(M.bossPosition(s, 999), origin)
        p.x, p.invuln = b.lanes[1], 0; M.tick(s, 3.9); eq(p.hp, 100)
        M.tick(s, 0.1); eq(b.phase, "attack"); eq(p.hp, 65)
        p.x, p.invuln = b.lanes[1], 0; M.tick(s, 0.4); eq(p.hp, 65); eq(table.concat(b.lanes, ","), lanes)
        M.tick(s, 0.1); eq(b.phase, "recover"); close(b.remaining, M.HAZARD_COOLDOWN); eq(#b.lanes, 0)
        local recoveryStarted = s.time
        for _ = 1, 29 do
            M.tick(s, 0.1); eq(b.phase, "recover"); close(M.bossPosition(s), origin)
            close(M.bossPosition(s, 999), origin); eq(p.hp, 65); eq(s.hazard.phase, "idle")
        end
        close(b.remaining, 0.1)
        M.tick(s, 0.1); eq(s.bossMotion.phase, "patrol"); close(M.bossPosition(s), origin)
        close(s.time - recoveryStarted, 3)
    end
end)
check("model: ranged columns hit every height; Snack Tax stomp is ground-only; knockback uses the locked boss origin", function()
    for stage = 1, 4 do
        local s = atStage(stage); M.addPlayer(s, 2)
        local p, q = s.players[1], s.players[2]
        p.x, q.x, q.y = 2, 2, 2; M.tick(s, M.PATROL_TIME)
        local b = s.bossMotion
        assert(b.lanes[1] == 2 or b.lanes[2] == 2)
        p.invuln, q.invuln = 0, 0
        M.tick(s, 5); M.tick(s, 2)
        eq(p.hp, 65); eq(p.x, 1)
        eq(q.hp, stage == 3 and 100 or 65); eq(q.y, stage == 3 and 2 or 1)
        eq(M.bossAttackKind(s), stage == 3 and "ground" or "ranged")
    end
    local s = atStage(2); local p = s.players[1]
    p.x = 5; M.tick(s, M.PATROL_TIME); eq(M.bossPosition(s), 6)
    p.invuln = 0; M.tick(s, 5); M.tick(s, 2); eq(p.x, 4) -- NOT away from old lane 4
    s = active(); p = s.players[1]; p.x, p.invuln = 4, 0
    M.tick(s, 2); eq(p.hp, 100) -- no new body-collision damage
end)
check("model: pursuit uses nearest eligible actor, deterministic slot ties and one-lane stride", function()
    local s = active(); M.addPlayer(s, 2); M.addPlayer(s, 3)
    -- Set up a real recovery transition: protected/KO actors cannot lure the boss.
    s.stage = 3; s.hazardID = 1
    s.bossMotion = {id=1,phase="recover",remaining=0.1,fromLane=4,toLane=4,lanes={}}
    s.players[1].x, s.players[2].x, s.players[3].x = 3, 5, 4
    s.players[3].protected = true; M.tick(s, 0.1); eq(s.bossMotion.toLane, 3)
    s.players[1].ko, s.players[1].hp, s.players[1].protected = 4, 0, true
    s.bossMotion = {id=1,phase="recover",remaining=0.1,fromLane=4,toLane=4,lanes={}}
    M.tick(s, 0.1); eq(s.bossMotion.toLane, 5)
end)
check("model: every boss phase freezes on pause and known-segment smoothing never advances a phase", function()
    local s = active(); local p = s.players[1]
    for _, phase in ipairs({"patrol", "windup", "attack", "recover"}) do
        eq(s.bossMotion.phase, phase)
        p.ko, p.hp, p.invuln = 2, 0, 0
        local b, time, position, remaining = s.bossMotion, s.time, M.bossPosition(s), s.bossMotion.remaining
        s.paused = true; M.tick(s, 5)
        eq(s.time, time); eq(b.remaining, remaining); close(M.bossPosition(s, 99), position)
        eq(p.ko, 2); eq(p.hp, 0); eq(s.hazard.remaining, remaining)
        s.paused = false; p.ko, p.hp, p.invuln = 0, 100, 30
        if phase == "patrol" then close(M.bossPosition(s, 99), b.toLane); eq(b.phase, "patrol") end
        if phase == "windup" then M.tick(s, 5); M.tick(s, 2) else M.tick(s, remaining) end
    end
end)
check("model: motion tick partition is deterministic, stage/replay reset all motion and AI chases the actual boss", function()
    local a, b = atStage(4), atStage(4)
    for _ = 1, 1400 do M.tick(a, 0.1); M.tick(b, 0.03); M.tick(b, 0.07) end
    eq(a.bossMotion.phase, b.bossMotion.phase); eq(a.bossMotion.id, b.bossMotion.id)
    close(a.bossMotion.remaining, b.bossMotion.remaining); close(M.bossPosition(a), M.bossPosition(b))
    a.phase, a.wait, a.stage = "clear", 0.1, 1; M.tick(a, 0.1)
    eq(a.stage, 2); eq(a.bossMotion.id, 1); eq(a.bossMotion.phase, "patrol"); close(M.bossPosition(a), 4)
    a.phase = "victory"; assert(M.start(a)); eq(a.stage, 1); eq(a.bossMotion.id, 1); eq(a.bossMotion.toLane, 5)
    M.addPlayer(a, 2, 1); local p = a.players[2]
    for i = 1, 9 do a.hp[i] = 0 end
    a.bossMotion = {id=2,phase="recover",remaining=M.HAZARD_COOLDOWN,fromLane=6,toLane=6,lanes={}}; M.syncHazard(a)
    p.x = 3; eq(M.botAction(a, 2), "R"); p.x = 6; eq(M.botAction(a, 2), "P")
    a.bossMotion.fromLane, a.bossMotion.toLane = 2, 2; p.x = 5; eq(M.botAction(a, 2), "L")
end)
check("model: five deterministic AI complete all four moving bosses in Co-op and Brawl without stalls", function()
    for _, mode in ipairs({"coop", "brawl"}) do
        local s=M.new(mode)
        for i=1,5 do assert(M.addPlayer(s,i,i)) end
        assert(M.start(s))
        local moved = {}
        for _=1,6000 do
            if s.phase=="victory" then break end
            local b=s.bossMotion
            if b and b.phase=="patrol" and M.bossPosition(s)~=b.fromLane then moved[s.stage]=true end
            M.tick(s,0.1)
        end
        eq(s.phase,"victory"); eq(s.stage,4); eq(M.total(s),2380)
        for stage=1,4 do assert(moved[stage],"AI skipped moving stage "..stage) end
        print(string.format("  Five AI %s clear four moving bosses in %.1f game seconds (600s limit)",mode,s.time))
    end
end)

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
local function fingerprint(value)
    if type(value) == "number" then return string.format("%.9f", value) end
    if type(value) ~= "table" then return tostring(value) end
    local keys, parts = {}, {}
    for key in pairs(value) do keys[#keys+1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do parts[#parts+1] = tostring(key).."="..fingerprint(value[key]) end
    return "{"..table.concat(parts, ";").."}"
end
local function botWorld(id, mode, slot)
    local s = M.new(mode); assert(M.addPlayer(s, slot or 1, id)); assert(M.start(s)); return s
end
local function mixedWorld(mode)
    local s = M.new(mode)
    for id = 1, 5 do assert(M.addPlayer(s, id, id)) end
    assert(M.start(s)); return s
end

check("model: five immutable identities expose four real profiles and distinct legal cadences", function()
    local expected = {"smasher", "chaser", "scrapper", "dodger", "smasher"}
    local labels = {"Smasher", "Chaser", "Scrapper", "Dodger", "Smasher"}
    local intervals = {0.4, 0.3, 0.5, 0.6, 0.5}
    for id = 1, 5 do
        local profile = assert(M.botProfile(id))
        eq(profile.key, expected[id]); eq(profile.label, labels[id]); eq(profile.interval, intervals[id])
        assert(#profile.description > 20); assert(profile.interval >= M.ACTION_INTERVAL)
    end
    assert(not M.botProfile(0)); assert(not M.botProfile(6)); assert(not M.botProfile(nil))
    eq(M.MAX_HP, 100); eq(M.PUNCH_INTERVAL, 0.6); eq(M.ACTION_INTERVAL, 0.2)
    assert(M.botProfile(1).description ~= M.botProfile(5).description)
end)

check("model: actual short mixed simulation diverges in actions, targets and non-lockstep clock cadences", function()
    local s, events, original = mixedWorld("coop"), {}, M.act
    for id = 1, 5 do events[id] = {} end
    M.act = function(world, slot, action)
        local p = world.players[slot]
        local score = p.score
        local result = original(world, slot, action)
        events[p.botID][#events[p.botID]+1] = {time=world.time, action=action, x=p.x, y=p.y, ok=result, useful=p.score>score}
        return result
    end
    for _ = 1, 29 do M.tick(s, 0.1) end
    M.act = original
    local signatures, schedules, counts = {}, {}, {}
    for id = 1, 5 do
        local actions, times, last = {}, {}, nil
        for _, event in ipairs(events[id]) do
            assert(event.ok, "Initial legal bot action rejected")
            if last then close(event.time-last, M.botProfile(id).interval) end
            last = event.time
            actions[#actions+1] = event.action..event.x..":"..event.y
            times[#times+1] = string.format("%.1f", event.time)
        end
        signatures[table.concat(actions, ",")] = true
        schedules[table.concat(times, ",")] = true
        counts[id] = #events[id]
    end
    local actionKinds, scheduleKinds = 0, 0
    for _ in pairs(signatures) do actionKinds = actionKinds+1 end
    for _ in pairs(schedules) do scheduleKinds = scheduleKinds+1 end
    eq(actionKinds, 5); eq(scheduleKinds, 5)
    assert(counts[2] > counts[1] and counts[1] > counts[4])
    local firstHits = {}
    for id = 1, 5 do
        for _, event in ipairs(events[id]) do if event.useful then firstHits[id] = event.x; break end end
    end
    eq(firstHits[1], 2); eq(firstHits[2], 4); eq(s.players[5].x, 6)
    assert(s.players[1].score > 0 and s.players[2].score > 0)
    print("  First 2.9s: five distinct action paths and schedules; Smasher/Chaser/east Smasher prioritize towers 2/4/6")
end)

check("model: Smasher spreads intact towers and Chaser clears near boss before tracking fractional exposure", function()
    local s = mixedWorld("coop")
    for _, p in pairs(s.players) do p.x, p.y = 4, 0 end
    s.bossMotion = {id=1, phase="recover", remaining=3, fromLane=6, toLane=6, lanes={}}; M.syncHazard(s)
    eq(M.botAction(s, 1), "L"); eq(M.botAction(s, 5), "R")
    eq(M.botAction(s, 2), "R") -- Chaser deliberately passes a live tower towards the boss.
    for i = 1, 3 do s.hp[i] = 0 end
    eq(M.botAction(s, 1), "U") -- West Smasher now works the next intact roof.
    for i = 7, 9 do s.hp[i] = 0 end
    eq(M.botAction(s, 5), "U") -- East preference never camps a destroyed tower.
    for i = 1, 9 do s.hp[i] = 0 end
    local p = s.players[2]
    eq(M.botAction(s, 2), "R"); eq(s.boss, 10)
    assert(M.act(s, 2, "R")); s.time = 0.3
    eq(M.botAction(s, 2), "P"); assert(M.act(s, 2, "P")); eq(s.boss, 9)
    s.bossMotion = {id=2, phase="patrol", remaining=1.5, fromLane=2, toLane=3, lanes={}}; M.syncHazard(s)
    close(M.bossPosition(s), 2.5); eq(M.botAction(s, 2), "L")
    p.x = 3; eq(M.botAction(s, 2), "P")
end)

check("model: Scrapper briefly seeks only eligible Brawl rivals and returns to objectives with safe Co-op fallback", function()
    local s = botWorld(3, "brawl"); assert(M.addPlayer(s, 2))
    local p, q = s.players[1], s.players[2]
    p.x, q.x, p.invuln, q.invuln, s.time = 5, 7, 0, 0, 8
    eq(M.botAction(s, 1), "R") -- Rival east; nearest intact objective west.
    assert(M.act(s, 1, M.botAction(s, 1))); eq(p.x, 6)
    s.time = 8.5; eq(M.botAction(s, 1), "P")
    assert(M.act(s, 1, M.botAction(s, 1))); eq(q.hp, 80)
    p.x, q.x, q.invuln = 5, 7, 0
    s.time = 10; eq(M.botAction(s, 1), "L") -- Hunt ended without any stored target.
    s.time = 8; s.mode = "coop"; eq(M.botAction(s, 1), "L"); eq(q.hp, 80)
    s.mode = "brawl"; q.protected = true; eq(M.botAction(s, 1), "L")
    q.protected, q.ko = false, 4; eq(M.botAction(s, 1), "L")
    q.ko, q.invuln = 0, 1; eq(M.botAction(s, 1), "L")
    q.invuln, q.x, q.y = 0, 6, 2; eq(M.botAction(s, 1), "L") -- Cannot chase an unreachable roof.
    q.y = 0; p.nextPunch = nil; eq(M.botAction(s, 1), "P")
    p.nextPunch = 9; eq(M.botAction(s, 1), "L") -- No bypass of the 0.6s PvP gate.
    p.nextPunch = nil; s.hazard = {phase="warning", remaining=2, lanes={6,7}}
    eq(M.botAction(s, 1), "L") -- Safety interrupts even an eligible hunt.
end)

check("model: Dodger reacts earlier, works safe objectives and never re-enters a warned ground lane", function()
    local s = mixedWorld("coop")
    s.hazard = {phase="warning", remaining=5, lanes={2}}
    local cautious, smasher = s.players[4], s.players[1]
    cautious.x, cautious.y, smasher.x, smasher.y = 2, 2, 2, 2
    eq(M.botAction(s, 4), "D"); eq(M.botAction(s, 1), "U")
    s.hazard.remaining = 3; eq(M.botAction(s, 1), "D")
    cautious.x, cautious.y = 4, 0
    eq(M.botAction(s, 4), "P") -- Safe street-level city damage, not a cosmetic retreat.
    local before = s.hp[4]; assert(M.act(s, 4, M.botAction(s, 4))); eq(s.hp[4], before-1)
    cautious.x, cautious.y = 3, 0
    eq(M.botAction(s, 4), "R") -- Prefer safe tower four, never warning lane two.
    for i = 4, 9 do s.hp[i] = 0 end
    eq(M.botAction(s, 4), nil) -- Waiting is safer than fake out-of-range punches.
    s.stage, cautious.x, cautious.y = 3, 2, 1
    s.hp[1], s.hp[2], s.hp[3] = 2, 0, 0
    eq(M.botAction(s, 4), "P") -- Elevated stomp safety still permits useful hits.
    s.hp[1] = 0; eq(M.botAction(s, 4), nil) -- No descending into a ground stomp.
end)

check("model: active Dodger has ordinary HP, punch vulnerability, boss damage, knockback and KO rules", function()
    local s = botWorld(4, "brawl"); assert(M.addPlayer(s, 2))
    local p, rival = s.players[1], s.players[2]
    p.x, p.invuln, rival.x, rival.invuln = 4, 0, 3, 0
    assert(M.act(s, 2, "P")); eq(p.hp, 80); eq(p.x, 5); eq(p.invuln, 0.8)
    eq(p.maxHP, M.MAX_HP); assert(not p.protected)
    -- A newly entered warning lane just before impact can still hit this active
    -- AI before its next legal decision. Avoidance does not grant immunity.
    s.time, p.x, p.invuln, p.nextBot = 0.2, 4, 0, nil
    s.bossMotion = {id=1, phase="windup", remaining=0.1, fromLane=5, toLane=5, lanes={4}}; M.syncHazard(s)
    M.tick(s, 0.1); eq(p.hp, 45); eq(s.bossMotion.phase, "attack")
    p.invuln = 0; assert(M.damage(s, 1, 35)); eq(p.hp, 10)
    p.invuln = 0; assert(M.damage(s, 1, 20, 2)); eq(p.hp, 0); eq(p.ko, 4); eq(rival.kos, 1)
end)

check("model: each individual identity completes all four bosses with exact shared score in both modes", function()
    for id = 1, 5 do
        for _, mode in ipairs({"coop", "brawl"}) do
            local s = botWorld(id, mode)
            local scores, damage = {}, 0
            for _ = 1, 3000 do
                if s.phase == "victory" then break end
                local before = s.players[1].hp
                M.tick(s, 0.1)
                if s.players[1].hp < before then damage = damage + before-s.players[1].hp end
                if s.phase == "clear" or s.phase == "victory" then scores[s.stage] = M.total(s) end
            end
            eq(s.phase, "victory"); eq(s.stage, 4); eq(M.total(s), 2380)
            for stage = 1, 4 do assert(scores[stage], "Missing completed boss "..stage) end
            print(string.format("  %s #%d %s: all four bosses %.1fs / 300s bound, boss damage taken %d", M.botProfile(id).label, id, mode, s.time, damage))
        end
    end
end)

check("model: every profile obeys exactly the human action, range, objective damage and PvP cooldown rules", function()
    for id = 1, 5 do
        for _, mode in ipairs({"coop", "brawl"}) do
            for _, fixture in ipairs({"city", "boss-near", "boss-far", "boss-elevated", "rival", "rival-far", "rival-height"}) do
                local ai = botWorld(id, mode); assert(M.addPlayer(ai, 2))
                local p, q = ai.players[1], ai.players[2]
                p.x, p.invuln, q.x, q.invuln = 4, 0, 7, 0
                if fixture:find("boss") then
                    for i = 1, 9 do ai.hp[i] = 0 end
                    if fixture == "boss-far" then p.x = 7 end
                    if fixture == "boss-elevated" then p.y = 1 end
                elseif fixture:find("rival") then
                    p.x, q.x = 3, fixture == "rival-far" and 6 or 4
                    if fixture == "rival-height" then q.y = 1 end
                end
                local human = copy(ai); human.players[1].bot, human.players[1].botID, human.players[1].name = false, nil, nil
                for _, time in ipairs({0, 0.1, 0.2, 0.59, 0.6, 0.8, 1.2}) do
                    ai.time, human.time = time, time
                    -- Keep identical target positions/immunity in both worlds so
                    -- this probes the exact shared cooldown, not accidental misses.
                    ai.players[2].invuln, human.players[2].invuln = 0, 0
                    if fixture == "rival" then ai.players[2].x, human.players[2].x = 4, 4 end
                    eq(M.act(ai, 1, "P"), M.act(human, 1, "P"))
                    local normalized = copy(ai)
                    normalized.players[1].bot, normalized.players[1].botID, normalized.players[1].name = false, nil, nil
                    eq(fingerprint(normalized), fingerprint(human))
                end
                if fixture == "boss-far" or fixture == "boss-elevated" then eq(ai.boss, 10) end
                if fixture == "rival-far" or fixture == "rival-height" or mode == "coop" then eq(ai.players[2].hp, 100) end
            end
        end
    end
end)

check("model: actual profile execution uses legal action gates and never buffs damage or teleports", function()
    local s, original, decisions, punches = mixedWorld("brawl"), M.act, 0, 0
    local last = {}
    M.act = function(world, slot, action)
        local p = world.players[slot]
        local x, y, city, boss, hp = p.x, p.y, 0, world.boss, {}
        local bossPosition = M.bossPosition(world)
        for i = 1, 9 do city = city + world.hp[i] end
        for other, q in pairs(world.players) do hp[other] = {hp=q.hp, x=q.x, y=q.y} end
        local result = original(world, slot, action)
        if action then
            assert(result, "AI attempted an illegal/cooldown-blocked action: "..action)
            if last[slot] then assert(world.time-last[slot] >= M.ACTION_INTERVAL-0.00001) end
            last[slot], decisions = world.time, decisions+1
            if action == "P" then punches = punches+1 end
            assert(math.abs(p.x-x) <= 1 and math.abs(p.y-y) <= 1 or (action == "P" and p.y == 0))
            local cityAfter, victims = 0, 0
            for i = 1, 9 do cityAfter = cityAfter + world.hp[i] end
            assert(city-cityAfter >= 0 and city-cityAfter <= 1)
            assert(boss-world.boss >= 0 and boss-world.boss <= 1)
            if city-cityAfter == 1 then assert(action == "P" and M.towerIndex(x)) end
            if boss-world.boss == 1 then assert(action == "P" and city == 0 and y == 0 and math.abs(x-bossPosition) <= 1.00000001) end
            for other, before in pairs(hp) do
                if world.players[other].hp < before.hp then
                    victims = victims+1
                    assert(action == "P" and other ~= slot and math.abs(before.x-x) <= 1 and before.y == y)
                    eq(before.hp-world.players[other].hp, math.min(20, before.hp))
                    close(p.nextPunch, world.time + M.PUNCH_INTERVAL)
                end
            end
            assert(victims <= 1)
        end
        return result
    end
    for _ = 1, 3000 do
        if s.phase == "victory" then break end
        M.tick(s, 0.1)
        if s.phase == "clear" then last = {} end -- Legal stage reset clears action gates.
    end
    M.act = original
    eq(s.phase, "victory"); eq(M.total(s), 2380); assert(decisions > 200 and punches > 100)
end)

check("model: mixed authoritative snapshot replay and pause preserve choices and all existing action timers", function()
    local live = mixedWorld("brawl")
    for _ = 1, 83 do M.tick(live, 0.1) end
    local resumed = copy(live)
    for id = 1, 5 do assert(resumed.players[id].nextBot); eq(resumed.players[id].botID, id) end
    resumed.paused = true
    local paused = fingerprint(resumed)
    for _ = 1, 10 do M.tick(resumed, 5) end
    eq(fingerprint(resumed), paused); resumed.paused = false
    for _ = 1, 3000 do
        eq(fingerprint(live), fingerprint(resumed))
        local before = fingerprint(live)
        for slot = 1, 5 do eq(M.botAction(live, slot), M.botAction(resumed, slot)) end
        eq(fingerprint(live), before) -- No hidden decision-state mutation.
        if live.phase == "victory" then break end
        M.tick(live, 0.1); M.tick(resumed, 0.1)
    end
    eq(live.phase, "victory"); eq(resumed.phase, "victory")
    assert(M.start(live)); assert(M.start(resumed))
    for _ = 1, 150 do M.tick(live, 0.1); M.tick(resumed, 0.1); eq(fingerprint(live), fingerprint(resumed)) end
end)

check("model: remove/re-add and late-add derive the same profile, decisions and clock from ID rather than actor slot", function()
    local function normalized(s)
        local n, players = copy(s), {}
        for _, p in pairs(n.players) do players[p.botID] = p end
        n.players = players; return fingerprint(n)
    end
    for id = 1, 5 do
        local a, b = botWorld(id, "coop", 1), botWorld(id, "coop", 25)
        for _ = 1, 43 do M.tick(a, 0.1); M.tick(b, 0.1) end
        eq(normalized(a), normalized(b))
        M.removePlayer(a, 1); M.removePlayer(b, 25)
        for _ = 1, 37 do M.tick(a, 0.1); M.tick(b, 0.1) end
        assert(M.addPlayer(a, 17, id)); assert(M.addPlayer(b, 2, id))
        assert(not M.addPlayer(a, 18, id)); eq(a.players[17].nextBot, nil)
        for _ = 1, 150 do
            eq(M.botAction(a, 17), M.botAction(b, 2))
            M.tick(a, 0.1); M.tick(b, 0.1); eq(normalized(a), normalized(b))
        end
        local profile = M.botProfile(a.players[17].botID); eq(profile.key, M.botProfile(id).key)
    end
end)

check("model: mixed profile cadence and decisions agree across 0.1, 0.05 and 0.03+0.07 game-clock partitions", function()
    for _, mode in ipairs({"coop", "brawl"}) do
        local a, b, c = mixedWorld(mode), mixedWorld(mode), mixedWorld(mode)
        for step = 1, 3000 do
            if a.phase == "victory" then break end
            M.tick(a, 0.1)
            M.tick(b, 0.05); M.tick(b, 0.05)
            M.tick(c, 0.03); M.tick(c, 0.07)
            if step % 10 == 0 or a.phase == "victory" then
                eq(fingerprint(a), fingerprint(b)); eq(fingerprint(a), fingerprint(c))
            end
        end
        eq(a.phase, "victory"); eq(b.phase, "victory"); eq(c.phase, "victory")
        eq(M.total(a), 2380)
    end
end)
