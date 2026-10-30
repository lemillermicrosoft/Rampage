-- Pure deterministic game rules. No WoW APIs, networking, randomness or services.
local _, addon = ...
local M = { MAX_PLAYERS = 25, MAX_BOTS = 5, LANES = 7, FLOORS = 3,
    MAX_HP = 100, ACTION_INTERVAL = 0.2, PUNCH_INTERVAL = 0.6,
    BOT_INTERVAL = 0.35, PATROL_TIME = 3, WARNING_TIME = 3, IMPACT_TIME = 0.5, HAZARD_COOLDOWN = 3 }
-- Public phase aliases share the existing model/presentation timing constants.
M.BOSS_PATROL, M.BOSS_WINDUP = M.PATROL_TIME, M.WARNING_TIME
M.BOSS_ATTACK, M.BOSS_RECOVER = M.IMPACT_TIME, M.HAZARD_COOLDOWN
addon.Model = M
M.BOSSES = { "The Crumb Baron", "Permitron 9000", "The Snack Tax", "Queuezilla" }
M.BOT_NAMES = { "Pebble Pal", "Noodle Knight", "Mochi Boots", "Waffle Scout", "Bumble Brick" }
M.ACTIONS = { L = true, R = true, U = true, D = true, P = true }
M.TOWERS = { 2, 4, 6 }
-- Profiles are a pure function of immutable botID, not actor slot or local time.
-- Slot five reuses Smasher with an east-first bias and a different cadence.
-- BOT_INTERVAL remains the legacy nominal constant; these are actual decisions.
local botProfiles = {
    { key = "smasher", label = "Smasher", description = "West-first tower demolition; works from the roof down.", interval = 0.4 },
    { key = "chaser", label = "Chaser", description = "Clears towers near the boss, then pursues its moving hitbox.", interval = 0.3 },
    { key = "scrapper", label = "Scrapper", description = "Brief Brawl rival hunts, then objectives; city helper in Co-op.", interval = 0.5 },
    { key = "dodger", label = "Dodger", description = "Escapes warnings early and works on safe objectives; no damage immunity.", interval = 0.6 },
    { key = "smasher", label = "Smasher", description = "East-first tower demolition with a steadier cadence.", interval = 0.5 },
}
function M.botProfile(botID) return botProfiles[botID] end
local function nextBotTime(time, botID)
    local interval, offset = botProfiles[botID].interval, (botID - 1) * 0.1
    -- Absolute game-clock lattice prevents cadence drift and needs no new
    -- checkpoint state. Existing nextBot/nextAction/nextPunch remain authoritative.
    return (math.floor((time - offset) / interval + 0.00001) + 1) * interval + offset
end
function M.validMode(mode) return mode == "coop" or mode == "brawl" end
function M.new(mode)
    return { phase = "lobby", mode = M.validMode(mode) and mode or "coop", time = 0,
        stage = 1, boss = 10, hp = {}, players = {}, paused = false, wait = 0,
        bossMotion = nil, bossDirection = 1, hazard = nil, hazardID = 0 }
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
-- The SAME pure fractional position is used by punches, AI and presentation.
-- Elapsed can smooth only this known segment, never invent the next phase.
function M.bossPosition(s, elapsed)
    local b = s.bossMotion
    if not b then return 4 end
    if b.phase ~= "patrol" then return b.toLane end
    if type(elapsed) ~= "number" or elapsed ~= elapsed or s.paused or s.phase ~= "play" then elapsed = 0 end
    local progress = math.max(0, math.min(1, (M.PATROL_TIME - b.remaining + math.max(0, elapsed)) / M.PATROL_TIME))
    return b.fromLane + (b.toLane - b.fromLane) * progress
end
function M.bossInReach(s, p)
    return p ~= nil and p.y == 0 and math.abs(p.x - M.bossPosition(s)) <= 1 + 0.00000001
end
function M.bossAttackKind(s) return s.stage == 3 and "ground" or "ranged" end
function M.syncHazard(s)
    local b = s.bossMotion
    if not b or s.phase ~= "play" then s.hazard = nil; return end
    local h = s.hazard or {}
    h.id, h.remaining, h.lanes = b.id, b.remaining, b.lanes
    h.phase = b.phase == "windup" and "warning" or (b.phase == "attack" and "impact" or "idle")
    s.hazard, s.hazardID = h, b.id
