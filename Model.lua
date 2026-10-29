-- Pure deterministic game rules. No WoW APIs, networking, randomness or services.
local _, addon = ...
local M = { MAX_PLAYERS = 25, MAX_BOTS = 5, LANES = 7, FLOORS = 3,
    MAX_HP = 100, ACTION_INTERVAL = 0.2, PUNCH_INTERVAL = 0.6,
    BOT_INTERVAL = 0.35, WARNING_TIME = 7, IMPACT_TIME = 0.5, HAZARD_COOLDOWN = 3 }
addon.Model = M
M.BOSSES = { "The Crumb Baron", "Permitron 9000", "The Snack Tax", "Queuezilla" }
M.BOT_NAMES = { "Pebble Pal", "Noodle Knight", "Mochi Boots", "Waffle Scout", "Bumble Brick" }
M.ACTIONS = { L = true, R = true, U = true, D = true, P = true }
M.TOWERS = { 2, 4, 6 }
function M.validMode(mode) return mode == "coop" or mode == "brawl" end
function M.new(mode)
    return { phase = "lobby", mode = M.validMode(mode) and mode or "coop", time = 0,
        stage = 1, boss = 10, hp = {}, players = {}, paused = false, wait = 0, hazard = nil, hazardID = 0 }
end
local function towerIndex(x)
    if x == 2 then return 1 elseif x == 4 then return 2 elseif x == 6 then return 3 end
end
M.towerIndex = towerIndex
function M.towerAlive(s, tower)
    for floor = 1, 3 do if (s.hp[(tower - 1) * 3 + floor] or 0) > 0 then return true end end
    return false
end
function M.cityAlive(s)
    for i = 1, 9 do if (s.hp[i] or 0) > 0 then return true end end
    return false
end
function M.addPlayer(s, slot, botID)
    if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > M.MAX_PLAYERS or s.players[slot] then return false end
    if botID then
        if not M.BOT_NAMES[botID] then return false end
        for _, p in pairs(s.players) do if p.botID == botID then return false end end
    end
    s.players[slot] = { x = 1, y = 0, score = 0, hit = 0, hp = 100, maxHP = 100,
        ko = 0, invuln = 3, kos = 0, protected = false, bot = botID ~= nil,
        botID = botID, name = botID and M.BOT_NAMES[botID] or nil }
    return true
end
function M.removePlayer(s, slot) s.players[slot] = nil end
local function warning(s)
    s.hazardID = (s.hazardID or 0) % 1679615 + 1
    local id, lanes = s.hazardID, {}
    if s.stage == 1 then lanes = { 1 + (id * 2 - 1) % 7 }
    elseif s.stage == 2 then local x = 1 + (id - 1) % 6; lanes = { x, x + 1 }
    elseif s.stage == 3 then lanes = id % 2 == 1 and { 2, 4, 6 } or { 1, 3, 5, 7 }
    else local x = 1 + (id - 1) % 7; lanes = { x, x % 7 + 1, (x + 1) % 7 + 1 } end
    s.hazard = { phase = "warning", lanes = lanes, remaining = M.WARNING_TIME, id = id }
end
local function loadStage(s)
    s.phase, s.wait, s.boss = "play", 0, 8 + s.stage * 2
    for i = 1, 9 do s.hp[i] = 2 end
    for _, p in pairs(s.players) do
        p.x, p.y, p.hp, p.ko, p.invuln, p.nextAction, p.nextPunch = 1, 0, 100, 0, 3, nil, nil
    end
    warning(s)
end
function M.start(s)
    if s.phase ~= "lobby" and s.phase ~= "victory" then return false end
    s.stage, s.time, s.hazardID = 1, 0, 0
    for _, p in pairs(s.players) do p.score, p.hit, p.kos, p.nextBot = 0, 0, 0, nil end
    loadStage(s); return true
end
function M.damage(s, slot, amount, attacker)
    local p = s.players[slot]
    if not p or s.paused or s.phase ~= "play" or p.protected or p.ko > 0 or p.invuln > 0 then return false end
    if attacker and (s.mode ~= "brawl" or attacker == slot or not s.players[attacker]) then return false end
    p.hp = math.max(0, p.hp - math.min(35, math.max(0, amount)))
    p.invuln = 0.8
    if p.y > 0 then p.y = p.y - 1
    else
        local from = attacker and s.players[attacker].x or 4
        p.x = math.max(1, math.min(7, p.x + (p.x < from and -1 or 1)))
    end
    if p.hp == 0 then
        p.ko, p.invuln, p.y = 4, 0, 0
        if attacker then local a = s.players[attacker]; a.kos = math.min(1295, a.kos + 1) end
    end
    return true
