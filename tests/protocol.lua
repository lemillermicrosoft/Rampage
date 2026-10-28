local N, M = Addon.Protocol, Addon.Model
local function input(client, seq, action, sid, joinToken, seenState)
    return table.concat({"R1", "I", sid or client.sid, joinToken or client.joinToken, seq, seenState or client.inSeq, action}, "|")
end
local function simulation(count)
    local sim = { time = 0, nodes = {}, pending = {}, sent = {}, roster = {} }
    for i = 1, count do sim.roster["Player" .. i .. "-Realm"] = true end
    for i = 1, count do
        local name, serial = "Player" .. i .. "-Realm", 0
        local node = { name = name, active = true }
        node.net = N.new({ name = name, now = function() return sim.time end,
            token = function() serial = serial + 1; return "T" .. i .. "x" .. serial end,
            send = function(payload)
                assert(#payload <= 255, "message exceeds WoW limit")
                local packet = { sender = name, payload = payload, time = sim.time }
                sim.pending[#sim.pending + 1] = packet; sim.sent[#sim.sent + 1] = packet
            end })
        node.net:setRoster(sim.roster, true); sim.nodes[i] = node
    end
    function sim:step(seconds)
        local steps = math.ceil(seconds / 0.05)
        for _ = 1, steps do
            self.time = self.time + 0.05
            for _, node in ipairs(self.nodes) do if node.active then node.net:tick(0.05) end end
            local pending = self.pending; self.pending = {}
            for _, packet in ipairs(pending) do
                for _, node in ipairs(self.nodes) do
                    if node.active and node.name ~= packet.sender and not (self.drop and self.drop(packet, node)) then
                        node.net:receive(packet.sender, packet.payload)
                    end
                end
            end
        end
    end
    function sim:connect(index)
        local host, client = self.nodes[1].net, self.nodes[index].net
        assert(client:join(host.name, host.sid)); self:step(1)
        eq(client.mode, "client"); assert(client.slot and client.state)
    end
    function sim:act(index, action)
        self:step(0.25); assert(self.nodes[index].net:action(action)); self:step(0.35)
    end
    assert(sim.nodes[1].net:host()); sim:step(0.5)
    return sim
end

check("protocol: discovery is opt-in join, never an unsolicited session", function()
    local sim = simulation(2); local h, c = sim.nodes[1].net, sim.nodes[2].net
    eq(c.mode, "idle"); eq(#c:lobbyList(), 1); assert(not c.state)
    c:receive(h.name, "R1|M|" .. h.sid .. "|1|2|" .. c.name .. "|fake")
    eq(c.mode, "idle"); assert(not c:join("Outsider-Realm", h.sid))
    sim:connect(2); eq(h:count(), 2); eq(c.members[c.slot].name, c.name)
end)
check("protocol: two clients cooperatively destroy one shared floor and synchronize scores", function()
    local sim = simulation(2); sim:connect(2)
    local h, c = sim.nodes[1].net, sim.nodes[2].net
    assert(h:start()); sim:step(0.4)
    sim:act(1, "R"); sim:act(2, "R"); sim:act(1, "P")
    eq(h.state.hp[1], 1); eq(c.state.hp[1], 1)
    sim:act(2, "P"); eq(h.state.hp[1], 0); eq(c.state.hp[1], 0)
    eq(h.state.players[1].score, 10); eq(c.state.players[c.slot].score, 10)
    eq(h.state.players[c.slot].score, c.state.players[c.slot].score)
end)
check("protocol: host-authority rejects outsiders, forged host, wrong session and token", function()
    local sim = simulation(3); sim:connect(2)
    local h, c, other = sim.nodes[1].net, sim.nodes[2].net, sim.nodes[3].net
    h:start(); sim:step(0.4)
    local before = c.inSeq
    local fake = N.encodeState(h.state, h.sid, before + 50)
    assert(not c:receive(other.name, fake)); assert(not c:receive("Stranger-Realm", fake)); eq(c.inSeq, before)
    assert(not h:receive("Stranger-Realm", "R1|J|" .. h.sid .. "|x"))
    assert(not h:receive(c.name, input(c, 500, "R", "WRONG")))
    assert(not h:receive(c.name, input(c, 500, "R", nil, "WRONG")))
    eq(h.state.players[c.slot].x, 1)
    assert(not c:receive(h.name, "R1|S|other|999|p|1|10|0|222222222|1,0,0,0;-;-;-"))
    eq(c.inSeq, before)
end)
check("protocol: duplicate/out-of-order inputs and rapid actions cannot double-apply", function()
    local sim = simulation(2); sim:connect(2)
    local h, c = sim.nodes[1].net, sim.nodes[2].net
    h:start(); sim:step(0.4)
    assert(h:receive(c.name, input(c, 10, "R"))); eq(h.state.players[c.slot].x, 2)
    assert(not h:receive(c.name, input(c, 10, "R"))); assert(not h:receive(c.name, input(c, 9, "R")))
    assert(not h:receive(c.name, input(c, 11, "R"))); eq(h.state.players[c.slot].x, 2)
    sim:step(0.3); assert(h:receive(c.name, input(c, 12, "R"))); eq(h.state.players[c.slot].x, 3)
end)
check("protocol: complete snapshots reject stale, duplicate and malformed state atomically", function()
    local sim = simulation(2); sim:connect(2)
    local h, c = sim.nodes[1].net, sim.nodes[2].net
    h:start(); sim:step(0.4)
    local seq, state = c.inSeq, c.state
    assert(not c:receive(h.name, N.encodeState(h.state, h.sid, seq)))
    assert(not c:receive(h.name, N.encodeState(h.state, h.sid, seq - 1)))
    local bad = {
        "p|5|10|0|222222222|1,0,0,0;-;-;-", "p|1|99|0|222222222|1,0,0,0;-;-;-",
        "p|1|10|2|222222222|1,0,0,0;-;-;-", "p|1|10|0|222292222|1,0,0,0;-;-;-",
        "p|1|10|0|222222222|8,0,0,0;-;-;-", "p|1|10|0|222222222|1,1,0,0;-;-;-",
        "p|1|10|0|222222222|1,0,-1,0;-;-;-", "p|1|10|0|222222222|1,0,0,1000;-;-;-",
        "p|1|10|0|222222222|1,0,0,0;-;-;-;-", "p|1|10|0|222222222|1,0,1e2,0;-;-;-"
    }
    for _, suffix in ipairs(bad) do assert(not c:receive(h.name, "R1|S|" .. h.sid .. "|99999|" .. suffix)) end
    eq(c.state, state); eq(c.inSeq, seq)
    assert(not c:receive(h.name, string.rep("x", 256)))
end)
check("protocol: mid-game late join receives current stage/city and existing personal scores", function()
    local sim = simulation(3); sim:connect(2)
    local h, late = sim.nodes[1].net, sim.nodes[3].net
    h:start(); h.state.stage = 3; h.state.boss = 14; h.state.hp[4] = 0; h.state.players[1].score = 745
    sim:step(0.4); sim:connect(3); sim:step(0.5)
    eq(late.state.stage, 3); eq(late.state.hp[4], 0); eq(late.state.players[1].score, 745)
    eq(late.state.players[late.slot].score, 0); eq(h:count(), 3)
end)
check("protocol: cap is four, fifth join times out without displacing anyone", function()
    local sim = simulation(5)
    for i = 2, 4 do sim:connect(i) end
    local h, fifth = sim.nodes[1].net, sim.nodes[5].net
    assert(fifth:join(h.name, h.sid)); sim:step(13)
    eq(h:count(), 4); eq(fifth.mode, "idle"); assert(string.find(fifth.status, "timed out", 1, true))
end)
check("protocol: leave/rejoin has a fresh token and stale actions cannot affect a reused slot", function()
    local sim = simulation(2); sim:connect(2)
    local h, c = sim.nodes[1].net, sim.nodes[2].net
    h:start(); sim:step(0.4); local oldToken = c.joinToken
    c:leave(); sim:step(0.4); eq(h:count(), 1)
    sim:connect(2); assert(c.joinToken ~= oldToken)
    assert(not h:receive(c.name, input(c, 9999, "R", nil, oldToken)))
    eq(h.state.players[c.slot].x, 1)
    local oldRemoval = table.concat({"R1", "M", h.sid, 2, c.slot, "-", "-"}, "|")
    assert(not c:receive(h.name, oldRemoval)); eq(c.mode, "client")
end)
check("protocol: roster departure removes members and host departure ends client session", function()
    local sim = simulation(3); sim:connect(2); sim:connect(3)
    local h, c = sim.nodes[1].net, sim.nodes[2].net
    local roster = { [h.name] = true, [c.name] = true }
    h:setRoster(roster, true); eq(h:count(), 2)
    c:setRoster({[c.name] = true}, true); eq(c.mode, "idle")
    assert(string.find(c.status, "Host left", 1, true))
    h:setRoster({[h.name] = true}, false); eq(h.mode, "idle")
end)
check("protocol: silent host timeout and silent guest timeout are bounded, no migration", function()
    local sim = simulation(2); sim:connect(2)
    sim.nodes[1].active = false; sim:step(16)
    eq(sim.nodes[2].net.mode, "idle"); assert(string.find(sim.nodes[2].net.status, "timed out", 1, true))
    sim = simulation(2); sim:connect(2); sim.nodes[2].active = false; sim:step(21)
    eq(sim.nodes[1].net:count(), 1)
end)
check("protocol: host leave notifies clients and old sessions cannot resume", function()
    local sim = simulation(2); sim:connect(2)
    local h, c = sim.nodes[1].net, sim.nodes[2].net
    local sid = h.sid; h:leave(); sim:step(0.4); eq(c.mode, "idle")
    assert(h:host()); assert(h.sid ~= sid); sim:step(0.4)
    assert(not h:receive(c.name, "R1|J|" .. sid .. "|stale")); eq(h:count(), 1)
end)
check("protocol: combat disables guest input and host combat pauses shared gameplay", function()
    local sim = simulation(2); sim:connect(2)
    local h, c = sim.nodes[1].net, sim.nodes[2].net
    h:start(); sim:step(0.4); c:setCombat(true); assert(not c:action("R"))
    c:setCombat(false); h:setCombat(true); sim:step(0.4)
    assert(c.state.paused); assert(not c:action("R")); assert(not h:action("R"))
    sim:step(21); eq(h:count(), 2); eq(c.mode, "client") -- heartbeats continue in combat
    h:setCombat(false); sim:step(0.4); assert(not c.state.paused); sim:act(2, "R")
end)
check("protocol: dropped snapshot self-heals on next full state; delayed state is ignored", function()
    local sim = simulation(2); sim:connect(2)
    local h, c = sim.nodes[1].net, sim.nodes[2].net
    h:start(); sim:step(0.5)
    sim.drop = function(packet) return string.sub(packet.payload, 1, 4) == "R1|S" end
    h:action("R"); sim:step(0.7); eq(c.state.players[1].x, 1)
    sim.drop = nil; sim:step(0.5); eq(c.state.players[1].x, 2)
end)
check("protocol: throttling, fixed queue, coalescing, bytes and inbound flood bounds", function()
    local sim = simulation(2); local h, c = sim.nodes[1].net, sim.nodes[2].net
    local before = #sim.sent
    for i = 1, 100 do h:enqueue("test" .. i, "R1|Q") end
    assert(#h.queueOrder <= 24)
    for i = 1, 100 do h:enqueue("state", N.encodeState(h.state, h.sid, i)) end
    assert(#h.queueOrder <= 24)
    assert(not h:enqueue("oversize", string.rep("x", 256)))
    local start = sim.time; sim:step(2)
    local count = 0
    for i = before + 1, #sim.sent do if sim.sent[i].sender == h.name then count = count + 1 end end
    assert(count <= 10 + math.ceil((sim.time - start) * 8), "outbound token bucket exceeded")
    local accepted = 0
    for _ = 1, 1000 do if c:receive(h.name, "R1|Q") then accepted = accepted + 1 end end
    assert(accepted <= 24); assert(not c.receiveBuckets["Outsider-Realm"])
end)
check("protocol: roster names must be real and snapshot encoding stays below 255 bytes at bounds", function()
    local sim = simulation(2); sim:connect(2)
    local h, c = sim.nodes[1].net, sim.nodes[2].net
    local before = c.members[3]
    assert(not c:receive(h.name, "R1|M|" .. h.sid .. "|999|3|Fake-Realm|xyz")); eq(c.members[3], before)
    assert(not c:receive(h.name, "R1|M|" .. h.sid .. "|999|9|" .. c.name .. "|xyz"))
    local s = M.new(); M.start(s)
    for i = 1, 4 do M.addPlayer(s, i); s.players[i] = {x = 6, y = 3, score = 99999, hit = 999} end
    local encoded = N.encodeState(s, string.rep("a", 16), 999999)
    assert(#encoded <= 255); print("  Maximum configured snapshot fixture: " .. #encoded .. " bytes")
end)
check("protocol: malformed/fuzz input cannot crash or grow player/queue state", function()
    local sim = simulation(2); sim:connect(2)
    local h, c = sim.nodes[1].net, sim.nodes[2].net
    local samples = { "", "R1", "R1|", "R1|I", "R1|M||||||||", "R1|A|x|p|999", "R1|S|x|nan", "R2|Q", "R1|J|!|x" }
    for _, sample in ipairs(samples) do h:receive(c.name, sample); c:receive(h.name, sample) end
    for i = 1, 300 do
        sim:step(0.05)
        local noise = "R1|" .. string.rep(string.char(32 + i % 90), i % 240)
        h:receive(c.name, noise); c:receive(h.name, noise)
    end
    eq(h:count(), 2); eq(c.mode, "client"); assert(#h.queueOrder <= 24)
end)
check("protocol: inputs from a previous stage/replay or future snapshot are rejected", function()
    local sim = simulation(2); sim:connect(2)
    local h, c = sim.nodes[1].net, sim.nodes[2].net
    h:start(); sim:step(0.5); local oldState = c.inSeq
    h.state.phase, h.state.wait = "clear", 0.1; sim:step(0.8)
    eq(c.state.stage, 2)
    assert(not h:receive(c.name, input(c, 100, "R", nil, nil, oldState)))
    assert(not h:receive(c.name, input(c, 100, "R", nil, nil, h.snapshotSeq + 1)))
    eq(h.state.players[c.slot].x, 1)
    h.state.phase = "victory"; assert(h:start()); sim:step(0.4)
    assert(not h:receive(c.name, input(c, 100, "R", nil, nil, oldState)))
    sim:act(2, "R"); eq(h.state.players[c.slot].x, 2)
end)
check("protocol: lost membership heals through retried join without duplicate players", function()
    local sim = simulation(2); local h, c = sim.nodes[1].net, sim.nodes[2].net
    sim.drop = function(packet) return string.sub(packet.payload, 1, 4) == "R1|M" end
    assert(c:join(h.name, h.sid)); sim:step(3); eq(c.mode, "joining"); eq(h:count(), 2)
    sim.drop = nil; sim:step(2); eq(c.mode, "client"); eq(h:count(), 2)
end)
check("protocol: periodic membership cannot mask a stalled world snapshot stream", function()
    local sim = simulation(2); sim:connect(2)
    sim.drop = function(packet) return string.sub(packet.payload, 1, 4) == "R1|S" end
    sim:step(16); eq(sim.nodes[2].net.mode, "idle")
    assert(string.find(sim.nodes[2].net.status, "timed out", 1, true))
end)
check("protocol: lobby cache is capped at eight and advertisements expire", function()
    local sim = simulation(10); local h = sim.nodes[1].net
    for i = 2, 10 do assert(h:receive(sim.nodes[i].name, "R1|A|lobby|l|1") == (i <= 9)) end
    eq(#h:lobbyList(), 8); sim:step(13); eq(#h:lobbyList(), 0)
end)
check("protocol: two-client full four-boss victory, personal scores and synchronized replay", function()
    local sim = simulation(2); sim:connect(2)
    local h, c = sim.nodes[1].net, sim.nodes[2].net
    h:start(); sim:step(0.4)
    local function walk(index, x)
        local n = sim.nodes[index].net
        while n.state.players[n.slot].y > 0 do sim:act(index, "D") end
        while n.state.players[n.slot].x < x do sim:act(index, "R") end
        while n.state.players[n.slot].x > x do sim:act(index, "L") end
    end
    for stage = 1, 4 do
        eq(h.state.stage, stage); eq(c.state.stage, stage)
        for tower, x in ipairs(M.TOWERS) do
            local actor = tower == 2 and 2 or 1
            walk(actor, x)
            for _ = 1, 3 do sim:act(actor, "U") end
            for _ = 1, 3 do sim:act(actor, "P"); sim:act(actor, "P"); sim:act(actor, "D") end
        end
        assert(not M.cityAlive(h.state)); assert(not M.cityAlive(c.state))
        walk(1, 4); walk(2, 4)
        local actor = 1
        while h.state.phase == "play" do sim:act(actor, "P"); actor = 3 - actor end
        if stage < 4 then sim:step(2.3) end
    end
    eq(h.state.phase, "victory"); eq(c.state.phase, "victory")
    eq(M.total(h.state), 2380); eq(M.total(c.state), 2380)
    assert(h.state.players[1].score > 0 and h.state.players[2].score > 0)
    eq(h.state.players[2].score, c.state.players[2].score)
    assert(h:start()); sim:step(0.5); eq(c.state.phase, "play"); eq(c.state.stage, 1); eq(M.total(c.state), 0)
end)
check("protocol: solo needs no group/network and combat never starts it", function()
    local sent = 0
    local n = N.new({ name = "Solo-Realm", now = function() return 0 end, token = function() return "solo" end,
        send = function() sent = sent + 1 end })
    assert(not n:host()); n:setCombat(true); assert(not n:solo())
    n:setCombat(false); assert(n:solo()); eq(n.state.phase, "play"); n:tick(1); eq(sent, 0)
    n:setRoster({[n.name] = true}, false); eq(n.mode, "solo"); n:leave(); eq(sent, 0)
end)
