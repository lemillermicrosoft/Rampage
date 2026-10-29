local M = Addon.Model
-- City-only fixtures advance the action clock without boss simulation.
local function act(s, slot, action) s.time = s.time + 0.21; return M.act(s, slot, action) end
local function active()
    local s = M.new(); M.addPlayer(s, 1); M.start(s); return s
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
        local s = active(); s.stage = stage; s.hazard = nil; M.tick(s, 0.1)
        local h, p = s.hazard, s.players[1]
        eq(h.phase, "warning"); assert(h.remaining >= 6.8)
        patterns[stage] = table.concat(h.lanes, ",")
        p.x, p.invuln = h.lanes[1], 0
        M.tick(s, 3); M.tick(s, 3); eq(p.hp, 100); eq(h.phase, "warning")
        M.tick(s, 1); eq(h.phase, "impact"); eq(p.hp, 65)
        assert(p.x ~= h.lanes[1] or p.x == 1 or p.x == 7)
        M.tick(s, 0.5); eq(h.phase, "idle"); M.tick(s, 3); eq(s.hazard.phase, "warning")
        local id = s.hazard.id; for i = 1, 9 do s.hp[i] = 0 end
        p.x, p.invuln = s.hazard.lanes[1], 0
        M.tick(s, 5); M.tick(s, 2); eq(p.hp, 30)
        M.tick(s, 3.5); assert(s.hazard.id > id)
    end
    assert(patterns[1] ~= patterns[2] and patterns[2] ~= patterns[3] and patterns[3] ~= patterns[4])
end)
check("model: stationary bot can be hurt and KO'd; deterministic AI alone clears all four bosses", function()
    local s = M.new(); M.addPlayer(s, 1, 1); M.start(s)
    local p = s.players[1]; p.invuln, p.nextBot = 0, 99999
    for _ = 1, 3 do
        p.x = s.hazard.lanes[1]; p.invuln = 0
        M.tick(s, 5); M.tick(s, 2)
        if p.ko == 0 then M.tick(s, 3.5) end
    end
    eq(p.hp, 0); assert(p.ko > 0)
    local function run()
        local world = M.new(); M.addPlayer(world, 1, 1); M.start(world)
        for _ = 1, 5000 do if world.phase == "victory" then break end; M.tick(world, 0.1) end
        eq(world.phase, "victory"); eq(world.stage, 4); eq(M.total(world), 2380)
        return world.time
    end
    local t = run(); eq(run(), t); print(string.format("  Solo deterministic AI clears four bosses in %.1f game seconds", t))
end)
check("model: warning is dodgable and host pause freezes hazard, HP, respawn and game clock", function()
    local s = active(); local p = s.players[1]
    p.invuln, p.x = 0, s.hazard.lanes[1]
    M.tick(s, 3); M.tick(s, 3); assert(M.act(s, 1, "R"))
    M.tick(s, 1); eq(p.hp, 100)
    local time, remaining = s.time, s.hazard.remaining
    s.paused = true; M.tick(s, 5); eq(s.time, time); eq(s.hazard.remaining, remaining)
    assert(not M.damage(s, 1, 35))
end)