end
function M.act(s, slot, action)
    local p = s.players[slot]
    if not p or s.phase ~= "play" or s.paused or p.protected or p.ko > 0 or not M.ACTIONS[action] then return false end
    if p.nextAction and s.time + 0.00001 < p.nextAction then return false end
    p.nextAction = s.time + M.ACTION_INTERVAL
    local tower = towerIndex(p.x)
    if action == "L" or action == "R" then
        if p.y ~= 0 then return false end
        p.x = math.max(1, math.min(7, p.x + (action == "L" and -1 or 1)))
    elseif action == "U" then
        if not tower or not M.towerAlive(s, tower) then return false end
        p.y = math.min(3, p.y + 1)
    elseif action == "D" then p.y = math.max(0, p.y - 1)
    elseif action == "P" then
        p.hit = (p.hit + 1) % 1000
        if s.mode == "brawl" and (not p.nextPunch or s.time + 0.00001 >= p.nextPunch) then
            p.nextPunch = s.time + M.PUNCH_INTERVAL
            -- At most ONE adjacent, same-height target per punch; no raid-wide splash.
            for other = 1, M.MAX_PLAYERS do
                local q = s.players[other]
                if other ~= slot and q and q.y == p.y and math.abs(q.x - p.x) <= 1
                    and M.damage(s, other, 20, slot) then break end
            end
        end
        if M.cityAlive(s) then
            if not tower then return true end
            local index = (tower - 1) * 3 + math.max(1, p.y)
            if s.hp[index] > 0 then
                s.hp[index], p.score = s.hp[index] - 1, p.score + 10
                if not M.towerAlive(s, tower) then
                    p.score = p.score + 40
                    for _, other in pairs(s.players) do if other.x == p.x then other.y = 0 end end
                end
            end
        elseif p.y == 0 and p.x >= 3 and p.x <= 5 then
            s.boss, p.score = math.max(0, s.boss - 1), p.score + 15
            if s.boss == 0 then
                p.score = p.score + 100; s.phase = s.stage == 4 and "victory" or "clear"
                s.wait, s.hazard = 2, nil
            end
        end
        p.score = math.min(99999, p.score)
    end
    return true
end
local function threatened(h, lane)
    if not h then return false end
    for _, x in ipairs(h.lanes) do if x == lane then return true end end
    return false
end
function M.botAction(s, slot)
    local p, h = s.players[slot], s.hazard
    if not p or not p.bot then return nil end
    if h and h.phase == "warning" and h.remaining <= 3 and threatened(h, p.x) then
        if p.y > 0 then return "D" end
        local target, distance
        for x = 1, 7 do
            if not threatened(h, x) and (not distance or math.abs(x-p.x) < distance) then target, distance = x, math.abs(x-p.x) end
        end
        if target then return target < p.x and "L" or "R" end
    end
    -- Brief deterministic scuffles, not permanent spawn-camping: city still advances.
    if s.mode == "brawl" and math.floor(s.time / 2) % 2 == 0 then
        for other = 1, M.MAX_PLAYERS do
            local q = s.players[other]
            if other ~= slot and q and q.ko == 0 and not q.protected and q.y == p.y and math.abs(q.x-p.x) <= 1 then return "P" end
        end
    end
    local target, floor, distance
    for tower = 1, 3 do
        for f = 3, 1, -1 do
            if s.hp[(tower-1)*3+f] > 0 then
                local d = math.abs(M.TOWERS[tower]-p.x)
                if not distance or d < distance then target, floor, distance = M.TOWERS[tower], f, d end
                break
            end
        end
    end
    if target then
        if p.x ~= target then return p.y > 0 and "D" or (p.x < target and "R" or "L") end
        if p.y < floor then return "U" elseif p.y > floor then return "D" else return "P" end
    end
    if p.y > 0 then return "D" elseif p.x < 3 then return "R" elseif p.x > 5 then return "L" else return "P" end
end
local function step(s, dt)
    s.time = math.min(6046617, s.time + dt)
    for slot = 1, M.MAX_PLAYERS do
        local p = s.players[slot]
        if p and not p.protected then
            if p.ko > 0 then
                p.ko = math.max(0, p.ko-dt)
                if p.ko < 0.00001 then p.ko, p.hp, p.x, p.y, p.invuln = 0, 100, 1, 0, 3 end
            else
                p.invuln = math.max(0, p.invuln-dt)
                if p.invuln < 0.00001 then p.invuln = 0 end
            end
        end
    end
    if s.phase == "clear" then
        s.wait = s.wait-dt
        if s.wait < 0.00001 then s.stage = s.stage+1; loadStage(s) end
        return
    end
    if s.phase ~= "play" then return end
    local h = s.hazard
    if not h then warning(s); h = s.hazard end
    h.remaining = math.max(0, h.remaining-dt)
    if h.remaining < 0.00001 then
        if h.phase == "warning" then
            h.phase, h.remaining = "impact", M.IMPACT_TIME
            for slot = 1, M.MAX_PLAYERS do local p = s.players[slot]; if p and threatened(h, p.x) then M.damage(s, slot, 35) end end
        elseif h.phase == "impact" then h.phase, h.remaining, h.lanes = "idle", M.HAZARD_COOLDOWN, {}
        else warning(s) end
    end
    for slot = 1, M.MAX_PLAYERS do
        local p = s.players[slot]
        if p and p.bot and (not p.nextBot or s.time + 0.00001 >= p.nextBot) then
            p.nextBot = s.time + M.BOT_INTERVAL
            M.act(s, slot, M.botAction(s, slot))
        end
    end
end
function M.tick(s, elapsed)
    if s.paused or (s.phase ~= "play" and s.phase ~= "clear") or type(elapsed) ~= "number" or elapsed ~= elapsed then return end
    -- Bound work and do not punish an alt-tab/stalled host by replaying missed attacks.
    local left = math.min(5, math.max(0, elapsed))
    while left > 0.00001 do local dt = math.min(0.1, left); step(s, dt); left = left-dt end
end
function M.total(s)
    local score = 0; for _, p in pairs(s.players) do score = score+p.score end; return score
end
