local N, M = Addon.Protocol, Addon.Model
local function input(c, seq, action, options)
    local o = options or {}
    return table.concat({"R6", "I", o.sid or c.sid, o.token or c.joinToken, o.generation or c.generation,
        seq, o.seen or c.inSeq, o.epoch or c.state._epoch, o.roleSeq or c.acceptedRoleSeq, action, o.term or c.term}, "|")
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
                p.due = sim.time + (sim.latency or 0) + (sim.jitter and (sim.serial % 4) * 0.1 or 0)
                sim.pending[#sim.pending + 1] = p
            end })
        sim.nodes[i] = node
    end
    for _, node in ipairs(sim.nodes) do node.net:setRoster(sim.roster, true) end
    function sim:step(seconds, drive)
        local dt = self.dt or 0.1
        for _ = 1, math.ceil(seconds / dt - 0.00001) do
            self.time = self.time + dt
            if drive then drive(self) end
            for _, node in ipairs(self.nodes) do
                if node.active then
                    local before, term = node.net.inSeq, node.net.term; node.net:tick(dt)
                    self.maxQueue = math.max(self.maxQueue, #node.net.queueOrder)
                    assert(#node.net.queueOrder <= N.MAX_QUEUE)
                    if node.net.mode == "client" and node.net.lastSnapshot then self.maxLag = math.max(self.maxLag, self.time - node.net.lastSnapshot) end
                    local assemblies = 0; for _ in pairs(node.net.assemblies) do assemblies = assemblies + 1 end
                    assert(assemblies <= N.MAX_ASSEMBLIES)
                    if node.net.mode == "client" and node.net.term==term then assert(node.net.inSeq >= before) end
                    local recovery=0; for _ in pairs(node.net.checkpointAssemblies or {}) do recovery=recovery+1 end; assert(recovery<=2)
                    for field,cap in pairs({configAcks=80,withdrawn=40,incarnations=40}) do
                        local count=0; for _ in pairs(node.net[field] or {}) do count=count+1 end; assert(count<=cap,field.." unbounded")
                    end
                end
            end
            local pending = self.pending; self.pending = {}
            for _, p in ipairs(pending) do
                if p.due > self.time + 0.00001 then self.pending[#self.pending + 1] = p
                else
                    for index, node in ipairs(self.nodes) do
                        if node.active and node.name ~= p.sender and not (self.drop and self.drop(p, node, index)) then
                            local before, term = node.net.inSeq, node.net.term
                            node.net:receive(p.sender, p.payload)
                            if self.duplicates and (p.serial + index) % 29 == 0 then node.net:receive(p.sender, p.payload) end
                            if node.net.mode == "client" and node.net.term==term then assert(node.net.inSeq >= before, "snapshot regressed within term") end
                        end
                    end
                end
            end
        end
    end
    function sim:wait(predicate, timeout)
        local deadline = self.time + (timeout or 15)
        while not predicate() and self.time < deadline do self:step(0.1) end
        if not predicate() then
            local h=self.nodes[1].net
            print("  Timeout diagnostics",h.mode,h.revision,h.configRevision,h.membershipPending,h.leasePaused,#h.queueOrder)
            for i,n in ipairs(self.nodes) do if n.net.mode~="client" then print("  node",i,n.net.mode,n.net.status,n.net.generation,n.net.electionFloor) end end
        end
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
        assert(math.abs(M.bossPosition(a)-M.bossPosition(b)) <= 0.067001)
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
check("protocol: R6 opt-in discovery and unchanged public interface", function()
    local sim = simulation(2); local h, c = sim.nodes[1].net, sim.nodes[2].net
    eq(N.VERSION, "R6"); eq(c.mode, "idle"); eq(#c:lobbyList(), 1); assert(not c.state)
    eq(c:lobbyList()[1].spectators, 0)
    for _, old in ipairs({"R1", "R2", "R3", "R4", "R5"}) do assert(not c:receive(h.name, old.."|Q")); assert(not h:receive(c.name, old.."|Q")) end
    assert(not c:join("Outsider-Realm", h.sid))
    sim:connect(2); eq(h:count(), 2); eq(c.role, "play"); eq(c.members[c.slot].name, c.name)
    assert(not c:start()); assert(h:setRole("spectate")); assert(not h.slot); eq(h.role,"spectate")
end)
check("protocol: actual roster sender, host, session and generated admission identity are mandatory", function()
    local sim = simulation(3); local c = sim:connect(2); local h, other = sim.nodes[1].net, sim.nodes[3].net
    h:start(); sim:step(2)
    local before = c.inSeq; local fake = N.encodeState(h.state, h.sid, before + 50)
    assert(not c:receive(other.name, fake[1])); assert(not c:receive("Stranger-Realm", fake[1])); eq(c.inSeq, before)
    assert(not h:receive("Stranger-Realm", "R6|J|" .. h.sid .. "|x|p|c"))
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
    assert(h:receive(c.name, "R6|J|" .. h.sid .. "|" .. oldToken .. "|p|c|1"))
    assert(not h:receive(c.name, "R6|B|" .. h.sid .. "|" .. oldToken .. "|" .. oldGen .. "|1"))
    assert(not h:receive(c.name, "R6|L|" .. h.sid .. "|" .. oldToken .. "|" .. oldGen .. "|1|1"))
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
    local bad = { "R6|S|" .. h.sid .. "|999|3|2|x|1", "R6|S|" .. h.sid .. "|999|1|9|x|1", "R6|S|" .. h.sid .. "|1e2|1|1|x|1",
        "R6|S|" .. h.sid .. "|999|1|1|bad|1", valid .. "|extra", string.rep("x", 256) }
    for _, text in ipairs(bad) do assert(not c:receive(h.name, text)) end
    local chunks = N.encodeState(h.state, h.sid, 999)
    local parts = {}; for i, chunk in ipairs(chunks) do parts[i] = string.match(chunk, "^R6|S|[^|]+|[^|]+|[^|]+|[^|]+|(.+)|[^|]+$") end
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
    assert(not h:receive(c.name, old)); assert(not h:receive(c.name, "R6|R|" .. h.sid .. "|" .. c.joinToken .. "|" .. c.generation .. "|1|s|1"))
    eq(c.role, "play")
end)
check("protocol: cooperative damage, dropped snapshot healing and paused shared host", function()
    local sim = simulation(2); local c = sim:connect(2); local h = sim.nodes[1].net
    h:start(); h.state.players[1].invuln, h.state.players[c.slot].invuln = 3, 3
    -- Cooperate before the new first impact at6s; the old sequential
    --1.8s-per-input helper let a boss knock one actor away before its punch.
    sim:step(2); assert(h:action("R")); assert(c:action("R")); sim:step(0.3)
    assert(h:action("P")); assert(c:action("P")); sim:step(1.5)
    eq(h.state.hp[1], 0); eq(c.state.hp[1], 0); eq(c.state.players[1].score, 10); eq(c.state.players[c.slot].score, 10)
    c:setCombat(true); assert(not c:action("R")); c:setCombat(false)
    local old = input(c, 100, "R"); h:setCombat(true); sim:step(2); assert(c.state.paused); assert(not c:action("R"))
    sim:step(36); eq(h:count(), 2); eq(c.mode, "client")
    h:setCombat(false); sim:step(2); assert(not h:receive(c.name, old)); assert(not c.state.paused)
    sim.drop = function(p) return string.sub(p.payload, 1, 4) == "R6|S" end
    local beforeMove=c.state.players[1].x
    assert(h:action("R")); sim:step(3); eq(c.state.players[1].x, beforeMove)
    sim.drop = nil; sim:step(2); eq(c.state.players[1].x, h.state.players[1].x)
end)
check("protocol: departures, host loss and stalled snapshots pause for evidence; silent spectators expire", function()
    local sim = simulation(3); local c = sim:connect(2); sim:connect(3, "spectate"); local h = sim.nodes[1].net
    sim.nodes[3].active = false; sim:step(36); eq(h:spectatorCount(), 0)
    c:setRoster({[c.name]=true}, true); eq(c.mode, "client"); assert(c.migration and c.state.paused)
    h:setRoster({[h.name]=true}, false); eq(h.mode, "idle")
    sim = simulation(2); c = sim:connect(2)
    sim.drop = function(p) return string.sub(p.payload, 1, 4) == "R6|S" end
    sim:step(21); eq(c.mode, "client"); assert(c.migration and c.state.paused)
    sim = simulation(2); c = sim:connect(2); h = sim.nodes[1].net
    local sid = h.sid; h:leave(); assert(h.leaving); sim:step(12); eq(c.mode, "host"); eq(h.mode,"idle"); assert(h:host()); assert(h.sid ~= sid)
    assert(not h:receive(c.name, "R6|J|" .. sid .. "|old|p|c"))
end)
check("protocol: world presence removes an expired guest even when its removal record is lost", function()
    local sim = simulation(3); local c = sim:connect(2); sim:connect(3); local h = sim.nodes[1].net
    sim.drop = function(p)
        return p.sender == c.name or string.sub(p.payload, 1, 4) == "R6|M"
    end
    sim:step(38); eq(h:count(),2); eq(c.mode,"idle")
    assert(string.find(c.status,"Removed",1,true))
end)
check("protocol: counter saturation never wraps to replayable generations or sequences", function()
    local sim = simulation(2); local c = sim:connect(2); local h = sim.nodes[1].net
    h:start(); sim:step(2); c.outSeq = 999999; assert(not c:action("R"))
    c.roleSeq = 999999; assert(not c:setRole("spectate"))
    h.snapshotSeq = 999999; h:snapshot(); eq(h.mode,"idle")
    sim:step(21); assert(c.migration and c.state.paused)
end)
check("protocol: lost admission record heals with retries without duplicate membership", function()
    local sim = simulation(2); local h, c = sim.nodes[1].net, sim.nodes[2].net
    sim.drop = function(p) return string.sub(p.payload, 1, 4) == "R6|M" end
    assert(c:join(h.name, h.sid)); sim:step(5); eq(c.mode, "joining"); eq(h:count(), 2)
    sim.drop = nil; sim:wait(function() return c.mode == "client" end); eq(h:count(), 2)
end)
check("protocol: finite byte/message buckets, coalesced input, bounded queues and inbound floods", function()
    local sim = simulation(2); local h, c = sim.nodes[1].net, sim.nodes[2].net
    for i = 1, 200 do h:enqueue("test" .. i, string.rep("x", 255)) end
    eq(#h.queueOrder, N.MAX_QUEUE); assert(not h:enqueue("oversize", string.rep("x", 256)))
    sim:step(4)
    local accepted = 0
    for _ = 1, 1000 do if c:receive(h.name, "R6|Q") then accepted = accepted + 1 end end
    assert(accepted <= 24)
    local s = M.new(); for i = 1, 25 do M.addPlayer(s, i) end; M.start(s)
    s.stage, s.boss, s.time, s.paused = 4, 16, 6046617.5, true
    s.bossMotion = {id=1679615,phase="windup",remaining=3,fromLane=6,toLane=6,lanes={5,6,7}}; M.syncHazard(s)
    local members = {}
    for i = 1, 40 do members[i] = {name=string.rep("n",96),slot=i<=25 and i or nil} end
    for i = 1, 25 do
        local p=s.players[i]; p.x,p.y,p.score,p.hit,p.hp,p.invuln,p.kos,p.protected=6,3,99999,999,100,3,1295,true
    end
    local chunks = N.encodeState(s, string.rep("a",16), 999999, 999999, 999999, members, 999999)
    local bytes, body, largest = 0, {}, 0
    for i, p in ipairs(chunks) do assert(#p <= 255); bytes = bytes + #p; largest=math.max(largest,#p)
        body[i]=string.match(p,"^R6|S|[^|]+|[^|]+|[^|]+|[^|]+|(.+)|[^|]+$"); assert(#body[i]<=176) end
    eq(#chunks,3); eq(#table.concat(body),494); assert(N.decodeState(table.concat(body)))
    eq(bytes,614); eq(bytes+#chunks*N.WIRE_OVERHEAD,662); eq(largest,216)
    print(string.format("  Maximum actual R6 world: %d body bytes; %d chunks; %d payload / %d charged bytes; largest packet %d/255", #table.concat(body),#chunks,bytes,bytes+#chunks*N.WIRE_OVERHEAD,largest))
end)
check("protocol: invalid member records, fuzz and bounded expiring advertisements", function()
    local sim = simulation(10); local c = sim:connect(2); local h = sim.nodes[1].net
    assert(not c:receive(h.name, "R6|M|" .. h.sid .. "|999|3|Fake-Realm|x|2|3|0|c|3|1"))
    assert(not c:receive(h.name, "R6|M|" .. h.sid .. "|999|41|" .. c.name .. "|x|2|3|0|c|3|1"))
    local samples = {"", "R6", "R6|", "R6|I", "R6|M||||||||", "R6|A|x|p|999|0", "R6|S|x|nan", "R1|Q", "R6|J|!|x|p"}
    for _, sample in ipairs(samples) do h:receive(c.name, sample); c:receive(h.name, sample) end
    for i = 1, 100 do sim:step(0.1); h:receive(c.name, "R6|" .. string.rep(string.char(32+i%90), i%240)) end
    eq(h:count(), 2); eq(c.mode, "client")
    for i = 2, 10 do assert(h:receive(sim.nodes[i].name, "R6|A|lobby|l|1|0|c|0|1") == (i <= 9)) end
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
    assert(sim.nodes[1].wire <= N.BYTE_RATE*sim.time+N.BYTE_BURST); assert(sim.nodes[1].packets <= N.SEND_RATE*sim.time+N.SEND_BURST)
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
    -- Distinct AI can finish while forty nodes are still settling admission.
    -- Start a real replay so the sustained loss fixture observes all four bosses
    -- with the full population, not a victory that occurred before this phase.
    sim:wait(function() return h.state.phase=="victory" end,240)
    assert(h:start()); sim:step(2)
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
    if maxStage~=4 then
        print("  Gameplay diagnostics",h.mode,h.state.phase,h.state.time,h.state.paused,h.leasePaused,h.membershipPending,h.revision,h.configRevision,h.inputEpoch,h.status)
        for id,m in pairs(h.participants) do if id~=h.ownMemberID then local a=h.configAcks[m.name]; print("  member",id,m.generation,m.seen,m.leaseUntil,a and a.revision) end end
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
            if string.sub(p.payload,1,4) == "R6|K" then heartbeats=heartbeats+1 end
        end
    end
    assert(heartbeats >= 39*math.floor(seconds/8-2), "spectator/player keepalives missing")
    assert(sim.nodes[1].wire-startWire <= N.BYTE_RATE*seconds+N.BYTE_BURST)
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
    assert(not h:receive(c.name,table.concat({"R6","K",h.sid,c.joinToken,c.generation,seq-1,0,(c.keepaliveSeq or 0)+1,c.inSeq,h.term},"|")))
    assert(not h:receive(c.name,table.concat({"R6","K",h.sid,c.joinToken,c.generation,seq,0,(c.keepaliveSeq or 0)+1,c.inSeq,h.term},"|")))
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
    sim.nodes[2].active=false; sim:step(13); assert(p.protected); sim:step(23); assert(h.state.paused and h.leasePaused)
    assert(h.state.players[c.slot]) -- cannot evict the only peer to evade a partition lease
end)
check("protocol: full R6 snapshot preserves mode, clock, hazard, HP, KOs, immunity, protection and bot identities", function()
    local s=M.new("brawl"); M.addPlayer(s,1); M.addPlayer(s,2,1); M.start(s)
    s.time=123.4; s.players[1].hp=0; s.players[1].ko=3.2; s.players[1].invuln=0; s.players[1].kos=7; s.players[1].protected=true
    s.players[2].hp=65; s.players[2].invuln=0.8
    local chunks=N.encodeState(s,"wire",999999,999999,999999,{ {name="Host-Realm",slot=1} })
    local parts={}; for i,p in ipairs(chunks) do parts[i]=string.match(p,"^R6|S|[^|]+|[^|]+|[^|]+|[^|]+|(.+)|[^|]+$") end
    local q=N.decodeState(table.concat(parts)); assert(q); eq(q.mode,"brawl"); eq(q.time,123.4)
    eq(q.bossMotion.phase,"patrol"); eq(q.bossMotion.remaining,3); eq(q.bossMotion.fromLane,4); eq(q.bossMotion.toLane,5)
    eq(q.hazard.phase,"idle"); eq(q.hazard.remaining,3); eq(#q.hazard.lanes,0)
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
check("protocol: short-warning blackout longer than windup cannot promise a visible dodge and never replays damage", function()
    local sim=simulation(2); local c=sim:connect(2); local h=sim.nodes[1].net
    sim:step(2); assert(h:start()); sim:step(2.5)
    local p=h.state.players[c.slot]; p.x,p.y,p.invuln=4,0,0; h.state.players[h.slot].x=7
    sim.drop=function(packet) return string.sub(packet.payload,1,4)=="R6|S" end
    sim:step(0.5); eq(h.state.bossMotion.phase,"windup"); eq(h.state.hazard.remaining,3)
    sim:step(3); eq(p.hp,65); assert(c.state.bossMotion.phase~="windup")
    sim.drop=nil; sim:step(1.5); eq(c.state.players[c.slot].hp,65)
    sim:step(1.5); eq(p.hp,65); eq(c.state.players[c.slot].hp,65)
end)
check("protocol: short-warning healthy two-client real-input dodges include reaction and snapshot phase delays", function()
    local cases, failures, maxNotice, minMargin, maxActions = 0, 0, 0, 99, 0
    for stage=1,4 do for _,height in ipairs({0,3}) do
        for _,reaction in ipairs({0.5,0.75}) do for _,offset in ipairs({0,0.3,0.6,0.9,1.2}) do
            local sim=simulation(2); local c=sim:connect(2); local h=sim.nodes[1].net
            sim:step(2); assert(h:start()); sim:step(0.5)
            -- Legal staged scene, then actual host patrol->warning. Never inject
            -- a warning directly into the receiving client or bypass its input.
            h.state.stage,h.state.phase,h.state.wait=stage-1,"clear",0.1
            sim:step(0.1); local p=h.state.players[c.slot]
            p.x,p.y,p.invuln=4,height,0; h.state.players[h.slot].x=7
            sim.latency,sim.dt=0.1,0.05 -- 200ms RTT,20fps update granularity, no loss.
            sim:step(2.8); eq(h.state.bossMotion.phase,"patrol")
            h.nextSnapshot=sim.time+0.2+offset
            local started,noticed,plan,nextAction,completed,impacted
            local function threatened(state,x,y)
                if state.stage==3 and y>0 then return false end
                for _,lane in ipairs(state.hazard.lanes) do if lane==x then return true end end
                return false
            end
            for _=1,84 do
                sim:step(0.05)
                if not started and h.state.bossMotion.phase=="windup" then started=sim.time end
                if started and not noticed and c.state.bossMotion.phase=="windup" and c.state.stage==stage then
                    noticed=sim.time; maxNotice=math.max(maxNotice,noticed-started)
                    local q=c.state.players[c.slot]; plan={}
                    if threatened(c.state,q.x,q.y) then
                        local target,distance
                        for lane=1,7 do
                            if not threatened(c.state,lane,0) and (not distance or math.abs(lane-q.x)<distance) then target,distance=lane,math.abs(lane-q.x) end
                        end
                        for _=1,q.y do plan[#plan+1]="D" end
                        for _=1,distance do plan[#plan+1]=target<q.x and "L" or "R" end
                    end
                    maxActions=math.max(maxActions,#plan); nextAction=noticed+reaction
                end
                if plan and #plan>0 and sim.time+0.00001>=nextAction then
                    assert(c:action(table.remove(plan,1)),"real client rejected scheduled dodge")
                    nextAction=sim.time+0.25 --205ms real keyboard repeat rounded to20fps; legal, not teleport.
                end
                if started and not completed and h.state.bossMotion.phase=="windup" and not threatened(h.state,p.x,p.y) then completed=sim.time end
                if started and h.state.bossMotion.phase=="attack" then impacted=true; break end
            end
            assert(started and noticed and impacted,"healthy client never observed warning/impact")
            cases=cases+1
            local margin=completed and (started+3-completed) or -1
            minMargin=math.min(minMargin,margin)
            if p.hp~=100 then failures=failures+1; print(string.format("  Dodge miss stage%d y%d reaction%.2f offset%.1f notice%.1f margin%.1f",stage,height,reaction,offset,noticed-started,margin)) end
        end end
    end end
    print(string.format("  Healthy 200ms RTT: %d real-client cases, %d hits, notice<=%.1fs, escape margin>=%.1fs, at most%d actions; reaction0.5/0.75s",cases,failures,maxNotice,minMargin,maxActions))
    eq(failures,0,"healthy phase-varied human dodge must be possible")
end)
local function stateBody(s)
    local chunks, parts = N.encodeState(s,"proof",1,1,1), {}
    for i,p in ipairs(chunks) do parts[i]=string.match(p,"^R6|S|[^|]+|[^|]+|[^|]+|[^|]+|(.+)|[^|]+$") end
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

local function committedRoom(sim, indices, timeout)
    local h=sim.nodes[1].net
    -- Capture AFTER all admissions, and wait for a COMPLETE host-committed
    -- checkpoint on every requested peer, never patch a client roster by hand.
    h.checkpointSend=nil; h.nextCheckpoint=sim.time
    sim:wait(function()
        local cp=h.committed
        if not cp or cp.revision~=h.revision then return false end
        for _,i in ipairs(indices) do
            local c=sim.nodes[i].net
            if not c.committed or c.committed.id~=cp.id or c.committed.hash~=cp.hash then return false end
        end
        return true
    end,timeout or 90)
    return h.committed
end
local function frozenEqual(expected, actual, departed)
    eq(actual.phase,expected.phase); eq(actual.stage,expected.stage); eq(actual.boss,expected.boss)
    assert(math.abs(actual.time-expected.time)<0.000001); eq(actual.wait,expected.wait)
    eq(actual.bossDirection,expected.bossDirection); eq(actual.hazardID,expected.hazardID)
    for i=1,9 do eq(actual.hp[i],expected.hp[i]) end
    if expected.bossMotion then
        for _,key in ipairs({"id","phase","fromLane","toLane"}) do eq(actual.bossMotion[key],expected.bossMotion[key]) end
        assert(math.abs(actual.bossMotion.remaining-expected.bossMotion.remaining)<0.000001)
        eq(table.concat(actual.bossMotion.lanes,","),table.concat(expected.bossMotion.lanes,","))
    end
    for slot,p in pairs(expected.players) do
        if slot~=departed then
            local q=actual.players[slot]; assert(q)
            for _,key in ipairs({"x","y","score","hit","hp","kos","bot","botID","nextAction","nextPunch","nextBot"}) do
                if type(p[key])=="number" then assert(math.abs((q[key] or -99)-p[key])<0.000001,key) else eq(q[key],p[key],key) end
            end
            assert(math.abs(q.ko-p.ko)<0.000001); assert(math.abs(q.invuln-p.invuln)<0.000001)
        else assert(not actual.players[slot]) end
    end
end
check("migration: graceful active succession preserves exact world, timers, AI, identity and ordinals",function()
    local sim=simulation(4); local h=sim.nodes[1].net
    local c=sim:connect(2); sim:connect(3,"spectate"); sim:connect(4)
    assert(h:addAI()); assert(h:addAI()); assert(h:start()); sim:step(5)
    local slot,id,joined=c.slot,c.ownMemberID,h.participants[c.ownMemberID].joined
    h.state.players[slot].score,h.state.players[slot].kos=321,4
    h.state.players[slot].hp,h.state.players[slot].ko,h.state.players[slot].invuln=0,2.345,0
    c:setCombat(true); sim:step(0.3)
    local oldEpoch=h.inputEpoch; local begun=sim.time
    assert(h:leave()); assert(h.leaving and h.migration and h.state.paused)
    local cp=h.checkpointSend; assert(cp and cp.participants[id].joined==joined)
    local frozen=cp.state
    sim:wait(function() return c.mode=="host" and h.mode=="idle" end,35)
    eq(c.term,2); eq(c.ownMemberID,id); eq(c.slot,slot); eq(c.role,"play"); eq(c:botCount(),2)
    eq(c.participants[id].joined,joined); assert(c.inputEpoch>oldEpoch); assert(c.state.paused)
    frozenEqual(frozen,c.state,1)
    for _,i in ipairs({3,4}) do eq(sim.nodes[i].net.hostName,c.name); eq(sim.nodes[i].net.term,2) end
    c:setCombat(false); sim:step(2); assert(not c.state.paused); assert(c.state.time>frozen.time)
    print(string.format("  Graceful checkpoint %d bytes / %d chunks; handoff %.1fs",#cp.body,cp.total,sim.time-begun-2))
end)
check("migration: oldest spectator becomes host without avatar, can change role, old host rejoins newest",function()
    local sim=simulation(3); local h=sim.nodes[1].net; local c=sim:connect(2,"spectate"); local d=sim:connect(3)
    local ordinal=h.participants[c.ownMemberID].joined
    assert(h:setRole("spectate")); assert(not h.slot); eq(h:spectatorCount(),2)
    assert(h:leave()); sim:wait(function() return c.mode=="host" and h.mode=="idle" end,35)
    eq(c.role,"spectate"); assert(not c.slot); eq(c.ownMemberID,2); eq(c:spectatorCount(),1)
    eq(c.participants[c.ownMemberID].joined,ordinal); assert(not c:action("P"))
    assert(c:setRole("play")); assert(c.slot); eq(c.participants[c.ownMemberID].joined,ordinal)
    assert(c:setRole("spectate")); assert(not c.slot); eq(c.participants[c.ownMemberID].joined,ordinal)
    h:discover(); sim:wait(function() return h.lobbies[c.name]~=nil end)
    assert(h:join(c.name,c.sid,"spectate")); sim:wait(function() return h.mode=="client" end,30)
    assert(c.participants[h.ownMemberID].joined>c.participants[d.ownMemberID].joined)
    eq(c:successor(),d.ownMemberID); eq(h.term,2)
end)
check("migration: unexpected loss uses complete committed state; spectator and combat host pause",function()
    local sim=simulation(4); local h=sim.nodes[1].net; local c=sim:connect(2,"spectate")
    sim:connect(3); sim:connect(4); assert(h:addAI()); assert(h:start()); sim:step(4)
    c:setCombat(true); sim:step(0.5)
    local cp=committedRoom(sim,{2,3,4}); local begun=sim.time
    sim.nodes[1].active=false
    sim:wait(function() return c.mode=="host" end,40)
    assert(c.state.paused); eq(c.role,"spectate"); assert(not c.slot); eq(c:botCount(),1)
    frozenEqual(cp.state,c.state,1)
    sim:step(3); for i=3,4 do eq(sim.nodes[i].net.term,2); eq(sim.nodes[i].net.hostName,c.name) end
    print(string.format("  Crash recovery %.1fs from latest complete %d-byte checkpoint",sim.time-begun,#cp.body))
end)
check("migration: simultaneous host and oldest failure selects next live rank with real majority",function()
    local sim=simulation(5); local h=sim.nodes[1].net
    for i=2,5 do sim:connect(i,i==3 and "spectate" or "play") end
    committedRoom(sim,{2,3,4,5}); sim.nodes[1].active,sim.nodes[2].active=false,false
    local c=sim.nodes[3].net; c:setCombat(true)
    sim:wait(function() return c.mode=="host" end,40); eq(c.role,"spectate"); eq(c.term,2)
    sim:step(3); for i=4,5 do eq(sim.nodes[i].net.hostName,c.name) end
end)
check("migration: incomplete membership/world, outsider, late join and forged rank cannot seize authority",function()
    local sim=simulation(4); local h=sim.nodes[1].net; local c=sim:connect(2); local d=sim:connect(3)
    local cp=committedRoom(sim,{2,3}); local id=c.ownMemberID
    local function raw(kind,target,hash,gen)
        return table.concat({"R6",kind,h.sid,cp.id,hash or cp.hash,2,id,target or id,gen or c.generation,1},"|")
    end
    assert(not d:receive(sim.nodes[4].name,raw("Y")))
    assert(not d:receive(c.name,raw("Y",id,"00000000")))
    assert(not d:receive(c.name,raw("Y",id,nil,999999)))
    assert(not d:receive(c.name,table.concat({"R6","D",h.sid,cp.id,cp.hash,2,id,"e",1},"|")))
    local late=sim:connect(4,"spectate"); assert(not cp.participants[late.ownMemberID])
    sim.drop=function(p) return p.sender==h.name and (p.payload:sub(1,4)=="R6|X" or p.payload:sub(1,4)=="R6|V") end
    sim.nodes[1].active=false; sim:step(23)
    assert(late.migration and late.state.paused); assert(not late:checkpointEligible(late.committed))
    assert(not late:action("R")); assert(not h:receive(late.name,raw("U")))
    -- No complete checkpoint at all is a hard stop, not fabricated local order.
    local sim2=simulation(2); local n=sim2:connect(2); sim2.nodes[1].active=false
    n.committed=nil; sim2:step(55); eq(n.mode,"client"); assert(n.migration and n.state.paused)
end)
check("migration: short partition rolls back only committed state, reconciles old host and rejects old term input",function()
    local sim=simulation(4); local h=sim.nodes[1].net; local c=sim:connect(2); sim:connect(3); sim:connect(4)
    assert(h:start()); sim:step(2); committedRoom(sim,{2,3,4})
    local oldInput=input(c,900,"P"); local oldSid=h.sid
    sim.drop=function(p,node) return p.sender==h.name or node.name==h.name end
    sim:step(39); eq(c.mode,"host"); assert(h.state.paused)
    local htime=h.state.time; sim:step(1); eq(h.state.time,htime)
    sim.drop=nil; sim:step(5); eq(h.mode,"idle")
    for i=3,4 do eq(sim.nodes[i].net.hostName,c.name); eq(sim.nodes[i].net.term,2) end
    assert(not c:receive(h.name,oldInput)); eq(c.sid,oldSid)
    assert(not c:receive(sim.nodes[3].name,oldInput)); assert(not c:receive(sim.nodes[3].name,oldInput:gsub("|1$","|2")))
end)
check("migration: split survivor electorate and missing majority fail closed with bounded timers",function()
    local sim=simulation(5); local h=sim.nodes[1].net
    for i=2,5 do sim:connect(i) end; committedRoom(sim,{2,3,4,5})
    sim.nodes[1].active=false
    sim.drop=function(p,node)
        local a=(p.sender==sim.nodes[2].name or p.sender==sim.nodes[3].name)
        local b=(node.name==sim.nodes[2].name or node.name==sim.nodes[3].name)
        return a~=b
    end
    sim:step(65)
    for i=2,5 do local n=sim.nodes[i].net; eq(n.mode,"client"); assert(n.migration and n.state.paused); assert(n.migration.expired) end
    sim.drop=nil; sim:step(5)
    for i=2,5 do eq(sim.nodes[i].net.mode,"client") end -- no unsafe revote after timeout
end)
check("migration: active successor fences input epochs, preserves counters and never replays a hit",function()
    local sim=simulation(3); local h=sim.nodes[1].net; local c=sim:connect(2); local d=sim:connect(3)
    h:start(); sim:step(2)
    assert(h:receive(d.name,input(d,30,"P"))); local old=input(d,31,"P")
    c:setCombat(true); sim:step(0.4); local cp=committedRoom(sim,{2,3})
    sim.nodes[1].active=false; sim:wait(function() return c.mode=="host" end,40)
    eq(c.ownMemberID,2); eq(c.slot,2); eq(c.participants[d.ownMemberID].seq,30)
    frozenEqual(cp.state,c.state,1); c:setCombat(false); sim:step(3)
    assert(not c.state.players[c.slot].protected); assert(c:action("R"))
    local p=c.state.players[d.slot]; local hit=p.hit
    assert(not c:receive(d.name,old)); assert(not c:receive(d.name,old:gsub("|1$","|2")))
    assert(not c:receive(d.name,input(d,30,"P")))
    assert(c:receive(d.name,input(d,31,"P"))); eq(p.hit,(hit+1)%1000)
    assert(not c:receive(d.name,input(d,31,"P"))); eq(p.hit,(hit+1)%1000)
    local late=N.encodeState(cp.state,c.sid,999999,cp.epoch,cp.revision,cp.participants,1)
    for _,packet in ipairs(late) do assert(not d:receive(h.name,packet)) end
    eq(d.term,2); eq(c.participants[d.ownMemberID].seq,31)
end)
check("migration: 40 maximum-name nodes, full actors plus five AI, loss/reorder, complete roster and graceful watcher host",function()
    local sim=simulation(40,true); local h=sim.nodes[1].net
    for _=1,5 do assert(h:addAI()) end
    local c=sim:connect(2,"spectate") -- admitted first, not actor 1 or member 1
    for i=3,40 do assert(sim.nodes[i].net:join(h.name,h.sid,i<=21 and "play" or "spectate")) end
    sim:wait(function() for i=2,40 do if sim.nodes[i].net.mode~="client" then return false end end; return true end,89)
    eq(h:count(),25); eq(h:spectatorCount(),20); eq(h:botCount(),5)
    assert(h:start()); sim:step(7); c:setCombat(true); sim:step(0.5)
    sim.jitter,sim.duplicates=true,true
    local lostFirst={}
    sim.drop=function(p,node,index)
        -- Every recipient loses a DIFFERENT checkpoint chunk. This cannot pass
        -- via a shared-memory roster or a lucky no-loss election.
        local part=tonumber(p.payload:match("^R6|X|[^|]+|[^|]+|([^|]+)|"))
        if part and part==index and not lostFirst[index] then lostFirst[index]=true; return true end
        return (p.serial*7+index*11)%37==0
    end
    local start=sim.time; local packets,wire=sim.nodes[1].packets,sim.nodes[1].wire
    assert(h:leave()); local cp,transfer=h.checkpointSend,h.migration
    sim:wait(function() return c.mode=="host" and h.mode=="idle" end,36)
    assert(transfer.acked,"loss fixture must complete actual graceful all-peer acknowledgments")
    sim:step(5)
    eq(c.role,"spectate"); assert(not c.slot); eq(c:botCount(),5); eq(c:count(),24); eq(c:spectatorCount(),20)
    frozenEqual(cp.state,c.state,1)
    for i=3,40 do
        local n=sim.nodes[i].net; eq(n.term,2); eq(n.hostName,c.name)
        for id,m in pairs(c.participants) do
            assert(n.participants[id]); eq(n.participants[id].name,m.name); eq(n.participants[id].joined,m.joined)
            eq(n.participants[id].generation,m.generation)
        end
    end
    local seconds=sim.time-start
    assert(sim.nodes[1].wire-wire<=N.BYTE_BURST+N.BYTE_RATE*seconds)
    assert(sim.nodes[1].packets-packets<=N.SEND_BURST+N.SEND_RATE*seconds)
    assert(sim.maxQueue<=N.MAX_QUEUE)
    print(string.format("  40-node LOSS migration: %d-byte exact checkpoint / %d chunks; %.1fs settle; %.2f msg/s, %.1f charged B/s; max queue %d; display gap %.1fs",#cp.body,cp.total,seconds,
        (sim.nodes[1].packets-packets)/seconds,(sim.nodes[1].wire-wire)/seconds,sim.maxQueue,sim.maxLag))
end)
check("migration: 40-node crashed host preserves five AI and ranks under duplicate/out-of-order/lost election packets",function()
    local sim=simulation(40,true); local h=sim.nodes[1].net
    for _=1,5 do h:addAI() end
    local c=sim:connect(2,"spectate")
    for i=3,40 do assert(sim.nodes[i].net:join(h.name,h.sid,i<=21 and "play" or "spectate")) end
    sim:wait(function() for i=2,40 do if sim.nodes[i].net.mode~="client" then return false end end; return true end,89)
    local indices={}; for i=2,40 do indices[#indices+1]=i end
    h:start(); sim:step(5); c:setCombat(true); sim:step(0.5)
    local cp=committedRoom(sim,indices,120)
    sim.nodes[1].active=false; sim.jitter,sim.duplicates=true,true
    sim.drop=function(p,node,index) return (p.serial*7+index*11)%23==0 end
    local began=sim.time; sim:wait(function() return c.mode=="host" end,45); sim:step(8)
    eq(c:botCount(),5); eq(c.role,"spectate"); frozenEqual(cp.state,c.state,1)
    for i=3,40 do
        local n=sim.nodes[i].net
        if n.term~=2 then print("  Crash convergence",i,n.mode,n.status,n.term,n.migration and n.migration.voted,c.revision,c.configRevision) end
        eq(n.term,2); eq(n.hostName,c.name)
    end
    local recoveredAt=sim.time
    c:setCombat(false); local clock=c.state.time
    sim:step(2,function()
        local active=0
        for _,node in ipairs(sim.nodes) do
            local n=node.net
            if node.active and n.mode=="host" and not n.state.paused then active=active+1 end
        end
        assert(active<=1,"healthy survivor majority must never run two authorities")
    end)
    assert(c.mode=="host" and not c.state.paused and c.state.time>clock+1.9,
        "healthy survivor majority must actually resume simulation, not just label a paused host")
    print(string.format("  40-node crash + 4.35%% recipient loss: %.1fs settle; checkpoint %d bytes; queue %d; unique host advances 2s",recoveredAt-began,#cp.body,sim.maxQueue))
end)
check("migration: graceful unresponsive oldest never races an authorized transfer; deadline then next eligible rank",function()
    local sim=simulation(5); local h=sim.nodes[1].net
    for i=2,5 do sim:connect(i) end
    sim.nodes[2].active=false; assert(h:leave())
    local c=sim.nodes[3].net; c:setCombat(true)
    sim:step(20); eq(c.mode,"client"); assert(c.state.paused and c.migration)
    sim:wait(function() return c.mode=="host" end,65); eq(c.term,2); eq(c.ownMemberID,3)
    eq(h.mode,"idle"); sim:step(3); for i=4,5 do eq(sim.nodes[i].net.term,2) end
end)
check("migration: observed post-checkpoint role/membership changes fail closed rather than force an old avatar",function()
    local sim=simulation(3); local h=sim.nodes[1].net; local c=sim:connect(2); local d=sim:connect(3)
    committedRoom(sim,{2,3})
    assert(c:setRole("spectate")); sim:wait(function() return c.role=="spectate" end)
    sim:step(2); sim.nodes[1].active=false; sim:step(55)
    for _,n in ipairs({c,d}) do eq(n.mode,"client"); assert(n.migration and n.state.paused) end
    assert(not c.slot); eq(c.role,"spectate")
end)
check("migration: roster-loss fast path still waits past old-host lease before any new simulation authority",function()
    local sim=simulation(4); local h=sim.nodes[1].net
    for i=2,4 do sim:connect(i) end; h:start(); sim:step(3)
    committedRoom(sim,{2,3,4})
    local roster={}; for i=2,4 do roster[sim.nodes[i].name]=true end
    sim.drop=function(p,node) return p.sender==h.name or node.name==h.name end
    for i=2,4 do sim.nodes[i].net:setRoster(roster,true) end
    local c=sim.nodes[2].net
    sim:step(18,function()
        local ticking=0
        for _,node in ipairs(sim.nodes) do
            local n=node.net
            if n.mode=="host" and not n.state.paused then ticking=ticking+1 end
        end
        assert(ticking<=1,"roster-loss election overlapped live host lease")
    end)
    eq(c.mode,"host"); assert(h.state.paused); eq(c.term,2)
end)
check("migration: asymmetric host-outbound loss cannot overlap leases or advance two host clocks",function()
    local sim=simulation(4); local h=sim.nodes[1].net
    for i=2,4 do sim:connect(i) end; h:start(); sim:step(3); committedRoom(sim,{2,3,4})
    sim.drop=function(p,node)
        if p.sender==h.name then return true end
        return node.name==h.name and (p.payload:sub(1,4)=="R6|U" or p.payload:sub(1,4)=="R6|Y" or p.payload:sub(1,4)=="R6|D")
    end
    local c=sim.nodes[2].net
    sim:step(40,function()
        local active=0
        for _,node in ipairs(sim.nodes) do
            local n=node.net; if n.mode=="host" and not n.state.paused then active=active+1 end
        end
        assert(active<=1,"asymmetric packet loss produced two ticking hosts")
    end)
    eq(c.mode,"host"); assert(h.state.paused); local time=h.state.time; sim:step(0.5); eq(h.state.time,time)
end)
check("migration: stale tiny opted-in roster cannot elect itself over later real participants",function()
    local sim=simulation(4); local h=sim.nodes[1].net; local c=sim:connect(2)
    committedRoom(sim,{2}); local cp=c.committed
    eq(cp.configRevision,cp.revision)
    -- Keep the old recovery checkpoint, but allow the mandatory newer fence.
    -- A majority of old admitted voters must receive/ACK it before new members
    -- become a certified electorate; unrelated native group members never vote.
    sim.drop=function(p,node)
        return node.name==c.name and p.sender==h.name and (p.payload:sub(1,4)=="R6|X" or p.payload:sub(1,4)=="R6|V")
    end
    sim:connect(3); sim:connect(4)
    sim:wait(function() return not h.membershipPending end,15)
    assert(c.electionFloor>cp.revision); assert(not c:checkpointEligible(cp))
    sim.drop=function(p,node) return p.sender==h.name and node.name==c.name end
    sim:step(42)
    eq(c.mode,"client"); assert(c.migration and c.state.paused)
    eq(h.mode,"host"); assert(not h.state.paused)
    eq(h.term,1); assert(not h.migration) -- fenced stale peer cannot seize or stop the stable host
end)
check("migration: forty native group members with only three admitted recover through admitted voter certificate",function()
    local sim=simulation(40); local h=sim.nodes[1].net; local c=sim:connect(2,"spectate"); local d=sim:connect(3)
    h:start(); sim:step(3); c:setCombat(true); sim:step(0.5)
    local cp=committedRoom(sim,{2,3}); eq(cp.configRevision,h.revision)
    local admitted=0; for _ in pairs(cp.participants) do admitted=admitted+1 end; eq(admitted,3)
    sim.nodes[1].active=false; local began=sim.time
    sim:wait(function() return c.mode=="host" end,45); sim:step(3)
    eq(c.role,"spectate"); eq(c.term,2); eq(d.hostName,c.name); frozenEqual(cp.state,c.state,1)
    for i=4,40 do eq(sim.nodes[i].net.mode,"idle"); assert(not sim.nodes[i].net.state) end
    print(string.format("  Sparse raid recovery: 40 native / 3 admitted; %.1fs; only two admitted votes",sim.time-began))
end)
check("migration: missing old-electorate fence ACK holds new membership paused and uncertified",function()
    local sim=simulation(4); local h=sim.nodes[1].net; local c=sim:connect(2)
    local cp=committedRoom(sim,{2})
    sim.drop=function(p,node)
        return p.sender==h.name and node.name==c.name and p.payload:sub(1,4)=="R6|W"
    end
    sim:connect(3); sim:connect(4); sim:step(8)
    assert(h.membershipPending and h.state.paused); eq(h.configRevision,cp.revision)
    assert(not h:captureCheckpoint(false)); eq(h.committed.id,cp.id)
    sim.drop=nil
    sim:wait(function() return not h.membershipPending end,10)
    assert(h.configRevision>cp.revision); assert(c.electionFloor>cp.revision)
    assert(not c:checkpointEligible(cp)); assert(not h.state.paused)
end)
check("migration: membership revision fences authenticate host, member generation and monotonic receipt",function()
    local sim=simulation(4); local h=sim.nodes[1].net; local c=sim:connect(2); local d=sim:connect(3)
    committedRoom(sim,{2,3}); local floor=c.electionFloor
    local function fence(sender,rev,term)
        return c:receive(sender,table.concat({"R6","W",h.sid,rev,term or h.term},"|"))
    end
    assert(not fence(d.name,h.revision+10)); assert(not fence(h.name,h.revision+10,h.term+1))
    eq(c.electionFloor,floor)
    assert(not fence(h.name,floor-1))
    local old=table.concat({"R6","O",h.sid,c.joinToken,c.generation,h.revision,c.inSeq,c:incarnation().first,h.term},"|")
    assert(h:receive(c.name,old)); assert(not h:receive(d.name,old))
    assert(not h:receive(sim.nodes[4].name,old))
    assert(c:setRole("spectate")); sim:wait(function() return c.role=="spectate" end)
    assert(not h:receive(c.name,old)); assert(h.revision>floor)
    sim:wait(function() return not h.membershipPending end,10); assert(c.electionFloor>=h.revision)
end)
check("migration: already cast election vote cannot acknowledge a competing membership revision",function()
    local sim=simulation(3); local h=sim.nodes[1].net; local c=sim:connect(2); sim:connect(3)
    local cp=committedRoom(sim,{2,3}); sim.nodes[1].active=false
    sim.drop=function(p,node) return p.sender==sim.nodes[3].name end
    sim:step(38); assert(c.migration and c.migration.voted)
    local floor=c.electionFloor
    assert(not c:receive(h.name,table.concat({"R6","W",c.sid,cp.revision+1,c.term},"|")))
    eq(c.electionFloor,floor); assert(not c.queue.membershipAck)
end)
check("migration: genuine delayed old-generation vote stays locked across same-room reset and re-admission",function()
    local sim=simulation(4); local h=sim.nodes[1].net; local a=sim:connect(2); local b=sim:connect(3); sim:connect(4)
    local cp=committedRoom(sim,{2,3,4}); local delayed; local rejoin=false
    sim.drop=function(p,node)
        if p.sender==h.name and (node.name==a.name or (node.name==b.name and not rejoin)) then return true end
        if p.sender==b.name and p.payload:sub(1,4)=="R6|Y" and node.name==a.name then delayed=p.payload; return true end
        return node.name==h.name and (p.payload:sub(1,4)=="R6|U" or p.payload:sub(1,4)=="R6|Y")
    end
    sim:step(38); assert(delayed and a.migration.voted==a.ownMemberID and b.migration.voted==a.ownMemberID)
    assert(h.leasePaused); local oldGeneration=b.generation
    assert(b:leave()); sim:step(0.3)
    assert(not h.withdrawn[b.name..":"..oldGeneration],"already emitted votes cannot be revoked by Leave")
    rejoin=true; h.lastAdvert=nil; h:advertise(); sim:step(2)
    assert(b:join(h.name,h.sid,"spectate")); sim:wait(function() return b.mode=="client" end,20)
    assert(b.generation>oldGeneration); assert(b:incarnation().voted)
    sim:step(3); assert(h.membershipPending and h.state.paused)
    assert(not b:receive(h.name,table.concat({"R6","W",h.sid,h.revision,h.term},"|")))
    assert(not b.queue.membershipAck)
    assert(a:receive(b.name,delayed)); sim:step(0.3)
    eq(a.mode,"host"); assert(h.state.paused)
    local t=h.state.time; sim:step(1); eq(h.state.time,t)
    assert(not (a.mode=="host" and not a.state.paused and h.mode=="host" and not h.state.paused))
end)
check("migration: late non-voting adopter locks its emitted old-term recovery witnesses",function()
    local sim=simulation(4); local h=sim.nodes[1].net
    local a=sim:connect(2); sim:connect(3); local late=sim:connect(4)
    committedRoom(sim,{2,3,4})
    local key=h.name..":"..h.sid..":"..h.term
    sim.drop=function(p,node)
        if p.sender==h.name and (node.name==sim.nodes[2].name or node.name==sim.nodes[3].name) then return true end
        return node.name==h.name and (p.payload:sub(1,4)=="R6|U" or p.payload:sub(1,4)=="R6|Y" or p.payload:sub(1,4)=="R6|D")
    end
    sim:wait(function() return a.mode=="host" end,45)
    assert(not late.migration and not late:incarnation().voted)
    sim.nodes[1].active=false
    sim:wait(function() return late.hostName==a.name end,25)
    assert(late.witness and late.incarnations[key].voted,
        "a genuine witness must retain the old vote lock even without an initial election ballot")
    sim:step(2)
    local emitted=false
    for _,p in ipairs(sim.sent) do
        if p.sender==late.name and p.payload:match("^R6|Y|.*|1$") then emitted=true end
    end
    assert(emitted); late:reset(); assert(late.incarnations[key].voted)
end)
check("migration: fresh process rejoin cannot claim a forgotten prior-generation vote fence",function()
    local sim=simulation(2); local h=sim.nodes[1].net; local c=sim:connect(2)
    local cp=committedRoom(sim,{2}); local oldGeneration=c.generation
    -- Actual new protocol instance, not deleting a lock from an existing peer.
    local fresh=N.new(c.env); sim.nodes[2].net=fresh; fresh:setRoster(sim.roster,true)
    fresh:discover(); sim:wait(function() return fresh.lobbies[h.name] end)
    assert(fresh:join(h.name,h.sid,"spectate")); sim:wait(function() return fresh.mode=="client" end,20)
    assert(fresh.generation>oldGeneration); eq(fresh:incarnation().first,fresh.generation)
    sim:step(4); assert(h.membershipPending and h.state.paused); eq(h.configRevision,cp.revision)
    assert(h.configAcks[fresh.name].first>oldGeneration)
end)
check("migration: asymmetric host roster shrink is not proof that old voters retired",function()
    local sim=simulation(4); local h=sim.nodes[1].net; local a=sim:connect(2)
    local cp=committedRoom(sim,{2})
    sim.drop=function(p,node) return p.sender==h.name and node.name==a.name end
    local hostView={}; for name in pairs(sim.roster) do if name~=a.name then hostView[name]=true end end
    h:setRoster(hostView,true); sim:connect(3); sim:connect(4); sim:step(8)
    assert(h.membershipPending and h.state.paused); eq(h.configRevision,cp.revision)
    assert(not h:captureCheckpoint(false))
    sim:wait(function() return a.mode=="host" end,45)
    assert(h.state.paused); local t=h.state.time; sim:step(1); eq(h.state.time,t)
end)
check("migration: delayed final checkpoint chunk cannot refresh the 120-second evidence lifetime",function()
    local sim=simulation(2); local h=sim.nodes[1].net; local c=sim:connect(2)
    h.checkpointSend=nil; h.nextCheckpoint=sim.time; h:captureCheckpoint(false)
    local cp=h.checkpointSend; local withheld
    sim.drop=function(p)
        local id,part,total=p.payload:match("^R6|X|[^|]+|([^|]+)|([^|]+)|([^|]+)|")
        if tonumber(id)==cp.id and part==total then withheld=p.payload; return true end
        if tonumber(id) and tonumber(id)>cp.id then return true end
        local commit=p.payload:match("^R6|V|[^|]+|([^|]+)|")
        return commit and tonumber(commit)>cp.id
    end
    sim:step(110); assert(withheld)
    assert(c:receive(h.name,withheld)); eq(c.committed.id,cp.id)
    assert(c.committed.evidenceAge>100,"assembly incorrectly reset evidence age")
    sim.nodes[1].active=false; sim:step(60)
    eq(c.mode,"client"); assert(c.migration and c.state.paused); assert(not c:checkpointEligible(c.committed))
end)
check("migration: replayed heartbeat/admission/role packets cannot sustain a vanished authority lease",function()
    local sim=simulation(2); local h=sim.nodes[1].net; local c=sim:connect(2)
    sim:step(10); local last
    for _,p in ipairs(sim.sent) do if p.sender==c.name and p.payload:sub(1,4)=="R6|K" then last=p.payload end end
    assert(last); local seen=h.participants[c.ownMemberID].seen
    assert(not h:receive(c.name,last)); eq(h.participants[c.ownMemberID].seen,seen)
    sim.nodes[2].active=false
    local admission=table.concat({"R6","B",h.sid,c.joinToken,c.generation,h.term},"|")
    sim:step(22,function()
        h:receive(c.name,last); h:receive(c.name,admission)
    end)
    eq(h.participants[c.ownMemberID].seen,seen); assert(h.leasePaused and h.state.paused)
end)
check("migration: exact ordinal and name ranking excludes AI and does not depend on actor/member id",function()
    local sim=simulation(4); local h=sim.nodes[1].net
    local candidates={
        [9]={name=sim.nodes[3].name,joined=5,slot=1},
        [2]={name=sim.nodes[2].name,joined=5},
        [40]={name=sim.nodes[4].name,joined=1,bot=true},
        [1]={name=h.name,joined=1,slot=25}
    }
    eq(h:successor(candidates),2)
    eq(h:successor(candidates,{[9]=true}),9)
    candidates[9].joined=4; eq(h:successor(candidates),9)
end)
check("migration: mixed AI profile decisions and legal cadence continue exactly through graceful and crash checkpoints",function()
    for _,graceful in ipairs({true,false}) do
        local sim=simulation(2); local h=sim.nodes[1].net
        assert(h:setMode("brawl")); sim:step(6)
        local c=sim:connect(2,"spectate"); assert(h:setRole("spectate"))
        for _=1,5 do assert(h:addAI()) end
        assert(h:start()); sim:step(7); c:setCombat(true); sim:step(0.5)
        local cp
        if graceful then
            assert(h:leave()); cp=h.checkpointSend
            sim:wait(function() return c.mode=="host" and h.mode=="idle" end,35)
        else
            cp=committedRoom(sim,{2}); sim.nodes[1].active=false
            sim:wait(function() return c.mode=="host" end,45)
        end
        assert(c.state.paused); eq(c:botCount(),5); assert(not c.slot)
        local function clone(v) if type(v)~="table" then return v end; local q={}; for k,x in pairs(v) do q[k]=clone(x) end; return q end
        local reference=clone(cp.state); reference.paused=false
        c:setCombat(false)
        local decisions=0
        for _=1,240 do
            for slot,p in pairs(reference.players) do
                if p.bot then
                    local q=c.state.players[slot]; eq(q.botID,p.botID)
                    local profile=M.botProfile(p.botID); assert(profile and profile.key and profile.interval)
                    eq(M.botProfile(q.botID).key,profile.key)
                    eq(M.botAction(c.state,slot),M.botAction(reference,slot)); decisions=decisions+1
                    assert(math.abs((q.nextBot or 0)-(p.nextBot or 0))<0.000001)
                end
            end
            M.tick(reference,0.1); sim:step(0.1)
            frozenEqual(reference,c.state,nil)
        end
        assert(decisions>=1200)
        -- Replay resets authoritative clocks for the same immutable mixed IDs.
        c.state.phase="victory"; assert(c:start()); sim:step(0.1)
        for _,p in pairs(c.state.players) do if p.bot then assert(M.botProfile(p.botID)); assert(p.nextBot and p.nextBot>c.state.time) end end
        print(string.format("  %s profile checkpoint continuity: %d exact per-bot decisions across 24s",graceful and "Graceful" or "Crash",decisions))
    end
end)
check("protocol: R6 round-trips every real boss phase and fractional position without replaying impacts", function()
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
        M.tick(s,0.7); M.tick(s,1.3); prove("windup")
        M.tick(s,1); M.tick(s,0.7); prove("attack")
        M.tick(s,0.5); M.tick(s,2.1); prove("recover")
    end
end)
check("protocol: strict R6 phase clocks, routes, lane masks and stage-derived ground kind reject malformed worlds", function()
    local s=M.new(); M.addPlayer(s,1); M.start(s); local body=stateBody(s)
    local bad={
        "-", "0001w0105", motionRecord("x",0,50,4,5), motionRecord("p",0,50,4,5,0),
        motionRecord("p",0,0,4,5), motionRecord("p",0,51,4,5), motionRecord("p",1,50,4,5),
        motionRecord("p",0,50,1,2), motionRecord("p",0,50,6,7), motionRecord("p",0,50,2,6),
        motionRecord("p",0,30,4,4), motionRecord("w",0,30,5,5), motionRecord("w",1,31,5,5),
        motionRecord("w",3,30,5,5), motionRecord("w",1,30,4,5), motionRecord("a",1,6,5,5),
        motionRecord("a",1,0,5,5), motionRecord("a",1,5,4,5), motionRecord("r",1,50,5,5),
        motionRecord("r",0,51,5,5), motionRecord("r",0,50,4,5), motionRecord("w",128,30,5,5)
    }
    for _,record in ipairs(bad) do assert(not N.decodeState(withMotion(body,record)),"accepted malformed record "..record) end
    assert(N.decodeState(withMotion(body,motionRecord("w",64,30,5,5))))
    assert(N.decodeState(withMotion(body,motionRecord("a",1,5,5,5))))
    assert(N.decodeState(withMotion(body,motionRecord("r",0,30,5,5))))
    for stage=2,4 do
        s.stage,s.boss=stage,8+stage*2; body=stateBody(s)
        if stage==2 then
            assert(not N.decodeState(withMotion(body,motionRecord("p",0,50,4,5))))
            assert(not N.decodeState(withMotion(body,motionRecord("w",5,30,4,4)))) -- separated columns
            assert(N.decodeState(withMotion(body,motionRecord("w",3,30,4,4))))
        elseif stage==3 then
            assert(N.decodeState(withMotion(body,motionRecord("p",0,30,4,4)))) -- pursuit can settle
            assert(not N.decodeState(withMotion(body,motionRecord("p",0,50,4,6))))
            assert(not N.decodeState(withMotion(body,motionRecord("w",7,30,4,4)))) -- not origin +/-1
            assert(N.decodeState(withMotion(body,motionRecord("w",28,30,4,4))))
        else
            assert(not N.decodeState(withMotion(body,motionRecord("p",0,50,4,6,1))))
            assert(N.decodeState(withMotion(body,motionRecord("p",0,30,4,6,2))))
            assert(not N.decodeState(withMotion(body,motionRecord("w",11,30,4,4))))
            assert(not N.decodeState(withMotion(body,motionRecord("w",15,30,4,4)))) -- too many columns
            assert(N.decodeState(withMotion(body,motionRecord("w",7,30,4,4))))
        end
    end
    s.phase="lobby"; body=stateBody(s)
    assert(not N.decodeState(withMotion(body,motionRecord("w",7,30,4,4))))
end)
check("protocol: short-warning exact checkpoint clocks freeze and resume to one locked impact for every boss", function()
    for stage=1,4 do for _,remaining in ipairs({3,1.37,0.01}) do
        local sim=simulation(1); local h=sim.nodes[1].net
        assert(h:start()); h.state.stage,h.state.phase,h.state.wait=stage-1,"clear",0.1
        M.tick(h.state,0.1); local p=h.state.players[h.slot]; p.x,p.invuln=4,0
        M.tick(h.state,3); eq(h.state.bossMotion.phase,"windup")
        p.x=h.state.hazard.lanes[1]
        M.tick(h.state,3-remaining)
        assert(h:captureCheckpoint(false)); local cp=N.decodeRecovery(h.checkpointSend.body,h.name); assert(cp)
        local s=cp.state; local b=s.bossMotion; local q=s.players[h.slot]
        assert(math.abs(b.remaining-remaining)<0.0000001); eq(s.hazard.remaining,b.remaining)
        local clock,origin,lanes=s.time,b.fromLane,table.concat(b.lanes,",")
        s.paused=true; M.tick(s,5); eq(s.time,clock); eq(b.remaining,remaining); eq(q.hp,100)
        s.paused=false; M.tick(s,remaining-0.001); eq(b.phase,"windup"); eq(q.hp,100)
        M.tick(s,0.001); eq(b.phase,"attack"); eq(q.hp,65)
        eq(b.fromLane,origin); eq(table.concat(b.lanes,","),lanes)
        assert(math.abs(s.time-clock-remaining)<0.0000001)
        q.x,q.invuln=b.lanes[1],0; M.tick(s,0.4); eq(q.hp,65)
        M.tick(s,0.1); eq(b.phase,"recover"); eq(q.hp,65)
    end end
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
    for i=1,total do chunks[i]=table.concat({"R6","S",h.sid,seq+20,i,total,string.sub(malformed,(i-1)*N.CHUNK_BYTES+1,i*N.CHUNK_BYTES),h.term},"|") end
    assert(not deliver(c,h,chunks)); eq(c.state,old); eq(c.inSeq,seq)
    h.state.bossMotion={id=3,phase="attack",remaining=0.4,fromLane=5,toLane=5,lanes={1}}
    h.state.players[1].hp=65; M.syncHazard(h.state)
    chunks=N.encodeState(h.state,h.sid,seq+21,h.inputEpoch,h.revision,h.participants)
    assert(deliver(c,h,chunks)); eq(c.state.players[1].hp,65)
    assert(not deliver(c,h,chunks)); eq(c.state.players[1].hp,65)
    assert(deliver(c,h,N.encodeState(h.state,h.sid,seq+22,h.inputEpoch,h.revision,h.participants)))
    c:tick(0.5); eq(c.state.players[1].hp,65); eq(c.state.bossMotion.remaining,0.4)
end)
