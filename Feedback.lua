-- Local presentation evidence only: immutable HP samples, no gameplay or wire writes.
local _, addon = ...
local M = addon.Model
local Feedback = { MAX_EVENTS = 32, MAX_TEAM_EVENTS = 8, MAX_AGE = 2.5 }
addon.Feedback = Feedback
local function localAuthority(net) return net.mode == "solo" or net.mode == "host" end
local function active(net, s)
    return s and not net.combat and not s.paused and net.mode ~= "idle" and net.mode ~= "joining"
        and (s.phase == "play" or s.phase == "clear" or s.phase == "victory")
end
-- Member records and snapshots arrive independently. Never attach a stale name to
-- a reused numeric slot. Unknown/mismatched membership suppresses actor deltas.
local function identities(net, s)
    local ids = {}
    for id = 1, 40 do
        local m = net.participants and net.participants[id]
        if m and m.slot and s.players[m.slot] and not s.players[m.slot].bot
            and (not s._mapping or s._mapping[id] == m.slot)
            and (not s._revision or (net.memberVersions and net.memberVersions[id] or 0) <= s._revision) then
            ids[m.slot] = table.concat({ "member", id, m.name or "", m.generation or 0, m.roleSeq or 0 }, ":")
        end
    end
    for slot = 1, M.MAX_PLAYERS do
        local p = s.players[slot]
        if p and p.bot and p.botID then
            local b = net.bots and net.bots[slot]
            ids[slot] = "bot:" .. p.botID .. ":" .. (b and b.order or 0)
        end
    end
    return ids
end
local function capture(net, s, now)
    local p, ids = {}, identities(net, s)
    for slot = 1, M.MAX_PLAYERS do
        local a = s.players[slot]
        if a then p[slot] = { hp = a.hp or M.MAX_HP, ko = a.ko or 0, x = a.x, y = a.y,
            id = ids[slot], protected = a.protected == true } end
    end
    local hp = {}; for i = 1, 9 do hp[i] = s.hp[i] or 0 end
    local own = net.slot and p[net.slot]
    return { players = p, hp = hp, boss = s.boss, bossX = M.bossPosition(s), stage = s.stage, phase = s.phase,
        time = s.time or 0, at = now, sampleAt = net.lastSnapshot, seq = net.inSeq or 0,
        epoch = s._epoch or net.inputEpoch, mode = net.mode, gameMode = s.mode, sid = net.sid,
        host = net.hostName or net.name, role = net.role, requestedRole = net.requestedRole,
        roleSeq = net.acceptedRoleSeq or net.roleSeq, slot = net.slot, memberGeneration = net.generation,
        ownID = own and own.id, ownKO = own and own.ko > 0 or false }
end
local function lifecycle(a, b)
    return a.mode ~= b.mode or a.gameMode ~= b.gameMode or a.sid ~= b.sid or a.host ~= b.host
        or a.epoch ~= b.epoch or a.stage ~= b.stage or a.role ~= b.role or a.requestedRole ~= b.requestedRole
        or a.roleSeq ~= b.roleSeq or a.slot ~= b.slot or a.memberGeneration ~= b.memberGeneration
        or a.ownID ~= b.ownID or b.time < a.time
end
local function phaseFinish(a, b)
    return a.phase == "play" and (b.phase == "clear" or b.phase == "victory")
        and a.boss > 0 and b.boss == 0
