-- API mocks are deliberately small: unknown methods fail instead of silently passing.
-- This is NOT a renderer, taint checker, protected-action simulator or actual TBC client.
Addon = {}
local frames, textures, fonts, sent, messages = {}, {}, {}, {}, {}
local now, grouped, raided, combat, loggedIn = 100, false, false, false, false
local methods = {}
local function newObject(kind, name, parent)
    local object = setmetatable({ kind = kind, name = name, parent = parent, shown = true, enabled = true,
        scripts = {}, events = {}, width = 0, height = 0, level = 1 }, { __index = methods })
    return object
end
function methods:SetPoint(...) self.point = {...} end
function methods:GetPoint()
    local p = self.point or {"CENTER"}
    return p[1], p[2] or UIParent, p[3] or p[1], p[4] or 0, p[5] or 0
end
function methods:ClearAllPoints() self.point = nil end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetFrameLevel(level) self.level = level end
function methods:GetFrameLevel() return self.level end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:IsEnabled() return self.enabled end
function methods:SetText(value) self.text = value end
function methods:GetText() return self.text end
function methods:SetColorTexture(r, g, b, a)
    assert(type(r) == "number" and type(g) == "number" and type(b) == "number")
    self.color = {r, g, b, a or 1}
end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:GetScript(event) return self.scripts[event] end
function methods:CreateTexture(name, layer)
    local t = newObject("Texture", name, self); t.layer = layer; textures[#textures + 1] = t; return t
end
function methods:CreateFontString(name, layer, template)
    local f = newObject("FontString", name, self); fonts[#fonts + 1] = f; return f
end
for _, method in ipairs({"SetFont", "SetJustifyH", "SetTextColor", "SetClampedToScreen", "SetFrameStrata",
    "EnableMouse", "SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing"}) do methods[method] = function() end end
UIParent = newObject("Frame", "UIParent")
STANDARD_TEXT_FONT = "MockFont"
SlashCmdList = {}
RampageDB = { best = -42, customKept = "yes", position = {point = "INVALID", x = 1, y = 2} }
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) messages[#messages + 1] = message end }
function CreateFrame(kind, name, parent, template)
    assert(kind == "Frame" or kind == "Button")
    assert(not template or template == "UIPanelButtonTemplate", "unexpected secure or other template")
    local f = newObject(kind, name, parent); frames[#frames + 1] = f; if name then _G[name] = f end; return f
end
function GetTime() return now end
function GetServerTime() return 1800000000 + math.floor(now) end
function GetRealmName() return "Test Realm" end
function GetNormalizedRealmName() return "TestRealm" end
function UnitFullName(unit)
    if unit == "player" or unit == "raid1" then return "Tester", "TestRealm" end
    if unit == "party1" or unit == "raid2" then return "Friend", "OtherRealm" end
    if unit == "party2" or unit == "raid3" then return "Friend", "TestRealm" end
end
function UnitName(unit) return UnitFullName(unit) end
function IsInRaid() return raided end
function IsInGroup() return grouped end
function GetNumGroupMembers() return grouped and 3 or 0 end
function InCombatLockdown() return combat end
function IsLoggedIn() return loggedIn end
C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix) assert(#prefix <= 16); return true end,
    SendAddonMessage = function(prefix, payload, distribution)
        assert(prefix == "ToastRampage1" and #payload <= 255)
        assert(distribution == "RAID" or distribution == "PARTY")
        sent[#sent + 1] = {payload = payload, distribution = distribution}
    end
}
function SendChatMessage() error("Public chat is forbidden") end
function SetBinding() error("Global keybinds are forbidden") end
function SetOverrideBinding() error("Key capture is out of MVP scope") end
function PlaySound() error("Unexpected sound") end
local function event(eventName, ...)
    for _, f in ipairs(frames) do
        if f.events[eventName] and f.scripts.OnEvent then f.scripts.OnEvent(f, eventName, ...) end
    end
end
local function step(seconds)
    for _ = 1, math.ceil(seconds / 0.05) do
        now = now + 0.05
        for _, f in ipairs(frames) do if f:IsShown() and f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.05) end end
    end
end
local function click(b)
    if b:IsShown() and b:IsEnabled() then b.scripts.OnClick(b) end
end

function runWoWSmoke()
    local app, ui = Addon.App, Addon.UI
    check("TOC/WoW mock: load-order, saved-variable sanitation and no forced window", function()
        assert(not app.net and not ui.root)
        event("ADDON_LOADED", "AnotherAddon"); assert(not app.net)
        event("ADDON_LOADED", "Rampage"); assert(SlashCmdList.RAMPAGE); eq(SLASH_RAMPAGE1, "/rampage")
        loggedIn = true; event("PLAYER_LOGIN")
        assert(app.net); eq(app.net.name, "Tester-TestRealm"); eq(RampageDB.best, 0); eq(RampageDB.customKept, "yes")
        eq(app.VERSION, "0.1.0"); assert(not ui.root); eq(#sent, 0)
    end)
    check("WoW mock: solo window, original geometry, buttons, damage and personal best", function()
        SlashCmdList.RAMPAGE("solo"); assert(ui.root:IsShown()); eq(app.net.mode, "solo")
        eq(ui.root:GetWidth(), 720); eq(#ui.monsters, 4); eq(#ui.floors, 9)
        eq(ui.root:GetPoint(), "CENTER") -- invalid persisted anchor ignored
        click(ui.controls[5]); eq(app.net.state.players[1].x, 2)
        step(0.25); click(ui.controls[3]); eq(app.net.state.hp[1], 1); eq(RampageDB.best, 10)
        assert(ui.floors[1].crack:IsShown()); step(0.25); click(ui.controls[3]); eq(app.net.state.hp[1], 0)
        assert(not ui.floors[1]:IsShown()); eq(RampageDB.best, 20); eq(#sent, 0)
    end)
    check("WoW mock: combat hides/blocks controls, restores only previously open window", function()
        local x = app.net.state.players[1].x
        combat = true; event("PLAYER_REGEN_DISABLED"); assert(not ui.root:IsShown()); assert(app.net.state.paused)
        app.net:action("R"); eq(app.net.state.players[1].x, x)
        SlashCmdList.RAMPAGE(""); assert(not ui.root:IsShown())
        step(0.3); combat = false; event("PLAYER_REGEN_ENABLED"); assert(ui.root:IsShown()); assert(not app.net.state.paused)
        SlashCmdList.RAMPAGE(""); assert(not ui.root:IsShown())
        combat = true; event("PLAYER_REGEN_DISABLED"); combat = false; event("PLAYER_REGEN_ENABLED")
        assert(not ui.root:IsShown()); SlashCmdList.RAMPAGE(""); assert(ui.root:IsShown())
    end)
    check("WoW mock: fixed frame/texture pools after 100 renders; no runtime allocations", function()
        local frameCount, textureCount, fontCount = #frames, #textures, #fonts
        for _ = 1, 100 do step(0.1); ui.render() end
        eq(#frames, frameCount); eq(#textures, textureCount); eq(#fonts, fontCount)
        print("  Fixed UI allocation fixture: " .. frameCount .. " frames, " .. textureCount .. " textures, " .. fontCount .. " font strings")
    end)
    check("WoW mock: group-channel filtering and canonical cross-realm roster identity", function()
        SlashCmdList.RAMPAGE("leave"); ui.root:Hide()
        grouped = true; event("GROUP_ROSTER_UPDATE")
        assert(app.net.roster["Friend-OtherRealm"] and app.net.roster["Friend-TestRealm"])
        event("CHAT_MSG_ADDON", "OtherPrefix", "R1|A|abc|l|1", "PARTY", "Friend-OtherRealm")
        event("CHAT_MSG_ADDON", "ToastRampage1", "R1|A|abc|l|1", "GUILD", "Friend-OtherRealm")
        event("CHAT_MSG_ADDON", "ToastRampage1", "R1|A|abc|l|1", "PARTY", "Stranger-Realm")
        eq(#app.net:lobbyList(), 0)
        event("CHAT_MSG_ADDON", "ToastRampage1", "R1|A|abc|l|1", "PARTY", "Friend-OtherRealm")
        event("CHAT_MSG_ADDON", "ToastRampage1", "R1|A|def|l|1", "PARTY", "Friend")
        eq(#app.net:lobbyList(), 2); assert(not ui.root:IsShown())
    end)
    check("WoW mock: host/start/leave slash commands use only bounded addon messages", function()
        SlashCmdList.RAMPAGE("host"); eq(app.net.mode, "host"); assert(ui.root:IsShown())
        step(0.5); assert(#sent > 0); eq(sent[#sent].distribution, "PARTY")
        SlashCmdList.RAMPAGE("start"); eq(app.net.state.phase, "play")
        raided = true; event("GROUP_ROSTER_UPDATE"); step(0.5); eq(sent[#sent].distribution, "RAID")
        combat = true; event("PLAYER_REGEN_DISABLED"); step(0.5); assert(app.net.state.paused)
        combat = false; event("PLAYER_REGEN_ENABLED"); assert(not app.net.state.paused)
        SlashCmdList.RAMPAGE("leave"); eq(app.net.mode, "idle"); eq(RampageDB.best, 20)
    end)
    check("WoW mock: join stays explicit, group departure resets, help stays local", function()
        SlashCmdList.RAMPAGE("join Friend-OtherRealm"); eq(app.net.mode, "joining")
        step(0.1); assert(string.find(sent[#sent].payload, "R1|J|abc|", 1, true))
        grouped, raided = false, false; event("GROUP_ROSTER_UPDATE"); eq(app.net.mode, "idle")
        local publicBefore = #sent; SlashCmdList.RAMPAGE("help"); assert(#messages >= 3); eq(#sent, publicBefore)
        ui.root.scripts.OnDragStop(ui.root); assert(type(RampageDB.position) == "table")
    end)
end
