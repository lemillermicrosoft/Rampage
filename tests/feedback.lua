-- Pure deterministic presentation tests; all actual damage still goes through Model/Protocol.
local M, N, F = Addon.Model, Addon.Protocol, Addon.Feedback
assert(F and F.create, "Feedback must be loaded by the real TOC test loader")
local function fixture(mode, gameMode)
    local clock = 10
    local app = { db = {}, now = function() return clock end }
    app.net = N.new({ name = "You-Realm", now = app.now, token = function() return "test" end,
        send = function() end, changed = function() if app.feedback then app.feedback:observe(true) end end })
    app.net:solo(gameMode)
    local net, s = app.net, app.net.state
    if mode == "host" then net.mode, net.sid, net.inputEpoch = "host", "host1", 1 end
    if mode == "client" then
        net.mode, net.sid, net.hostName, net.inSeq, net.lastSnapshot = "client", "host1", "Host-Realm", 1, clock
        net.joinToken, net.generation, net.acceptedRoleSeq, net.ownMemberID = "you1", 2, 0, 2
        net.participants = { { name = "Host-Realm", slot = 1, generation = 1, roleSeq = 0 },
            { name = "You-Realm", slot = 2, generation = 2, roleSeq = 0 } }
        net.memberVersions = {1, 1}; net.slot = 2
        M.addPlayer(s, 2); net:rebuildMembers()
        s._epoch, s._revision, s._mapping = 1, 1, {1, 2}
    end
    local f = F.create(app); f:observe(true)
    local function advance(dt, sample)
        clock, s.time = clock + dt, s.time + dt
        if sample then net.inSeq, net.lastSnapshot = net.inSeq + 1, clock end
    end
    return app, net, s, f, advance