end
local function priority(e) return e.localActor or e.source == "you" or e.kind == "notice" or e.kind == "swing" end
function Feedback.create(app)
    local self = { generation = 0, queue = {}, teamEvents = 0, visible = false, inAction = false, nextNotice = 0 }
    app.feedback = self
    function self:reset()
        self.generation = self.generation + 1
        self.baseline, self.queue, self.teamEvents, self.nextNotice = nil, {}, 0, 0
        self.stale = false
    end
    function self:push(e)
        -- Undrained evidence is useful only briefly. Purge before applying the
        -- burst cap so a paused consumer cannot starve the next fresh event.
        local now = app.now()
        for i = #self.queue, 1, -1 do
            local old = self.queue[i]
            if now < old.at or now - old.at > Feedback.MAX_AGE then
                if not priority(old) then self.teamEvents = self.teamEvents - 1 end
                table.remove(self.queue, i)
            end
        end
        local important = priority(e)
        if not important and self.teamEvents >= Feedback.MAX_TEAM_EVENTS then return end
        if #self.queue >= Feedback.MAX_EVENTS then
            if not important then return end
            local index = 1
            for i, old in ipairs(self.queue) do if not priority(old) then index = i; break end end
            if not priority(self.queue[index]) then self.teamEvents = self.teamEvents - 1 end
            table.remove(self.queue, index)
        end
        self.queue[#self.queue + 1] = e
        if not important then self.teamEvents = self.teamEvents + 1 end
    end
    function self:drain()
        local out, now = {}, app.now()
        for _, e in ipairs(self.queue) do
            if now >= e.at and now - e.at <= Feedback.MAX_AGE then out[#out + 1] = e end
        end
        self.queue, self.teamEvents = {}, 0
        return out
    end
    function self:delta(before, after, source, onlyBoss)
        local now, own = app.now(), app.net.slot
        -- Reserve room for boss readability even during a raid-wide hurt burst.
        if after.boss < before.boss then
            self:push({ kind = "boss", at = now, amount = before.boss - after.boss, source = source,
                x = after.phase == "play" and after.bossX or before.bossX, y = 0 })
        end
        -- Local incoming damage always bypasses the restrained team-event cap.
        local function hurt(slot)
            local a, b = before.players[slot], after.players[slot]
            if a and b and a.id and a.id == b.id and a.ko == 0 and not a.protected and not b.protected and b.hp < a.hp then
                self:push({ kind = "hurt", at = now, amount = a.hp - b.hp, slot = slot,
                    localActor = slot == own, source = source, x = b.x, y = b.y })
            end
        end
        if not onlyBoss then
            if own then hurt(own) end
            for slot = 1, M.MAX_PLAYERS do if slot ~= own then hurt(slot) end end
        end
        if not onlyBoss then
            for index = 1, 9 do
                if after.hp[index] < before.hp[index] then
                    self:push({ kind = "building", at = now, amount = before.hp[index] - after.hp[index],
                        source = source, index = index, x = M.TOWERS[math.floor((index - 1) / 3) + 1], y = (index - 1) % 3 + 1 })
                end
            end
        end
    end
    function self:observe(visible)
        -- Protocol.action synchronously calls changed. Its observation must not
        -- consume exact before/after evidence and relabel it as TEAM.
        if self.inAction then
            if self.deferredVisible ~= false then self.deferredVisible = visible end
            return
        end
        local net, now = app.net, app.now()
        local s = net and net.state
        if not visible or not net or not active(net, s) then
            if self.visible or self.baseline or #self.queue > 0 then self:reset() end
            self.visible = false
            return
        end
        local after = capture(net, s, now)
        local before = self.baseline
        if not self.visible or not before then
            self:reset(); self.visible, self.baseline = true, after; return
        end
        local remote = not localAuthority(net)
        -- A reordered sample is never allowed to roll back clocks/epochs or
        -- actor identity. Real role/session changes still take precedence.
        local sameSession = before.mode == after.mode and before.sid == after.sid and before.host == after.host
            and before.memberGeneration == after.memberGeneration and before.role == after.role and before.slot == after.slot
        if remote and sameSession and after.seq < before.seq then return end
        if lifecycle(before, after) then self:reset(); self.baseline = after; return end
        -- Check the PREVIOUS arrival timestamp before replacing it. Repeated
        -- renders cannot keep a remote sample young, including no-render stalls.
        local priorAt = remote and before.sampleAt or before.at
        local stale = not priorAt or now < priorAt or now - priorAt > Feedback.MAX_AGE
        local currentStale = remote and (not after.sampleAt or now < after.sampleAt or now - after.sampleAt > Feedback.MAX_AGE)
        if currentStale then stale = true end
        if stale then
            if not self.stale then self:reset() end
            -- A new, fresh arrival closes the blackout but contributes no delta.
            self.baseline, self.stale = after, remote and (currentStale or after.seq == before.seq) or false
            return
        end
        if self.stale then
            -- First genuinely fresh sample after a blackout is a baseline too.
            self.baseline = after
            if not remote or after.seq > before.seq then self.stale = false end
            return
        end
        if remote and after.seq == before.seq then
            -- Membership can change between snapshots: invalidate affected actors
            -- now, not after a replacement actor's HP has already been compared.
            local changed = false
            for slot = 1, M.MAX_PLAYERS do
                local a, b = before.players[slot], after.players[slot]
                if (a and a.id) ~= (b and b.id) then before.players[slot] = b; changed = true end
            end
            if changed then
                -- Also discard undrained evidence and active UI effects belonging
                -- to a former occupant, including one removed between renders.
                self.generation, self.queue, self.teamEvents = self.generation + 1, {}, 0
            end
            if before.ownKO ~= after.ownKO then self:reset(); self.baseline = after end
            return
        end
        if remote and after.seq ~= before.seq + 1 then self:reset(); self.baseline = after; return end
        local finish = phaseFinish(before, after)
        if before.phase ~= after.phase then
            self:reset(); self.baseline = after
            if finish then self:delta(before, after, "team", true) end
            return
        end
        local actorChange = before.ownKO ~= after.ownKO
        for slot = 1, M.MAX_PLAYERS do
            local a, b = before.players[slot], after.players[slot]
            if (a and a.id) ~= (b and b.id) or (a and b and (a.ko > 0) ~= (b.ko > 0)) then actorChange = true end
        end
        if actorChange then self:reset() end
        if after.phase == "play" then self:delta(before, after, "team") end
        self.baseline = after
    end
    function self:guidance()
        local net = app.net
        local s = net and net.state
        local sampled = net and not localAuthority(net) or false
        local g = { text = "Join a game to see boss health.", sampled = sampled, bossReach = false, bossShielded = false }
        if not s then return g end
        local p = net.slot and s.players[net.slot]
        local floors = 0; for i = 1, 9 do if (s.hp[i] or 0) > 0 then floors = floors + 1 end end
        g.bossShielded, g.bossReach = M.cityAlive(s), M.bossInReach(s, p)
        local prefix = sampled and "SAMPLED / estimated • " or ""
        local instruction
        if g.bossShielded then instruction = "SHIELDED • destroy " .. floors .. " remaining floors"
        elseif not p then instruction = "EXPOSED • ground punches within moving boss range"
        elseif p.y ~= 0 then instruction = "EXPOSED • get to ground level"
        elseif not g.bossReach then instruction = "EXPOSED • move within 1 lane of boss"
        else instruction = "EXPOSED • in ground range — punch!" end
        g.text = prefix .. "BOSS " .. (s.boss or 0) .. "/" .. (8 + s.stage * 2) .. " HP • " .. instruction
        if s.mode == "brawl" then
            local canPunch = p and (p.ko or 0) == 0 and not p.protected and not s.paused and s.phase == "play"
            if localAuthority(net) and canPunch and ((p.nextPunch and s.time + 0.00001 < p.nextPunch)
                or (p.nextAction and s.time + 0.00001 < p.nextAction)
                or (net.lastLocalAction and app.now() - net.lastLocalAction < 0.2)) then canPunch = false end
            if canPunch then
                for slot = 1, M.MAX_PLAYERS do
                    local q = s.players[slot]
                    if slot ~= net.slot and q and q.y == p.y and math.abs(q.x - p.x) <= 1
                        and not q.protected and (q.ko or 0) == 0 and (q.invuln or 0) <= 0 then g.pvpSlot = slot; break end
                end
            end
            g.text = g.text .. " • BRAWL: lowest eligible slot first"
                .. (g.pvpSlot and (" (#" .. g.pvpSlot .. ")") or " (same height, within 1 lane)")
        end
        return g
    end
    function self:notice(text)
        local now = app.now()
        if now < self.nextNotice then return end
        self.nextNotice = now + 1.2
        self:push({ kind = "notice", at = now, text = text, localActor = true })
    end
    function self:act(action)
        local net, now = app.net, app.now()
        -- Observe prior unrelated damage first, before this action can claim any
        -- credit. Input's capture checks remain entirely owned by Input.lua.
        self:observe(self.visible)
        local s = net.state
        local before = self.visible and active(net, s) and capture(net, s, now) or nil
        local p = s and net.slot and s.players[net.slot]
        local eligible = before and s.phase == "play" and net.role == "play" and p and not p.protected and (p.ko or 0) == 0
        local cooldown = eligible and ((net.lastLocalAction and now - net.lastLocalAction < 0.2)
            or (localAuthority(net) and p.nextAction and s.time + 0.00001 < p.nextAction))
        local pvpCooldown = eligible and localAuthority(net) and s.mode == "brawl" and p.nextPunch
            and s.time + 0.00001 < p.nextPunch
        local guidance = eligible and action == "P" and self:guidance() or nil
        local x, y = p and p.x, p and p.y
        self.inAction, self.deferredVisible = true, nil
        local result = net:action(action) -- exactly once; a successful client send is NOT damage evidence
        self.inAction = false
        if self.deferredVisible == false then self.deferredVisible = nil; self:observe(false); return result end
        self.deferredVisible = nil
        local after = before and net.state and capture(net, net.state, app.now()) or nil
        if after and not lifecycle(before, after) then
            if localAuthority(net) then
                local finish = phaseFinish(before, after)
                local reset = before.phase ~= after.phase or before.ownKO ~= after.ownKO
                for slot = 1, M.MAX_PLAYERS do
                    local a, b = before.players[slot], after.players[slot]
                    if (a and a.id) ~= (b and b.id) or (a and b and (a.ko > 0) ~= (b.ko > 0)) then reset = true end
                end
                if reset then self:reset() end
                if before.phase == after.phase or finish then self:delta(before, after, "you", finish) end
                self.baseline = after
            else
                self:observe(self.visible)
            end
            if eligible and action == "P" then
                if result and not cooldown then
                    self:push({ kind = "swing", at = now, slot = net.slot, localActor = true, x = x, y = y })
                end
                if cooldown then self:notice("Punch cooldown — try again shortly")
                elseif localAuthority(net) then
                    local contact = after.boss < before.boss
                    for i = 1, 9 do if after.hp[i] < before.hp[i] then contact = true end end
                    for slot = 1, M.MAX_PLAYERS do
                        local a, b = before.players[slot], after.players[slot]
                        if a and b and a.id and a.id == b.id and b.hp < a.hp then contact = true end
                    end
                    if result and not contact and guidance then
                        if pvpCooldown then self:notice("Brawl punch cooldown")
                        elseif guidance.bossShielded then self:notice("Boss shielded — destroy remaining floors")
                        elseif y ~= 0 then self:notice("Boss needs a ground-level punch")
                        elseif not guidance.bossReach then self:notice("Out of boss range — move closer") end
                    end
                end
                -- Remote guidance stays explicitly sampled/persistent; no invented
                -- host rejection, hit, number or immunity/cooldown acknowledgement.
            end
        elseif before then self:observe(self.visible) end
        return result
    end
    return self
end
