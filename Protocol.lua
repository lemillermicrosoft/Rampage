-- R2: host-authoritative, bounded group broadcasts. Tokens are correlation, not secrets.
local _, addon = ...
local M = addon.Model
local N = { PREFIX = "ToastRampage1", VERSION = "R2", MAX_BYTES = 255,
    MAX_MEMBERS = 40, SEND_RATE = 8, SEND_BURST = 10, BYTE_RATE = 700,
    BYTE_BURST = 1000, WIRE_OVERHEAD = 16, MAX_QUEUE = 128,
    SNAPSHOT_INTERVAL = 1.25, CHUNK_BYTES = 176, MAX_CHUNKS = 2,
    ASSEMBLY_TIMEOUT = 6, MAX_ASSEMBLIES = 3 }
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
local function packet(...) return table.concat({ "R2", ... }, "|") end
local function roleCode(role) return role == "spectate" and "s" or "p" end
local function roleOK(role) return role == "play" or role == "spectate" end

-- A fixed 25-slot numeric world plus a 40-member presence/role map. Names travel
-- separately; an incomplete name carousel never blocks the world stream.
function N.encodeState(s, sid, seq, epoch, revision, participants)
    local hp, players, map = {}, {}, {}
    for i = 1, 9 do hp[i] = tostring(s.hp[i] or 0) end
    for i = 1, 40 do map[i] = "." end
    if participants then
        for id, member in pairs(participants) do map[id] = base(member.slot or 0, 1) end
    else
        for slot = 1, 25 do if s.players[slot] then map[slot] = base(slot, 1) end end
    end
    for slot = 1, 25 do
        local p = s.players[slot]
        players[slot] = p and (base(p.x, 1) .. base(p.y, 1) .. base(p.score, 4) .. base(p.hit, 2)) or "--------"
    end
    local body = table.concat({ phases[s.phase], s.stage, s.boss, s.paused and 1 or 0,
        epoch or 1, revision or 1, table.concat(hp), table.concat(map), table.concat(players) }, ",")
    local chunks, total = {}, math.ceil(#body / N.CHUNK_BYTES)
    assert(total <= N.MAX_CHUNKS, "snapshot exceeds configured bound")
    for part = 1, total do
        chunks[part] = packet("S", sid, seq, part, total, string.sub(body, (part - 1) * N.CHUNK_BYTES + 1, part * N.CHUNK_BYTES))
        assert(#chunks[part] <= N.MAX_BYTES, "snapshot packet exceeds transport")
    end
    return chunks
end
function N.decodeState(body)
    if type(body) ~= "string" or #body > N.CHUNK_BYTES * N.MAX_CHUNKS then return nil end
    local f = split(body, ",")
    if #f ~= 9 or not phaseNames[f[1]] then return nil end
    local stage, boss, paused = integer(f[2], 1, 4), integer(f[3], 0, 16), integer(f[4], 0, 1)
    local epoch, revision = integer(f[5], 1, 999999), integer(f[6], 1, 999999)
    if not stage or not boss or boss > 8 + stage * 2 or not paused or not epoch or not revision
        or #f[7] ~= 9 or string.find(f[7], "[^012]") or #f[8] ~= 40 or #f[9] ~= 200 then return nil end
    local s, used, mapping = M.new(), {}, {}
    s.phase, s.stage, s.boss, s.paused, s._epoch, s._revision = phaseNames[f[1]], stage, boss, paused == 1, epoch, revision
    s._activeCount, s._spectators = 0, 0
    for i = 1, 9 do s.hp[i] = tonumber(string.sub(f[7], i, i)) end
    for id = 1, 40 do
        local c = string.sub(f[8], id, id)
        if c ~= "." then
            local slot = unbase(c, 0, 25); if not slot or (slot > 0 and used[slot]) then return nil end
            mapping[id] = slot
            if slot > 0 then used[slot] = true; s._activeCount = s._activeCount + 1 else s._spectators = s._spectators + 1 end
        end
    end
    if mapping[1] ~= 1 then return nil end
    s._mapping = mapping
    for slot = 1, 25 do
        local p = string.sub(f[9], (slot - 1) * 8 + 1, slot * 8)
        if p ~= "--------" then
            local x, y = unbase(string.sub(p, 1, 1), 1, 7), unbase(string.sub(p, 2, 2), 0, 3)
            local score, hit = unbase(string.sub(p, 3, 6), 0, 99999), unbase(string.sub(p, 7, 8), 0, 999)
            if not x or not y or not score or not hit or not used[slot] or (y > 0 and not M.towerIndex(x)) then return nil end
            s.players[slot] = { x = x, y = y, score = score, hit = hit }
        elseif used[slot] then return nil end
    end
    return s
end

function N.new(env)
    assert(nameOK(env.name), "A canonical player-realm name is required")
    return setmetatable({ env = env, name = env.name, mode = "idle", roster = {}, grouped = false,
        lobbies = {}, members = {}, participants = {}, memberVersions = {}, receiveBuckets = {},
        queue = {}, queueOrder = {}, tokens = N.SEND_BURST, bytes = N.BYTE_BURST, lastRefill = env.now(),
        assemblies = {}, inSeq = 0, outSeq = 0, status = "Solo practice, or find a party/raid lobby." }, { __index = methods })
end
function methods:notice(message)
    if message then self.status = message end
    if self.env.changed then self.env.changed(self) end
end
function methods:enqueue(key, text, priority)
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
    self.roleSeq, self.acceptedRoleSeq, self.lastLocalAction, self.requestedRole = 0, 0, nil, nil
    self.challenges, self.ownMemberID = {}, nil; self:notice(message or "Left the game.")
end
function methods:rebuildMembers()
    self.members = {}
    for _, member in pairs(self.participants) do if member.slot then self.members[member.slot] = member end end
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
    if self.mode ~= "host" and not roster[self.hostName] then
        self:reset("Host left the group. No host migration; join or host a new game.")
    elseif self.mode == "host" then
        for id = 2, 40 do if self.participants[id] and not roster[self.participants[id].name] then self:remove(id) end end
        for name in pairs(self.challenges) do if not roster[name] then self.challenges[name] = nil end end
    end
end
function methods:solo()
    if self.mode ~= "idle" or self.combat then return false end
    self.mode, self.slot, self.role, self.state = "solo", 1, "play", M.new()
    self.participants = { { name = self.name, slot = 1 } }; self:rebuildMembers()
    M.addPlayer(self.state, 1); M.start(self.state); self:notice("Solo practice: flatten three towers, then punch the boss!"); return true
end
function methods:host()
    if self.mode ~= "idle" or self.combat or not self.grouped then
        self:notice("Hosting needs a party/raid, out of combat, and no active game."); return false
    end
    self.mode, self.hostName, self.sid, self.slot, self.role = "host", self.name, self.env.token(), 1, "play"
    assert(token(self.sid), "Invalid session token")
    self.state, self.revision, self.snapshotSeq, self.inputEpoch, self.nextGeneration = M.new(), 1, 0, 1, 1
    self.inSeq, self.outSeq, self.roleSeq, self.acceptedRoleSeq, self.inputFloor = 0, 0, 0, 0, 1
    self.challenges, self.memberVersions = {}, {1}
    self.participants = { { name = self.name, token = self.env.token(), generation = 1, slot = 1, seq = 0, roleSeq = 0, seen = self.env.now() } }
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
function methods:join(hostName, sid, role)
    role = role or "play"
    if not roleOK(role) or self.mode ~= "idle" or self.combat or not self.grouped or hostName == self.name then return false end
    local lobby = self.lobbies[hostName]
    if not lobby or lobby.sid ~= sid or self.env.now() - lobby.seen > 15 or not self.roster[hostName] then return false end
    self.mode, self.hostName, self.sid, self.role, self.requestedRole = "joining", hostName, sid, role, role
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
    self:enqueue("advert", packet("A", self.sid, phases[self.state.phase], self:count(), self:spectatorCount()), 1)
end
function methods:sendMember(id)
    local m = self.participants[id]
    self:enqueue("member" .. id, packet("M", self.sid, self.memberVersions[id] or self.revision, id,
        m and m.name or "-", m and m.token or "-", m and m.generation or 0, m and m.slot or 0, m and m.roleSeq or 0), 2)
end
function methods:broadcastMembers()
    -- Compatibility helper: bounded coalesced records, never a per-client full roster.
    for id = 1, 40 do if self.memberVersions[id] then self:sendMember(id) end end
end
function methods:snapshot()
    if self.snapshotSeq >= 999999 then self:leave(); return end
    -- Never replace half a pending snapshot: finish it before capturing a new one.
    if self.queue.state1 or self.queue.state2 or #self.queueOrder > N.MAX_QUEUE - N.MAX_CHUNKS then return end
    self.snapshotSeq = self.snapshotSeq + 1
    for i, text in ipairs(N.encodeState(self.state, self.sid, self.snapshotSeq, self.inputEpoch, self.revision, self.participants)) do
        self:enqueue("state" .. i, text, 1)
    end
end
function methods:changedMember(id)
    if self.revision >= 999999 then self:leave(); return false end
    self.revision = self.revision + 1; self.memberVersions[id] = self.revision
    self:rebuildMembers(); self:sendMember(id); self:advertise(); self:notice(); return true
end
function methods:remove(id)
    if id == 1 or not self.participants[id] then return end
    local m = self.participants[id]; if m.slot then M.removePlayer(self.state, m.slot) end
    self.participants[id] = nil; self:changedMember(id)
end
function methods:bumpEpoch()
    if self.inputEpoch >= 999999 then self:leave(); return false end
    self.inputEpoch, self.inputFloor = self.inputEpoch + 1, self.snapshotSeq + 1; return true
end
function methods:start()
    if self.combat or (self.mode ~= "host" and self.mode ~= "solo") then return false end
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
        self.state.paused = self.combat
        if changed and self.mode == "host" then self:bumpEpoch() end
    end
    self:notice()
end
function methods:setRole(role)
    if not roleOK(role) or self.mode ~= "client" then return false end
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
function methods:leave()
    self.queue, self.queueOrder = {}, {}
    if self.mode == "host" then self:enqueue("end", packet("E", self.sid), 1)
    elseif self.mode == "client" then self:enqueue("leave", packet("L", self.sid, self.joinToken, self.generation), 1) end
    self:flush(); self:reset("Left the game. Your local best score is kept.")
end
local function findMember(self, sender)
    for id = 2, 40 do local m = self.participants[id]; if m and m.name == sender then return id, m end end
end
local function freeSlot(self)
    for slot = 2, 25 do if not self.members[slot] then return slot end end
end
function methods:pruneAssemblies(now)
    for seq, a in pairs(self.assemblies) do
        if seq <= self.inSeq or now - a.started > N.ASSEMBLY_TIMEOUT then self.assemblies[seq] = nil end
    end
end
function methods:receiveState(f, now)
    if #f ~= 7 then return false end
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
    self.state, self.inSeq, self.lastSnapshot = state, seq, now
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
    if self.mode ~= "host" and sender ~= self.hostName and text ~= "R2|Q" and string.sub(text, 1, 5) ~= "R2|A|" then return false end
    local now = self.env.now(); local bucket = self.receiveBuckets[sender] or { tokens = 24, time = now }
    self.receiveBuckets[sender] = bucket
    bucket.tokens = math.min(24, bucket.tokens + math.max(0, now - bucket.time) * 16); bucket.time = now
    if bucket.tokens < 1 then return false end; bucket.tokens = bucket.tokens - 1
    local f = split(text, "|"); if f[1] ~= "R2" then return false end
    local kind = f[2]
    if kind == "Q" and #f == 2 then
        if self.mode == "host" and (not self.lastAdvert or now - self.lastAdvert >= 2) then self:advertise() end
        return true
    end
    if not token(f[3]) then return false end
    if kind == "A" then
        local count, spectators = integer(f[5], 1, 25), integer(f[6], 0, 39)
        if #f ~= 6 or not phaseNames[f[4]] or not count or not spectators or count + spectators > 40 then return false end
        if not self.lobbies[sender] then
            local n = 0; for _ in pairs(self.lobbies) do n = n + 1 end; if n >= 8 then return false end
        end
        self.lobbies[sender] = { name = sender, sid = f[3], phase = phaseNames[f[4]], count = count, spectators = spectators, seen = now }
        self:notice(); return true
    end
    if f[3] ~= self.sid then return false end
    if self.mode == "host" then
        if kind == "J" and #f == 5 and token(f[4]) and (f[5] == "p" or f[5] == "s") then
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
                challenge = { token = f[4], generation = self.nextGeneration, role = f[5], created = now }
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
                member.seen = now; return true
            end
            if not gen or not challenge or challenge.token ~= f[4] or challenge.generation ~= gen or now - challenge.created > 60 then return false end
            if not id then for i = 2, 40 do if not self.participants[i] then id = i; break end end end
            if not id then return false end
            local slot = member and member.slot
            if challenge.role == "s" then
                if slot then M.removePlayer(self.state, slot) end; slot = nil
            elseif not slot then slot = freeSlot(self) end
            member = { name = sender, token = f[4], generation = gen, slot = slot, seq = 0, roleSeq = 0, seen = now }
            self.participants[id], self.challenges[sender] = member, nil
            if slot and not self.state.players[slot] then M.addPlayer(self.state, slot) end
            self:changedMember(id); return true
        end
        local id, member = findMember(self, sender)
        if not member or member.token ~= f[4] or integer(f[5], 1, 999999) ~= member.generation then return false end
        if kind == "K" and #f == 5 then member.seen = now; return true end
        if kind == "L" and #f == 5 then self:remove(id); return true end
        if kind == "R" and #f == 7 and (f[7] == "p" or f[7] == "s") then
            local seq = integer(f[6], 1, 999999)
            if not seq or seq < member.roleSeq then return false end
            member.seen = now
            if seq == member.roleSeq then
                if not member.lastRoleReply or now - member.lastRoleReply >= 4 then self:sendMember(id); member.lastRoleReply = now end
                return true
            end
            member.roleSeq = seq
            if f[7] == "s" and member.slot then M.removePlayer(self.state, member.slot); member.slot = nil
            elseif f[7] == "p" and not member.slot then
                member.slot = freeSlot(self); if member.slot then M.addPlayer(self.state, member.slot) end
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
    if (self.mode ~= "client" and self.mode ~= "joining") or sender ~= self.hostName then return false end
    if kind == "E" and #f == 3 then self:reset("Host ended the game. Choose Solo, Host or Join."); return true end
    if kind == "C" and #f == 6 and self.mode == "joining" and f[4] == self.name and f[5] == self.joinToken then
        local gen = integer(f[6], 1, 999999); if not gen or (self.generation and gen < self.generation) then return false end
        self.generation, self.nextJoin = gen, 0; return true
    end
    if kind == "M" and #f == 10 then
        local revision, id = integer(f[4], 1, 999999), integer(f[5], 1, 40)
        local gen, slot, roleSeq = integer(f[8], 0, 999999), integer(f[9], 0, 25), integer(f[10], 0, 999999)
        if not revision or not id or not gen or not slot or not roleSeq or revision <= (self.memberVersions[id] or 0) then return false end
        if f[6] == "-" then
            if f[7] ~= "-" or gen ~= 0 or slot ~= 0 or roleSeq ~= 0 or id == 1 then return false end
        elseif not nameOK(f[6]) or not self.roster[f[6]] or not token(f[7]) or gen < 1
            or (id == 1 and (f[6] ~= self.hostName or slot ~= 1)) or (id ~= 1 and (slot == 1 or f[6] == self.hostName)) then return false end
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
            slot = slot > 0 and slot or nil, roleSeq = roleSeq } or nil
        self:rebuildMembers()
        if f[6] == self.name and f[7] == self.joinToken and gen == self.generation then
            local first = self.mode == "joining"
            self.slot, self.role, self.mode = slot > 0 and slot or nil, slot > 0 and "play" or "spectate", "client"
            self.acceptedRoleSeq, self.ownMemberID = roleSeq, id
            self.lastSnapshot = self.lastSnapshot or now
            if first then self.nextKeepalive = now + 1 + (gen % 40) * 0.15 end
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
    if self.mode == "host" or self.mode == "solo" then
        local oldPhase = self.state.phase; M.tick(self.state, math.min(math.max(elapsed, 0), 0.5))
        if self.mode == "host" then
            if oldPhase ~= "play" and self.state.phase == "play" then if not self:bumpEpoch() then return end end
            for id = 2, 40 do
                if self.participants[id] and now - self.participants[id].seen > 35 then self:remove(id) end
                if self.mode ~= "host" then return end
            end
            for name, c in pairs(self.challenges) do if now - c.created > 60 then self.challenges[name] = nil end end
            if now >= self.nextAdvert then self.nextAdvert = now + 5; self:advertise() end
            if now >= self.nextMember then
                self.nextMember = now + 0.5
                for _ = 1, 40 do
                    local id = self.memberCursor; self.memberCursor = id % 40 + 1
                    if self.memberVersions[id] then self:sendMember(id); break end
                end
            end
            if now >= self.nextSnapshot then self.nextSnapshot = now + N.SNAPSHOT_INTERVAL; self:snapshot() end
        end
    elseif self.mode == "joining" then
        if now - self.joinStarted > 90 then self:reset("Join timed out (40-member capacity, host busy or gone). Find and retry.")
        elseif now >= self.nextJoin then
            self.nextJoin = now + 4
            self:enqueue("join", self.generation and packet("B", self.sid, self.joinToken, self.generation)
                or packet("J", self.sid, self.joinToken, roleCode(self.role)), 2)
        end
    elseif self.mode == "client" then
        if now - (self.lastSnapshot or now) > 20 then self:reset("Host timed out. No migration; find or host a new game.")
        else
            if now >= (self.nextKeepalive or 0) then
                self.nextKeepalive = now + 8; self:enqueue("keepalive", packet("K", self.sid, self.joinToken, self.generation), 1)
            end
            if self.requestedRole and self.roleSeq > self.acceptedRoleSeq and now >= (self.nextRole or 0) then
                self.nextRole = now + 4; self:enqueue("role", packet("R", self.sid, self.joinToken, self.generation, self.roleSeq, roleCode(self.requestedRole)), 2)
            end
        end
    end
    self:flush()
end
