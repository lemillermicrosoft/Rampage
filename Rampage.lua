-- WoW adapter only: group identity, addon channel, persistence and combat safety.
-- TOC order: Model.lua, Protocol.lua, Feedback.lua, Input.lua, Sound.lua, UI.lua, Rampage.lua.
local addonName, addon = ...
local app = { now = function() return GetTime() end }
app.VERSION = "0.6.0" -- Kept in sync with the TOC by the release packager.
addon.App = app
local frame = CreateFrame("Frame")
local function localMessage(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffaa44Rampage|r: " .. message) end
end
local function realmName()
    return (GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or ""):gsub("%s", "")
end
local function canonical(name, realm)
    if not name or name == "" then return nil end
    local character, includedRealm = string.match(name, "^([^-]+)%-(.+)$")
    if character then return character .. "-" .. includedRealm:gsub("%s", "") end
    return name .. "-" .. ((realm and realm ~= "" and realm or realmName()):gsub("%s", ""))
end
local function unitIdentity(unit)
    local name, realm
    if UnitFullName then name, realm = UnitFullName(unit) else name, realm = UnitName(unit) end
    return canonical(name, realm)
end
local function channel()
    if IsInRaid() then return "RAID" elseif IsInGroup() then return "PARTY" end
end
function app.refreshRoster()
    if not app.net then return end
    local roster = { [app.net.name] = true }
    app.rosterUnits = { [app.net.name] = "player" }
    if IsInRaid() then
        for i = 1, math.min(40, GetNumGroupMembers()) do
            local unit="raid" .. i
            local name = unitIdentity(unit); if name then roster[name] = true; app.rosterUnits[name]=unit end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local unit="party" .. i
            local name = unitIdentity(unit); if name then roster[name] = true; app.rosterUnits[name]=unit end
        end
    end
    app.net:setRoster(roster, app.networkEnabled and channel() ~= nil)
end
function app.persist()
    if not app.net or not app.db then return end
    local s, slot = app.net.state, app.net.slot
    local p = s and slot and s.players[slot]
    if p and p.score > app.db.best then app.db.best = p.score end
end
local serial = 0
local function newToken()
    serial = (serial + 1) % 65536
    -- Session identifier, not a credential. Actual sender/roster checks are the trust boundary.
    return string.format("%x%x%x", GetServerTime() % 16777216, math.random(0, 65535), serial)
end

local function sanitizeDB(db)
    if type(db) ~= "table" then db = {} end
    if type(db.best) ~= "number" or db.best ~= db.best or db.best < 0 or db.best > 99999 then db.best = 0 end
    db.best = math.floor(db.best)
    db.useBlasterMaster = db.useBlasterMaster == true
    db.muted = db.muted == true
    db.reducedMotion = db.reducedMotion == true
    -- Existing explicit Mouse/Keyboard choices survive. Fresh, nil and invalid
    -- legacy values intentionally migrate to the new Keyboard default.
    if db.controlMode ~= "mouse" and db.controlMode ~= "keyboard" then db.controlMode = "keyboard" end
    return db
end
app.sanitizeDB = sanitizeDB
function app.applyPreferredCapture()
    if not app.captureAfterJoin or not app.input or app.net.requestedRole ~= nil then return false end
    if app.net.role == "play" and app.input:canPlay() then
        app.captureAfterJoin = false; return app.input:grab()
    end
    if app.net.mode ~= "joining" and app.net.role == "spectate" then app.captureAfterJoin = false end
    return false
end
local function initialize()
    if app.net then return end
    app.db = RampageDB
    local name = unitIdentity("player")
    if not name then return end
    local register = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
    local send = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    app.networkEnabled = register and send and register(addon.Protocol.PREFIX) ~= false or false
    app.net = addon.Protocol.new({ name = name, now = app.now, token = newToken,
        -- Read-only fallback protects real group members even when their combat
        -- notify is still queued. AI names are never placed in the WoW roster.
        inCombat = function(memberName)
            local unit=app.rosterUnits and app.rosterUnits[memberName]
            return unit and UnitAffectingCombat and UnitAffectingCombat(unit) or false
        end,
        send = function(payload)
            local distribution = channel()
            if app.networkEnabled and distribution and #payload <= 255 then
                send(addon.Protocol.PREFIX, payload, distribution)
            end
        end,
        changed = function()
            app.persist()
            if app.input then
                if not app.input:canCapture() then app.input:release("Game changed - keys released")
                else app.input:syncPhase() end
                -- Preference alone never joins or captures. Only an explicit
                -- successful Join fight arms this one-shot activation, and only
                -- the accepted play role may consume it. Safety release after
                -- activation cannot re-arm itself.
                app.applyPreferredCapture()
            end
            if app.sound then app.sound:observe(addon.UI.root and addon.UI.root:IsShown() or false) end
            if app.feedback then app.feedback:observe(addon.UI.root and addon.UI.root:IsShown() or false) end
        end })
    app.feedback = addon.Feedback.create(app)
    app.sound = addon.Sound.create(app)
    app.refreshRoster()
    app.net:setCombat(InCombatLockdown())
    if not app.networkEnabled then app.net:notice("Addon messaging unavailable; solo practice still works.") end
end

-- User-intent gate: discovery/auto-watch only while explicitly opened and visible.
-- Closing hides but retains admitted membership/host tenure. Leave suppresses rejoin
-- until a fresh user open/Watch action; combat window restoration is not user intent.
local function visible() return addon.UI.root and addon.UI.root:IsShown() end
local function draw() if addon.UI.root then addon.UI.render() end end
local function knownRoom()
    local list = app.net:lobbyList()
    for _, room in ipairs(list) do
        if room.name == app.watchHost and room.sid == app.watchSid then return room end
    end
    -- Existing discovery records have no shared creation clock; use deterministic
    -- name/session order only when no sticky selected/admitted room exists.
    table.sort(list, function(a,b) if a.name==b.name then return a.sid<b.sid end return a.name<b.name end)
    return list[1]
end
local function showWindow()
    if not app.net or app.net.combat then return false end
    addon.UI.create(app):Show(); draw(); return true
end
function app.updateWatch()
    local net, now = app.net, app.now()
    if not net or not app.watchEnabled or not visible() or net.combat or not net.grouped or net.mode~="idle" then return end
    if now < (app.nextWatchAttempt or 0) then return end
    local room = knownRoom()
    if room and now >= (app.watchCollectUntil or 0) then
        app.watchHost,app.watchSid=room.name,room.sid
        local humans=(room.count or 0)-(room.bots or 0)+(room.spectators or 0)
        if humans>=40 then
            app.nextWatchAttempt=now+5
            if app.watchFullRoom~=room.sid then app.watchFullRoom=room.sid; net:notice("Room full • watching needs a free participant seat") end
            return
        end
        app.watchFullRoom=nil; app.nextWatchAttempt=now+5
        net:join(room.name,room.sid,"spectate",room.mode)
        return
    end
    app.nextWatchAttempt=now+1
    if now >= (app.nextWatchDiscover or 0) then
        app.nextWatchDiscover=now+4
        net:discover()
    end
end
function app.watch()
    if not app.net or app.net.combat then return false end
    app.watchEnabled=true; app.watchFullRoom=nil
    app.nextWatchAttempt,app.nextWatchDiscover=0,0
    app.watchCollectUntil=app.now()+0.75
    if not showWindow() then return false end
    app.updateWatch(); return true
end
function app.openWindow()
    return app.watch()
end
function app.hostGame()
    local net=app.net
    if not net or net.combat or net.mode~="idle" or not net.grouped then return false end
    local room=knownRoom()
    if room then
        app.watchHost,app.watchSid=room.name,room.sid
        app.watch(); app.watchCollectUntil=0; app.nextWatchAttempt=0; app.updateWatch()
        return false -- an established room wins over another local Host click
    end
    app.watchEnabled=true
    local result=net:host("brawl")
    if result then app.watchHost,app.watchSid=net.hostName,net.sid; showWindow() end
    return result
end
function app.soloGame()
    local net=app.net
    if not net or net.combat or net.mode~="idle" then return false end
    app.watchEnabled=false
    local result=net:solo("brawl")
    if result then showWindow() end
    return result
end
function app.joinFight()
    local net=app.net
    if not net or net.combat or net.leaving or net.migrationActive then return false end
    app.captureAfterJoin = app.input and app.input.preference == "keyboard" or false
    if app.input then app.input:release(app.captureAfterJoin and "Keyboard preferred • waiting for fighter role" or "Mouse preferred • joining fight") end
    local result=false
    if net.mode=="client" or net.mode=="host" or net.mode=="solo" then
        if not net.state or net.state.mode~="brawl" then net:notice("Legacy Co-op room • watch only in this build"); return false end
        if net.role=="spectate" and net:count()>=25 and net:botCount()==0 then net:notice("Fight full • you remain watching"); return false end
        if net.role=="spectate" then result=net:setRole("play") end
    elseif net.mode=="idle" then
        local room=knownRoom()
        if not room or room.mode~="brawl" then return false end
        if (room.count or 0)>=25 and (room.bots or 0)==0 then app.watch(); return false end
        app.watchHost,app.watchSid,app.watchEnabled=room.name,room.sid,true
        result=net:join(room.name,room.sid,"play","brawl")
    end
    if not result then app.captureAfterJoin=false end
    draw(); return result
end
function app.leaveFight()
    local net=app.net
    if not net or (net.mode~="client" and net.mode~="host" and net.mode~="solo") or net.role~="play" or net.combat then return false end
    app.captureAfterJoin=false
    if app.input then app.input:release(app.input.preference=="keyboard" and "Keyboard preferred • watching • no captured keys" or "Mouse preferred • watching") end
    local result=net:setRole("spectate"); draw(); return result
end
function app.leaveGame()
    if not app.net then return false end
    app.watchEnabled=false; app.watchHost,app.watchSid,app.watchFullRoom=nil,nil,nil
    app.captureAfterJoin=false
    if app.input then app.input:release(app.input.preference=="keyboard" and "Left game • Keyboard preferred, inactive" or "Left game • Mouse preferred") end
    if app.feedback then app.feedback:observe(false) end
    app.persist(); app.net:leave(); draw(); return true
end
local function slash(input)
    if not app.net then localMessage("Still loading; try again after entering the world."); return end
    local command, argument=string.match(input or "", "^%s*(%S*)%s*(.-)%s*$")
    command,argument=string.lower(command or ""),string.lower(argument or "")
    if command=="help" or command=="info" or command=="settings" then
        if app.openWindow() and addon.UI.setPanel then addon.UI.setPanel(command=="settings" and "settings" or "info") end
    elseif command=="leave" then app.leaveGame()
    elseif command=="solo" or command=="host" then
        if argument~="" and argument~="brawl" then localMessage("This build exposes Brawl only. Co-op remains internal, not a public mode switch."); return end
        if command=="host" then app.refreshRoster(); app.hostGame() else app.soloGame() end
    elseif command=="find" or command=="watch" or command=="spectate" then
        if app.net.role=="play" and app.net.mode~="idle" then app.leaveFight() end
        app.watch()
    elseif command=="join" or command=="play" then
        -- Explicit public command requests Brawl participation, never key capture.
        app.joinFight(); showWindow()
    elseif command=="start" then
        if (app.net.mode=="host" or app.net.mode=="solo") and app.net.state and app.net.state.mode=="brawl" then app.net:start(); showWindow() end
    else
        if visible() then addon.UI.root:Hide() else app.openWindow() end
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
frame:RegisterEvent("UI_SCALE_CHANGED")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= addonName then return end
        RampageDB = sanitizeDB(RampageDB)
        SLASH_RAMPAGE1 = "/rampage"; SlashCmdList.RAMPAGE = slash
        frame:UnregisterEvent("ADDON_LOADED")
        if IsLoggedIn and IsLoggedIn() then initialize() end
    elseif event == "PLAYER_LOGIN" then
        initialize(); app.refreshRoster()
    elseif event == "GROUP_ROSTER_UPDATE" then
        app.refreshRoster()
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, payload, distribution, sender = ...
        if app.net and prefix == addon.Protocol.PREFIX and distribution == channel()
            and (distribution == "PARTY" or distribution == "RAID") then
            app.net:receive(canonical(sender), payload)
        end
    elseif event == "PLAYER_LEAVING_WORLD" then
        app.captureAfterJoin=false
        if app.input then app.input:release("Leaving world - keys released") end
        if app.feedback then app.feedback:observe(false) end
        app.persist()
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        addon.UI.fit()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if app.net then
            local active = event == "PLAYER_REGEN_DISABLED"
            app.net:setCombat(active); addon.UI.combat(active)
        end
    end
end)
local elapsedNet, elapsedUI = 0, 0
frame:SetScript("OnUpdate", function(_, elapsed)
    if not app.net then return end
    if app.input then app.input:update(elapsed) end -- every frame: chat/focus/combat safety
    addon.UI.update(elapsed)
    elapsedNet, elapsedUI = elapsedNet + elapsed, elapsedUI + elapsed
    if elapsedNet >= 0.05 then
        app.updateWatch()
        app.net:tick(elapsedNet); elapsedNet = 0; app.persist(); app.applyPreferredCapture()
        if app.sound then app.sound:observe(addon.UI.root and addon.UI.root:IsShown() or false) end
        if app.feedback then app.feedback:observe(addon.UI.root and addon.UI.root:IsShown() or false) end
    end
    if elapsedUI >= 0.033 then elapsedUI = 0; addon.UI.render() end
end)
