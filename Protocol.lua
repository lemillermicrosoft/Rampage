-- R5: fenced authority terms and complete recovery checkpoints. Tokens are correlation, not secrets.
-- Public integration: net.term is the authority fence; net.migration is a table
-- while unsafe (migrationActive mirrors it), net.leaving is true during asynchronous leave (up to 35s), and
-- state.paused always blocks simulation/input then. participants[id].joined is
-- durable admission order. ownMemberID/slot are NOT necessarily 1. A host may be
-- a spectator and may setRole without surrendering authority. leave() is truthy.
-- No perfect partition consensus: a host needs fresh peer leases; takeover needs a
-- majority of a certified checkpoint's ADMITTED non-host voters. Membership
-- changes pause until intersecting old/new admitted sets acknowledge a monotonic
-- revision fence. Acknowledgers cannot vote for older checkpoints, even if the
-- new certificate is lost. Rejoin keeps vote locks; fresh processes cannot prove
-- forgotten old generations. Local roster absence alone is NOT a fence receipt.
-- Unopened/uninstalled group members are never voters.
-- Missing evidence PAUSES; native group roster remains trusted sender input.
-- Checkpoints may lag display snapshots (up to the 120s evidence lifetime); lost
-- uncommitted progress can roll back. No perfect-consensus or Byzantine claim.
local _, addon = ...
local M = addon.Model
local N = { PREFIX = "ToastRampage1", VERSION = "R5", MAX_BYTES = 255,
    MAX_MEMBERS = 40, SEND_RATE = 8, SEND_BURST = 10, BYTE_RATE = 700,
    BYTE_BURST = 1000, WIRE_OVERHEAD = 16, MAX_QUEUE = 128,
    SNAPSHOT_INTERVAL = 1.25, CHUNK_BYTES = 176, MAX_CHUNKS = 3,
    ASSEMBLY_TIMEOUT = 6, MAX_ASSEMBLIES = 3,
    CHECKPOINT_BYTES = 16000, CHECKPOINT_CHUNKS = 91, CHECKPOINT_TIMEOUT = 120,
    CHECKPOINT_INTERVAL = 8, HOST_TIMEOUT = 20, LEASE_TIMEOUT = 14,
    ELECTION_GRACE = 16, ELECTION_TIMEOUT = 40, LEAVE_TIMEOUT = 35 }
