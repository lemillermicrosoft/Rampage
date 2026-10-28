local M = Addon.Model
local function active()
    local s = M.new(); M.addPlayer(s, 1); M.start(s); return s
end
local function walk(s, slot, x)
    while s.players[slot].y > 0 do M.act(s, slot, "D") end
    while s.players[slot].x < x do M.act(s, slot, "R") end
    while s.players[slot].x > x do M.act(s, slot, "L") end
end
local function flatten(s, slot)
    for _, x in ipairs(M.TOWERS) do
        walk(s, slot, x)
        for _ = 1, 3 do M.act(s, slot, "U") end
        for _ = 1, 3 do
            M.act(s, slot, "P"); M.act(s, slot, "P"); M.act(s, slot, "D")
        end
    end
end

check("model: explicit lobby/start, four-player cap and restart rules", function()
    local s = M.new(); eq(s.phase, "lobby")
    for i = 1, 4 do assert(M.addPlayer(s, i)) end
    assert(not M.addPlayer(s, 5)); assert(not M.addPlayer(s, 1))
    assert(not M.act(s, 1, "R")); assert(M.start(s)); assert(not M.start(s))
    eq(s.boss, 10); eq(#s.hp, 9)
end)
check("model: bounded ground movement and tower-only climbing", function()
    local s = active()
    assert(not M.act(s, 1, "U")); M.act(s, 1, "L"); eq(s.players[1].x, 1)
    for _ = 1, 20 do M.act(s, 1, "R") end
    eq(s.players[1].x, 7); M.act(s, 1, "L")
    for _ = 1, 10 do M.act(s, 1, "U") end
    eq(s.players[1].y, 3); assert(not M.act(s, 1, "R")); eq(s.players[1].x, 6)
    for _ = 1, 10 do M.act(s, 1, "D") end
    eq(s.players[1].y, 0); assert(not M.act(s, 1, "BOOM")); assert(not M.act(s, 8, "P"))
end)
check("model: two monsters damage the SAME floor and share tower collapse", function()
    local s = active(); M.addPlayer(s, 2)
    walk(s, 1, 2); walk(s, 2, 2)
    M.act(s, 1, "P"); eq(s.hp[1], 1); M.act(s, 2, "P"); eq(s.hp[1], 0)
    eq(s.players[1].score, 10); eq(s.players[2].score, 10)
    for slot = 1, 2 do M.act(s, slot, "U"); M.act(s, slot, "U") end
    M.act(s, 1, "P"); M.act(s, 2, "P"); eq(s.hp[2], 0)
    for slot = 1, 2 do M.act(s, slot, "U") end
    M.act(s, 1, "P"); M.act(s, 2, "P")
    assert(not M.towerAlive(s, 1)); eq(s.players[1].y, 0); eq(s.players[2].y, 0)
    eq(s.players[2].score, 70); assert(not M.act(s, 1, "U"))
end)
check("model: boss shield, exposure and reach checks", function()
    local s = active(); walk(s, 1, 3); M.act(s, 1, "P"); eq(s.boss, 10)
    flatten(s, 1); assert(not M.cityAlive(s)); eq(s.players[1].score, 300)
    walk(s, 1, 7); M.act(s, 1, "P"); eq(s.boss, 10)
    walk(s, 1, 4); M.act(s, 1, "P"); eq(s.boss, 9); eq(s.players[1].score, 315)
end)
check("model: four complete stages, shared victory, exact score and replay", function()
    local s = active()
    for stage = 1, 4 do
        eq(s.stage, stage); flatten(s, 1); walk(s, 1, 4)
        for _ = 1, 8 + stage * 2 do M.act(s, 1, "P") end
        eq(s.boss, 0)
        if stage < 4 then
            eq(s.phase, "clear"); M.tick(s, 1); eq(s.stage, stage); M.tick(s, 1)
        else eq(s.phase, "victory") end
    end
    eq(s.players[1].score, 2380); eq(M.total(s), 2380)
    assert(not M.act(s, 1, "P")); M.tick(s, 100); eq(s.stage, 4)
    assert(M.start(s)); eq(s.stage, 1); eq(s.players[1].score, 0); eq(s.phase, "play")
end)
check("model: pause blocks input and intermission progression", function()
    local s = active(); s.paused = true
    assert(not M.act(s, 1, "R")); eq(s.players[1].x, 1)
    s.phase, s.wait = "clear", 1; M.tick(s, 5); eq(s.stage, 1)
    s.paused = false; M.tick(s, 1); eq(s.stage, 2)
end)
check("model: removal and late addition do not reset shared city", function()
    local s = active(); M.act(s, 1, "R"); M.act(s, 1, "P")
    M.addPlayer(s, 2); eq(s.hp[1], 1); eq(s.players[2].score, 0)
    M.removePlayer(s, 2); assert(not s.players[2]); eq(s.hp[1], 1)
end)