end
local function nearestActor(s, origin)
    local target, distance
    for slot = 1, M.MAX_PLAYERS do
        local p = s.players[slot]
        if p and p.ko == 0 and not p.protected then
            local d = math.abs(p.x - origin)
            -- Equal distances keep the lowest slot; no pairs-order/random ties.
            if not distance or d < distance then target, distance = p.x, d end
        end
    end
    return target
end
local function patrol(s, origin)
    local id = (s.hazardID or 0) % 1679615 + 1
    local stride = s.stage == 2 and 2 or (s.stage == 4 and (id % 2 == 0 and 2 or 1) or 1)
    local target = s.stage == 3 and nearestActor(s, origin)
    local destination
    if target then
        destination = origin + (target < origin and -1 or (target > origin and 1 or 0))
        destination = math.max(2, math.min(6, destination))
    else
        local direction = s.bossDirection or 1
        if origin + stride * direction < 2 or origin + stride * direction > 6 then direction = -direction end
        s.bossDirection, destination = direction, origin + stride * direction
    end
    s.bossMotion = { id = id, phase = "patrol", remaining = M.PATROL_TIME,
        fromLane = origin, toLane = destination, lanes = {} }
    M.syncHazard(s)
end
local function warning(s)
    local b, lanes = s.bossMotion, {}
    local origin = b.toLane
    local target = nearestActor(s, origin) or origin
    if s.stage == 1 then lanes = { target }
    elseif s.stage == 2 then local x = math.max(1, math.min(6, target)); lanes = { x, x + 1 }
    elseif s.stage == 3 then lanes = { origin - 1, origin, origin + 1 }
    else local x = math.max(2, math.min(6, target)); lanes = { x - 1, x, x + 1 } end
    b.phase, b.remaining, b.fromLane, b.lanes = "windup", M.WARNING_TIME, origin, lanes
    M.syncHazard(s)
end
local function loadStage(s)
    s.phase, s.wait, s.boss = "play", 0, 8 + s.stage * 2
    for i = 1, 9 do s.hp[i] = 2 end
    for _, p in pairs(s.players) do
        p.x, p.y, p.hp, p.ko, p.invuln, p.nextAction, p.nextPunch, p.nextBot = 1, 0, 100, 0, 3, nil, nil, nil
    end
    s.hazardID, s.bossDirection, s.hazard = 0, 1, nil
    patrol(s, 4)
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
        local from = attacker and s.players[attacker].x or M.bossPosition(s)
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
        elseif M.bossInReach(s, p) then
            s.boss, p.score = math.max(0, s.boss - 1), p.score + 15
            if s.boss == 0 then
                p.score = p.score + 100; s.phase = s.stage == 4 and "victory" or "clear"
                s.wait, s.hazard, s.bossMotion = 2, nil, nil
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
local function objectiveAction(s, p, profile, avoid)
    local target, floor, priority
    local ground = M.bossAttackKind(s) == "ground"
    for tower = 1, 3 do
        local x, chosen = M.TOWERS[tower]
        -- Smasher/chaser clear roofs first; scrapper/dodger start at street level.
        for f = 1, 3 do
            local level = (profile.key == "smasher" or profile.key == "chaser") and 4-f or f
            if (s.hp[(tower-1)*3+level] or 0) > 0 then chosen = level; break end
        end
        local safe = not avoid or not threatened(s.hazard, x) or (ground and p.x == x and p.y > 0)
        if chosen and safe then
            local rank = math.abs(x-p.x)
            if profile.key == "smasher" then
                rank = (tower - (p.botID == 5 and 3 or 1)) % 3
            elseif profile.key == "chaser" then
                -- Finish an occupied tower rather than switching every patrol tick.
                rank = p.x == x and p.y > 0 and -1 or math.abs(x-M.bossPosition(s)) + math.abs(x-p.x) * 0.1
            end
            if not priority or rank < priority - 0.00001 then target, floor, priority = x, chosen, rank end
        end
    end
    if target then
        if p.x ~= target then return p.y > 0 and "D" or (p.x < target and "R" or "L") end
        -- Ground punches already reach floor one; do not climb unnecessarily.
        if floor == 1 and p.y == 0 then return "P" end
        if p.y < floor then return "U" elseif p.y > floor then return "D" else return "P" end
    end
    if M.cityAlive(s) then return nil end -- No safe tower until this warning ends.
    if p.y > 0 then return "D" end
    if M.bossInReach(s, p) then return "P" end
    return p.x < M.bossPosition(s) and "R" or "L"
