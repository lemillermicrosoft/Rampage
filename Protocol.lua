-- Bounded, host-authoritative group protocol. All identity comes from the actual
-- addon-message sender and the adapter's current WoW roster, never a payload claim.
local _, addon = ...
local M = addon.Model
local N = { PREFIX = "ToastRampage1", VERSION = "R1", MAX_BYTES = 255 }
addon.Protocol = N
local methods = {}
local phases = { lobby = "l", play = "p", clear = "c", victory = "v" }
local phaseNames = { l = "lobby", p = "play", c = "clear", v = "victory" }

local function split(text, separator)
    local out, start = {}, 1
    while true do
        local pos = string.find(text, separator, start, true)
        if not pos then out[#out + 1] = string.sub(text, start); return out end
        out[#out + 1] = string.sub(text, start, pos - 1)
        start = pos + #separator
    end
end
local function integer(text, low, high)
    if type(text) ~= "string" or #text > 7 or not string.match(text, "^%d+$") then return nil end
    local n = tonumber(text)
    if n < low or n > high then return nil end
    return n
end
local function token(text)
    return type(text) == "string" and #text >= 1 and #text <= 16 and string.match(text, "^[a-zA-Z0-9]+$") ~= nil
end
local function nameOK(text)
    return type(text) == "string" and #text >= 1 and #text <= 96 and not string.find(text, "[|%c]")
end

function N.encodeState(s, sid, seq)
    local hp, players = {}, {}
    for i = 1, 9 do hp[i] = tostring(s.hp[i] or 0) end
    for slot = 1, 4 do
        local p = s.players[slot]
        players[slot] = p and table.concat({p.x, p.y, p.score, p.hit}, ",") or "-"
    end
    return table.concat({ "R1", "S", sid, seq, phases[s.phase], s.stage, s.boss,
        s.paused and 1 or 0, table.concat(hp), table.concat(players, ";") }, "|")
end

function N.decodeState(f)
    if #f ~= 10 or not phaseNames[f[5]] then return nil end
    local seq, stage, boss, paused = integer(f[4], 1, 999999), integer(f[6], 1, 4),
        integer(f[7], 0, 16), integer(f[8], 0, 1)
    if not seq or not stage or not boss or not paused or #f[9] ~= 9 or string.find(f[9], "[^012]") then return nil end
    local s = M.new()
    s.phase, s.stage, s.boss, s.paused = phaseNames[f[5]], stage, boss, paused == 1
    if boss > 8 + stage * 2 then return nil end
    for i = 1, 9 do s.hp[i] = tonumber(string.sub(f[9], i, i)) end
    local players = split(f[10], ";")
    if #players ~= 4 then return nil end
    for slot = 1, 4 do
        if players[slot] ~= "-" then
            local p = split(players[slot], ",")
            if #p ~= 4 then return nil end
            local x, y, score, hit = integer(p[1], 1, 7), integer(p[2], 0, 3),
                integer(p[3], 0, 99999), integer(p[4], 0, 999)
            if not x or not y or not score or not hit then return nil end
            if y > 0 and not M.towerIndex(x) then return nil end
            s.players[slot] = { x = x, y = y, score = score, hit = hit }
        end
    end
    return s, seq
end

function N.new(env)
    assert(nameOK(env.name), "A canonical player-realm name is required")
    local self = setmetatable({ env = env, name = env.name, mode = "idle", roster = {}, grouped = false,
        lobbies = {}, members = {}, memberVersions = {}, receiveBuckets = {},
        queue = {}, queueOrder = {}, tokens = 10, lastRefill = env.now(),
        state = nil, status = "Solo practice, or find a party/raid lobby." }, { __index = methods })
    return self
end

function methods:notice(message)
    if message then self.status = message end
    if self.env.changed then self.env.changed(self) end
end

function methods:enqueue(key, text)
    if #text > 255 then return false end
    if not self.queue[key] then
        if #self.queueOrder >= 24 then return false end
        self.queueOrder[#self.queueOrder + 1] = key
    end
    self.queue[key] = text
    return true
end

function methods:flush()
    local now = self.env.now()
    self.tokens = math.min(10, self.tokens + math.max(0, now - self.lastRefill) * 8)
    self.lastRefill = now
    while self.tokens >= 1 and #self.queueOrder > 0 do
        local key = table.remove(self.queueOrder, 1)
        local text = self.queue[key]
        self.queue[key] = nil
        self.tokens = self.tokens - 1
        self.env.send(text)
    end
end

function methods:reset(message)
    self.mode, self.state, self.sid, self.hostName, self.slot = "idle", nil, nil, nil, nil
    self.members, self.memberVersions, self.queue, self.queueOrder = {}, {}, {}, {}
    self.joinToken, self.lastSnapshot, self.inSeq, self.outSeq = nil, nil, 0, 0
    self:notice(message or "Left the game.")
end

function methods:setRoster(roster, grouped)
    self.roster, self.grouped = roster, grouped
    for name in pairs(self.receiveBuckets) do if not roster[name] then self.receiveBuckets[name] = nil end end
    for name in pairs(self.lobbies) do if not roster[name] then self.lobbies[name] = nil end end
    if self.mode == "solo" or self.mode == "idle" then return end
    if not grouped then self:reset("Group left. Game ended; solo practice is available."); return end
    if self.mode ~= "host" and not roster[self.hostName] then
        self:reset("Host left the group. No host migration; join or host a new game.")
    elseif self.mode == "host" then
        for slot = 2, 4 do
            if self.members[slot] and not roster[self.members[slot].name] then self:remove(slot) end
        end
    end
end

function methods:solo()
    if self.mode ~= "idle" or self.combat then return false end
    self.mode, self.slot, self.state = "solo", 1, M.new()
    self.members = { { name = self.name } }
    M.addPlayer(self.state, 1); M.start(self.state)
    self:notice("Solo practice: flatten three towers, then punch the boss!")
    return true
end

function methods:host()
    if self.mode ~= "idle" or self.combat or not self.grouped then
        self:notice("Hosting needs a party/raid, out of combat, and no active game."); return false
    end
    self.mode, self.hostName, self.sid, self.slot = "host", self.name, self.env.token(), 1
    self.state, self.revision, self.snapshotSeq, self.inSeq, self.outSeq = M.new(), 1, 0, 0, 0
    self.inputFloor = 1
    self.members = { { name = self.name, token = self.env.token(), seq = 0, seen = self.env.now() } }
    M.addPlayer(self.state, 1)
    self.nextSnapshot, self.nextAdvert = 0, 0
    self:notice("Lobby open (4 monsters max). Friends choose Find, Join; host chooses Start.")
    self:broadcastMembers(); self:advertise(); self:snapshot()
    return true
end

function methods:discover()
    if not self.grouped then self:notice("Join a party/raid first, or choose Solo."); return false end
    local now = self.env.now()
    if self.lastDiscover and now - self.lastDiscover < 2 then return false end
    self.lastDiscover = now
    self:enqueue("query", "R1|Q")
    self:notice("Looking for opted-in lobbies; pick a host and click Join.")
    return true
end

function methods:lobbyList()
    local list, now = {}, self.env.now()
    for name, info in pairs(self.lobbies) do
        if now - info.seen <= 12 and self.roster[name] then list[#list + 1] = info end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function methods:join(hostName, sid)
    if self.mode ~= "idle" or self.combat or not self.grouped or hostName == self.name then return false end
    local lobby = self.lobbies[hostName]
    if not lobby or lobby.sid ~= sid or self.env.now() - lobby.seen > 12 or not self.roster[hostName] then return false end
    self.mode, self.hostName, self.sid = "joining", hostName, sid
    self.joinToken, self.joinStarted, self.nextJoin = self.env.token(), self.env.now(), 0
    self.inSeq, self.outSeq = 0, 0
    self:notice("Joining " .. hostName .. "...")
    return true
end

function methods:count()
    local count = 0
    for slot = 1, 4 do if self.members[slot] then count = count + 1 end end
    return count
end

function methods:advertise()
    if self.mode ~= "host" then return end
    self.lastAdvert = self.env.now()
    self:enqueue("advert", table.concat({ "R1", "A", self.sid, phases[self.state.phase], self:count() }, "|"))
end

function methods:broadcastMembers()
    for slot = 1, 4 do
        local member = self.members[slot]
        self:enqueue("member" .. slot, table.concat({ "R1", "M", self.sid, self.revision, slot,
            member and member.name or "-", member and member.token or "-" }, "|"))
    end
end

function methods:snapshot()
    if self.snapshotSeq >= 999999 then self:leave(); return end
    self.snapshotSeq = self.snapshotSeq + 1
    self:enqueue("state", N.encodeState(self.state, self.sid, self.snapshotSeq))
end

function methods:remove(slot)
    if slot == 1 or not self.members[slot] then return end
    self.members[slot] = nil; M.removePlayer(self.state, slot)
    self.revision = self.revision + 1
    self:broadcastMembers(); self:advertise()
    self:notice("A monster left. Remaining players can keep smashing.")
end

function methods:start()
    if self.combat or (self.mode ~= "host" and self.mode ~= "solo") then return false end
    if M.start(self.state) then
        -- Inputs must reference a snapshot from this stage/replay, not a delayed prior city.
        if self.mode == "host" then self.inputFloor = self.snapshotSeq + 1 end
        self:notice("FOUR MORE BOSSES! Climb and smash all three towers."); return true
    end
    return false
end

function methods:setCombat(inCombat)
    self.combat = inCombat and true or false
    if self.state and (self.mode == "host" or self.mode == "solo") then self.state.paused = self.combat end
    self:notice()
end

function methods:action(action)
    if self.combat or not M.ACTIONS[action] or not self.state or self.state.paused or self.state.phase ~= "play" then return false end
    local now = self.env.now()
    if self.lastLocalAction and now - self.lastLocalAction < 0.18 then return false end
    self.lastLocalAction = now
    if self.mode == "host" or self.mode == "solo" then
        local result = M.act(self.state, self.slot, action); self:notice(); return result
    elseif self.mode == "client" then
        if self.outSeq >= 999999 then return false end
        self.outSeq = self.outSeq + 1
        return self:enqueue("input" .. self.outSeq, table.concat({ "R1", "I", self.sid, self.joinToken, self.outSeq, self.inSeq, action }, "|"))
    end
    return false
end

function methods:leave()
    -- Best-effort departure stays within the token bucket; timeout is the fallback.
    self.queue, self.queueOrder = {}, {}
    if self.mode == "host" then self:enqueue("end", "R1|E|" .. self.sid)
    elseif self.mode == "client" or self.mode == "joining" then self:enqueue("leave", "R1|L|" .. self.sid .. "|" .. self.joinToken) end
    self:flush(); self:reset("Left the game. Your local best score is kept.")
end

local function findMember(self, sender, joinToken)
    for slot = 2, 4 do
        local member = self.members[slot]
        if member and member.name == sender and member.token == joinToken then return slot, member end
    end
end

function methods:receive(sender, text)
    if sender == self.name or not self.grouped or not self.roster[sender] or not nameOK(sender)
        or type(text) ~= "string" or #text > 255 or #text < 4 then return false end
    local now = self.env.now()
    local bucket = self.receiveBuckets[sender] or { tokens = 24, time = now }
    self.receiveBuckets[sender] = bucket
    bucket.tokens = math.min(24, bucket.tokens + math.max(0, now - bucket.time) * 16); bucket.time = now
    if bucket.tokens < 1 then return false end
    bucket.tokens = bucket.tokens - 1
    local f = split(text, "|")
    if f[1] ~= "R1" then return false end
    local kind = f[2]
    if kind == "Q" and #f == 2 then
        if self.mode == "host" and (not self.lastAdvert or now - self.lastAdvert >= 1) then self:advertise() end
        return true
    end
    if not token(f[3]) then return false end
    if kind == "A" then
        if #f ~= 5 or not phaseNames[f[4]] or not integer(f[5], 1, 4) then return false end
        if not self.lobbies[sender] then
            local count = 0; for _ in pairs(self.lobbies) do count = count + 1 end
            if count >= 8 then return false end
        end
        self.lobbies[sender] = { name = sender, sid = f[3], phase = phaseNames[f[4]], count = tonumber(f[5]), seen = now }
        self:notice(); return true
    end
    if f[3] ~= self.sid then return false end
    if self.mode == "host" then
        if kind == "J" and #f == 4 and token(f[4]) then
            local existing
            for slot = 2, 4 do if self.members[slot] and self.members[slot].name == sender then existing = slot end end
            if existing then
                local member = self.members[existing]
                if member.token ~= f[4] then
                    member.token, member.seq = f[4], 0; self.revision = self.revision + 1
                elseif member.lastJoin and now - member.lastJoin < 1 then return false end
                member.seen, member.lastJoin = now, now
            else
                local free
                for slot = 2, 4 do if not self.members[slot] then free = slot; break end end
                if not free then return false end
                self.members[free] = { name = sender, token = f[4], seq = 0, seen = now, lastJoin = now }
                M.addPlayer(self.state, free); self.revision = self.revision + 1
            end
            self:broadcastMembers(); self:advertise(); self:notice(); return true
        end
        local slot, member = findMember(self, sender, f[4])
        if not member then return false end
        if kind == "K" and #f == 4 then member.seen = now; return true end
        if kind == "L" and #f == 4 then self:remove(slot); return true end
        if kind == "I" and #f == 7 and M.ACTIONS[f[7]] then
            local seq, seenState = integer(f[5], 1, 999999), integer(f[6], 1, 999999)
            if not seq or seq <= member.seq or not seenState or seenState < self.inputFloor or seenState > self.snapshotSeq then return false end
            member.seq, member.seen = seq, now
            if member.lastAction and now - member.lastAction < 0.16 then return false end
            member.lastAction = now
            local result = M.act(self.state, slot, f[7]); self:notice(); return result
        end
        return false
    end
    if (self.mode ~= "client" and self.mode ~= "joining") or sender ~= self.hostName then return false end
    if kind == "E" and #f == 3 then self:reset("Host ended the game. Choose Solo, Host or Join."); return true end
    if kind == "M" and #f == 7 then
        local revision, slot = integer(f[4], 1, 999999), integer(f[5], 1, 4)
        if not revision or not slot or revision < (self.memberVersions[slot] or 0) then return false end
        if f[6] ~= "-" and (not nameOK(f[6]) or not self.roster[f[6]] or not token(f[7])) then return false end
        if f[6] == "-" and f[7] ~= "-" then return false end
        if slot == 1 and f[6] ~= self.hostName then return false end
        self.memberVersions[slot] = revision
        self.members[slot] = f[6] ~= "-" and { name = f[6], token = f[7] } or nil
        if f[6] == self.name and f[7] == self.joinToken then
            self.slot, self.mode, self.lastSnapshot, self.nextKeepalive = slot, "client", self.lastSnapshot or now, 0
            self:notice("Joined! Flatten the city together; personal scores, shared victory.")
        elseif self.mode == "client" and slot == self.slot then
            self:reset("Removed from lobby or connection expired. Find and Join to reconnect.")
        end
        return true
    end
    if kind == "S" then
        local state, seq = N.decodeState(f)
        if not state or seq <= (self.inSeq or 0) then return false end
        self.state, self.inSeq, self.lastSnapshot = state, seq, now
        self:notice(); return true
    end
    return false
end

function methods:tick(elapsed)
    local now = self.env.now()
    for name, info in pairs(self.lobbies) do if now - info.seen > 12 then self.lobbies[name] = nil end end
    if self.mode == "host" or self.mode == "solo" then
        local oldPhase = self.state.phase
        M.tick(self.state, math.min(elapsed, 0.5))
        if self.mode == "host" then
            if oldPhase ~= "play" and self.state.phase == "play" then self.inputFloor = self.snapshotSeq + 1 end
            for slot = 2, 4 do
                if self.members[slot] and now - self.members[slot].seen > 20 then self:remove(slot) end
            end
            if now >= self.nextAdvert then
                self.nextAdvert = now + 4; self:advertise(); self:broadcastMembers()
            end
            if now >= self.nextSnapshot then self.nextSnapshot = now + 0.25; self:snapshot() end
        end
    elseif self.mode == "joining" then
        if now - self.joinStarted > 12 then self:reset("Join timed out (lobby full, host busy or gone). Find and retry.")
        elseif now >= self.nextJoin then
            self.nextJoin = now + 2; self:enqueue("join", "R1|J|" .. self.sid .. "|" .. self.joinToken)
        end
    elseif self.mode == "client" then
        if now - (self.lastSnapshot or now) > 15 then self:reset("Host timed out. No migration; find or host a new game.")
        elseif now >= (self.nextKeepalive or 0) then
            self.nextKeepalive = now + 3; self:enqueue("keepalive", "R1|K|" .. self.sid .. "|" .. self.joinToken)
        end
    end
    self:flush()
end
