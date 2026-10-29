local N, M = Addon.Protocol, Addon.Model
local function input(c, seq, action, options)
    local o = options or {}
    return table.concat({"R4", "I", o.sid or c.sid, o.token or c.joinToken, o.generation or c.generation,
        seq, o.seen or c.inSeq, o.epoch or c.state._epoch, o.roleSeq or c.acceptedRoleSeq, action}, "|")
end
local function simulation(count, longNames)
    local sim = { time = 0, nodes = {}, pending = {}, sent = {}, roster = {}, serial = 0, maxQueue = 0, maxLag = 0 }
    for i = 1, count do
        local name = "Player" .. i .. "-Realm"
        if longNames then name = name .. string.rep("r", 96 - #name) end
        sim.roster[name] = true
        local serial, node = 0, { name = name, active = true, packets = 0, bytes = 0, wire = 0 }
        node.net = N.new({ name = name, now = function() return sim.time end,
            token = function() serial = serial + 1; return "T" .. i .. "x" .. serial end,
            send = function(payload)
                assert(#payload <= 255, "message exceeds WoW limit")
                node.packets, node.bytes, node.wire = node.packets + 1, node.bytes + #payload, node.wire + #payload + N.WIRE_OVERHEAD
                assert(node.packets <= N.SEND_BURST + sim.time * N.SEND_RATE + 0.01, "packet bucket exceeded")
                assert(node.wire <= N.BYTE_BURST + sim.time * N.BYTE_RATE + 0.01, "byte bucket exceeded")
                sim.serial = sim.serial + 1
                local p = { sender = name, payload = payload, time = sim.time, serial = sim.serial }
                sim.sent[#sim.sent + 1] = p
                -- Deterministic transport jitter gives real packet reordering, not just late assertions.
                p.due = sim.time + (sim.jitter and (sim.serial % 4) * 0.1 or 0)
                sim.pending[#sim.pending + 1] = p
            end })
        sim.nodes[i] = node
    end
    for _, node in ipairs(sim.nodes) do node.net:setRoster(sim.roster, true) end
    function sim:step(seconds, drive)
        for _ = 1, math.ceil(seconds / 0.1 - 0.00001) do
            self.time = self.time + 0.1
            if drive then drive(self) end
            for _, node in ipairs(self.nodes) do
                if node.active then
                    local before = node.net.inSeq; node.net:tick(0.1)
                    self.maxQueue = math.max(self.maxQueue, #node.net.queueOrder)
                    assert(#node.net.queueOrder <= N.MAX_QUEUE)
                    if node.net.mode == "client" and node.net.lastSnapshot then self.maxLag = math.max(self.maxLag, self.time - node.net.lastSnapshot) end
                    local assemblies = 0; for _ in pairs(node.net.assemblies) do assemblies = assemblies + 1 end
                    assert(assemblies <= N.MAX_ASSEMBLIES)
                    if node.net.mode == "client" then assert(node.net.inSeq >= before) end
                end
            end
            local pending = self.pending; self.pending = {}
            for _, p in ipairs(pending) do
                if p.due > self.time + 0.00001 then self.pending[#self.pending + 1] = p
                else
                    for index, node in ipairs(self.nodes) do
                        if node.active and node.name ~= p.sender and not (self.drop and self.drop(p, node, index)) then
                            local before = node.net.inSeq
                            node.net:receive(p.sender, p.payload)
                            if self.duplicates and (p.serial + index) % 29 == 0 then node.net:receive(p.sender, p.payload) end
                            if node.net.mode == "client" then assert(node.net.inSeq >= before, "snapshot regressed") end
                        end
                    end
                end
            end
        end
    end
    function sim:wait(predicate, timeout)
        local deadline = self.time + (timeout or 15)
        while not predicate() and self.time < deadline do self:step(0.1) end
        assert(predicate(), "condition timed out at " .. self.time)
    end
    function sim:connect(index, role)
        local h, c = self.nodes[1].net, self.nodes[index].net
        if not c.lobbies[h.name] then c:discover(); self:wait(function() return c.lobbies[h.name] ~= nil end) end
        assert(c:join(h.name, h.sid, role))
        self:wait(function() return c.mode == "client" and c.state and c.state._revision == h.revision end, 30)
        return c
    end
    function sim:act(index, action)
        self:step(0.3); assert(self.nodes[index].net:action(action)); self:step(1.5)
    end
    assert(sim.nodes[1].net:host()); sim:step(0.5)
    return sim
end
local function deliver(c, h, chunks)
    local accepted
    for _, chunk in ipairs(chunks) do accepted = c:receive(h.name, chunk) end
    return accepted
end
local function worldSame(a, b)
    eq(b.phase, a.phase); eq(b.stage, a.stage); eq(b.boss, a.boss); eq(b.paused, a.paused); eq(b.mode,a.mode)
    eq(b.time, math.ceil(a.time*10-0.00001)/10)
    eq(a.bossMotion ~= nil,b.bossMotion ~= nil)
    if a.bossMotion then
        local p, q = a.bossMotion, b.bossMotion
        eq(q.id,p.id); eq(q.phase,p.phase); eq(q.fromLane,p.fromLane); eq(q.toLane,p.toLane)
        eq(q.remaining,math.ceil(p.remaining*10-0.00001)/10); eq(table.concat(q.lanes,","),table.concat(p.lanes,","))
        assert(math.abs(M.bossPosition(a)-M.bossPosition(b)) <= 0.040001)
    end
    eq(a.hazard ~= nil,b.hazard ~= nil)
    if a.hazard then
        eq(b.hazard.phase,a.hazard.phase); eq(b.hazard.id,a.hazard.id); eq(table.concat(b.hazard.lanes,","),table.concat(a.hazard.lanes,","))
        eq(b.hazard.remaining,math.ceil(a.hazard.remaining*10-0.00001)/10)
    end
    for i = 1, 9 do eq(b.hp[i], a.hp[i] or 0) end
    for slot = 1, 25 do
        local p, q = a.players[slot], b.players[slot]
        eq(p ~= nil, q ~= nil)
        if p then
            eq(q.x,p.x); eq(q.y,p.y); eq(q.score,p.score); eq(q.hit,p.hit); eq(q.hp,p.hp); eq(q.kos,p.kos)
            eq(q.bot,p.bot); eq(q.protected,p.protected); eq(q.ko,math.ceil(p.ko*10-0.00001)/10)
            eq(q.invuln,math.ceil(p.invuln*10-0.00001)/10)
        end
    end
end
check("protocol: R4 opt-in discovery and unchanged public interface", function()
    local sim = simulation(2); local h, c = sim.nodes[1].net, sim.nodes[2].net
    eq(N.VERSION, "R4"); eq(c.mode, "idle"); eq(#c:lobbyList(), 1); assert(not c.state)
    eq(c:lobbyList()[1].spectators, 0)
    for _, old in ipairs({"R1", "R2", "R3"}) do assert(not c:receive(h.name, old.."|Q")); assert(not h:receive(c.name, old.."|Q")) end
    assert(not c:join("Outsider-Realm", h.sid))
    sim:connect(2); eq(h:count(), 2); eq(c.role, "play"); eq(c.members[c.slot].name, c.name)
    assert(not c:start()); assert(not h:setRole("spectate")); eq(h.slot, 1)
end)
check("protocol: actual roster sender, host, session and generated admission identity are mandatory", function()
    local sim = simulation(3); local c = sim:connect(2); local h, other = sim.nodes[1].net, sim.nodes[3].net
    h:start(); sim:step(2)
    local before = c.inSeq; local fake = N.encodeState(h.state, h.sid, before + 50)
    assert(not c:receive(other.name, fake[1])); assert(not c:receive("Stranger-Realm", fake[1])); eq(c.inSeq, before)
    assert(not h:receive("Stranger-Realm", "R4|J|" .. h.sid .. "|x|p|c"))
    for _, o in ipairs({{sid="WRONG"}, {token="WRONG"}, {generation=999999}, {epoch=999999}, {roleSeq=99}}) do
        assert(not h:receive(c.name, input(c, 500, "R", o)))
    end
    assert(not h:receive(other.name, input(c, 500, "R"))); eq(h.state.players[c.slot].x, 1)
    assert(not c.receiveBuckets["Stranger-Realm"])
end)
check("protocol: host challenge prevents replayed old joins and confirmations replacing live identity", function()
    local sim = simulation(2); local c = sim:connect(2); local h = sim.nodes[1].net
    local oldToken, oldGen = c.joinToken, c.generation
    c:leave(); sim:step(1); eq(h:count(), 1); sim:connect(2)
    assert(c.joinToken ~= oldToken and c.generation > oldGen)
    local currentGen = c.generation
    assert(h:receive(c.name, "R4|J|" .. h.sid .. "|" .. oldToken .. "|p|c"))
    assert(not h:receive(c.name, "R4|B|" .. h.sid .. "|" .. oldToken .. "|" .. oldGen))
    assert(not h:receive(c.name, "R4|L|" .. h.sid .. "|" .. oldToken .. "|" .. oldGen))
    eq(h.members[c.slot].generation, currentGen)
end)
check("protocol: duplicate, out-of-order, too-fast, previous stage/replay and future inputs rejected", function()
    local sim = simulation(2); local c = sim:connect(2); local h = sim.nodes[1].net
    h:start(); sim:step(2)
    assert(h:receive(c.name, input(c, 10, "R"))); eq(h.state.players[c.slot].x, 2)
    assert(not h:receive(c.name, input(c, 10, "R"))); assert(not h:receive(c.name, input(c, 9, "R")))
    assert(not h:receive(c.name, input(c, 11, "R"))); eq(h.state.players[c.slot].x, 2)
    sim:step(0.3); assert(h:receive(c.name, input(c, 12, "R"))); eq(h.state.players[c.slot].x, 3)
    local old = input(c, 13, "R"); local seen = c.inSeq
    h.state.phase, h.state.wait = "clear", 0.1; sim:step(2); eq(c.state.stage, 2)
    assert(not h:receive(c.name, old)); assert(not h:receive(c.name, input(c, 14, "R", {seen=seen})))
    assert(not h:receive(c.name, input(c, 14, "R", {seen=h.snapshotSeq+1})))
    old = input(c, 15, "R"); h.state.phase = "victory"; assert(h:start()); sim:step(2)
    assert(not h:receive(c.name, old)); eq(h.state.players[c.slot].x, 1)
end)
check("protocol: bounded chunks assemble atomically under reordering, stale/duplicate and incomplete expiry", function()
    local sim = simulation(2); local c = sim:connect(2); local h = sim.nodes[1].net
    local oldState, seq = c.state, c.inSeq
    local chunks = N.encodeState(h.state, h.sid, seq + 10, h.inputEpoch, h.revision, h.participants)
    eq(#chunks, 3); assert(c:receive(h.name, chunks[3])); assert(c:receive(h.name, chunks[2])); eq(c.state, oldState); eq(c.inSeq, seq)
    assert(not c:receive(h.name, chunks[2])); assert(c:receive(h.name, chunks[1])); eq(c.inSeq, seq + 10)
    assert(not deliver(c, h, chunks)); assert(not deliver(c, h, N.encodeState(h.state, h.sid, seq + 9)))
    for i = 1, 9 do
        sim:step(0.1)
        assert(c:receive(h.name, N.encodeState(h.state, h.sid, seq + 10 + i)[1]))
    end
    local count = 0; for _ in pairs(c.assemblies) do count = count + 1 end; eq(count, N.MAX_ASSEMBLIES)
    sim.nodes[1].active = false; sim:step(N.ASSEMBLY_TIMEOUT + 0.2); assert(not next(c.assemblies))
end)
check("protocol: malformed bounded snapshots never partially replace a world", function()
    local sim = simulation(2); local c = sim:connect(2); local h = sim.nodes[1].net
    local valid = N.encodeState(h.state, h.sid, 999)[1]
    local oldState, seq = c.state, c.inSeq
    local bad = { "R4|S|" .. h.sid .. "|999|3|2|x", "R4|S|" .. h.sid .. "|999|1|9|x", "R4|S|" .. h.sid .. "|1e2|1|1|x",
        "R4|S|" .. h.sid .. "|999|1|1|bad", valid .. "|extra", string.rep("x", 256) }
    for _, text in ipairs(bad) do assert(not c:receive(h.name, text)) end
    local chunks = N.encodeState(h.state, h.sid, 999)
    local parts = {}; for i, chunk in ipairs(chunks) do parts[i] = string.match(chunk, "^R4|S|[^|]+|[^|]+|[^|]+|[^|]+|(.+)$") end
    local body = table.concat(parts)
    assert(N.decodeState(body))
    for _, b in ipairs({body:gsub("^l,1,10,0", "p,5,10,0"), body:gsub("^l,1,10,0", "p,1,99,0"), body:gsub("^l,1,10,0", "p,1,10,2"), body:gsub("000000000", "000090000", 1)}) do
        assert(not N.decodeState(b))
    end
    local prefix, players = string.match(body, "^(.*),([^,]+)$")
    local badPlayers = {"800000002s000000", "110000002s000000", "10zzzz002s000000", "100000zz2s000000", "----------------"}
    for _, p in ipairs(badPlayers) do assert(not N.decodeState(prefix .. "," .. p .. string.sub(players, 17))) end
    assert(not N.decodeState(body .. "x"))
    eq(c.state, oldState); eq(c.inSeq, seq)
end)
check("protocol: spectator late join has world but no avatar, score, action or start; role changes are sequenced", function()
    local sim = simulation(3); local h = sim.nodes[1].net
    h:start(); h.state.stage, h.state.boss, h.state.hp[4], h.state.players[1].score = 3, 14, 0, 745
    local c = sim:connect(2, "spectate")
    eq(c.role, "spectate"); assert(not c.slot); eq(h:count(), 1); eq(h:spectatorCount(), 1)
    eq(c.state.stage, 3); eq(c.state.hp[4], 0); eq(c.state.players[1].score, 745)
    assert(not c:action("R")); assert(not c:start()); assert(not h:receive(c.name, input(c, 1, "R")))
    assert(c:setRole("play")); sim:wait(function() return c.role == "play" end); sim:step(2)
    local slot = c.slot; eq(c.state.players[slot].score, 0)
    local old = input(c, 2, "R")
    assert(c:setRole("spectate")); sim:wait(function() return c.role == "spectate" end); sim:step(2)
    assert(not h.state.players[slot]); assert(not c.state.players[slot]); assert(not h:receive(c.name, old))
    assert(c:setRole("play")); sim:wait(function() return c.role == "play" end); sim:step(2)
    assert(not h:receive(c.name, old)); assert(not h:receive(c.name, "R4|R|" .. h.sid .. "|" .. c.joinToken .. "|" .. c.generation .. "|1|s"))
    eq(c.role, "play")
end)
check("protocol: cooperative damage, dropped snapshot healing and paused shared host", function()
    local sim = simulation(2); local c = sim:connect(2); local h = sim.nodes[1].net
    h:start(); h.state.players[1].invuln, h.state.players[c.slot].invuln = 30, 30
    sim:step(2); sim:act(1, "R"); sim:act(2, "R"); sim:act(1, "P"); sim:act(2, "P")
    eq(h.state.hp[1], 0); eq(c.state.hp[1], 0); eq(c.state.players[1].score, 10); eq(c.state.players[c.slot].score, 10)
    c:setCombat(true); assert(not c:action("R")); c:setCombat(false)
    local old = input(c, 100, "R"); h:setCombat(true); sim:step(2); assert(c.state.paused); assert(not c:action("R"))
    sim:step(36); eq(h:count(), 2); eq(c.mode, "client")
    h:setCombat(false); sim:step(2); assert(not h:receive(c.name, old)); assert(not c.state.paused)
    sim.drop = function(p) return string.sub(p.payload, 1, 4) == "R4|S" end
    assert(h:action("R")); sim:step(3); eq(c.state.players[1].x, 2)
    sim.drop = nil; sim:step(2); eq(c.state.players[1].x, 3)
end)
check("protocol: departures, host loss, stalled snapshots and silent spectator expire without migration", function()
    local sim = simulation(3); local c = sim:connect(2); sim:connect(3, "spectate"); local h = sim.nodes[1].net
    sim.nodes[3].active = false; sim:step(36); eq(h:spectatorCount(), 0)
    c:setRoster({[c.name]=true}, true); eq(c.mode, "idle"); assert(string.find(c.status, "Host left", 1, true))
    h:setRoster({[h.name]=true}, false); eq(h.mode, "idle")
    sim = simulation(2); c = sim:connect(2)
    sim.drop = function(p) return string.sub(p.payload, 1, 4) == "R4|S" end
    sim:step(21); eq(c.mode, "idle"); assert(string.find(c.status, "timed out", 1, true))
    sim = simulation(2); c = sim:connect(2); h = sim.nodes[1].net
    local sid = h.sid; h:leave(); sim:step(1); eq(c.mode, "idle"); assert(h:host()); assert(h.sid ~= sid)
    assert(not h:receive(c.name, "R4|J|" .. sid .. "|old|p|c"))
end)
check("protocol: world presence removes an expired guest even when its removal record is lost", function()
    local sim = simulation(2); local c = sim:connect(2); local h = sim.nodes[1].net
    sim.drop = function(p)
        return p.sender == c.name or string.sub(p.payload, 1, 4) == "R4|M"
    end
    sim:step(38); eq(h:count(),1); eq(c.mode,"idle")
    assert(string.find(c.status,"Removed",1,true))
end)
check("protocol: counter saturation never wraps to replayable generations or sequences", function()
    local sim = simulation(2); local c = sim:connect(2); local h = sim.nodes[1].net
    h:start(); sim:step(2); c.outSeq = 999999; assert(not c:action("R"))
    c.roleSeq = 999999; assert(not c:setRole("spectate"))
    h.snapshotSeq = 999999; h:snapshot(); eq(h.mode,"idle")
    sim:step(1); eq(c.mode,"idle")
end)
check("protocol: lost admission record heals with retries without duplicate membership", function()
    local sim = simulation(2); local h, c = sim.nodes[1].net, sim.nodes[2].net
    sim.drop = function(p) return string.sub(p.payload, 1, 4) == "R4|M" end
    assert(c:join(h.name, h.sid)); sim:step(5); eq(c.mode, "joining"); eq(h:count(), 2)
    sim.drop = nil; sim:wait(function() return c.mode == "client" end); eq(h:count(), 2)
end)
check("protocol: finite byte/message buckets, coalesced input, bounded queues and inbound floods", function()
    local sim = simulation(2); local h, c = sim.nodes[1].net, sim.nodes[2].net
    for i = 1, 200 do h:enqueue("test" .. i, string.rep("x", 255)) end
    eq(#h.queueOrder, N.MAX_QUEUE); assert(not h:enqueue("oversize", string.rep("x", 256)))
    sim:step(4)
    local accepted = 0
    for _ = 1, 1000 do if c:receive(h.name, "R4|Q") then accepted = accepted + 1 end end
    assert(accepted <= 24)
    local s = M.new(); for i = 1, 25 do M.addPlayer(s, i) end; M.start(s)
    s.stage, s.boss, s.time, s.paused = 4, 16, 6046617.5, true
    s.bossMotion = {id=1679615,phase="windup",remaining=7,fromLane=6,toLane=6,lanes={5,6,7}}; M.syncHazard(s)
    local members = {}
    for i = 1, 40 do members[i] = {name=string.rep("n",96),slot=i<=25 and i or nil} end
    for i = 1, 25 do
        local p=s.players[i]; p.x,p.y,p.score,p.hit,p.hp,p.invuln,p.kos,p.protected=6,3,99999,999,100,3,1295,true
    end
    local chunks = N.encodeState(s, string.rep("a",16), 999999, 999999, 999999, members)
    local bytes, body, largest = 0, {}, 0
    for i, p in ipairs(chunks) do assert(#p <= 255); bytes = bytes + #p; largest=math.max(largest,#p)
        body[i]=string.match(p,"^R4|S|[^|]+|[^|]+|[^|]+|[^|]+|(.+)$"); assert(#body[i]<=176) end
    eq(#chunks,3); eq(#table.concat(body),494); assert(N.decodeState(table.concat(body)))
    eq(bytes,593); eq(bytes+#chunks*N.WIRE_OVERHEAD,641); eq(largest,209)
    print(string.format("  Maximum actual R4 world: %d body bytes; %d chunks; %d payload / %d charged bytes; largest packet %d/255", #table.concat(body),#chunks,bytes,bytes+#chunks*N.WIRE_OVERHEAD,largest))
end)
check("protocol: invalid member records, fuzz and bounded expiring advertisements", function()
    local sim = simulation(10); local c = sim:connect(2); local h = sim.nodes[1].net
    assert(not c:receive(h.name, "R4|M|" .. h.sid .. "|999|3|Fake-Realm|x|2|3|0|c"))
    assert(not c:receive(h.name, "R4|M|" .. h.sid .. "|999|41|" .. c.name .. "|x|2|3|0|c"))
    local samples = {"", "R4", "R4|", "R4|I", "R4|M||||||||", "R4|A|x|p|999|0", "R4|S|x|nan", "R1|Q", "R4|J|!|x|p"}
    for _, sample in ipairs(samples) do h:receive(c.name, sample); c:receive(h.name, sample) end
    for i = 1, 100 do sim:step(0.1); h:receive(c.name, "R4|" .. string.rep(string.char(32+i%90), i%240)) end
    eq(h:count(), 2); eq(c.mode, "client")
    for i = 2, 10 do assert(h:receive(sim.nodes[i].name, "R4|A|lobby|l|1|0|c|0") == (i <= 9)) end
    eq(#h:lobbyList(), 8); sim:step(16); eq(#h:lobbyList(), 0)
end)
check("protocol: forty 96-byte-name members join in-progress, role fallback and simultaneous rejoin", function()
    local sim = simulation(40, true); local h = sim.nodes[1].net
    h:start(); h.state.players[1].score = 100; sim:step(2)
    local begun = sim.time
    for i = 2, 40 do assert(sim.nodes[i].net:join(h.name, h.sid)) end
    sim:wait(function()
        for i = 2, 40 do if sim.nodes[i].net.mode ~= "client" then return false end end
        return true
    end, 89)
    local joinTime = sim.time - begun
    eq(h:count(), 25); eq(h:spectatorCount(), 15); sim:step(25)
    local spectator, player
    for i = 2, 40 do
        local c = sim.nodes[i].net
        eq(c:count(), 25); eq(c:spectatorCount(), 15); eq(c.state.players[1].score, 100)
        eq(c:count() + c:spectatorCount(), 40)
        if c.role == "spectate" then spectator = i; assert(not c.slot); assert(string.find(c.status, "full", 1, true)) else player = i end
        for slot = 1, 25 do assert(c.members[slot] and #c.members[slot].name == 96) end
    end
    local watcher, actor = sim.nodes[spectator].net, sim.nodes[player].net
    assert(watcher:setRole("play")); sim:wait(function() return watcher.requestedRole == nil end, 15)
    eq(watcher.role, "spectate"); assert(not watcher:action("P")); assert(not watcher:start())
    assert(actor:setRole("spectate")); sim:wait(function() return actor.role == "spectate" end, 15)
    assert(watcher:setRole("play")); sim:wait(function() return watcher.role == "play" end, 15)
    eq(h:count(), 25); eq(h:spectatorCount(), 15); sim:step(2)
    -- Reload/rejoin while still admitted preserves the host-owned avatar/score,
    -- but requires new host generation. All 39 guests reconnect concurrently.
    local old = {}
    for i = 2, 40 do
        local c = sim.nodes[i].net; old[i] = c.generation
        local role = c.role; c:reset("simulated reload"); assert(c:join(h.name, h.sid, role))
    end
    sim:wait(function()
        for i = 2, 40 do if sim.nodes[i].net.mode ~= "client" then return false end end
        return true
    end, 89)
    h:setCombat(true); sim:step(25)
    for i = 2, 40 do
        local c = sim.nodes[i].net; assert(c.generation > old[i]); eq(c.mode, "client"); worldSame(h.state,c.state)
    end
    eq(h:count(), 25); eq(h:spectatorCount(), 15)
    assert(sim.nodes[1].wire/sim.time <= N.BYTE_RATE); assert(sim.nodes[1].packets/sim.time <= N.SEND_RATE)
    print(string.format("  40 maximum-name members: admission %.1fs; host %.2f msg/s, %.1f payload B/s (%.1f charged B/s); max queue %d, snapshot gap %.1fs", joinTime,
        sim.nodes[1].packets/sim.time,sim.nodes[1].bytes/sim.time,sim.nodes[1].wire/sim.time,sim.maxQueue,sim.maxLag))
end)
check("protocol: sustained real 40-node broadcasts, 25 actors including five AI, 20 spectators, loss/reorder, combat and four shared bosses", function()
    local sim = simulation(40); local h = sim.nodes[1].net
    for _ = 1, 5 do assert(h:addAI()) end; h:start(); sim:step(2)
    for i = 2, 40 do assert(sim.nodes[i].net:join(h.name, h.sid, i > 20 and "spectate" or "play")) end
    sim:wait(function()
        for i = 2, 40 do if sim.nodes[i].net.mode ~= "client" then return false end end; return true
    end, 60)
    sim:step(22)
    eq(h:botCount(),5); eq(h:count(), 25); eq(h:spectatorCount(), 20)
    sim.jitter, sim.duplicates = true, true
    sim.drop = function(p, _, index) return (p.serial * 7 + index * 11) % 23 == 0 end -- 4.35% per-recipient loss
    local startTime, startPackets, startBytes = sim.time, sim.nodes[1].packets, sim.nodes[1].bytes
    local startWire = sim.nodes[1].wire
    local function drive()
        -- Each active client chooses from its own delayed authoritative snapshot.
        -- All 25 operate continuously; no direct state edits/teleports are used.
        for i = 1, 20 do
            local n = sim.nodes[i].net; local s = n.state; local p = s and s.players[n.slot]
            if p and s.phase == "play" and not s.paused then
                local target, floor
                for tower = 1, 3 do
                    for f = 3, 1, -1 do if s.hp[(tower-1)*3+f] > 0 then target, floor = M.TOWERS[tower], f; break end end
                    if target then break end
                end
                local action
                if target then
                    if p.x ~= target then action = p.y > 0 and "D" or (p.x < target and "R" or "L")
                    elseif p.y < floor then action = "U" elseif p.y > floor then action = "D" else action = "P" end
                else
                    if p.y > 0 then action = "D" elseif M.bossInReach(s,p) then action = "P"
                    else action = p.x < M.bossPosition(s) and "R" or "L" end
                end
                n:action(action)
            end
        end
    end
    local pauseDone, deadline, maxStage = false, sim.time + 240, 1
    while h.state.phase ~= "victory" and sim.time < deadline do
        if h.state.stage >= 2 and not pauseDone then
            h:setCombat(true); local stage, boss, total = h.state.stage, h.state.boss, M.total(h.state)
            sim:step(12, drive); eq(h.state.stage,stage); eq(h.state.boss,boss); eq(M.total(h.state),total)
            for i = 2, 40 do assert(sim.nodes[i].net.state.paused); eq(sim.nodes[i].net.mode,"client") end
            h:setCombat(false); pauseDone = true
        end
        sim:step(0.1, drive); maxStage = math.max(maxStage, h.state.stage)
    end
    eq(maxStage, 4); eq(h.state.phase,"victory"); assert(pauseDone)
    -- Keep all 40 connected and drive high-frequency harmless punches/movement
    -- after replay, then settle with zero loss for exact full-world convergence.
    sim:step(4); eq(M.total(h.state),2380)
    for i = 2, 40 do eq(sim.nodes[i].net.mode,"client"); eq(sim.nodes[i].net.state.stage,4) end
    assert(h:start()); sim:step(3)
    sim:step(30, function()
        for i = 1, 20 do local c = sim.nodes[i].net; c:action(math.floor(sim.time*5)%2 == 0 and "R" or "L") end
    end)
    h:setCombat(true); sim.drop, sim.jitter, sim.duplicates = nil, nil, nil; sim:step(25)
    for i = 2, 40 do
        local c = sim.nodes[i].net; eq(c.mode,"client"); worldSame(h.state,c.state)
        eq(c:count(),25); eq(c:spectatorCount(),20)
        if i > 20 then eq(c.role,"spectate"); assert(not c.slot); assert(not c:action("P")) end
    end
    local seconds = sim.time-startTime; local allPackets, allBytes, heartbeats = 0,0,0
    for _, p in ipairs(sim.sent) do
        if p.time >= startTime then
            allPackets, allBytes = allPackets+1,allBytes+#p.payload
            if string.sub(p.payload,1,4) == "R4|K" then heartbeats=heartbeats+1 end
        end
    end
    assert(heartbeats >= 39*math.floor(seconds/8-2), "spectator/player keepalives missing")
    assert((sim.nodes[1].wire-startWire)/seconds <= N.BYTE_RATE)
    assert((sim.nodes[1].packets-startPackets)/seconds <= N.SEND_RATE)
    assert(sim.maxLag < 20, "snapshot starvation under join/input traffic")
    print(string.format("  Sustained %.1fs: host %.2f msg/s, %.1f payload B/s, %.1f charged B/s; group %.2f msg/s, %.1f payload B/s; %d heartbeats; max queue %d; snapshot gap %.1fs", seconds,
        (sim.nodes[1].packets-startPackets)/seconds,(sim.nodes[1].bytes-startBytes)/seconds,(sim.nodes[1].wire-startWire)/seconds,
        allPackets/seconds,allBytes/seconds,heartbeats,sim.maxQueue,sim.maxLag))
end)
check("protocol: solo needs no network and combat never starts it", function()
    local sent = 0
    local n = N.new({name="Solo-Realm", now=function() return 0 end,token=function() return "solo" end,send=function() sent=sent+1 end})
    assert(not n:host()); n:setCombat(true); assert(not n:solo()); n:setCombat(false); assert(n:solo())
    eq(n.role,"play"); eq(n.slot,1); eq(n:spectatorCount(),0); n:tick(1); eq(sent,0)
    n:setRoster({[n.name]=true},false); eq(n.mode,"solo"); n:leave(); eq(sent,0)
end)
check("protocol: explicit modes cannot change midmatch, admission validates advertised choice and R2 is incompatible", function()
    local sim = simulation(2); local h, c = sim.nodes[1].net, sim.nodes[2].net
    eq(h.state.mode, "coop"); assert(not c:receive(h.name, "R2|Q"))
    assert(not c:join(h.name, h.sid, "play", "brawl")); assert(h:setMode("brawl")); sim:step(6)
    eq(c:lobbyList()[1].mode, "brawl"); assert(not c:join(h.name, h.sid, "play", "coop"))
    sim:connect(2); eq(c.state.mode, "brawl"); assert(not c:setMode("coop"))
    assert(h:start()); assert(not h:setMode("coop")); sim:step(2); eq(c.state.mode, "brawl")
    h.state.phase = "victory"; assert(not h:setMode("coop")); eq(h.state.mode,"brawl")
    assert(c:setRole("spectate")); sim:wait(function() return c.role=="spectate" end)
    assert(not h:setMode("coop")) -- spectators consented to the same mode too
    c:leave(); sim:step(1); assert(h:setMode("coop")); assert(h:start())
    local n = N.new({name="Solo-Realm", now=function() return 0 end, token=function() return "solo" end, send=function() error("solo sent") end})
    assert(n:setMode("brawl")); assert(n:solo()); eq(n.state.mode,"brawl"); assert(not n:setMode("coop"))
end)
check("protocol: an admitted Co-op client rejects an unsolicited Brawl world", function()
    local sim=simulation(2); local h=sim.nodes[1].net; local c=sim:connect(2)
    eq(c.expectedMode,"coop")
    -- Bypass normal host setter only to exercise receiving-side fail-closed defense.
    h.state.mode="brawl"; sim:step(2)
    eq(c.mode,"idle"); assert(string.find(c.status,"mode changed",1,true))
end)
check("protocol: bots are host-owned distinct actors, never physical members; oldest bot vacates for humans", function()
    local sim = simulation(26); local h = sim.nodes[1].net
    for _ = 1, 5 do assert(h:addAI()) end
    assert(not h:addAI()); eq(h:botCount(),5); eq(h:count(),6)
    local members = 0; for _ in pairs(h.participants) do members=members+1 end; eq(members,1)
    assert(not h.roster[M.BOT_NAMES[1]]); assert(h.members[2].bot)
    sim:step(6); local c = sim:connect(2,"spectate"); sim:step(2)
    eq(c:botCount(),5); assert(c.members[2].bot); eq(c.members[2].name,M.BOT_NAMES[1])
    assert(not c:addAI()); assert(not c:removeAI()); assert(not c:action("P"))
    assert(not h:receive(M.BOT_NAMES[1],input(c,10,"P")))
    for i = 3, 26 do assert(sim.nodes[i].net:join(h.name,h.sid)) end
    sim:wait(function() for i=3,26 do if sim.nodes[i].net.mode~="client" then return false end end; return true end,70)
    eq(h:count(),25); eq(h:botCount(),0); eq(h:spectatorCount(),1)
    assert(not h:addAI()); assert(not h:removeAI())
    -- Free a real avatar, add a fresh AI, then a human role request evicts it.
    local actor=sim.nodes[3].net; assert(actor:setRole("spectate")); sim:wait(function() return actor.role=="spectate" end)
    assert(h:addAI()); eq(h:botCount(),1)
    assert(c:setRole("play")); sim:wait(function() return c.role=="play" end); eq(h:botCount(),0)
    sim:step(2); assert(not c.state.players[c.slot].bot)
end)
check("protocol: combat notify and roster fallback protect actual guests, reject stale toggles and freeze host clock", function()
    local sim=simulation(2); local c=sim:connect(2); local h=sim.nodes[1].net
    assert(h:start()); sim:step(2); local p=h.state.players[c.slot]; p.invuln=0
    c:setCombat(true); sim:step(0.3); assert(p.protected); assert(not M.damage(h.state,c.slot,35))
    local before=p.hp; sim:step(9); eq(p.hp,before)
    local seq=c.protectionSeq
    assert(not h:receive(c.name,table.concat({"R4","K",h.sid,c.joinToken,c.generation,seq-1,0},"|")))
    assert(not h:receive(c.name,table.concat({"R4","K",h.sid,c.joinToken,c.generation,seq,0},"|")))
    c:setCombat(false); sim:step(0.3); assert(not p.protected)
    assert(h:setMemberCombat(c.name,true)); assert(p.protected); assert(not M.damage(h.state,c.slot,35))
    assert(h:setMemberCombat(c.name,false)); assert(not p.protected)
    h.env.inCombat=function(name) return name==c.name end
    p.protected,p.invuln,p.hp,p.x=false,0,100,2
    h.state.bossMotion={phase="windup",remaining=0.01,lanes={2},id=99,fromLane=5,toLane=5}; M.syncHazard(h.state)
    h:tick(0.05); eq(p.hp,100); assert(p.protected) -- fallback precedes the impact tick
    sim:step(0.1); assert(p.protected)
    local t=h.state.time; h:setCombat(true); sim:step(4); eq(h.state.time,t); eq(c.state.time,math.ceil(t*10-0.00001)/10)
    h:setCombat(false); h.env.inCombat=nil; h:setMemberCombat(c.name,false)
    sim.nodes[2].active=false; sim:step(13); assert(p.protected); sim:step(23); assert(not h.state.players[c.slot])
end)
check("protocol: full R4 snapshot preserves mode, clock, hazard, HP, KOs, immunity, protection and bot identities", function()
    local s=M.new("brawl"); M.addPlayer(s,1); M.addPlayer(s,2,1); M.start(s)
    s.time=123.4; s.players[1].hp=0; s.players[1].ko=3.2; s.players[1].invuln=0; s.players[1].kos=7; s.players[1].protected=true
    s.players[2].hp=65; s.players[2].invuln=0.8
    local chunks=N.encodeState(s,"wire",999999,999999,999999,{ {name="Host-Realm",slot=1} })
    local parts={}; for i,p in ipairs(chunks) do parts[i]=string.match(p,"^R4|S|[^|]+|[^|]+|[^|]+|[^|]+|(.+)$") end
    local q=N.decodeState(table.concat(parts)); assert(q); eq(q.mode,"brawl"); eq(q.time,123.4)
    eq(q.bossMotion.phase,"patrol"); eq(q.bossMotion.remaining,5); eq(q.bossMotion.fromLane,4); eq(q.bossMotion.toLane,5)
    eq(q.hazard.phase,"idle"); eq(q.hazard.remaining,5); eq(#q.hazard.lanes,0)
    eq(q.players[1].hp,0); eq(q.players[1].ko,3.2); eq(q.players[1].kos,7); assert(q.players[1].protected)
    eq(q.players[2].hp,65); eq(q.players[2].invuln,0.8); eq(q.players[2].name,"Pebble Pal"); eq(q._botCount,1)
    local body=table.concat(parts)
    assert(not N.decodeState(body:gsub(",b,",",z,",1)))
    local prefix,players=string.match(body,"^(.*),([^,]+)$")
    local bad=string.sub(players,1,15).."2"..string.sub(players,17) -- mapped host cannot be an AI
    assert(not N.decodeState(prefix..","..bad))
    bad=string.sub(players,1,31).."3"..string.sub(players,33) -- AI cannot claim real combat protection
    assert(not N.decodeState(prefix..","..bad))
end)
check("protocol: a three-second snapshot outage still leaves a visible warning and legal dodge", function()
    local sim=simulation(2); local c=sim:connect(2); local h=sim.nodes[1].net
    assert(h:start()); sim:step(5); eq(h.state.bossMotion.phase,"windup"); local p=h.state.players[c.slot]
    p.x, p.invuln = h.state.hazard.lanes[1], 0
    sim:step(1.5); eq(c.state.hazard.phase,"warning")
    sim.drop=function(packet) return string.sub(packet.payload,1,4)=="R4|S" end
    sim:step(3); eq(p.hp,100)
    sim.drop=nil; sim:step(1.3)
    eq(c.state.hazard.phase,"warning"); assert(c.state.hazard.remaining>=1)
    assert(c:action("R")); sim:step(2); eq(p.hp,100)
end)
local function stateBody(s)
    local chunks, parts = N.encodeState(s,"proof",1,1,1), {}
    for i,p in ipairs(chunks) do parts[i]=string.match(p,"^R4|S|[^|]+|[^|]+|[^|]+|[^|]+|(.+)$") end
    return table.concat(parts)
end
local function withMotion(body, record)
    local fields = {}; for f in string.gmatch(body,"[^,]+") do fields[#fields+1]=f end
    fields[11]=record; return table.concat(fields,",")
end
local function wireBase(n, width)
    local digits, text = "0123456789abcdefghijklmnopqrstuvwxyz", ""
    for _=1,width do local d=n%36; text=string.sub(digits,d+1,d+1)..text; n=math.floor(n/36) end
    return text
end
local function motionRecord(phase, mask, remaining, from, to, id)
    return wireBase(id or 1,4)..phase..wireBase(mask,2)..wireBase(remaining,2)..wireBase(from,1)..wireBase(to,1)
end
check("protocol: R4 round-trips every real boss phase and fractional position without replaying impacts", function()
    for stage=1,4 do
        local s=M.new(); M.addPlayer(s,1); M.start(s)
        s.stage,s.phase,s.wait=stage-1,"clear",0.1; M.tick(s,0.1)
        local function prove(phase)
            eq(s.bossMotion.phase,phase)
            local health=s.players[1].hp
            local q=N.decodeState(stateBody(s)); assert(q); worldSame(s,q)
            assert(math.abs(M.bossPosition(q)-M.bossPosition(s))<0.000001)
            eq(q.players[1].hp,health); eq(M.bossAttackKind(q),stage==3 and "ground" or "ranged")
            local again=N.decodeState(stateBody(q)); assert(again); eq(again.players[1].hp,health)
        end
        M.tick(s,2.3); prove("patrol")
        M.tick(s,2.7); M.tick(s,1.3); prove("windup")
        M.tick(s,5); M.tick(s,0.7); prove("attack")
        M.tick(s,0.5); M.tick(s,2.1); prove("recover")
    end
end)
check("protocol: strict R4 phase clocks, routes, lane masks and stage-derived ground kind reject malformed worlds", function()
    local s=M.new(); M.addPlayer(s,1); M.start(s); local body=stateBody(s)
    local bad={
        "-", "0001w0105", motionRecord("x",0,50,4,5), motionRecord("p",0,50,4,5,0),
        motionRecord("p",0,0,4,5), motionRecord("p",0,51,4,5), motionRecord("p",1,50,4,5),
        motionRecord("p",0,50,1,2), motionRecord("p",0,50,6,7), motionRecord("p",0,50,2,6),
        motionRecord("p",0,50,4,4), motionRecord("w",0,70,5,5), motionRecord("w",1,71,5,5),
        motionRecord("w",3,70,5,5), motionRecord("w",1,70,4,5), motionRecord("a",1,6,5,5),
        motionRecord("a",1,0,5,5), motionRecord("a",1,5,4,5), motionRecord("r",1,50,5,5),
        motionRecord("r",0,51,5,5), motionRecord("r",0,50,4,5), motionRecord("w",128,70,5,5)
    }
    for _,record in ipairs(bad) do assert(not N.decodeState(withMotion(body,record)),"accepted malformed record "..record) end
    assert(N.decodeState(withMotion(body,motionRecord("w",64,70,5,5))))
    assert(N.decodeState(withMotion(body,motionRecord("a",1,5,5,5))))
    assert(N.decodeState(withMotion(body,motionRecord("r",0,50,5,5))))
    for stage=2,4 do
        s.stage,s.boss=stage,8+stage*2; body=stateBody(s)
        if stage==2 then
            assert(not N.decodeState(withMotion(body,motionRecord("p",0,50,4,5))))
            assert(not N.decodeState(withMotion(body,motionRecord("w",5,70,4,4)))) -- separated columns
            assert(N.decodeState(withMotion(body,motionRecord("w",3,70,4,4))))
        elseif stage==3 then
            assert(N.decodeState(withMotion(body,motionRecord("p",0,50,4,4)))) -- pursuit can settle
            assert(not N.decodeState(withMotion(body,motionRecord("p",0,50,4,6))))
            assert(not N.decodeState(withMotion(body,motionRecord("w",7,70,4,4)))) -- not origin +/-1
            assert(N.decodeState(withMotion(body,motionRecord("w",28,70,4,4))))
        else
            assert(not N.decodeState(withMotion(body,motionRecord("p",0,50,4,6,1))))
            assert(N.decodeState(withMotion(body,motionRecord("p",0,50,4,6,2))))
            assert(not N.decodeState(withMotion(body,motionRecord("w",11,70,4,4))))
            assert(not N.decodeState(withMotion(body,motionRecord("w",15,70,4,4)))) -- too many columns
            assert(N.decodeState(withMotion(body,motionRecord("w",7,70,4,4))))
        end
    end
    s.phase="lobby"; body=stateBody(s)
    assert(not N.decodeState(withMotion(body,motionRecord("w",7,70,4,4))))
end)
check("protocol: mid-patrol late join reconstructs position; invalid new-phase snapshot cannot replace a valid world", function()
    local sim=simulation(2); local h=sim.nodes[1].net
    assert(h:start()); sim:step(2.3); h:setCombat(true)
    local c=sim:connect(2); sim:step(2); eq(c.state.bossMotion.phase,"patrol")
    worldSame(h.state,c.state); assert(math.abs(M.bossPosition(h.state)-M.bossPosition(c.state))<0.000001)
    eq(M.bossPosition(c.state,999),M.bossPosition(c.state)) -- pause freezes smoothing too
    local old, seq=c.state,c.inSeq
    local malformed=withMotion(stateBody(h.state),motionRecord("a",1,5,4,5)) -- attack cannot move
    local chunks={}; local total=math.ceil(#malformed/N.CHUNK_BYTES)
    for i=1,total do chunks[i]=table.concat({"R4","S",h.sid,seq+20,i,total,string.sub(malformed,(i-1)*N.CHUNK_BYTES+1,i*N.CHUNK_BYTES)},"|") end
    assert(not deliver(c,h,chunks)); eq(c.state,old); eq(c.inSeq,seq)
    h.state.bossMotion={id=3,phase="attack",remaining=0.4,fromLane=5,toLane=5,lanes={1}}
    h.state.players[1].hp=65; M.syncHazard(h.state)
    chunks=N.encodeState(h.state,h.sid,seq+21,h.inputEpoch,h.revision,h.participants)
    assert(deliver(c,h,chunks)); eq(c.state.players[1].hp,65)
    assert(not deliver(c,h,chunks)); eq(c.state.players[1].hp,65)
    assert(deliver(c,h,N.encodeState(h.state,h.sid,seq+22,h.inputEpoch,h.revision,h.participants)))
    c:tick(0.5); eq(c.state.players[1].hp,65); eq(c.state.bossMotion.remaining,0.4)
end)