addon.Protocol = N
local methods = {}
local phases = { lobby = "l", play = "p", clear = "c", victory = "v" }
local phaseNames = { l = "lobby", p = "play", c = "clear", v = "victory" }
local digits = "0123456789abcdefghijklmnopqrstuvwxyz"
local function split(text, sep)
    local out, start = {}, 1
    while true do
        local pos = string.find(text, sep, start, true)
        if not pos then out[#out + 1] = string.sub(text, start); return out end
        out[#out + 1] = string.sub(text, start, pos - 1); start = pos + #sep
    end
end
local function integer(text, low, high)
    if type(text) ~= "string" or #text > 6 or not string.match(text, "^%d+$") then return nil end
    local n = tonumber(text); if n < low or n > high then return nil end; return n
end
local function token(text)
    return type(text) == "string" and #text >= 1 and #text <= 16 and string.match(text, "^[a-zA-Z0-9]+$") ~= nil
end
local function nameOK(text)
    return type(text) == "string" and #text >= 1 and #text <= 96 and not string.find(text, "[|%c]")
end
local function base(n, width)
    local s = ""
    for _ = 1, width do local d = n % 36; s = string.sub(digits, d + 1, d + 1) .. s; n = math.floor(n / 36) end
    return s
end
local function unbase(s, low, high)
    local n = 0
    for i = 1, #s do
        local p = string.find(digits, string.sub(s, i, i), 1, true)
        if not p then return nil end; n = n * 36 + p - 1
    end
    if n < low or n > high then return nil end; return n
end
local function packet(...) return table.concat({ N.VERSION, ... }, "|") end
local function roleCode(role) return role == "spectate" and "s" or "p" end
local function roleOK(role) return role == "play" or role == "spectate" end
local function modeCode(mode) return mode == "brawl" and "b" or "c" end
local modeNames = { c = "coop", b = "brawl" }
local motionCodes = { patrol = "p", windup = "w", attack = "a", recover = "r" }
local motionNames = { p = "patrol", w = "windup", a = "attack", r = "recover" }
local function tenths(n, maximum) return math.min(maximum, math.max(0, math.ceil((n or 0) * 10 - 0.00001))) end

-- Fixed numeric actors and independent real-member/name stream; bots never occupy member IDs.
function N.encodeState(s, sid, seq, epoch, revision, participants, term)
    local hp, players, map = {}, {}, {}
    for i = 1, 9 do hp[i] = tostring(s.hp[i] or 0) end
    for i = 1, 40 do map[i] = "." end
    if participants then
        for id, member in pairs(participants) do map[id] = base(member.slot or 0, 1) end
    else
        for slot = 1, 25 do if s.players[slot] and not s.players[slot].bot then map[slot] = base(slot, 1) end end
    end
    for slot = 1, 25 do
        local p = s.players[slot]
        players[slot] = p and (base(p.x, 1) .. base(p.y, 1) .. base(p.score, 4) .. base(p.hit, 2)
            .. base(p.hp or 100, 2) .. base(tenths(p.ko, 40), 2) .. base(tenths(p.invuln, 30), 1)
            .. base(p.kos or 0, 2) .. base((p.botID or 0)*2 + (p.protected and 1 or 0), 1)) or "----------------"
    end
    local motion, b, mask = "-", s.phase == "play" and s.bossMotion or nil, 0
    if b then
        for _, lane in ipairs(b.lanes) do mask = mask + 2^(lane-1) end
        motion = base(b.id, 4) .. motionCodes[b.phase] .. base(mask, 2) .. base(tenths(b.remaining, M.WARNING_TIME * 10), 2)
            .. base(b.fromLane, 1) .. base(b.toLane, 1)
    end
    local body = table.concat({ phases[s.phase], s.stage, s.boss, s.paused and 1 or 0,
        epoch or 1, revision or 1, table.concat(hp), table.concat(map), modeCode(s.mode),
        base(tenths(s.time, 60466175), 5), motion, table.concat(players) }, ",")
    local chunks, total = {}, math.ceil(#body / N.CHUNK_BYTES)
    assert(total <= N.MAX_CHUNKS, "snapshot exceeds configured bound")
    for part = 1, total do
        chunks[part] = packet("S", sid, seq, part, total, string.sub(body, (part - 1) * N.CHUNK_BYTES + 1, part * N.CHUNK_BYTES), term or 1)
        assert(#chunks[part] <= N.MAX_BYTES, "snapshot packet exceeds transport")
    end
    return chunks
end
function N.decodeState(body)
    if type(body) ~= "string" or #body > N.CHUNK_BYTES * N.MAX_CHUNKS then return nil end
    local f = split(body, ",")
    if #f ~= 12 or not phaseNames[f[1]] or not modeNames[f[9]] then return nil end
    local stage, boss, paused = integer(f[2], 1, 4), integer(f[3], 0, 16), integer(f[4], 0, 1)
    local epoch, revision = integer(f[5], 1, 999999), integer(f[6], 1, 999999)
    local clock = #f[10] == 5 and unbase(f[10], 0, 60466175)
    if not stage or not boss or boss > 8 + stage * 2 or not paused or not epoch or not revision or not clock
        or #f[7] ~= 9 or string.find(f[7], "[^012]") or #f[8] ~= 40 or #f[12] ~= 400 then return nil end
    local s, used, mapping, botIDs = M.new(modeNames[f[9]]), {}, {}, {}
    s.phase, s.stage, s.boss, s.paused, s._epoch, s._revision = phaseNames[f[1]], stage, boss, paused == 1, epoch, revision
    s.time, s._activeCount, s._spectators, s._botCount = clock/10, 0, 0, 0
    if (s.phase == "play") ~= (f[11] ~= "-") then return nil end
    if f[11] ~= "-" then
        local b = f[11]; if #b ~= 11 then return nil end
        local id, phase = unbase(string.sub(b, 1, 4), 1, 1679615), motionNames[string.sub(b, 5, 5)]
        local mask, remaining = unbase(string.sub(b, 6, 7), 0, 127), unbase(string.sub(b, 8, 9), 1, M.WARNING_TIME * 10)
        local from, to = unbase(string.sub(b, 10, 10), 2, 6), unbase(string.sub(b, 11, 11), 2, 6)
        if not id or not phase or not mask or not remaining or not from or not to then return nil end
        local lanes = {}; for x = 1, 7 do if math.floor(mask/2^(x-1)) % 2 == 1 then lanes[#lanes+1] = x end end
        if phase == "patrol" then
            local stride = stage == 2 and 2 or (stage == 4 and (id % 2 == 0 and 2 or 1) or 1)
            if mask ~= 0 or remaining > M.PATROL_TIME * 10 or (stage == 3 and math.abs(to-from) > 1)
                or (stage ~= 3 and math.abs(to-from) ~= stride) then return nil end
        else
            if from ~= to then return nil end
            if phase == "recover" then
                if mask ~= 0 or remaining > M.HAZARD_COOLDOWN * 10 then return nil end
            else
                local count = stage == 1 and 1 or (stage == 2 and 2 or 3)
                if #lanes ~= count or (phase == "attack" and remaining > M.IMPACT_TIME * 10) then return nil end
                for i = 2, #lanes do if lanes[i] ~= lanes[i-1]+1 then return nil end end
                if stage == 3 and (lanes[1] ~= to-1 or lanes[3] ~= to+1) then return nil end
            end
        end
        s.bossMotion, s.hazardID = { id = id, phase = phase, lanes = lanes, remaining = remaining/10, fromLane = from, toLane = to }, id
        M.syncHazard(s)
    end
    for i = 1, 9 do s.hp[i] = tonumber(string.sub(f[7], i, i)) end
    for id = 1, 40 do
        local c = string.sub(f[8], id, id)
        if c ~= "." then
            local slot = unbase(c, 0, 25); if not slot or (slot > 0 and used[slot]) then return nil end
            mapping[id] = slot
            if slot > 0 then used[slot] = true else s._spectators = s._spectators + 1 end
        end
    end
    s._mapping = mapping
    for slot = 1, 25 do
        local p = string.sub(f[12], (slot - 1) * 16 + 1, slot * 16)
        if p ~= "----------------" then
            local x, y = unbase(string.sub(p, 1, 1), 1, 7), unbase(string.sub(p, 2, 2), 0, 3)
            local score, hit = unbase(string.sub(p, 3, 6), 0, 99999), unbase(string.sub(p, 7, 8), 0, 999)
            local health, ko = unbase(string.sub(p, 9, 10), 0, 100), unbase(string.sub(p, 11, 12), 0, 40)
            local invuln, kos = unbase(string.sub(p, 13, 13), 0, 30), unbase(string.sub(p, 14, 15), 0, 1295)
            local flags = unbase(string.sub(p, 16, 16), 0, 11)
            if not x or not y or not score or not hit or not health or not ko or not invuln or not kos or not flags
                or (y > 0 and not M.towerIndex(x)) or (ko > 0 and health ~= 0) or (health == 0 and ko == 0) then return nil end
            local botID = math.floor(flags/2)
            if botID > 0 then
                if used[slot] or botIDs[botID] or flags % 2 == 1 then return nil end
                botIDs[botID] = true; s._botCount = s._botCount+1
            elseif not used[slot] then return nil end
            s._activeCount = s._activeCount+1
            s.players[slot] = { x=x, y=y, score=score, hit=hit, hp=health, maxHP=100,
                ko=ko/10, invuln=invuln/10, kos=kos, protected=flags%2==1,
                bot=botID>0, botID=botID>0 and botID or nil, name=M.BOT_NAMES[botID] }
        elseif used[slot] then return nil end
    end
    return s
end

function N.new(env)
    assert(nameOK(env.name), "A canonical player-realm name is required")
    return setmetatable({ env = env, name = env.name, mode = "idle", roster = {}, grouped = false,
        lobbies = {}, members = {}, bots = {}, selectedMode = "coop", protectionSeq = 0, participants = {}, memberVersions = {}, receiveBuckets = {},
        queue = {}, queueOrder = {}, tokens = N.SEND_BURST, bytes = N.BYTE_BURST, lastRefill = env.now(),
        assemblies = {}, inSeq = 0, outSeq = 0, status = "Solo practice, or find a party/raid lobby." }, { __index = methods })
end
function methods:notice(message)
    if message then self.status = message end
    if self.env.changed then self.env.changed(self) end
end
function methods:enqueue(key, text, priority, fence)
    -- All session traffic, including admission and end/leave, is term-fenced.
    -- encodeState is also public and already appends its explicit term.
    if type(text) == "string" and string.sub(text, 1, 3) == "R5|"
        and string.sub(text, 4, 5) ~= "S|" and text ~= "R5|Q" then
        text = text .. "|" .. tostring(fence or self.term or 1)
    end
    if type(text) ~= "string" or #text > N.MAX_BYTES then return false end
    if not self.queue[key] then
        if #self.queueOrder >= N.MAX_QUEUE then return false end
        self.queueOrder[#self.queueOrder + 1] = key
    end
    self.queue[key] = { text = text, priority = priority or 3 }; return true
end
function methods:flush()
    local now = self.env.now()
    local dt = math.max(0, now - self.lastRefill); self.lastRefill = now
    self.tokens = math.min(N.SEND_BURST, self.tokens + dt * N.SEND_RATE)
    self.bytes = math.min(N.BYTE_BURST, self.bytes + dt * N.BYTE_RATE)
    while self.tokens >= 1 and #self.queueOrder > 0 do
        local best = 1
        for i = 2, #self.queueOrder do
            if self.queue[self.queueOrder[i]].priority < self.queue[self.queueOrder[best]].priority then best = i end
        end
        local key = self.queueOrder[best]; local item = self.queue[key]
        local cost = #item.text + N.WIRE_OVERHEAD
        if self.bytes < cost then break end
        table.remove(self.queueOrder, best); self.queue[key] = nil
        self.tokens, self.bytes = self.tokens - 1, self.bytes - cost
        self.env.send(item.text)
    end
end
function methods:reset(message)
    self.mode, self.state, self.sid, self.hostName, self.slot, self.role = "idle", nil, nil, nil, nil, nil
    self.members, self.participants, self.memberVersions, self.queue, self.queueOrder, self.assemblies = {}, {}, {}, {}, {}, {}
    self.joinToken, self.generation, self.lastSnapshot, self.inSeq, self.outSeq = nil, nil, nil, 0, 0
    self.roleSeq, self.acceptedRoleSeq, self.lastLocalAction, self.requestedRole, self.keepaliveSeq = 0, 0, nil, nil, 0
    self.challenges, self.ownMemberID, self.bots, self.protectionSeq, self.expectedMode = {}, nil, {}, 0, nil
    self.term, self.migration, self.leaving, self.committed, self.checkpointSend, self.migrationActive = nil, nil, nil, nil, nil, false
    self.checkpointAssemblies, self.checkpointCache, self.transfer, self.claim, self.votes, self.witness = {}, {}, nil, nil, {}, nil
    self.nextJoined, self.checkpointSerial, self.nextCheckpoint, self.snapshotTimes = 0, 0, 0, {}
    self.configVoters,self.configAcks,self.withdrawn,self.configRevision,self.electionFloor={}, {}, {}, nil, 0
    self.membershipPending,self.nextFence=nil,nil
    self:notice(message or "Left the game.")
end
function methods:rebuildMembers()
    self.members = {}
    for _, member in pairs(self.participants) do if member.slot then self.members[member.slot] = member end end
    if self.mode == "host" or self.mode == "solo" then
        for slot, member in pairs(self.bots) do self.members[slot] = member end
    elseif self.state then
        for slot, p in pairs(self.state.players) do
            if p.bot then self.members[slot] = { name = p.name, bot = true, botID = p.botID, slot = slot } end
        end
    end
end
function methods:botCount()
    if self.mode ~= "host" and self.mode ~= "solo" and self.state then return self.state._botCount or 0 end
    local n = 0; for _ in pairs(self.bots) do n = n+1 end; return n
end
function methods:setMode(mode)
    if not M.validMode(mode) or self.combat or self.migration or self.leaving or self.leasePaused then return false end
    if self.mode == "idle" then self.selectedMode = mode; self:notice(); return true end
    if (self.mode ~= "host" and self.mode ~= "solo") or (self.state.phase ~= "lobby" and self.state.phase ~= "victory") then return false end
    if self.mode == "host" and mode ~= self.state.mode then
        -- Joined players AND spectators consented to a particular mode. Require
        -- them to leave/rejoin instead of silently turning their game into PvP.
        for id = 1, 40 do
            if self.participants[id] and id ~= self.ownMemberID then
                self:notice("Mode locked while guests are joined. Start a new lobby or ask guests to Leave first.")
                return false
            end
        end
    end
    self.selectedMode, self.state.mode = mode, mode
    if self.mode == "host" then self:advertise() end
    self:notice("Next game: " .. (mode == "brawl" and "Brawl (friendly fire ON)." or "Co-op (no friendly fire).")); return true
end
function methods:addAI()
    if (self.mode ~= "host" and self.mode ~= "solo") or self.combat or self.migration or self.leaving or self.leasePaused or self:botCount() >= M.MAX_BOTS or self:count() >= M.MAX_PLAYERS then return false end
    local used, slot = {}, nil
    for _, bot in pairs(self.bots) do used[bot.botID] = true end
    for i = 1, M.MAX_PLAYERS do if not self.members[i] then slot = i; break end end
    local botID; for i = 1, M.MAX_BOTS do if not used[i] then botID = i; break end end
    if not slot or not botID or not M.addPlayer(self.state, slot, botID) then return false end
    self.botSerial = (self.botSerial or 0)+1
    self.bots[slot] = { name = M.BOT_NAMES[botID], bot = true, botID = botID, slot = slot, order = self.botSerial }
    self:rebuildMembers(); if self.mode == "host" then self:advertise() end
    self:notice("Added " .. M.BOT_NAMES[botID] .. " (Addon AI)."); return true
end
function methods:removeAI()
    if self.migration or self.leaving or self.leasePaused or (self.mode ~= "host" and self.mode ~= "solo") then return false end
    local oldest
    for slot, bot in pairs(self.bots) do if not oldest or bot.order < self.bots[oldest].order then oldest = slot end end
    if not oldest then return false end
    local name = self.bots[oldest].name
    self.bots[oldest] = nil; M.removePlayer(self.state, oldest); self:rebuildMembers()
    if self.mode == "host" then self:advertise() end
    self:notice("Removed " .. name .. " (Addon AI)."); return true
end
function methods:count()
    if self.mode ~= "host" and self.mode ~= "solo" and self.state then return self.state._activeCount or 0 end
    local n = 0; for _ in pairs(self.members) do n = n + 1 end; return n
end
function methods:spectatorCount()
    if self.mode ~= "host" and self.mode ~= "solo" and self.state then return self.state._spectators or 0 end
    local n = 0; for _, m in pairs(self.participants) do if not m.slot then n = n + 1 end end; return n
end
function methods:setRoster(roster, grouped)
    self.roster, self.grouped = roster, grouped
    for name in pairs(self.receiveBuckets) do if not roster[name] then self.receiveBuckets[name] = nil end end
    for name in pairs(self.lobbies) do if not roster[name] then self.lobbies[name] = nil end end
    if self.mode == "solo" or self.mode == "idle" then return end
    if not grouped then self:reset("Group left. Game ended; solo practice is available."); return end
    if self.mode == "client" and not roster[self.hostName] then
        self:beginMigration("Host left the group")
    elseif self.mode == "host" then
        for id = 1, 40 do if id ~= self.ownMemberID and self.participants[id] and not roster[self.participants[id].name] then self:remove(id) end end
        for name in pairs(self.challenges) do if not roster[name] then self.challenges[name] = nil end end
    end
end
function methods:solo(mode)
    mode = mode or self.selectedMode or "coop"
    if self.mode ~= "idle" or self.combat or not M.validMode(mode) then return false end
    self.mode, self.slot, self.role, self.state = "solo", 1, "play", M.new(mode)
    self.selectedMode, self.bots = mode, {}
    self.participants = { { name = self.name, slot = 1 } }; self:rebuildMembers()
    M.addPlayer(self.state, 1); M.start(self.state); self:notice("Solo practice: flatten three towers, then punch the boss!"); return true
end
function methods:host(mode)
    mode = mode or self.selectedMode or "coop"
    if self.mode ~= "idle" or self.combat or not self.grouped or not M.validMode(mode) then
        self:notice("Hosting needs a party/raid, out of combat, and no active game."); return false
    end
    self.mode, self.hostName, self.sid, self.slot, self.role = "host", self.name, self.env.token(), 1, "play"
    self.term, self.ownMemberID, self.nextJoined = 1, 1, 1
    self.checkpointSerial, self.nextCheckpoint, self.checkpointCache, self.checkpointAssemblies = 0, 0, {}, {}
    self.authoritySince, self.votes, self.snapshotTimes = self.env.now(), {}, {}
    self.configVoters,self.configAcks,self.withdrawn,self.configRevision,self.electionFloor={}, {}, {}, 1, 1
    self.membershipPending,self.nextFence=nil,nil
    assert(token(self.sid), "Invalid session token")
    self.state, self.revision, self.snapshotSeq, self.inputEpoch, self.nextGeneration = M.new(mode), 1, 0, 1, 1
    self.selectedMode, self.bots = mode, {}
    self.inSeq, self.outSeq, self.roleSeq, self.acceptedRoleSeq, self.inputFloor = 0, 0, 0, 0, 1
    self.challenges, self.memberVersions = {}, {1}
    self.participants = { { name = self.name, token = self.env.token(), generation = 1, joined = 1, slot = 1, seq = 0, roleSeq = 0, seen = self.env.now() } }
    self.joinToken, self.generation = self.participants[1].token, 1
    self:rebuildMembers(); M.addPlayer(self.state, 1)
    self.nextSnapshot, self.nextAdvert, self.nextMember, self.memberCursor, self.lastAdvert = 0, 0, 0, 1, nil
    self:notice("Lobby open: 25 players, 40 total. Late join and spectating are available.")
    self:sendMember(1); self:advertise(); self:snapshot(); return true
end
function methods:discover()
    if not self.grouped then self:notice("Join a party/raid first, or choose Solo."); return false end
    local now = self.env.now(); if self.lastDiscover and now - self.lastDiscover < 2 then return false end
    self.lastDiscover = now; self:enqueue("query", packet("Q")); self:notice("Looking for opted-in lobbies; pick a host and Join or Spectate."); return true
end
function methods:lobbyList()
    local list, now = {}, self.env.now()
    for name, info in pairs(self.lobbies) do if now - info.seen <= 15 and self.roster[name] then list[#list + 1] = info end end
    table.sort(list, function(a, b) return a.name < b.name end); return list
end
function methods:join(hostName, sid, role, expectedMode)
    role = role or "play"
    if not roleOK(role) or self.mode ~= "idle" or self.combat or not self.grouped or hostName == self.name then return false end
    local lobby = self.lobbies[hostName]
    if not lobby or lobby.sid ~= sid or self.env.now() - lobby.seen > 15 or not self.roster[hostName] then return false end
    expectedMode = expectedMode or lobby.mode
    if not M.validMode(expectedMode) or expectedMode ~= lobby.mode then return false end
    self.expectedMode, self.protectionSeq = expectedMode, 0
    self.mode, self.hostName, self.sid, self.role, self.requestedRole = "joining", hostName, sid, role, role
    self.term = lobby.term
    self.checkpointAssemblies, self.checkpointCache, self.votes = {}, {}, {}
    self.joinToken, self.joinStarted, self.nextJoin = self.env.token(), self.env.now(), 0
    assert(token(self.joinToken), "Invalid join token")
    self.inSeq, self.outSeq, self.roleSeq, self.acceptedRoleSeq, self.generation = 0, 0, 0, 0, nil
    self:notice("Joining " .. hostName .. " (large raids may take up to 90 seconds)..."); return true
end
function methods:advertise()
    if self.mode ~= "host" then return end
    local now = self.env.now()
    if self.lastAdvert and now - self.lastAdvert < 2 then return end
    self.lastAdvert = now
    self:enqueue("advert", packet("A", self.sid, phases[self.state.phase], self:count(), self:spectatorCount(), modeCode(self.state.mode), self:botCount()), 1)
end
function methods:sendMember(id)
    local m = self.participants[id]
    self:enqueue("member" .. id, packet("M", self.sid, self.memberVersions[id] or self.revision, id,
        m and m.name or "-", m and m.token or "-", m and m.generation or 0, m and m.slot or 0, m and m.roleSeq or 0, modeCode(self.state.mode), m and m.joined or 0), 2)
end
function methods:broadcastMembers()
    -- Compatibility helper: bounded coalesced records, never a per-client full roster.
    for id = 1, 40 do if self.memberVersions[id] then self:sendMember(id) end end
end
function methods:snapshot()
    if self.snapshotSeq >= 999999 then self:reset("Sequence exhausted. Start a new room."); return end
    -- Never replace half a pending snapshot: finish it before capturing a new one.
    for i = 1, N.MAX_CHUNKS do if self.queue["state" .. i] then return end end
    if #self.queueOrder > N.MAX_QUEUE - N.MAX_CHUNKS then return end
    self.snapshotSeq = self.snapshotSeq + 1
    self.snapshotTimes=self.snapshotTimes or {}; self.snapshotTimes[self.snapshotSeq]=self.env.now()
    self.snapshotTimes[self.snapshotSeq-32]=nil
    for i, text in ipairs(N.encodeState(self.state, self.sid, self.snapshotSeq, self.inputEpoch, self.revision, self.participants, self.term)) do
        self:enqueue("state" .. i, text, 1)
    end
end
function methods:changedMember(id)
    if self.revision >= 999999 then self:leave(); return false end
    self.revision = self.revision + 1; self.memberVersions[id] = self.revision
    self.membershipPending,self.state.paused,self.nextFence=true,true,0
    local relevant={}
    for _,m in pairs(self.configVoters) do relevant[m.name]=true end
    for _,m in pairs(self.participants) do relevant[m.name]=true end
    for name in pairs(self.configAcks) do if not relevant[name] then self.configAcks[name]=nil end end
    self:rebuildMembers(); self:sendMember(id); self:advertise(); self:notice(); return true
end
function methods:remove(id, withdrawn)
    if id == self.ownMemberID or not self.participants[id] or self.leaving then return end
    if withdrawn then
        local m=self.participants[id]
        for _,old in pairs(self.configVoters) do
            if old.name==m.name and old.generation==m.generation then self.withdrawn[m.name..":"..m.generation]=true end
        end
    end
    local m = self.participants[id]; if m.slot then M.removePlayer(self.state, m.slot) end
    self.participants[id] = nil; self:changedMember(id)
end
function methods:bumpEpoch()
    if self.inputEpoch >= 999999 then self:leave(); return false end
    self.inputEpoch, self.inputFloor = self.inputEpoch + 1, self.snapshotSeq + 1; return true
end
function methods:start()
    if self.combat or self.migration or self.leaving or self.leasePaused or (self.mode ~= "host" and self.mode ~= "solo") then return false end
    if M.start(self.state) then
        if self.mode == "host" then self:bumpEpoch() end
        self:notice("FOUR MORE BOSSES! Climb and smash all three towers."); return true
    end
    return false
end
function methods:setCombat(inCombat)
    local changed = self.combat ~= (inCombat and true or false)
    self.combat = inCombat and true or false
    if self.state and (self.mode == "host" or self.mode == "solo") then
        self.state.paused = self.combat or self.migration ~= nil or self.leaving == true or self.leasePaused == true or self.membershipPending==true
        if changed and self.mode == "host" then self:bumpEpoch() end
    end
    if changed and (self.mode == "client" or self.mode == "joining") then
        self.protectionSeq = math.min(999999, (self.protectionSeq or 0)+1)
        self.nextKeepalive = 0
    end
    self:notice()
end
-- Adapter supplies true for real WoW combat; missing roster information must not revoke a notify.
function methods:setMemberCombat(name, inCombat)
    if self.mode ~= "host" then return false end
    for _, member in pairs(self.participants) do
        if member.name == name and member.slot then
            member.rosterCombat = inCombat and true or false
            self.state.players[member.slot].protected = member.rosterCombat or member.notifiedCombat or false
            return true
        end
    end
    return false
end
function methods:setRole(role)
    if not roleOK(role) or self.migration or self.leaving or self.leasePaused then return false end
    if self.mode == "host" then
        local member = self.participants[self.ownMemberID]
        if not member or member.roleSeq >= 999999 then return false end
        member.roleSeq = member.roleSeq + 1
        if role == "spectate" and member.slot then M.removePlayer(self.state, member.slot); member.slot = nil
        elseif role == "play" and not member.slot then
            for slot = 1, 25 do if not self.members[slot] then member.slot = slot; break end end
            if not member.slot and self:removeAI() then
                for slot = 1, 25 do if not self.members[slot] then member.slot = slot; break end end
            end
            if member.slot then M.addPlayer(self.state, member.slot) end
        end
        self.slot, self.role = member.slot, member.slot and "play" or "spectate"
        self:changedMember(self.ownMemberID); return self.role == role
    end
    if self.mode ~= "client" then return false end
    if self.roleSeq >= 999999 then return false end
    self.roleSeq = self.roleSeq + 1; self.requestedRole = role; self.nextRole = 0
    self:notice(role == "play" and "Requesting a player slot..." or "Switching to spectator..."); return true
end
function methods:action(action)
    if self.role ~= "play" or not self.slot or self.combat or not M.ACTIONS[action] or not self.state or self.state.paused or self.state.phase ~= "play" then return false end
    local now = self.env.now(); if self.lastLocalAction and now - self.lastLocalAction < 0.2 then return false end
    self.lastLocalAction = now
    if self.mode == "host" or self.mode == "solo" then
        local result = M.act(self.state, self.slot, action); self:notice(); return result
    elseif self.mode == "client" then
        if self.outSeq >= 999999 then return false end
        self.outSeq = self.outSeq + 1
        return self:enqueue("input", packet("I", self.sid, self.joinToken, self.generation, self.outSeq,
            self.inSeq, self.state._epoch, self.acceptedRoleSeq, action), 2)
    end
    return false
end
-- Delayed genuine votes survive a UI reset/rejoin. Keep a bounded incarnation
-- history outside reset(): a replacement may fence an earlier generation ONLY
-- when this same live process remembers an unbroken, never-voted lineage. A
-- reload/eviction starts at the new generation, never claims forgotten safety.
function methods:incarnation()
    if not self.hostName or not self.sid or not self.term or not self.generation then return nil end
    self.incarnations=self.incarnations or {}
    local key=self.hostName..":"..self.sid..":"..self.term
    local a=self.incarnations[key]
    if not a then
        local n,oldest=0,nil
        for k,v in pairs(self.incarnations) do n=n+1; if not oldest or v.seen<self.incarnations[oldest].seen then oldest=k end end
        if n>=40 then self.incarnations[oldest]=nil end
        a={first=self.generation,floor=self.electionFloor or 0,seen=self.env.now()}; self.incarnations[key]=a
    end
    a.seen=self.env.now(); self.electionFloor=math.max(self.electionFloor or 0,a.floor)
    return a
end
function methods:leave()
    if self.leaving then return true end
    if self.mode == "host" and self:successor() then
        self.leaving, self.migration, self.migrationActive = true, { kind = "graceful", started = self.env.now() }, true
        self.state.paused = true; self:bumpEpoch()
        self.queue, self.queueOrder = {}, {}
        self:captureCheckpoint(true)
        self:notice("Passing host to the longest-present participant..."); return true
    end
    self.queue, self.queueOrder = {}, {}
    if self.mode == "host" then self:enqueue("end", packet("E", self.sid), 1)
    elseif self.mode == "client" then
        local a=self:incarnation()
        self:enqueue("leave", packet("L", self.sid, self.joinToken, self.generation,a and not a.voted and 1 or 0), 1)
    end
    self:flush(); self:reset("Left the game. Your local best score is kept."); return true
end
local function findMember(self, sender)
    for id = 1, 40 do local m = self.participants[id]; if m and m.name == sender then return id, m end end
end
local function freeSlot(self)
    for slot = 1, 25 do if not self.members[slot] then return slot end end
    -- Humans always take precedence; evict the oldest bot, not a physical member.
    if self:removeAI() then for slot = 1, 25 do if not self.members[slot] then return slot end end end
end
-- A recovery stream includes exact clocks/cooldowns, complete real membership,
-- durable order, generations, input counters and bot insertion order. Ordinary
-- lossy display snapshots are NEVER sufficient to become simulation authority.
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}; for k, v in pairs(value) do out[k] = copy(v) end; return out
end
local function digest(text)
    local a, b = 1, 0
    for i = 1, #text do a = (a + string.byte(text, i)) % 65521; b = (b + a) % 65521 end
    return base(b, 4) .. base(a, 4) -- corruption check, not a signature
end
local function numberText(n)
    if n == nil then return "-" end
    return (string.format("%.8f", n):gsub("0+$", ""):gsub("%.$", ""))
end
local function recoveryBody(self)
    local s, values = self.state, {}
    local function put(v) v = tostring(v); values[#values+1] = #v .. ":" .. v end
    local chunks = N.encodeState(s, self.sid, self.snapshotSeq, self.inputEpoch, self.revision, self.participants, self.term)
    local body = {}; for i, text in ipairs(chunks) do body[i] = split(text, "|")[7] end
    put(table.concat(body))
    put(self.configRevision)
    for _, n in ipairs({self.snapshotSeq, self.inputEpoch, self.revision, self.nextGeneration,
        self.nextJoined, self.botSerial or 0, s.time, s.wait or 0, s.bossDirection or 1,
        s.bossMotion and s.bossMotion.remaining or 0, s.hazardID or 0}) do put(numberText(n)) end
    for slot = 1, 25 do
        local p = s.players[slot]; put(p and 1 or 0)
        if p then
            for _, key in ipairs({"ko", "invuln", "nextAction", "nextPunch", "nextBot"}) do put(numberText(p[key])) end
            put(self.bots[slot] and self.bots[slot].order or 0)
        end
    end
    for id = 1, 40 do
        local m = self.participants[id]; put(m and 1 or 0)
        if m then
            put(m.name); put(m.token)
            for _, n in ipairs({m.generation, m.joined, m.slot or 0, m.seq or 0, m.roleSeq or 0,
                m.protectionSeq or 0, m.keepaliveSeq or 0, m.notifiedCombat and 1 or 0, m.rosterCombat and 1 or 0,
                math.min(35, math.max(0, self.env.now()-(m.seen or self.env.now()))), self.memberVersions[id]}) do put(numberText(n)) end
        else put(self.memberVersions[id] or 0) end
    end
    return table.concat(values)
end
local function decodeRecovery(body, hostName)
    if type(body) ~= "string" or #body > N.CHECKPOINT_BYTES then return nil end
    local at, failed = 1, false
    local function get()
        local colon = string.find(body, ":", at, true)
        if not colon or colon-at > 5 then failed = true; return "" end
        local length = integer(string.sub(body, at, colon-1), 0, N.CHECKPOINT_BYTES)
        if not length or colon+length > #body then failed = true; return "" end
        local value = string.sub(body, colon+1, colon+length); at = colon+length+1; return value
    end
    local function num(lo, hi, optional)
        local text = get(); if optional and text == "-" then return nil end
        if #text > 20 or not string.match(text, "^%-?%d+%.?%d*$") then failed = true; return 0 end
        local n = tonumber(text)
        if not n or n < lo or n > hi then failed = true; return 0 end; return n
    end
    local function int(lo, hi) local n = num(lo, hi); if n ~= math.floor(n) then failed = true end; return n end
    local s = N.decodeState(get()); if not s then return nil end
    local cp = { state = s, participants = {}, memberVersions = {}, bots = {} }
    cp.configRevision=int(1,999999)
    cp.seq, cp.epoch, cp.revision = int(1,999999), int(1,999999), int(1,999999)
    cp.nextGeneration, cp.nextJoined, cp.botSerial = int(1,999999), int(1,999999), int(0,999999)
    s.time, s.wait, s.bossDirection = num(0,6046617.5), num(0,2), int(-1,1)
    local remaining = num(0,M.WARNING_TIME); s.hazardID = int(0,1679615)
    if s.bossDirection == 0 or cp.epoch ~= s._epoch or cp.revision ~= s._revision or cp.configRevision~=cp.revision then failed = true end
    if s.bossMotion then
        if remaining <= 0 or math.abs(remaining-s.bossMotion.remaining) > 0.100001 or s.hazardID ~= s.bossMotion.id then failed = true end
        s.bossMotion.remaining = remaining; M.syncHazard(s)
    elseif remaining ~= 0 then failed = true end
    for slot = 1, 25 do
        local present, p = int(0,1), s.players[slot]
        if (present == 1) ~= (p ~= nil) then return nil end
        if p then
            local ko, invuln = num(0,4), num(0,3)
            if math.abs(ko-p.ko)>0.100001 or math.abs(invuln-p.invuln)>0.100001 then failed = true end
            p.ko, p.invuln = ko, invuln
            p.nextAction, p.nextPunch, p.nextBot = num(0,6046618.5,true), num(0,6046618.5,true), num(0,6046618.5,true)
            local order = int(0,999999)
            if p.bot then
                if order < 1 or order > cp.botSerial then failed = true end
                cp.bots[slot] = {slot=slot, bot=true, botID=p.botID, name=p.name, order=order}
            elseif order ~= 0 then failed = true end
        end
    end
    local names, generations, orders = {}, {}, {}
    for id = 1, 40 do
        local present = int(0,1)
        if present == 1 then
            local name, tok = get(), get()
            local m = {name=name, token=tok, generation=int(1,999999), joined=int(1,999999)}
            local slot = int(0,25); m.slot = slot > 0 and slot or nil
            m.seq, m.roleSeq, m.protectionSeq = int(0,999999), int(0,999999), int(0,999999)
            m.keepaliveSeq = int(0,999999)
            m.notifiedCombat, m.rosterCombat, m.age = int(0,1)==1, int(0,1)==1, num(0,35)
            cp.memberVersions[id] = int(1,999999)
            if not nameOK(name) or not token(tok) or names[name] or generations[m.generation] or orders[m.joined]
                or m.generation > cp.nextGeneration or m.joined > cp.nextJoined or s._mapping[id] ~= slot
                or cp.memberVersions[id] > cp.revision then failed = true end
            names[name], generations[m.generation], orders[m.joined] = true, true, true
            cp.participants[id] = m; if name == hostName then cp.hostID = id end
        else
            cp.memberVersions[id] = int(0,999999)
            if s._mapping[id] ~= nil then failed = true end
        end
    end
    if failed or at ~= #body+1 or not cp.hostID then return nil end
    return cp
end
N.decodeRecovery = decodeRecovery
function methods:successor(participants, live)
    local best
    for id, m in pairs(participants or self.participants) do
        if not m.bot and m.name ~= self.hostName and self.roster[m.name] and m.joined and (not live or live[id]) then
            local b = best and (participants or self.participants)[best]
            if not b or m.joined < b.joined or (m.joined == b.joined and m.name < b.name) then best = id end
        end
    end
    return best
end
function methods:captureCheckpoint(graceful)
    if self.membershipPending or self.configRevision~=self.revision then return false end
    if self.checkpointSerial >= 999999 or self.term >= 999999 then
        self.state.paused = true; self:notice("Authority counter exhausted; Leave and start a new room."); return false
    end
    self.checkpointSerial = self.checkpointSerial + 1
    local body = recoveryBody(self)
    if #body > N.CHECKPOINT_BYTES then self.state.paused = true; return false end
    local cp = decodeRecovery(body, self.hostName); if not cp then self.state.paused = true; return false end
    cp.id, cp.hash, cp.body, cp.term, cp.created = self.checkpointSerial, digest(body), body, self.term, self.env.now()
    cp.total, cp.part, cp.graceful = math.ceil(#body/N.CHUNK_BYTES), 1, graceful
    self.checkpointSend, self.checkpointCache = cp, { [cp.id] = cp }
    return true
end
function methods:sendRecovery(now)
    local cp = self.checkpointSend
    if not cp then
        if now >= (self.nextCheckpoint or 0) then self:captureCheckpoint(self.leaving==true); cp = self.checkpointSend end
        if not cp then return end
    end
    if now-cp.created>N.CHECKPOINT_TIMEOUT then
        self.checkpointSend=nil; self.nextCheckpoint=now; return
    end
    if not self.queue.recovery and cp.part <= cp.total then
        local part = cp.part; cp.part = part+1
        self:enqueue("recovery", packet("X", self.sid, cp.id, part, cp.total, cp.hash,
            string.sub(cp.body,(part-1)*N.CHUNK_BYTES+1,part*N.CHUNK_BYTES)), cp.graceful and 1 or 3)
    elseif cp.part > cp.total and not self.queue.recovery then
        cp.finished = cp.finished or now
        if not cp.nextCommit or now >= cp.nextCommit then
            cp.nextCommit = now+2; self:enqueue("commit", packet("V", self.sid, cp.id, cp.hash,math.min(120,math.ceil(now-cp.created))), cp.graceful and 1 or 3)
            self.committed = cp; cp.committedAt,cp.evidenceAge = now,now-cp.created
        end
        if cp.graceful then
            local target = self:successor(cp.participants)
            if target and (not cp.nextTransfer or now >= cp.nextTransfer) then
                cp.nextTransfer = now+2
                self:enqueue("transfer", packet("T", self.sid, cp.id, cp.hash, self.term+1, target), 1)
            end
        elseif now-cp.finished >= 12 then
            self.checkpointSend, self.nextCheckpoint = nil, now+N.CHECKPOINT_INTERVAL
        end
    end
end
function methods:commitRecovery(a, now)
    if not a.marker or a.count ~= a.total then return false end
    local body = table.concat(a.parts)
    if digest(body) ~= a.hash then return false end
    local cp = decodeRecovery(body, self.hostName); if not cp then return false end
    cp.id, cp.hash, cp.term, cp.committedAt,cp.evidenceAge = a.id, a.hash, self.term, now,math.max(0,now-(a.evidenceOrigin or now))
    if self.committed and cp.id <= self.committed.id then return false end
    self.committed = cp; self.checkpointCache = { [cp.id] = cp }
    self.checkpointAssemblies[cp.id] = nil; return true
end
function methods:receiveRecovery(f, now)
    self.checkpointAssemblies = self.checkpointAssemblies or {}
    local id = integer(f[4],1,999999)
    if not id or (self.committed and id <= self.committed.id) then return false end
    local hash = f[2] == "X" and f[7] or f[5]
    if type(hash) ~= "string" or #hash ~= 8 or not string.match(hash,"^[0-9a-z]+$") then return false end
    local a = self.checkpointAssemblies[id]
    if not a then
        local count, oldest = 0, nil
        for k in pairs(self.checkpointAssemblies) do count=count+1; if not oldest or k<oldest then oldest=k end end
        if count >= 2 then if id < oldest then return false end; self.checkpointAssemblies[oldest]=nil end
        a = {id=id,hash=hash,parts={},count=0,started=now}; self.checkpointAssemblies[id]=a
    end
    if a.hash ~= hash then return false end
    if f[2] == "V" and #f == 6 then
        local age=integer(f[6],0,N.CHECKPOINT_TIMEOUT); if not age then return false end
        a.marker=true
        -- A delayed final chunk cannot erase time since the commit marker.
        -- Older/reordered markers may shorten evidence life, never extend it.
        a.evidenceOrigin=math.min(a.evidenceOrigin or a.started,a.started,now-age)
    elseif f[2] == "X" and #f == 8 then
        local part, total = integer(f[5],1,N.CHECKPOINT_CHUNKS), integer(f[6],1,N.CHECKPOINT_CHUNKS)
        if not part or not total or part>total or #f[8]<1 or #f[8]>N.CHUNK_BYTES
            or (part==total and (total-1)*N.CHUNK_BYTES+#f[8]>N.CHECKPOINT_BYTES)
            or (part<total and #f[8]~=N.CHUNK_BYTES) or (a.total and a.total~=total) or a.parts[part] then return false end
        a.total, a.parts[part], a.count = total, f[8], a.count+1
    else return false end
    self:commitRecovery(a,now); return true
end
function methods:beginMigration(reason)
    if self.migration then return end
    self.migration = {kind="election",started=self.env.now(),live={},votes={}}
    self.migrationActive=true
    self.queue, self.queueOrder, self.assemblies = {}, {}, {}
    if self.state then self.state.paused = true end
    self:notice((reason or "Host unavailable") .. ". Paused while checking a complete recovery checkpoint.")
end
function methods:checkpointEligible(cp)
    if not cp or cp.term ~= self.term or not self.ownMemberID or self.term>=999999
        or cp.epoch>=999999 or cp.revision>=999999 or cp.seq>=999999 then return false end
    if self.ownMemberID==cp.hostID or cp.configRevision~=(cp.revision or 0) or cp.revision<(self.electionFloor or 0) then return false end
    for _,version in pairs(self.memberVersions) do if version>cp.revision then return false end end
    if self.state and self.state._revision and self.state._revision>cp.revision then return false end
    local m = cp.participants[self.ownMemberID]
    return m and m.name == self.name and m.token == self.joinToken and m.generation == self.generation
        and m.roleSeq==(self.acceptedRoleSeq or 0) and m.slot==self.slot
        and self.env.now()-cp.committedAt+(cp.evidenceAge or 0) <= N.CHECKPOINT_TIMEOUT
end
function methods:adopt(cp, target, round, graceful)
    local successor = cp.participants[target]
    if not successor or successor.name == self.hostName or not self.roster[successor.name] then return false end
    local oldHost, oldTerm, now = self.hostName, self.term, self.env.now()
    self.retiredHosts=self.retiredHosts or {}
    local retiredCount,oldest=0,nil
    for name in pairs(self.retiredHosts) do retiredCount=retiredCount+1; if not oldest or name<oldest then oldest=name end end
    if retiredCount>=40 and not self.retiredHosts[oldHost] then self.retiredHosts[oldest]=nil end
    self.retiredHosts[oldHost]={sid=self.sid,term=oldTerm}
    if self.name == oldHost then self:reset("Host passed on. Reopen to watch, or explicitly join again."); return true end
    local own = self.ownMemberID and cp.participants[self.ownMemberID]
    if not own or not self:checkpointEligible(cp) then
        if self.state then self.state.paused = true end
        self:notice("Not in the committed recovery roster. Leave and rejoin the new host."); return false
    end
    local election=self.migration
    -- An adopter can learn an already sufficient quorum before casting its own
    -- vote. Its recovery witnesses are still genuine OLD-term votes: retain the
    -- old incarnation lock before changing host/term, just as for election Y.
    if not graceful then self:incarnation().voted=true end
    self.state, self.participants, self.memberVersions, self.bots = copy(cp.state), copy(cp.participants), copy(cp.memberVersions), copy(cp.bots)
    local gone = self.participants[cp.hostID]
    if gone.slot then M.removePlayer(self.state,gone.slot) end
    self.participants[cp.hostID] = nil
    self.hostName, self.term = successor.name, oldTerm+1
    self.inputEpoch, self.revision, self.snapshotSeq, self.inputFloor = cp.epoch+1, cp.revision+1, cp.seq, cp.seq+1
    self.memberVersions[cp.hostID] = self.revision
    for id,m in pairs(self.participants) do
        if not self.roster[m.name] then
            if m.slot then M.removePlayer(self.state,m.slot) end
            self.participants[id],self.memberVersions[id],self.state._mapping[id]=nil,self.revision,nil
        end
    end
    self.state._epoch, self.state._revision, self.inSeq = self.inputEpoch, self.revision, cp.seq
    self.state._mapping[cp.hostID] = nil
    self.nextGeneration, self.nextJoined, self.botSerial = cp.nextGeneration, cp.nextJoined, cp.botSerial
    self.outSeq = math.max(self.outSeq or 0,own.seq)
    self.slot, self.role, self.acceptedRoleSeq = own.slot, own.slot and "play" or "spectate", own.roleSeq
    self.roleSeq, self.requestedRole = own.roleSeq, nil
    self.mode = self.name == successor.name and "host" or "client"
    self.migration, self.leaving, self.leasePaused, self.transfer, self.migrationActive = nil, nil, nil, nil, false
    self.queue, self.queueOrder, self.assemblies, self.challenges, self.checkpointAssemblies = {}, {}, {}, {}, {}
    self.checkpointSend, self.committed, self.checkpointCache, self.nextCheckpoint = nil, nil, {}, now+3
    self.checkpointSerial = cp.id
    self.configRevision,self.electionFloor,self.membershipPending=self.revision,self.revision,nil
    self.configVoters,self.configAcks,self.withdrawn={},{},{}
    for id,m in pairs(self.participants) do if id~=self.ownMemberID then self.configVoters[id]={name=m.name,generation=m.generation} end end
    self.authoritySince, self.lastSnapshot, self.nextKeepalive, self.snapshotTimes = now, now, now, {}
    self.nextSnapshot, self.nextAdvert, self.nextMember, self.memberCursor, self.lastAdvert = now,now,now,1,nil
    for id, m in pairs(self.participants) do
        -- Recovery uses fresh authenticated election liveness, not a possibly
        -- minute-old checkpoint's last-seen age. Otherwise a live voter can be
        -- evicted on the very first successor tick. Graceful F certifies ready
        -- acknowledgments; unseen crash peers stay protected during the grace.
        m.seen,m.lastAction,m.leaseUntil=now,now,now+N.LEASE_TIMEOUT; m.age=nil
        if not graceful and id~=self.ownMemberID then
            m.seen=election and election.live[id] or now-13
        end
    end
    self.state.paused = self.mode == "host" and self.combat == true or self.mode == "client"
    if self.mode=="host" and self.slot then self.state.players[self.slot].protected=false end
    self:rebuildMembers()
    self.state._activeCount,self.state._spectators,self.state._botCount=0,0,0
    for _,p in pairs(self.state.players) do
        self.state._activeCount=self.state._activeCount+1
        if p.bot then self.state._botCount=self.state._botCount+1 end
    end
    for _,m in pairs(self.participants) do if not m.slot then self.state._spectators=self.state._spectators+1 end end
    if not graceful then self.witness={cp=cp,target=target,oldTerm=oldTerm,untilTime=now+30,next=0} end
    if self.mode == "host" then
        self.claim = {cp=cp,target=target,round=round or 0,graceful=graceful,oldTerm=oldTerm,untilTime=now+30,next=0}
        self:broadcastMembers(); self:snapshot(); self:advertise()
    end
    self:notice("Host passed to " .. successor.name .. ". " .. (self.state.paused and "Paused until authority is ready." or "World restored."))
    return true
end
function methods:voteCount(cp, migration, target)
    local voters, yes = 0, 0
    for id in pairs(cp.participants) do
        if id ~= cp.hostID then
            voters = voters+1
            if migration.votes[id] == target then yes = yes+1 end
        end
    end
    return yes >= math.floor(voters/2)+1, voters
end
function methods:migrationTick(now)
    local mig, cp = self.migration, self.committed
    if not mig then return end
    if self.state then self.state.paused = true end
    if self.leaving then
        if not mig.nextPause or now>=mig.nextPause then
            mig.nextPause=now+2; self:enqueue("pause",packet("H",self.sid),1)
        end
        self:sendRecovery(now)
        if (mig.finishAt and now>=mig.finishAt) or now-mig.started > N.LEAVE_TIMEOUT then
            self:reset(mig.acked and "Host passed on. Left the game." or "Left. Transfer deadline reached; peers recover only with complete evidence.")
        end
        return
    end
    if self.transfer and not self.transfer.expired then
        local t=self.transfer
        if now-t.started <= N.LEAVE_TIMEOUT then
            if self:checkpointEligible(cp) and (not t.nextReady or now>=t.nextReady) then
                t.nextReady=now+2; self:enqueue("ready",packet("G",self.sid,cp.id,cp.hash,self.term+1,self.ownMemberID),1)
            end
            return
        end
        t.expired=true; mig.started,mig.live,mig.votes=now,{},{}
    end
    if not self:checkpointEligible(cp) then return end
    local id = self.ownMemberID
    if now-mig.started > N.ELECTION_TIMEOUT then
        if not mig.expired then mig.expired=true; self:notice("Recovery paused: no safe majority / matching checkpoint. Leave and reconnect after the group heals.") end
        return
    end
    if not mig.nextHello or now >= mig.nextHello then
        mig.nextHello = now+2; mig.live[id] = now
        self:enqueue("election", packet("U",self.sid,cp.id,cp.hash,self.term+1,id,cp.participants[id].generation),1)
    end
    if now-mig.started >= N.ELECTION_GRACE then
        local live = {}; for member, seen in pairs(mig.live) do if now-seen <= 6 then live[member]=true end end
        local target = self:successor(cp.participants,live)
        local incarnation=self:incarnation()
        if target and not mig.voted and not incarnation.voted then
            mig.voted=target; mig.votes[id]=target; incarnation.voted=true
        end
        if mig.voted and (not mig.nextVote or now >= mig.nextVote) then
            mig.nextVote = now+2
            self:enqueue("vote",packet("Y",self.sid,cp.id,cp.hash,self.term+1,id,mig.voted,cp.participants[id].generation),1)
        end
        if mig.voted == id and self:voteCount(cp,mig,id) then
            self:flush() -- publish this node's own vote before changing the fence
            self:adopt(cp,id,1,false)
        end
    end
end
-- Host-certified membership changes use intersecting acknowledged revision
-- fences, not a native-raid electorate. For n old voters ceil(n/2) receipts
-- intersects every possible floor(n/2)+1 old election. The same fence is required
-- from the new electorate before the host resumes. A peer that has already cast
-- an election vote cannot acknowledge a competing membership change, including
-- after Leave/rejoin in the same authority term. Explicit never-voted departures
-- can retire a voter; unilateral roster shrink or forgotten lineage cannot.
function methods:membershipTick(now)
    if self.mode~="host" or not self.membershipPending then return end
    self.state.paused=true
    if not self.nextFence or now>=self.nextFence then
        self.nextFence=now+2; self:enqueue("membershipFence",packet("W",self.sid,self.revision),1)
    end
    local function enough(voters)
        local n,ack=0,0
        for _,m in pairs(voters) do
            if m.name~=self.name then
                n=n+1
                local a=self.configAcks[m.name]
                if self.withdrawn[m.name..":"..m.generation]
                    or (a and a.first<=m.generation and a.generation>=m.generation and a.revision>=self.revision) then ack=ack+1 end
            end
        end
        return ack>=math.ceil(n/2)
    end
    if not enough(self.configVoters) or not enough(self.participants) then return end
    self.configVoters={}
    for id,m in pairs(self.participants) do if id~=self.ownMemberID then self.configVoters[id]={name=m.name,generation=m.generation} end end
    self.configRevision,self.electionFloor,self.membershipPending=self.revision,self.revision,nil
    local keep={}; for _,m in pairs(self.participants) do if self.configAcks[m.name] then keep[m.name]=self.configAcks[m.name] end end
    self.configAcks,self.withdrawn=keep,{}; self:bumpEpoch()
    self.state.paused=self.combat==true or self.migration~=nil or self.leaving==true or self.leasePaused==true
    -- The next COMPLETE recovery stream carries this certificate. Acknowledgers
    -- remain fenced from the previous stream even if the new stream is lost.
    self.checkpointSend=nil; self.nextCheckpoint=now
end
function methods:receiveAuthority(sender, f, wireTerm, now)
    local kind = f[2]
    if kind=="W" then
        local revision=integer(f[4],1,999999)
        if #f~=4 or sender~=self.hostName or wireTerm~=self.term or not revision
            or self.mode=="host" or not self.generation or revision<(self.electionFloor or 0) then return false end
        local a=self:incarnation()
        if a.voted or (self.migration and self.migration.voted) then return false end
        self.electionFloor=revision
        a.floor=revision
        self:enqueue("membershipAck",packet("O",self.sid,self.joinToken,self.generation,revision,self.inSeq,a.first),1)
        return true
    end
    if kind=="O" then
        local _,m=findMember(self,sender)
        local revision=integer(f[6],1,999999)
        local first=integer(f[8],1,999999)
        if #f~=8 or self.mode~="host" or wireTerm~=self.term or not m or m.token~=f[4]
            or not first or first>m.generation
            or m.generation~=integer(f[5],1,999999) or revision~=self.revision then return false end
        self.configAcks[sender]={generation=m.generation,revision=revision,first=first}
        local seen=integer(f[7],1,999999); local at=seen and self.snapshotTimes[seen]
        if at then
            m.leaseUntil=math.max(m.leaseUntil or 0,at+N.LEASE_TIMEOUT)
            if seen>(m.fenceSeen or 0) then m.seen,m.fenceSeen=now,seen end
        end
        return true
    end
    if kind == "X" or kind == "V" then
        if sender ~= self.hostName or wireTerm ~= self.term or self.migration then return false end
        return self:receiveRecovery(f,now)
    end
    if kind == "Z" and #f == 5 and self.mode == "host" and wireTerm == self.term then
        local _, member = findMember(self,sender)
        local cp = self.checkpointSend
        if not member or not cp or integer(f[4],1,999999)~=cp.id or (member.repairAt and now-member.repairAt<4) then return false end
        member.repairAt = now
        local count=0
        for text in string.gmatch(f[5],"[^,]+") do
            count=count+1; local part=integer(text,1,cp.total)
            if not part or count>8 then return false end
            self:enqueue("repair"..part,packet("X",self.sid,cp.id,part,cp.total,cp.hash,
                string.sub(cp.body,(part-1)*N.CHUNK_BYTES+1,part*N.CHUNK_BYTES)),cp.graceful and 1 or 3)
        end
        return true
    end
    local cp = self.committed
    if not cp or wireTerm ~= self.term or integer(f[4],1,999999) ~= cp.id or f[5] ~= cp.hash
        or integer(f[6],1,999999) ~= self.term+1 then return false end
    if kind == "T" and #f == 7 and sender == self.hostName then
        local target = integer(f[7],1,40)
        if target ~= self:successor(cp.participants) then return false end
        if self.transfer and (self.transfer.expired or self.transfer.target~=target) then return false end
        self.transfer = self.transfer or {target=target,cp=cp,started=now}
        self:beginMigration("Host is leaving")
        if self:checkpointEligible(cp) then
            self:enqueue("ready",packet("G",self.sid,cp.id,cp.hash,self.term+1,self.ownMemberID),1)
        end
        return true
    end
    if kind == "G" and #f == 7 and self.leaving then
        local id = integer(f[7],1,40)
        if not id or not cp.participants[id] or cp.participants[id].name~=sender or id==cp.hostID then return false end
        local mig=self.migration; mig.ready=mig.ready or {}; mig.ready[id]=true
        for other,m in pairs(cp.participants) do
            if other~=cp.hostID and self.roster[m.name] and not mig.ready[other] then return true end
        end
        local target=self:successor(cp.participants)
        self:enqueue("finish",packet("F",self.sid,cp.id,cp.hash,self.term+1,target),1)
        mig.acked, mig.finishAt = true, mig.finishAt or now+3; return true
    end
    if kind == "F" and #f == 7 and sender == self.hostName and self.transfer and not self.transfer.expired then
        local target = integer(f[7],1,40)
        if target ~= self.transfer.target then return false end
        return self:adopt(cp,target,0,true)
    end
    if kind == "D" and #f == 8 then
        local target, graceful = integer(f[7],1,40), f[8] == "g"
        if f[8]~="g" and f[8]~="e" then return false end
        if not target or not cp.participants[target] or cp.participants[target].name ~= sender then return false end
        if graceful then
            if not self.transfer or self.transfer.expired or self.transfer.target ~= target then return false end
        elseif not self.migration or self.migration.expired or (self.migration.voted and self.migration.voted~=target)
            or not self:voteCount(cp,self.migration,target) then return false end
        return self:adopt(cp,target,1,graceful)
    end
    if (kind == "U" and #f == 8) or (kind == "Y" and #f == 9) then
        local id = integer(f[7],1,40); local member = id and cp.participants[id]
        if not member or id == cp.hostID or member.name ~= sender or integer(f[#f],1,999999)~=member.generation then return false end
        if not self.migration then
            if self.mode=="host" and not self.leasePaused then return false end
            if self.mode ~= "host" and self.roster[self.hostName] and now-(self.lastSnapshot or now)<N.HOST_TIMEOUT then return false end
            self:beginMigration("Host recovery requested")
        end
        local mig=self.migration
        if mig.kind ~= "election" then return false end
        if kind == "U" then mig.live[id]=now; return true end
        local target=integer(f[8],1,40)
        if not target or not cp.participants[target] or target==cp.hostID or not self.roster[cp.participants[target].name] then return false end
        if mig.votes[id] and mig.votes[id]~=target then return false end
        mig.votes[id]=target; return true
    end
    return false
end
function methods:pruneAssemblies(now)
    for seq, a in pairs(self.assemblies) do
        if seq <= self.inSeq or now - a.started > N.ASSEMBLY_TIMEOUT then self.assemblies[seq] = nil end
    end
    for id, a in pairs(self.checkpointAssemblies or {}) do
        if now-a.started > N.CHECKPOINT_TIMEOUT then self.checkpointAssemblies[id]=nil
        elseif a.marker and a.total and not self.migration and (not a.nextRepair or now>=a.nextRepair) then
            a.nextRepair = now+8+(self.ownMemberID or 1)*0.07
            local missing={}
            for part=1,a.total do if not a.parts[part] and #missing<8 then missing[#missing+1]=part end end
            if #missing>0 then self:enqueue("repairRequest",packet("Z",self.sid,id,table.concat(missing,",")),3) end
        end
    end
end
function methods:receiveState(f, now)
    if #f ~= 7 or self.migration then return false end
    local seq, part, total = integer(f[4], 1, 999999), integer(f[5], 1, N.MAX_CHUNKS), integer(f[6], 1, N.MAX_CHUNKS)
    if not seq or seq <= self.inSeq or not part or not total or part > total or #f[7] < 1 or #f[7] > N.CHUNK_BYTES
        or (part < total and #f[7] ~= N.CHUNK_BYTES) then return false end
    self:pruneAssemblies(now)
    local a = self.assemblies[seq]
    if not a then
        local count, oldest = 0, nil
        for n in pairs(self.assemblies) do count = count + 1; if not oldest or n < oldest then oldest = n end end
        if count >= N.MAX_ASSEMBLIES then
            if seq < oldest then return false end; self.assemblies[oldest] = nil
        end
        a = { started = now, total = total, parts = {}, count = 0 }; self.assemblies[seq] = a
    end
    if a.total ~= total then return false end
    if a.parts[part] then return false end
    a.parts[part], a.count = f[7], a.count + 1
    if a.count < total then return true end
    self.assemblies[seq] = nil
    local state = N.decodeState(table.concat(a.parts))
    if not state or (self.state and (state._epoch < self.state._epoch or state._revision < self.state._revision)) then return false end
    if (self.mode == "joining" or self.mode == "client") and self.expectedMode and state.mode ~= self.expectedMode then
        self:reset("Lobby mode changed. Review the mode and join again."); return false
    end
    self.state, self.inSeq, self.lastSnapshot = state, seq, now
    self:rebuildMembers()
    if self.mode == "client" and self.ownMemberID and not state._mapping[self.ownMemberID]
        and state._revision >= (self.memberVersions[self.ownMemberID] or 0) then
        self:reset("Removed from lobby or connection expired. Find and Join to reconnect."); return true
    end
    self:pruneAssemblies(now); self:notice(); return true
end
function methods:receive(sender, text)
    if sender == self.name or not self.grouped or not self.roster[sender] or not nameOK(sender)
        or type(text) ~= "string" or #text > N.MAX_BYTES or #text < 4 then return false end
    -- Every raid broadcast reaches every client. Discard peer gameplay before
    -- allocating a bucket or splitting fields; only discovery is peer-visible.
    local authority = string.match(text,"^R5|([XVZTGFUYDWO])|")
    if self.mode ~= "host" and sender ~= self.hostName and text ~= "R5|Q" and string.sub(text, 1, 5) ~= "R5|A|" and not authority then return false end
    local now = self.env.now(); local bucket = self.receiveBuckets[sender] or { tokens = 24, time = now }
    self.receiveBuckets[sender] = bucket
    bucket.tokens = math.min(24, bucket.tokens + math.max(0, now - bucket.time) * 16); bucket.time = now
    if bucket.tokens < 1 then return false end; bucket.tokens = bucket.tokens - 1
    local f = split(text, "|"); if f[1] ~= N.VERSION then return false end
    local kind = f[2]
    if kind == "Q" and #f == 2 then
        if self.mode == "host" and (not self.lastAdvert or now - self.lastAdvert >= 2) then self:advertise() end
        return true
    end
    local wireTerm = integer(f[#f],1,999999)
    if not wireTerm then return false end
    table.remove(f)
    if not token(f[3]) then return false end
    if kind == "A" then
        local retired=self.retiredHosts and self.retiredHosts[sender]
        if retired and retired.sid==f[3] and wireTerm<=retired.term then return false end
        local count, spectators, bots = integer(f[5], 0, 25), integer(f[6], 0, 40), integer(f[8], 0, 5)
        if #f ~= 8 or not phaseNames[f[4]] or not modeNames[f[7]] or not count or not spectators or not bots
            or bots > count or count-bots+spectators > 40 or count-bots+spectators < 1 then return false end
        if not self.lobbies[sender] then
            local n = 0; for _ in pairs(self.lobbies) do n = n + 1 end; if n >= 8 then return false end
        end
        self.lobbies[sender] = { name = sender, sid = f[3], term = wireTerm, phase = phaseNames[f[4]], count = count, spectators = spectators, bots = bots, mode = modeNames[f[7]], seen = now }
        self:notice(); return true
    end
    if f[3] ~= self.sid then return false end
    if authority then return self:receiveAuthority(sender,f,wireTerm,now) end
    if wireTerm ~= self.term then return false end
    if self.mode == "host" then
        if self.migration or self.leaving or (self.leasePaused and kind~="K" and kind~="J" and kind~="B") then return false end
        if kind == "J" and #f == 6 and token(f[4]) and (f[5] == "p" or f[5] == "s") and modeNames[f[6]] == self.state.mode then
            local id, member = findMember(self, sender)
            if member and member.token == f[4] then
                -- Never refresh liveness or mutate a membership from replayed J.
                if not member.lastJoinReply or now - member.lastJoinReply >= 4 then self:sendMember(id); member.lastJoinReply = now end
                return true
            end
            local challenge = self.challenges[sender]
            if challenge and now - challenge.created < 60 then
                if challenge.token ~= f[4] then return false end
            else
                if self.nextGeneration >= 999999 then return false end
                self.nextGeneration = self.nextGeneration + 1
                challenge = { token = f[4], generation = self.nextGeneration, role = f[5], mode = self.state.mode, created = now }
                self.challenges[sender] = challenge
            end
            if not challenge.sent or now - challenge.sent >= 12 then
                self:enqueue("challenge" .. sender, packet("C", self.sid, sender, challenge.token, challenge.generation), 2); challenge.sent = now
            end
            return true
        end
        if kind == "B" and #f == 5 and token(f[4]) then
            local gen = integer(f[5], 1, 999999); local challenge = self.challenges[sender]
            local id, member = findMember(self, sender)
            if member and member.token == f[4] and member.generation == gen then
                if not member.lastJoinReply or now - member.lastJoinReply >= 4 then self:sendMember(id); member.lastJoinReply = now end
                return true -- replayed admission confirms no new liveness
            end
            if not gen or not challenge or challenge.token ~= f[4] or challenge.generation ~= gen or now - challenge.created > 60 or challenge.mode ~= self.state.mode then return false end
            if not id then for i = 1, 40 do if not self.participants[i] then id = i; break end end end
            if not id then return false end
            local slot = member and member.slot
            if challenge.role == "s" then
                if slot then M.removePlayer(self.state, slot) end; slot = nil
            elseif not slot then slot = freeSlot(self) end
            if self.nextJoined >= 999999 then return false end
            self.nextJoined = self.nextJoined+1
            member = { name = sender, token = f[4], generation = gen, joined = self.nextJoined, slot = slot, seq = 0, roleSeq = 0, seen = now, leaseUntil = now+N.LEASE_TIMEOUT }
            self.participants[id], self.challenges[sender],self.lastAdmission = member, nil, now
            if slot and not self.state.players[slot] then M.addPlayer(self.state, slot) end
            self:changedMember(id); return true
        end
        local id, member = findMember(self, sender)
        if not member or member.token ~= f[4] or integer(f[5], 1, 999999) ~= member.generation then return false end
        if kind == "K" and #f == 9 then
            local heartbeat=integer(f[8],1,999999)
            if not heartbeat or heartbeat<=(member.keepaliveSeq or 0) then return false end
            local seq, combat = integer(f[6], 0, 999999), integer(f[7], 0, 1)
            if not seq or not combat or seq < (member.protectionSeq or 0) then return false end
            if seq == (member.protectionSeq or 0) and member.notifiedCombat ~= nil and member.notifiedCombat ~= (combat == 1) then return false end
            local seen=integer(f[9],1,999999)
            local at=seen and self.snapshotTimes and self.snapshotTimes[seen]
            if not at then return false end
            member.leaseUntil=at+N.LEASE_TIMEOUT
            member.keepaliveSeq=heartbeat
            member.protectionSeq, member.notifiedCombat, member.seen = seq, combat == 1, now
            if member.slot then self.state.players[member.slot].protected = member.notifiedCombat or member.rosterCombat or false end
            return true
        end
        if kind == "L" and #f == 6 and (f[6]=="0" or f[6]=="1") then self:remove(id,f[6]=="1"); return true end
        if kind == "R" and #f == 7 and (f[7] == "p" or f[7] == "s") then
            local seq = integer(f[6], 1, 999999)
            if not seq or seq < member.roleSeq then return false end
            if seq == member.roleSeq then
                if not member.lastRoleReply or now - member.lastRoleReply >= 4 then self:sendMember(id); member.lastRoleReply = now end
                return true
            end
            member.roleSeq, member.seen = seq, now
            if f[7] == "s" and member.slot then M.removePlayer(self.state, member.slot); member.slot = nil
            elseif f[7] == "p" and not member.slot then
                member.slot = freeSlot(self)
                if member.slot then M.addPlayer(self.state, member.slot); self.state.players[member.slot].protected = member.notifiedCombat or member.rosterCombat or false end
            end
            self:changedMember(id); return true
        end
        if kind == "I" and #f == 10 and M.ACTIONS[f[10]] then
            local seq, seen = integer(f[6], 1, 999999), integer(f[7], 1, 999999)
            if not member.slot or not seq or seq <= member.seq or not seen or seen < self.inputFloor or seen > self.snapshotSeq
                or integer(f[8], 1, 999999) ~= self.inputEpoch or integer(f[9], 0, 999999) ~= member.roleSeq then return false end
            member.seq, member.seen = seq, now
            if member.lastAction and now - member.lastAction < 0.16 then return false end
            member.lastAction = now; local result = M.act(self.state, member.slot, f[10]); self:notice(); return result
        end
        return false
    end
    if (self.mode ~= "client" and self.mode ~= "joining") or sender ~= self.hostName or self.migration then return false end
    if kind == "H" and #f==3 then
        if self.state then self.state.paused=true end
        self.lastSnapshot=now; return true
    end
    if kind == "E" and #f == 3 then self:reset("Host ended the game. Choose Solo, Host or Join."); return true end
    if kind == "C" and #f == 6 and self.mode == "joining" and f[4] == self.name and f[5] == self.joinToken then
        local gen = integer(f[6], 1, 999999); if not gen or (self.generation and gen < self.generation) then return false end
        self.generation, self.nextJoin = gen, 0; self:incarnation(); return true
    end
    if kind == "M" and #f == 12 and modeNames[f[11]] then
        local revision, id = integer(f[4], 1, 999999), integer(f[5], 1, 40)
        local gen, slot, roleSeq = integer(f[8], 0, 999999), integer(f[9], 0, 25), integer(f[10], 0, 999999)
        local joined = integer(f[12],0,999999)
        if not revision or not id or not gen or not slot or not roleSeq or not joined or revision <= (self.memberVersions[id] or 0) then return false end
        if f[6] == "-" then
            if f[7] ~= "-" or gen ~= 0 or slot ~= 0 or roleSeq ~= 0 or joined ~= 0 then return false end
        elseif not nameOK(f[6]) or not self.roster[f[6]] or not token(f[7]) or gen < 1
            or joined < 1 then return false end
        -- A newer record wins slot collisions while the carousel catches up.
        for otherID, other in pairs(self.participants) do
            if otherID ~= id and (other.name == f[6] or (slot > 0 and other.slot == slot)) then
                if (self.memberVersions[otherID] or 0) > revision then return false end
                self.participants[otherID] = nil
            end
        end
        local old = self.participants[id]
        self.memberVersions[id] = revision
        self.participants[id] = f[6] ~= "-" and { name = f[6], token = f[7], generation = gen,
            slot = slot > 0 and slot or nil, roleSeq = roleSeq, joined = joined } or nil
        self:rebuildMembers()
        if f[6] == self.name and f[7] == self.joinToken and gen == self.generation then
            local first = self.mode == "joining"
            if first and modeNames[f[11]] ~= self.expectedMode then self:reset("Lobby mode changed. Review the mode and join again."); return false end
            self.expectedMode = self.expectedMode or modeNames[f[11]]
            self.slot, self.role, self.mode = slot > 0 and slot or nil, slot > 0 and "play" or "spectate", "client"
            self.acceptedRoleSeq, self.ownMemberID = roleSeq, id
            self.lastSnapshot = self.lastSnapshot or now
            if first then self.nextKeepalive = self.combat and 0 or now + 1 + (gen % 40) * 0.15 end
            if self.roleSeq <= roleSeq then
                if self.role == "spectate" and self.requestedRole == "play" then self:notice("Player slots full (25). Joined as spectator; choose Play when a slot opens.")
                else self:notice(self.role == "play" and "Joined as player! Shared city, personal score." or "Spectating: no avatar, score or gameplay input.") end
                self.requestedRole = nil
            end
        elseif old and old.name == self.name and self.mode == "client" then
            self:reset("Removed from lobby or connection expired. Find and Join to reconnect.")
        end
        return true
    end
    if kind == "S" then return self:receiveState(f, now) end
    return false
end
function methods:tick(elapsed)
    local now = self.env.now()
    for name, info in pairs(self.lobbies) do if now - info.seen > 15 then self.lobbies[name] = nil end end
    self:pruneAssemblies(now)
    if self.witness and now<=self.witness.untilTime and now>=self.witness.next then
        local c=self.witness; c.next=now+2
        local id=self.ownMemberID; local own=c.cp.participants[id]
        self:enqueue("witness",packet("Y",self.sid,c.cp.id,c.cp.hash,c.oldTerm+1,id,c.target,own.generation),1,c.oldTerm)
    end
    if self.claim and now<=self.claim.untilTime and now>=self.claim.next then
        local c=self.claim; c.next=now+2
        self:enqueue("claim",packet("D",self.sid,c.cp.id,c.cp.hash,self.term,c.target,c.graceful and "g" or "e"),1,c.oldTerm)
    end
    if self.mode=="client" and not self.migration and now-(self.lastSnapshot or now)>N.HOST_TIMEOUT then self:beginMigration("Host timed out") end
    if self.mode=="host" then self:membershipTick(now) end
    if self.migration then self:migrationTick(now); self:flush(); return end
    if self.mode == "host" then
        local peers, fresh=0,0
        for id,m in pairs(self.participants) do
            if id~=self.ownMemberID then peers=peers+1; if now<=(m.leaseUntil or m.seen+N.LEASE_TIMEOUT) then fresh=fresh+1 end end
        end
        self.leasePaused = peers>0 and now-(self.authoritySince or now)>N.LEASE_TIMEOUT and fresh<math.ceil(peers/2)
        self.state.paused = self.combat==true or self.leasePaused or self.membershipPending==true
        -- Never shrink a partitioned electorate by timing out the missing peers.
        if self.leasePaused then
            -- Send paused probes, never advance a hazard while reacquiring leases.
            if now>=self.nextSnapshot then self.nextSnapshot=now+N.SNAPSHOT_INTERVAL; self:snapshot() end
            self:flush(); return
        end
    end
    if self.mode == "host" or self.mode == "solo" then
        -- Reconcile native group combat BEFORE a hazard/AI tick, not one tick
        -- afterwards; notification latency must not create a damage window.
        if self.mode == "host" then
            for id = 1, 40 do
                local member = self.participants[id]
                if member and id ~= self.ownMemberID and member.slot then
                    if self.env.inCombat then member.rosterCombat = self.env.inCombat(member.name) and true or false end
                    self.state.players[member.slot].protected = member.notifiedCombat or member.rosterCombat or now-member.seen > 12
                end
            end
        end
        local oldPhase = self.state.phase; M.tick(self.state, math.min(math.max(elapsed, 0), 0.5))
        if self.mode == "host" then
            if oldPhase ~= "play" and self.state.phase == "play" then if not self:bumpEpoch() then return end end
            for id = 1, 40 do
                local member = self.participants[id]
                -- An unresponsive guest was protected above; remove after timeout.
                if member and id ~= self.ownMemberID and now - member.seen > 35 then self:remove(id) end
                if self.mode ~= "host" then return end
            end
            for name, c in pairs(self.challenges) do if now - c.created > 60 then self.challenges[name] = nil end end
            if now >= self.nextAdvert then self.nextAdvert = now + 5; self:advertise() end
            if now >= self.nextMember then
                -- Catch recent joins up quickly, then reserve recovery bandwidth
                -- in the background carousel for maximum-length realm names.
                self.nextMember = now + (now-(self.lastAdmission or self.authoritySince or 0)<30 and 1 or 2)
                for _ = 1, 40 do
                    local id = self.memberCursor; self.memberCursor = id % 40 + 1
                    if self.memberVersions[id] then self:sendMember(id); break end
                end
            end
            if not self.leasePaused and now >= self.nextSnapshot then self.nextSnapshot = now + N.SNAPSHOT_INTERVAL; self:snapshot() end
            if not self.leasePaused then self:sendRecovery(now) end
        end
    elseif self.mode == "joining" then
        if now - self.joinStarted > 90 then self:reset("Join timed out (40-member capacity, host busy or gone). Find and retry.")
        elseif now >= self.nextJoin then
            self.nextJoin = now + 4
            self:enqueue("join", self.generation and packet("B", self.sid, self.joinToken, self.generation)
                or packet("J", self.sid, self.joinToken, roleCode(self.role), modeCode(self.expectedMode)), 2)
        end
    elseif self.mode == "client" then
        if now - (self.lastSnapshot or now) > N.HOST_TIMEOUT then self:beginMigration("Host timed out")
        else
            local p = self.state and self.slot and self.state.players[self.slot]
            local unconfirmed = p and p.protected ~= (self.combat and true or false)
            if unconfirmed and now >= (self.lastProtectionSend or -1) + 1 then self.nextKeepalive = 0 end
            if now >= (self.nextKeepalive or 0) then
                self.lastProtectionSend = now
                self.keepaliveSeq=math.min(999999,(self.keepaliveSeq or 0)+1)
                self.nextKeepalive = now + 8; self:enqueue("keepalive", packet("K", self.sid, self.joinToken, self.generation, self.protectionSeq or 0, self.combat and 1 or 0,self.keepaliveSeq,self.inSeq), 1)
            end
            if self.requestedRole and self.roleSeq > self.acceptedRoleSeq and now >= (self.nextRole or 0) then
                self.nextRole = now + 4; self:enqueue("role", packet("R", self.sid, self.joinToken, self.generation, self.roleSeq, roleCode(self.requestedRole)), 2)
            end
        end
    end
    self:flush()
end