end
local function rivalAction(s, slot, p)
    -- Two seconds out of each ten, phased by immutable identity. No persistent
    -- target/timer, no pursuit during a warning dodge, and no friendly Co-op hunt.
    if s.mode ~= "brawl" or (s.time + p.botID * 0.7 + 0.00001) % 10 >= 2 then return nil end
    local target, distance
    for other = 1, M.MAX_PLAYERS do
        local q = s.players[other]
        if other ~= slot and q and q.ko == 0 and not q.protected and q.invuln == 0
            and (q.y == 0 or (q.x == p.x and towerIndex(q.x) and M.towerAlive(s, towerIndex(q.x)))) then
            local d = math.abs(q.x-p.x) + math.abs(q.y-p.y) * 2
            if not distance or d < distance then target, distance = q, d end
        end
    end
    if not target then return nil end
    if p.y == target.y and math.abs(p.x-target.x) <= 1 then
        if not p.nextPunch or s.time + 0.00001 >= p.nextPunch then return "P" end
        return nil
    end
    if p.x ~= target.x then return p.y > 0 and "D" or (p.x < target.x and "R" or "L") end
    return p.y > target.y and "D" or "U"
end
function M.botAction(s, slot)
    local p, h = s.players[slot], s.hazard
    if not p or not p.bot or p.protected or p.ko > 0 or s.phase ~= "play" or s.paused then return nil end
    local profile = M.botProfile(p.botID)
    if not profile then return nil end
    local ground = M.bossAttackKind(s) == "ground"
    -- Match action-clock tolerance at boundaries; 0.05/0.1s partitions must not
    -- choose different targets because a warning is 2.50000000000001 seconds.
    -- R6 short warnings: Dodger reacts after 0.5s, others after 1s. Their
    -- ordinary decision cadences still apply; no immunity or extra movement.
    local avoid = h and ((h.phase == "warning" and h.remaining <= (profile.key == "dodger" and 2.5 or 2) + 0.00001) or h.phase == "impact")
    if avoid and threatened(h, p.x) and (not ground or p.y == 0) then
        if p.y > 0 then return "D" end
        local target, distance
        -- Identity-biased equal-distance escapes, not randomized jitter.
        for i = 1, 7 do
            local x = p.botID % 2 == 0 and 8-i or i
            if not threatened(h, x) and (not distance or math.abs(x-p.x) < distance) then target, distance = x, math.abs(x-p.x) end
        end
        if target then return target < p.x and "L" or "R" end
    end
    local action = not avoid and profile.key == "scrapper" and rivalAction(s, slot, p) or nil
    action = action or objectiveAction(s, p, profile, avoid)
    if avoid then
        -- Keep working safely rather than idle-punching or walking straight back
        -- into a warning. Elevated stomp targets may work, but not descend into it.
        local x = p.x + (action == "L" and -1 or (action == "R" and 1 or 0))
        local y = action == "D" and math.max(0, p.y-1) or p.y
        if threatened(h, x) and (not ground or y == 0) then return nil end
    end
    return action
end
local function moveBoss(s, dt)
    if not s.bossMotion then patrol(s, 4) end
    -- Carry fractional overshoot across a boundary, so 0.05/0.1s updates lock
    -- the same warning and never shorten the three-second escape window.
    while dt > 0.00000001 do
        local b = s.bossMotion
        local used = math.min(dt, b.remaining)
        b.remaining, dt = math.max(0, b.remaining - used), dt - used
        if b.remaining < 0.00000001 then
            if b.phase == "patrol" then warning(s)
            elseif b.phase == "windup" then
                b.phase, b.remaining = "attack", M.IMPACT_TIME
                for slot = 1, M.MAX_PLAYERS do
                    local p = s.players[slot]
                    if p and threatened(b, p.x) and (M.bossAttackKind(s) ~= "ground" or p.y == 0) then M.damage(s, slot, 35) end
                end
            elseif b.phase == "attack" then b.phase, b.remaining, b.lanes = "recover", M.HAZARD_COOLDOWN, {}
            else patrol(s, b.toLane) end
        end
    end
    M.syncHazard(s)
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
    moveBoss(s, dt)
    for slot = 1, M.MAX_PLAYERS do
        local p = s.players[slot]
        if p and p.bot and M.botProfile(p.botID) then
            if not p.nextBot then p.nextBot = nextBotTime(s.time-dt, p.botID) end
            if s.time + 0.00001 >= p.nextBot then
                p.nextBot = nextBotTime(s.time, p.botID)
                M.act(s, slot, M.botAction(s, slot))
            end
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
