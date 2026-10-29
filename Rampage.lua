-- WoW adapter only: group identity, addon channel, persistence and combat safety.
-- TOC order: Model.lua, Protocol.lua, Input.lua, Sound.lua, UI.lua, Rampage.lua.
local addonName, addon = ...
local app = { now = function() return GetTime() end }
app.VERSION = "0.1.0" -- Kept in sync with the TOC by the release packager.
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
    if IsInRaid() then
        for i = 1, math.min(40, GetNumGroupMembers()) do
            local name = unitIdentity("raid" .. i); if name then roster[name] = true end
        end
    elseif IsInGroup() then
        for i = 1, 4 do local name = unitIdentity("party" .. i); if name then roster[name] = true end end
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

local function initialize()
    if app.net then return end
    app.db = RampageDB
    local name = unitIdentity("player")
    if not name then return end
    local register = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
    local send = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    app.networkEnabled = register and send and register(addon.Protocol.PREFIX) ~= false or false
    app.net = addon.Protocol.new({ name = name, now = app.now, token = newToken,
        send = function(payload)
            local distribution = channel()
            if app.networkEnabled and distribution and #payload <= 255 then
                send(addon.Protocol.PREFIX, payload, distribution)
            end
        end,
        changed = function()
            app.persist()
            if app.input and not app.input:canPlay() then app.input:release("Game changed — keys released") end
            if app.sound then app.sound:observe(addon.UI.root and addon.UI.root:IsShown() or false) end
        end })
    app.sound = addon.Sound.create(app)
    app.refreshRoster()
    app.net:setCombat(InCombatLockdown())
    if not app.networkEnabled then app.net:notice("Addon messaging unavailable; solo practice still works.") end
end

local function showWindow()
    if not app.net or app.net.combat then return end
    addon.UI.create(app):Show(); addon.UI.render()
end
local function slash(input)
    if not app.net then localMessage("Still loading; try again after entering the world."); return end
    local command, argument = string.match(input or "", "^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    if command == "help" then
        localMessage("/rampage — toggle window. /rampage solo | host | find | join [Name-Realm] | spectate [Name-Realm] | play | start | leave")
        localMessage("Click PLAY for WASD/arrows + hold Space. Escape releases keys. Climb and smash each floor twice; flatten towers, then punch the boss. Four stages; 25 players + 15 spectators.")
        localMessage("Open window discovers lobbies; joining is opt-in. No public chat or global bindings. Combat hides/releases keys; host combat pauses everyone. Closing does not leave. Optional local BlasterMaster defaults OFF.")
    elseif command == "leave" then
        if app.input then app.input:release("Left game — keys released") end
        app.persist(); app.net:leave(); addon.UI.render()
    elseif command == "solo" then
        if app.net:solo() then showWindow() end
    elseif command == "host" then
        app.refreshRoster(); if app.net:host() then showWindow() else localMessage(app.net.status) end
    elseif command == "find" then
        app.refreshRoster(); app.net:discover(); showWindow()
    elseif command == "play" then
        if app.net.role == "spectate" and app.net.setRole then app.net:setRole("play") end
        showWindow() -- Chat commands do not capture keys: click PLAY afterward.
    elseif command == "join" or command == "spectate" then
        if command == "spectate" and app.net.mode ~= "idle" then
            if app.input then app.input:release("Spectating — keys released") end
            if app.net.setRole then app.net:setRole("spectate") end
            showWindow(); return
        end
        local chosen
        for _, lobby in ipairs(app.net:lobbyList()) do
            if argument == "" or string.lower(lobby.name) == string.lower(argument) then chosen = lobby; break end
        end
        if chosen and app.net:join(chosen.name, chosen.sid, command == "spectate" and "spectate" or "play") then showWindow()
        else localMessage("No matching recent lobby. Use /rampage find, select a host, then Join.") end
    elseif command == "start" then
        app.net:start(); showWindow()
    else
        if not addon.UI.toggle(app) then localMessage("Window and controls are disabled during combat.") end
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
        if type(RampageDB) ~= "table" then RampageDB = {} end
        if type(RampageDB.best) ~= "number" or RampageDB.best ~= RampageDB.best or RampageDB.best < 0 or RampageDB.best > 99999 then RampageDB.best = 0 end
        RampageDB.best = math.floor(RampageDB.best)
        RampageDB.useBlasterMaster = RampageDB.useBlasterMaster == true
        RampageDB.muted = RampageDB.muted == true
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
        if app.input then app.input:release("Leaving world — keys released") end
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
        app.net:tick(elapsedNet); elapsedNet = 0; app.persist()
        if app.sound then app.sound:observe(addon.UI.root and addon.UI.root:IsShown() or false) end
    end
    if elapsedUI >= 0.033 then elapsedUI = 0; addon.UI.render() end
end)
