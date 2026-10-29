local N, M = Addon.Protocol, Addon.Model
local function input(c, seq, action, options)
    local o = options or {}
    return table.concat({"R2", "I", o.sid or c.sid, o.token or c.joinToken, o.generation or c.generation,
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
    eq(b.phase, a.phase); eq(b.stage, a.stage); eq(b.boss, a.boss); eq(b.paused, a.paused)
    for i = 1, 9 do eq(b.hp[i], a.hp[i] or 0) end
    for slot = 1, 25 do
        local p, q = a.players[slot], b.players[slot]
        eq(p ~= nil, q ~= nil)
        if p then eq(q.x, p.x); eq(q.y, p.y); eq(q.score, p.score); eq(q.hit, p.hit) end
    end
end
check("protocol: R2 opt-in discovery and unchanged public interface", function()
    local sim = simulation(2); local h, c = sim.nodes[1].net, sim.nodes[2].net
    eq(N.VERSION, "R2"); eq(c.mode, "idle"); eq(#c:lobbyList(), 1); assert(not c.state)
    eq(c:lobbyList()[1].spectators, 0)
    assert(not c:receive(h.name, "R1|Q")); assert(not c:join("Outsider-Realm", h.sid))
    sim:connect(2); eq(h:count(), 2); eq(c.role, "play"); eq(c.members[c.slot].name, c.name)
    assert(not c:start()); assert(not h:setRole("spectate")); eq(h.slot, 1)
end)
check("protocol: actual roster sender, host, session and generated admission identity are mandatory", function()
    local sim = simulation(3); local c = sim:connect(2); local h, other = sim.nodes[1].net, sim.nodes[3].net
    h:start(); sim:step(2)
    local before = c.inSeq; local fake = N.encodeState(h.state, h.sid, before + 50)
    assert(not c:receive(other.name, fake[1])); assert(not c:receive("Stranger-Realm", fake[1])); eq(c.inSeq, before)
    assert(not h:receive("Stranger-Realm", "R2|J|" .. h.sid .. "|x|p"))
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
    assert(h:receive(c.name, "R2|J|" .. h.sid .. "|" .. oldToken .. "|p"))
    assert(not h:receive(c.name, "R2|B|" .. h.sid .. "|" .. oldToken .. "|" .. oldGen))
    assert(not h:receive(c.name, "R2|L|" .. h.sid .. "|" .. oldToken .. "|" .. oldGen))
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
    eq(#chunks, 2); assert(c:receive(h.name, chunks[2])); eq(c.state, oldState); eq(c.inSeq, seq)
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
    local bad = { "R2|S|" .. h.sid .. "|999|3|2|x", "R2|S|" .. h.sid .. "|999|1|9|x", "R2|S|" .. h.sid .. "|1e2|1|1|x",
        "R2|S|" .. h.sid .. "|999|1|1|bad", valid .. "|extra", string.rep("x", 256) }
    for _, text in ipairs(bad) do assert(not c:receive(h.name, text)) end
    local chunks = N.encodeState(h.state, h.sid, 999)
    local body = string.match(chunks[1], "^R2|S|[^|]+|[^|]+|[^|]+|[^|]+|(.+)$") .. string.match(chunks[2], "^R2|S|[^|]+|[^|]+|[^|]+|[^|]+|(.+)$")
    assert(N.decodeState(body))
    for _, b in ipairs({body:gsub("^l,1,10,0", "p,5,10,0"), body:gsub("^l,1,10,0", "p,1,99,0"), body:gsub("^l,1,10,0", "p,1,10,2"), body:gsub("000000000", "000090000", 1)}) do
        assert(not N.decodeState(b))
    end
    local prefix, players = string.match(body, "^(.*),([^,]+)$")
    local badPlayers = {"80000000", "11000000", "10zzzz00", "100000zz", "--------"}
    for _, p in ipairs(badPlayers) do assert(not N.decodeState(prefix .. "," .. p .. string.sub(players, 9))) end
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
    assert(not h:receive(c.name, old)); assert(not h:receive(c.name, "R2|R|" .. h.sid .. "|" .. c.joinToken .. "|" .. c.generation .. "|1|s"))
    eq(c.role, "play")
end)
check("protocol: cooperative damage, dropped snapshot healing and paused shared host", function()
    local sim = simulation(2); local c = sim:connect(2); local h = sim.nodes[1].net
    h:start(); sim:step(2); sim:act(1, "R"); sim:act(2, "R"); sim:act(1, "P"); sim:act(2, "P")
    eq(h.state.hp[1], 0); eq(c.state.hp[1], 0); eq(c.state.players[1].score, 10); eq(c.state.players[c.slot].score, 10)
    c:setCombat(true); assert(not c:action("R")); c:setCombat(false)
    local old = input(c, 100, "R"); h:setCombat(true); sim:step(2); assert(c.state.paused); assert(not c:action("R"))
    sim:step(36); eq(h:count(), 2); eq(c.mode, "client")
    h:setCombat(false); sim:step(2); assert(not h:receive(c.name, old)); assert(not c.state.paused)
    sim.drop = function(p) return string.sub(p.payload, 1, 4) == "R2|S" end
    assert(h:action("R")); sim:step(3); eq(c.state.players[1].x, 2)
    sim.drop = nil; sim:step(2); eq(c.state.players[1].x, 3)
end)
check("protocol: departures, host loss, stalled snapshots and silent spectator expire without migration", function()
    local sim = simulation(3); local c = sim:connect(2); sim:connect(3, "spectate"); local h = sim.nodes[1].net
    sim.nodes[3].active = false; sim:step(36); eq(h:spectatorCount(), 0)
    c:setRoster({[c.name]=true}, true); eq(c.mode, "idle"); assert(string.find(c.status, "Host left", 1, true))
    h:setRoster({[h.name]=true}, false); eq(h.mode, "idle")
    sim = simulation(2); c = sim:connect(2)
    sim.drop = function(p) return string.sub(p.payload, 1, 4) == "R2|S" end
    sim:step(21); eq(c.mode, "idle"); assert(string.find(c.status, "timed out", 1, true))
    sim = simulation(2); c = sim:connect(2); h = sim.nodes[1].net
    local sid = h.sid; h:leave(); sim:step(1); eq(c.mode, "idle"); assert(h:host()); assert(h.sid ~= sid)
    assert(not h:receive(c.name, "R2|J|" .. sid .. "|old|p"))
end)
check("protocol: world presence removes an expired guest even when its removal record is lost", function()
    local sim = simulation(2); local c = sim:connect(2); local h = sim.nodes[1].net
    sim.drop = function(p)
        return p.sender == c.name or string.sub(p.payload, 1, 4) == "R2|M"
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
    sim.drop = function(p) return string.sub(p.payload, 1, 4) == "R2|M" end
    assert(c:join(h.name, h.sid)); sim:step(5); eq(c.mode, "joining"); eq(h:count(), 2)
    sim.drop = nil; sim:wait(function() return c.mode == "client" end); eq(h:count(), 2)
end)
check("protocol: finite byte/message buckets, coalesced input, bounded queues and inbound floods", function()
    local sim = simulation(2); local h, c = sim.nodes[1].net, sim.nodes[2].net
    for i = 1, 200 do h:enqueue("test" .. i, string.rep("x", 255)) end
    eq(#h.queueOrder, N.MAX_QUEUE); assert(not h:enqueue("oversize", string.rep("x", 256)))
    sim:step(4)
    local accepted = 0
    for _ = 1, 1000 do if c:receive(h.name, "R2|Q") then accepted = accepted + 1 end end
    assert(accepted <= 24)
    local s = M.new(); for i = 1, 25 do M.addPlayer(s, i); s.players[i] = {x=6,y=3,score=99999,hit=999} end; M.start(s)
    for i = 1, 25 do s.players[i] = {x=6,y=3,score=99999,hit=999} end
    local chunks = N.encodeState(s, string.rep("a",16), 999999, 999999, 999999)
    local bytes = 0; for _, p in ipairs(chunks) do assert(#p <= 255); bytes = bytes + #p end
    print("  25-player maximum-field world: " .. #chunks .. " chunks, " .. bytes .. " payload bytes")
end)
check("protocol: invalid member records, fuzz and bounded expiring advertisements", function()
    local sim = simulation(10); local c = sim:connect(2); local h = sim.nodes[1].net
    assert(not c:receive(h.name, "R2|M|" .. h.sid .. "|999|3|Fake-Realm|x|2|3|0"))
    assert(not c:receive(h.name, "R2|M|" .. h.sid .. "|999|41|" .. c.name .. "|x|2|3|0"))
    local samples = {"", "R2", "R2|", "R2|I", "R2|M||||||||", "R2|A|x|p|999|0", "R2|S|x|nan", "R1|Q", "R2|J|!|x|p"}
    for _, sample in ipairs(samples) do h:receive(c.name, sample); c:receive(h.name, sample) end
    for i = 1, 100 do sim:step(0.1); h:receive(c.name, "R2|" .. string.rep(string.char(32+i%90), i%240)) end
    eq(h:count(), 2); eq(c.mode, "client")
    for i = 2, 10 do assert(h:receive(sim.nodes[i].name, "R2|A|lobby|l|1|0") == (i <= 9)) end
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
    sim:step(25)
    for i = 2, 40 do
        local c = sim.nodes[i].net; assert(c.generation > old[i]); eq(c.mode, "client"); worldSame(h.state,c.state)
    end
    eq(h:count(), 25); eq(h:spectatorCount(), 15)
    print(string.format("  40 maximum-name members: admission %.1fs; host %.2f msg/s, %.1f payload B/s (%.1f charged B/s); max queue %d, snapshot gap %.1fs", joinTime,
        sim.nodes[1].packets/sim.time,sim.nodes[1].bytes/sim.time,sim.nodes[1].wire/sim.time,sim.maxQueue,sim.maxLag))
end)
check("protocol: sustained real 40-node broadcasts, 25 actors, 15 spectators, loss/reorder, combat and four shared bosses", function()
    local sim = simulation(40); local h = sim.nodes[1].net
    h:start(); sim:step(2)
    for i = 2, 40 do assert(sim.nodes[i].net:join(h.name, h.sid, i > 25 and "spectate" or "play")) end
    sim:wait(function()
        for i = 2, 40 do if sim.nodes[i].net.mode ~= "client" then return false end end; return true
    end, 60)
    sim:step(22)
    eq(h:count(), 25); eq(h:spectatorCount(), 15)
    sim.jitter, sim.duplicates = true, true
    sim.drop = function(p, _, index) return (p.serial * 7 + index * 11) % 23 == 0 end -- 4.35% per-recipient loss
    local startTime, startPackets, startBytes = sim.time, sim.nodes[1].packets, sim.nodes[1].bytes
    local startWire = sim.nodes[1].wire
    local function drive()
        -- Each active client chooses from its own delayed authoritative snapshot.
        -- All 25 operate continuously; no direct state edits/teleports are used.
        for i = 1, 25 do
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
                    if p.y > 0 then action = "D" elseif p.x < 3 then action = "R" elseif p.x > 5 then action = "L" else action = "P" end
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
        for i = 1, 25 do local c = sim.nodes[i].net; c:action(math.floor(sim.time*5)%2 == 0 and "R" or "L") end
    end)
    sim.drop, sim.jitter, sim.duplicates = nil, nil, nil; sim:step(25)
    for i = 2, 40 do
        local c = sim.nodes[i].net; eq(c.mode,"client"); worldSame(h.state,c.state)
        eq(c:count(),25); eq(c:spectatorCount(),15)
        if i > 25 then eq(c.role,"spectate"); assert(not c.slot); assert(not c:action("P")) end
    end
    local seconds = sim.time-startTime; local allPackets, allBytes, heartbeats = 0,0,0
    for _, p in ipairs(sim.sent) do
        if p.time >= startTime then
            allPackets, allBytes = allPackets+1,allBytes+#p.payload
            if string.sub(p.payload,1,4) == "R2|K" then heartbeats=heartbeats+1 end
        end
    end
    assert(heartbeats >= 39*math.floor(seconds/8-2), "spectator/player keepalives missing")
    assert((sim.nodes[1].wire-startWire)/seconds <= N.BYTE_RATE + N.BYTE_BURST/seconds)
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
