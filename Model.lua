-- Pure deterministic game rules. No WoW APIs, networking, random numbers or art assets.
local _, addon = ...
local M = { MAX_PLAYERS = 4, LANES = 7, FLOORS = 3 }
addon.Model = M
M.BOSSES = { "The Crumb Baron", "Permitron 9000", "The Snack Tax", "Queuezilla" }
M.ACTIONS = { L = true, R = true, U = true, D = true, P = true }
M.TOWERS = { 2, 4, 6 }

function M.new()
    return { phase = "lobby", stage = 1, boss = 10, hp = {}, players = {}, paused = false, wait = 0 }
end

local function towerIndex(x)
    if x == 2 then return 1 elseif x == 4 then return 2 elseif x == 6 then return 3 end
end
M.towerIndex = towerIndex

function M.towerAlive(s, tower)
    for floor = 1, 3 do
        if (s.hp[(tower - 1) * 3 + floor] or 0) > 0 then return true end
    end
    return false
end

function M.cityAlive(s)
    for i = 1, 9 do if (s.hp[i] or 0) > 0 then return true end end
    return false
end

function M.addPlayer(s, slot)
    if slot < 1 or slot > M.MAX_PLAYERS or s.players[slot] then return false end
    s.players[slot] = { x = 1, y = 0, score = 0, hit = 0 }
    return true
end

function M.removePlayer(s, slot) s.players[slot] = nil end

local function loadStage(s)
    s.phase, s.wait, s.boss = "play", 0, 8 + s.stage * 2
    for i = 1, 9 do s.hp[i] = 2 end
    for _, p in pairs(s.players) do p.x, p.y = 1, 0 end
end

function M.start(s)
    if s.phase ~= "lobby" and s.phase ~= "victory" then return false end
    s.stage = 1
    for _, p in pairs(s.players) do p.score, p.hit = 0, 0 end
    loadStage(s)
    return true
end

function M.act(s, slot, action)
    local p = s.players[slot]
    if not p or s.phase ~= "play" or s.paused or not M.ACTIONS[action] then return false end
    local tower = towerIndex(p.x)
    if action == "L" or action == "R" then
        -- Sideways steps are deliberately ground-only: climb, smash, descend, move.
        if p.y ~= 0 then return false end
        p.x = math.max(1, math.min(7, p.x + (action == "L" and -1 or 1)))
    elseif action == "U" then
        if not tower or not M.towerAlive(s, tower) then return false end
        p.y = math.min(3, p.y + 1)
    elseif action == "D" then
        p.y = math.max(0, p.y - 1)
    elseif action == "P" then
        p.hit = (p.hit + 1) % 1000
        if M.cityAlive(s) then
            if not tower then return true end
            local floor = math.max(1, p.y)
            local index = (tower - 1) * 3 + floor
            if s.hp[index] > 0 then
                s.hp[index] = s.hp[index] - 1
                p.score = p.score + 10
                if not M.towerAlive(s, tower) then
                    p.score = p.score + 40
                    for _, other in pairs(s.players) do
                        if other.x == p.x then other.y = 0 end
                    end
                end
            end
        elseif p.y == 0 and p.x >= 3 and p.x <= 5 then
            s.boss = math.max(0, s.boss - 1)
            p.score = p.score + 15
            if s.boss == 0 then
                p.score = p.score + 100
                s.phase = s.stage == 4 and "victory" or "clear"
                s.wait = 2
            end
        end
    end
    return true
end

function M.tick(s, elapsed)
    if s.paused or s.phase ~= "clear" then return end
    s.wait = s.wait - elapsed
    if s.wait <= 0 then s.stage = s.stage + 1; loadStage(s) end
end

function M.total(s)
    local score = 0
    for _, p in pairs(s.players) do score = score + p.score end
    return score
end