end
local function kind(events, wanted)
    local found = {}; for _, e in ipairs(events) do if e.kind == wanted then found[#found + 1] = e end end
    return found
end
local function exposed(s) for i = 1, 9 do s.hp[i] = 0 end end
local function member(net, s, slot, name)
    M.addPlayer(s, slot)
    net.participants[slot] = { name = name or ("Other" .. slot .. "-Realm"), slot = slot, generation = slot, roleSeq = 0 }
    net:rebuildMembers()
    if s._mapping then s._mapping[slot] = slot; net.memberVersions[slot] = s._revision end
end
check("feedback: baseline and score/hit counters never manufacture contact", function()
    local _, _, s, f = fixture()
    eq(#f:drain(), 0)
    s.players[1].score, s.players[1].hit = 99999, 123
    f:observe(true); eq(#f:drain(), 0)
    eq(f.app, nil) -- samples/events hold values, not the mutable application
end)
check("feedback: exact solo building damage is YOU once through synchronous changed", function()
    local _, net, s, f = fixture()
    s.players[1].x = 2
    local original, calls = net.action, 0
    net.action = function(self, action) calls = calls + 1; return original(self, action) end
    assert(f:act("P")); eq(calls, 1)
    local events = f:drain(); local e = kind(events, "building")[1]
    eq(#kind(events, "building"), 1); eq(e.amount, 1); eq(e.source, "you"); eq(e.index, 1); eq(e.x, 2); eq(e.y, 1)
    eq(#kind(events, "swing"), 1); eq(kind(events, "swing")[1].amount, nil)
    f:observe(true); f:observe(true); eq(#f:drain(), 0); eq(s.players[1].score, 10)
end)
check("feedback: exact host boss hit reports HP not 15 fame", function()
    local _, _, s, f = fixture("host")
    exposed(s); s.players[1].x = 4; f:observe(true); f:drain()
    assert(f:act("P")); local e = kind(f:drain(), "boss")[1]
    eq(e.amount, 1); eq(e.source, "you"); eq(s.players[1].score, 15)
end)
check("feedback: unrelated host human/AI deltas cannot acquire local credit", function()
    local _, net, s, f = fixture("host")
    member(net, s, 2); s.players[1].x, s.players[2].x = 2, 4
    f:observe(true); assert(M.act(s, 2, "P"))
    assert(f:act("P")); local events = kind(f:drain(), "building")
    eq(#events, 2); eq(events[1].source, "team"); eq(events[1].index, 4)
    eq(events[2].source, "you"); eq(events[2].index, 1)
end)
check("feedback: successful remote send is swing intention, never a hit", function()
    local _, _, s, f = fixture("client")
    s.players[2].x = 2
    assert(f:act("P")); local events = f:drain()
    eq(#events, 1); eq(events[1].kind, "swing"); eq(events[1].amount, nil); eq(events[1].source, nil)
    eq(s.hp[1], 2); eq(s.players[2].score, 0)
end)
check("feedback: consecutive remote aggregate boss/building damage always TEAM", function()
    local _, _, s, f, advance = fixture("client")
    advance(1.25, true); s.boss, s.hp[1] = 8, 0
    s.players[2].score = 999; f:observe(true)
    local events = f:drain(); eq(#events, 2)
    for _, e in ipairs(events) do eq(e.source, "team"); eq(e.amount, 2) end
    f:observe(true); eq(#f:drain(), 0)
end)
check("feedback: incoming loss is positive aggregate HP with local emphasis", function()
    local _, net, s, f, advance = fixture("host", "brawl")
    member(net, s, 2); s.players[1].invuln, s.players[2].invuln = 0, 0
    f:observe(true); advance(0.1); assert(M.damage(s, 1, 35)); assert(M.damage(s, 2, 20))
    f:observe(true); local events = kind(f:drain(), "hurt"); eq(#events, 2)
    eq(events[1].slot, 1); eq(events[1].amount, 35); eq(events[1].localActor, true)
    eq(events[2].amount, 20); eq(events[2].localActor, false)
end)
check("feedback: healing and respawn never show incoming damage; KO resets generation", function()
    local _, _, s, f, advance = fixture()
    s.players[1].hp = 50; f:observe(true); f:drain()
    s.players[1].hp = 100; f:observe(true); eq(#f:drain(), 0)
    local gen = f.generation
    s.players[1].hp, s.players[1].ko = 0, 4; advance(0.1); f:observe(true)
    assert(f.generation > gen); eq(kind(f:drain(), "hurt")[1].amount, 100)
    gen = f.generation; s.players[1].hp, s.players[1].ko = 100, 0; advance(0.1); f:observe(true)
    assert(f.generation > gen); eq(#f:drain(), 0)
end)
check("feedback: actor member generation and role sequence prevent slot reuse loss", function()
    for _, field in ipairs({"generation", "roleSeq"}) do
        local _, net, s, f, advance = fixture("client")
        member(net, s, 3); f:observe(true)
        net.participants[3][field] = net.participants[3][field] + 1
        s.players[3].hp = 50; advance(1, true); f:observe(true); eq(#f:drain(), 0)
        s.players[3].hp = 40; advance(1, true); f:observe(true); eq(kind(f:drain(), "hurt")[1].amount, 10)
    end
end)
check("feedback: independent membership stream suppresses stale mapping and catches up safely", function()
    local _, net, s, f, advance = fixture("client")
    member(net, s, 3); f:observe(true)
    net.participants[3] = { name = "New-Realm", slot = 3, generation = 8, roleSeq = 0 }
    net.memberVersions[3] = 2; s.players[3].hp = 60
    advance(1, true); f:observe(true); eq(#f:drain(), 0)
    s._revision = 2; advance(1, true); f:observe(true); eq(#f:drain(), 0)
    s.players[3].hp = 40; advance(1, true); f:observe(true); eq(kind(f:drain(), "hurt")[1].amount, 20)
end)
check("feedback: bot identity and removal/readd suppress reused actor slots", function()
    local _, net, s, f = fixture()
    assert(net:addAI()); f:observe(true); f:drain()
    -- Suppress adapter callbacks to exercise reuse between observations, not
    -- real damage after an already-observed fresh spawn.
    net.env.changed = nil
    assert(net:removeAI()); assert(net:addAI()); s.players[2].hp = 50
    f:observe(true); eq(#f:drain(), 0)
    s.players[2].hp = 40; f:observe(true); eq(kind(f:drain(), "hurt")[1].amount, 10)
    s.players[2].botID = 2; s.players[2].hp = 20; f:observe(true); eq(#f:drain(), 0)
end)
check("feedback: join, reopen, combat, pause and session change rebaseline", function()
    local _, net, s, f = fixture()
    for _, change in ipairs({"hide", "combat", "pause", "session"}) do
        if change == "hide" then f:observe(false)
        elseif change == "combat" then net.combat = true; f:observe(true)
        elseif change == "pause" then s.paused = true; f:observe(true)
        else net.sid = "new" end
        s.players[1].hp = s.players[1].hp - 10
        net.combat, s.paused = false, false
        f:observe(true); eq(#f:drain(), 0, change)
    end
end)
check("feedback: stage, replay, epoch, role and local slot transitions are silent", function()
    for _, change in ipairs({"stage", "replay", "epoch", "role", "slot", "generation"}) do
        local _, net, s, f, advance = fixture("client")
        if change == "stage" then s.stage = 2
        elseif change == "replay" then s.time = 10; f:observe(true); s.time = -2
        elseif change == "epoch" then s._epoch = 2
        elseif change == "role" then net.role = "spectate"
        elseif change == "slot" then net.slot = 1
        else net.generation = 3 end
        s.boss, s.players[2].hp = 5, 50; advance(1, true)
        local gen = f.generation; f:observe(true); assert(f.generation > gen); eq(#f:drain(), 0, change)
    end
end)
check("feedback: duplicate and reordered samples cannot move baseline or replay damage", function()
    local _, net, s, f, advance = fixture("client")
    advance(1, true); s.boss = 9; f:observe(true); eq(kind(f:drain(), "boss")[1].amount, 1)
    s.boss = 8; f:observe(true); eq(#f:drain(), 0)
    net.inSeq = 1; s.boss = 10; f:observe(true); eq(#f:drain(), 0)
    net.inSeq = 2; advance(1, true); s.boss = 8; f:observe(true)
    eq(kind(f:drain(), "boss")[1].amount, 1)
end)
check("feedback: skipped sequence suppresses catch-up then accepts timely follow-up", function()
    local _, net, s, f, advance = fixture("client")
    advance(1, true); net.inSeq = net.inSeq + 1; s.boss = 8
    f:observe(true); eq(#f:drain(), 0)
    advance(1, true); s.boss = 7; f:observe(true); eq(kind(f:drain(), "boss")[1].amount, 1)
end)
check("feedback: PRIOR sample age without intermediate render enforces exact 2.5s cutoff", function()
    for _, dt in ipairs({2.499, 2.5, 2.501, 6}) do
        local _, _, s, f, advance = fixture("client")
        advance(dt, true); s.boss = 9; f:observe(true)
        eq(#kind(f:drain(), "boss"), dt <= 2.5 and 1 or 0, "prior age " .. dt)
    end
end)
check("feedback: render loops cannot refresh remote sample age; blackout recovery is silent", function()
    local _, _, s, f, advance = fixture("client")
    for _ = 1, 30 do advance(0.1); f:observe(true) end
    advance(0.1, true); s.boss = 5; f:observe(true); eq(#f:drain(), 0)
    advance(1, true); s.boss = 4; f:observe(true); eq(kind(f:drain(), "boss")[1].amount, 1)
end)
check("feedback: stale current sample and backwards arrival clock fail closed", function()
    local _, net, s, f, advance = fixture("client")
    advance(1, true); net.lastSnapshot = 0; s.boss = 9; f:observe(true); eq(#f:drain(), 0)
    advance(1, true); net.lastSnapshot = 100; s.boss = 8; f:observe(true); eq(#f:drain(), 0)
end)
check("feedback: local no-render stall drops catch-up but current exact act can still hit", function()
    local _, _, s, f, advance = fixture()
    advance(3); s.players[1].hp = 65; s.players[1].x = 2
    assert(f:act("P")); local events = f:drain()
    eq(#kind(events, "hurt"), 0); eq(kind(events, "building")[1].source, "you")
end)
check("feedback: safe same-stage final hit retains one number and exact source", function()
    for _, mode in ipairs({"solo", "client"}) do
        local _, _, s, f, advance = fixture(mode)
        exposed(s); s.boss = 1; s.players[1].x = 4
        if mode == "client" then advance(1, true) end
        f:observe(true); f:drain(); local gen = f.generation
        if mode == "solo" then assert(f:act("P"))
        else advance(1, true); s.boss, s.phase = 0, "clear"; f:observe(true) end
        local boss = kind(f:drain(), "boss"); eq(#boss, 1); eq(boss[1].amount, 1)
        eq(boss[1].source, mode == "solo" and "you" or "team"); assert(f.generation > gen)
        f:observe(true); eq(#f:drain(), 0)
    end
end)
check("feedback: stale final hit, replay and phase reset cannot invent final damage", function()
    local _, _, s, f, advance = fixture("client")
    advance(3, true); s.boss, s.phase = 0, "clear"; f:observe(true); eq(#f:drain(), 0)
    advance(1, true); s.boss, s.phase = 10, "play"; f:observe(true); eq(#f:drain(), 0)
end)
check("feedback: moving boss guidance uses shared reach helper including ground requirement", function()
    local _, _, s, f = fixture()
    exposed(s); s.bossMotion = { phase = "patrol", fromLane = 4, toLane = 5, remaining = 2.5 }
    local p = s.players[1]; p.x = 3
    local g = f:guidance(); eq(g.bossReach, M.bossInReach(s, p)); assert(not g.bossReach)
    assert(string.find(g.text, "10/10 HP", 1, true)); assert(string.find(g.text, "EXPOSED", 1, true))
    p.x = 4; assert(f:guidance().bossReach)
    p.y = 1; assert(not f:guidance().bossReach); assert(string.find(f:guidance().text, "ground", 1, true))
    s.hp[1] = 2; g = f:guidance(); assert(g.bossShielded); assert(string.find(g.text, "1 remaining floors", 1, true))
end)
check("feedback: client guidance is explicitly sampled, never rejection inference", function()
    local _, _, s, f = fixture("client")
    local g = f:guidance(); assert(g.sampled); assert(string.find(g.text, "SAMPLED / estimated", 1, true))
    assert(f:act("P")); eq(#kind(f:drain(), "notice"), 0); eq(s.boss, 10)
end)
check("feedback: Brawl guidance follows lowest eligible in-range slot and immunity", function()
    local _, net, s, f, advance = fixture("host", "brawl")
    member(net, s, 2); member(net, s, 3); member(net, s, 4)
    for slot = 1, 4 do s.players[slot].x, s.players[slot].invuln = 3, 0 end
    s.players[2].protected = true; s.players[3].invuln = 1
    eq(f:guidance().pvpSlot, 4)
    s.players[3].invuln = 0; eq(f:guidance().pvpSlot, 3)
    s.players[2].protected = false; eq(f:guidance().pvpSlot, 2)
    s.players[2].y = 1; eq(f:guidance().pvpSlot, 3)
    s.players[3].x = 7; eq(f:guidance().pvpSlot, 4)
    f:observe(true); assert(f:act("P")); eq(s.players[4].hp, 80)
    eq(kind(f:drain(), "hurt")[1].source, "you"); eq(f:guidance().pvpSlot, nil)
    advance(0.6); s.players[2].y = 0; eq(f:guidance().pvpSlot, 2)
end)
check("feedback: shield/range/ground notices are throttled and not damage", function()
    for _, reason in ipairs({"shield", "range", "ground"}) do
        local _, _, s, f, advance = fixture()
        if reason ~= "shield" then exposed(s) end
        if reason == "ground" then s.players[1].x, s.players[1].y = 4, 1 end
        f:observe(true); f:drain()
        assert(f:act("P")); local events = f:drain(); eq(#kind(events, "notice"), 1)
        eq(#kind(events, "boss"), 0); eq(#kind(events, "building"), 0)
        advance(0.21); assert(f:act("P")); eq(#kind(f:drain(), "notice"), 0)
        advance(1.2); assert(f:act("P")); eq(#kind(f:drain(), "notice"), 1)
    end
end)
check("feedback: local rate-limit rejection preserves false result with no swing/contact", function()
    local _, net, s, f = fixture()
    s.players[1].x = 2; net.lastLocalAction = 9.9
    eq(f:act("P"), false); local events = f:drain()
    eq(#events, 1); eq(events[1].kind, "notice"); assert(string.find(events[1].text, "cooldown", 1, true))
    eq(s.hp[1], 2)
end)
check("feedback: queue and 25-actor scan stay bounded with local priority", function()
    local _, net, s, f = fixture("host")
    for slot = 2, 25 do member(net, s, slot) end
    net.slot = 25; f:observe(true)
    for slot = 1, 25 do s.players[slot].hp = 80 end
    f:observe(true); local events = f:drain()
    eq(#events, F.MAX_TEAM_EVENTS + 1); eq(events[1].slot, 25); assert(events[1].localActor)
    for _ = 1, 100 do f:push({ kind = "swing", at = 10, localActor = true }) end
    eq(#f:drain(), 32); eq(#f:drain(), 0)
end)
check("feedback: expired queue, hide and reset remove evidence and bump generation", function()
    local _, _, s, f, advance = fixture()
    s.players[1].hp = 80; f:observe(true); advance(3); eq(#f:drain(), 0)
    local gen = f.generation; f:observe(false); assert(f.generation > gen); eq(#f:drain(), 0)
    gen = f.generation; f:observe(false); eq(f.generation, gen)
end)
check("feedback: reduced motion does not suppress truthful static damage evidence", function()
    local app, _, s, f = fixture(); app.db.reducedMotion = true
    s.players[1].hp = 65; f:observe(true); eq(kind(f:drain(), "hurt")[1].amount, 35)
end)
check("feedback: member removal clears queued old-occupant evidence and active generation", function()
    local _, net, s, f = fixture("host")
    member(net, s, 2); f:observe(true)
    s.players[2].hp = 80; f:observe(true); local gen = f.generation
    net.participants[2] = nil; M.removePlayer(s, 2); net:rebuildMembers(); f:observe(true)
    assert(f.generation > gen); eq(#f:drain(), 0)
end)
check("feedback: stale repeated renders clear once rather than reset every frame", function()
    local _, _, _, f, advance = fixture("client")
    advance(3); f:observe(true); local gen = f.generation
    for _ = 1, 100 do f:observe(true) end
    eq(f.generation, gen)
end)
check("feedback: reorder with older model time cannot poison the accepted baseline", function()
    local _, net, s, f, advance = fixture("client")
    advance(1, true); s.boss = 9; f:observe(true); f:drain()
    local gen = f.generation; net.inSeq, s.time, s.boss = 1, 0, 10; f:observe(true)
    eq(f.generation, gen); eq(#f:drain(), 0)
    net.inSeq, s.time = 2, 1; advance(1, true); s.boss = 8; f:observe(true)
    eq(kind(f:drain(), "boss")[1].amount, 1)
end)
check("feedback: known Brawl cooldown is captured before action, never guessed afterward", function()
    local _, _, s, f, advance = fixture("solo", "brawl")
    s.players[1].nextPunch = s.time + 0.6
    assert(f:act("P")); local notices = kind(f:drain(), "notice")
    eq(#notices, 1); eq(notices[1].text, "Brawl punch cooldown")
    advance(1.3); assert(f:act("P")); notices = kind(f:drain(), "notice")
    eq(#notices, 1); eq(notices[1].text, "Boss shielded — destroy remaining floors")
end)
check("feedback: nonlocal KO clears stale effect generation even on exact local punch", function()
    local _, net, s, f = fixture("host", "brawl")
    member(net, s, 2); s.players[1].x, s.players[2].x = 3, 3
    s.players[2].hp, s.players[2].invuln = 20, 0; f:observe(true)
    local gen = f.generation; assert(f:act("P")); assert(f.generation > gen)
    local hurt = kind(f:drain(), "hurt"); eq(#hurt, 1); eq(hurt[1].amount, 20); eq(hurt[1].source, "you")
end)
check("feedback: synchronous hidden observation wins without dropping action result", function()
    local _, net, s, f = fixture()
    s.players[1].x = 2
    net.env.changed = function() f:observe(false) end
    assert(f:act("P")); eq(s.hp[1], 1); eq(#f:drain(), 0); eq(f.visible, false)
end)
check("feedback: raid-wide burst retains boss readability and local incoming damage", function()
    local _, net, s, f = fixture("host")
    for slot = 2, 25 do member(net, s, slot) end
    net.slot = 25; f:observe(true)
    for slot = 1, 25 do s.players[slot].hp = 80 end
    s.boss = 8; f:observe(true); local events = f:drain()
    eq(#events, 9); eq(#kind(events, "boss"), 1)
    local localHurt = false
    for _, e in ipairs(events) do if e.kind == "hurt" and e.localActor then localHurt = true end end
    assert(localHurt)
end)
check("feedback: expired undrained team bursts cannot starve fresh evidence", function()
    local _, _, s, f, advance = fixture()
    for i = 1, 8 do f:push({ kind = "building", at = 10, amount = 1, source = "team", index = i }) end
    advance(3); f:push({ kind = "boss", at = 13, amount = 1, source = "team" })
    local events = f:drain(); eq(#events, 1); eq(events[1].kind, "boss")
    eq(s.boss, 10)
end)
check("feedback: hidden callback remains sticky through another synchronous callback", function()
    local _, net, s, f = fixture()
    s.players[1].x = 2
    net.env.changed = function() f:observe(false); f:observe(true) end
    assert(f:act("P")); eq(#f:drain(), 0); eq(f.visible, false)
end)
check("feedback: immutable numeric snapshots survive in-place model mutation", function()
    local _, _, s, f = fixture()
    local before = f.baseline; s.players[1].hp, s.hp[1], s.boss = 50, 0, 8
    eq(before.players[1].hp, 100); eq(before.hp[1], 2); eq(before.boss, 10)
    f:observe(true); local events = f:drain(); eq(#events, 3)
    eq(s.players[1].hp, 50); eq(s.hp[1], 0); eq(s.boss, 8); eq(s.players[1].score, 0)
end)
