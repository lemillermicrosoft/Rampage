-- Optional external provider only. No redistributed audio, settings hooks, volume
-- CVars or claimed per-call volume control. The provider owns remapping/None/gain.
local _, addon = ...
local Sound = {}
addon.Sound = Sound
local roles = { punch = "crit", collapse = "combatStart", boss = "levelUp", victory = "levelUp", stage = "combatStart" }
local gaps = { punch = 1.3, collapse = 2.2, boss = 2.3, victory = 2.3, stage = 2.2 }
function Sound.create(app)
    local self = { app = app, last = {}, nextAny = 0, status = "Sound off", seen = {} }
    function self:enabled()
        return app.db.useBlasterMaster == true and app.db.muted ~= true
    end
    function self:cue(cue)
        local now = app.now()
        if not self:enabled() then self.status = "Sound off"; return false end
        if not roles[cue] or now < self.nextAny or (self.last[cue] and now - self.last[cue] < gaps[cue]) then return false end
        -- Reserve the throttle even on failure: never hammer a missing/broken provider.
        self.last[cue], self.nextAny = now, now + (cue == "punch" and 1.3 or 2.2)
        if type(BlasterMaster_GetSfxPath) ~= "function" then self.status = "BlasterMaster not loaded — muted"; return false end
        local ok, path = pcall(BlasterMaster_GetSfxPath, roles[cue])
        if not ok or type(path) ~= "string" or path == "" or string.lower(path) == "none" then
            self.status = "Provider cue disabled / unavailable"; return false
        end
        if type(PlaySoundFile) ~= "function" then self.status = "Sound API unavailable"; return false end
        local played, success = pcall(PlaySoundFile, path, "SFX")
        if not played or not success then self.status = "SFX unavailable / disabled"; return false end
        self.status = "Local BlasterMaster • SFX channel"
        return true
    end
    function self:observe(visible)
        local net, now = app.net, app.now()
        local s = net.state
        if not s then self.baseline, self.seen, self.session = nil, {}, nil; return end
        local identity = (net.sid or net.mode) .. ":" .. (net.hostName or net.name or "local")
        local prev = self.baseline
        -- Defense in depth: the protocol rejects old snapshots; audio does too.
        if prev and identity == self.session and (net.inSeq or 0) < (prev.seq or 0) then return end
        local reset = identity ~= self.session or not prev
        -- Replay is an actual progression reset. A late join only establishes baseline.
        if prev and (s.stage < prev.stage or (prev.phase == "victory" and s.phase == "play")) then reset = true end
        if reset then self.seen = {} end
        local fresh = not reset and prev.visible and visible and now - prev.at <= 1.5
            and (net.inSeq or 0) >= (prev.seq or 0)
        local major
        if fresh then
            if s.phase == "victory" and prev.phase ~= "victory" then major = "victory"
            elseif s.phase == "clear" and prev.phase ~= "clear" then major = "boss"
            elseif s.stage ~= prev.stage then major = "stage" end
            local key = tostring(s.stage) .. ":" .. tostring(s.phase)
            if major and not self.seen[key] then self.seen[key] = true; self:cue(major) end
            if not major and net.role ~= "spectate" then
                for tower = 1, 3 do
                    local alive = addon.Model.towerAlive(s, tower)
                    local collapseKey = tostring(s.stage) .. ":tower:" .. tower
                    if prev.towers[tower] and not alive and not self.seen[collapseKey] then
                        self.seen[collapseKey] = true; major = "collapse"; self:cue("collapse"); break
                    end
                end
                local p = net.slot and s.players[net.slot]
                if not major and s.stage == prev.stage and s.phase == "play" and p and prev.slot == net.slot
                    and prev.hit ~= nil and p.hit ~= prev.hit then self:cue("punch") end
            end
        end
        local p = net.slot and s.players[net.slot]
        self.session = identity
        self.baseline = { stage = s.stage, phase = s.phase, at = now, visible = visible, seq = net.inSeq or 0,
            slot = net.slot, hit = p and p.hit, towers = {} }
        for tower = 1, 3 do self.baseline.towers[tower] = addon.Model.towerAlive(s, tower) end
        if not self:enabled() then self.status = "Sound off" end
    end
    return self
end
